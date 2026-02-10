"""
Service for splitting long utterances into shorter sentences.

Splits on natural boundaries (sentence-ending punctuation, clause boundaries)
and uses word-level timestamps from AssemblyAI for precise audio alignment.
"""

import re
from typing import List

from app.services.assemblyai_transcriber import UtteranceInfo, WordTimestamp


# Sentence-ending punctuation followed by space and uppercase letter
SENTENCE_BOUNDARY_RE = re.compile(r'(?<=[.!?])\s+(?=[A-Z])')

# Clause boundary punctuation
CLAUSE_BOUNDARY_CHARS = {',', ';', ':', '\u2014', '\u2013'}

MIN_SEGMENT_WORDS = 3


class SentenceSplitter:
    """
    Splits long utterances into shorter segments.

    Strategy:
    1. Split on sentence-ending punctuation (. ? !) where followed by uppercase
    2. Split remaining long segments on clause boundaries (, ; : ---)
    3. Hard split at max_words as last resort

    Args:
        max_words: Maximum number of words per segment before splitting.
    """

    def __init__(self, max_words: int = 100):
        self.max_words = max_words

    def split_utterances(self, utterances: List[UtteranceInfo]) -> List[UtteranceInfo]:
        """
        Split utterances into shorter segments.

        Always splits on sentence boundaries (. ? ! followed by uppercase).
        Additionally splits on clause boundaries or hard word limits for
        segments that exceed max_words.

        Args:
            utterances: List of utterances to process.

        Returns:
            List of utterances split at natural boundaries.
        """
        result: List[UtteranceInfo] = []
        for utt in utterances:
            segments = self._split_utterance(utt)
            result.extend(segments)
        return result

    def _split_utterance(self, utt: UtteranceInfo) -> List[UtteranceInfo]:
        """Split a single long utterance into multiple shorter ones."""
        # Step 1: Always split on sentence boundaries (. ? ! followed by uppercase)
        raw_segments = SENTENCE_BOUNDARY_RE.split(utt.text)
        raw_segments = [s.strip() for s in raw_segments if s.strip()]

        # Step 2: Split any still-long segments on clause boundaries
        refined: List[str] = []
        for seg in raw_segments:
            if len(seg.split()) > self.max_words:
                refined.extend(self._split_on_clauses(seg))
            else:
                refined.append(seg)

        # Step 3: Hard-split any still-long segments
        final_texts: List[str] = []
        for seg in refined:
            if len(seg.split()) > self.max_words:
                final_texts.extend(self._hard_split(seg))
            else:
                final_texts.append(seg)

        # Step 4: Merge short segments (<MIN_SEGMENT_WORDS) with neighbors
        final_texts = self._merge_short_segments(final_texts)

        # If we ended up with just one segment, return original
        if len(final_texts) <= 1:
            return [utt]

        # Map text segments to word timestamps and create new UtteranceInfos
        return self._map_to_utterances(final_texts, utt)

    def _split_on_clauses(self, text: str) -> List[str]:
        """
        Split text on clause boundary punctuation, picking closest to midpoint.

        Args:
            text: Text to split on clause boundaries.

        Returns:
            List of text segments split at clause boundaries.
        """
        words = text.split()
        total = len(words)

        if total <= self.max_words:
            return [text]

        # Find clause boundary positions (word index where word ends with clause punct)
        boundary_positions: List[int] = []
        for i, word in enumerate(words):
            if word and word[-1] in CLAUSE_BOUNDARY_CHARS:
                boundary_positions.append(i)

        if not boundary_positions:
            return [text]  # No clause boundaries found

        # Pick split point closest to midpoint
        midpoint = total // 2
        best_pos = min(boundary_positions, key=lambda p: abs(p - midpoint))

        left = " ".join(words[:best_pos + 1])
        right = " ".join(words[best_pos + 1:])

        # Recursively split if still too long
        result: List[str] = []
        if len(left.split()) > self.max_words:
            result.extend(self._split_on_clauses(left))
        else:
            result.append(left)

        if right and len(right.split()) > self.max_words:
            result.extend(self._split_on_clauses(right))
        elif right:
            result.append(right)

        return result

    def _hard_split(self, text: str) -> List[str]:
        """
        Split text at exactly max_words boundary.

        Args:
            text: Text to hard-split.

        Returns:
            List of text segments, each with at most max_words words.
        """
        words = text.split()
        segments: List[str] = []
        for i in range(0, len(words), self.max_words):
            segment = " ".join(words[i:i + self.max_words])
            if segment:
                segments.append(segment)
        return segments

    def _merge_short_segments(self, segments: List[str]) -> List[str]:
        """
        Merge segments with fewer than MIN_SEGMENT_WORDS into neighbors.

        Args:
            segments: List of text segments to merge.

        Returns:
            List of segments where short ones have been merged with neighbors.
        """
        if len(segments) <= 1:
            return segments

        merged: List[str] = []
        i = 0
        while i < len(segments):
            seg = segments[i]
            if len(seg.split()) < MIN_SEGMENT_WORDS:
                if merged:
                    # Merge with previous
                    merged[-1] = merged[-1] + " " + seg
                elif i + 1 < len(segments):
                    # Merge with next
                    segments[i + 1] = seg + " " + segments[i + 1]
                else:
                    merged.append(seg)
            else:
                merged.append(seg)
            i += 1

        return merged

    def _map_to_utterances(
        self, texts: List[str], original: UtteranceInfo
    ) -> List[UtteranceInfo]:
        """
        Map text segments back to UtteranceInfo objects with word timestamps.

        Args:
            texts: List of text segments from splitting.
            original: The original UtteranceInfo being split.

        Returns:
            List of new UtteranceInfo objects with correct timestamps and words.
        """
        words = original.words
        utterances: List[UtteranceInfo] = []
        word_idx = 0

        for text in texts:
            seg_word_count = len(text.split())

            # Get the words for this segment
            seg_words = words[word_idx:word_idx + seg_word_count]
            word_idx += seg_word_count

            if seg_words:
                start = seg_words[0].start
                end = seg_words[-1].end
            else:
                # Fallback: estimate from original
                start = original.start
                end = original.end

            utterances.append(UtteranceInfo(
                text=text,
                start=start,
                end=end,
                speaker_label=original.speaker_label,
                words=seg_words,
            ))

        # Ensure first segment starts at original start, last ends at original end
        if utterances:
            utterances[0] = UtteranceInfo(
                text=utterances[0].text,
                start=original.start,
                end=utterances[0].end,
                speaker_label=utterances[0].speaker_label,
                words=utterances[0].words,
            )
            utterances[-1] = UtteranceInfo(
                text=utterances[-1].text,
                start=utterances[-1].start,
                end=original.end,
                speaker_label=utterances[-1].speaker_label,
                words=utterances[-1].words,
            )

        return utterances
