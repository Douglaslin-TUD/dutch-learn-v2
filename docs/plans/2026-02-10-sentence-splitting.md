# Sentence Splitting Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split long transcription utterances (>100 words) into shorter sentences for easier learning, using AssemblyAI word-level timestamps for precise audio alignment.

**Architecture:** A pure-logic `SentenceSplitter` service inserted between AssemblyAI transcription parsing and database storage. Captures word-level timestamps from AssemblyAI's transcript response, attaches them to utterances, then splits any utterance exceeding `max_sentence_words` using punctuation-based boundaries with timestamp precision.

**Tech Stack:** Python 3, AssemblyAI SDK (`assemblyai`), pytest, dataclasses

---

## Task 1: Add `max_sentence_words` config setting

**Files:**
- Modify: `desktop/app/config.py:44` (add setting after `max_retries`)

**Step 1: Add the setting**

In `desktop/app/config.py`, add after line 44 (`max_retries: int = 3`):

```python
    max_sentence_words: int = 100
```

**Step 2: Verify**

Run: `cd desktop && source ../venv/bin/activate && python -c "from app.config import settings; print(f'max_sentence_words={settings.max_sentence_words}')"`

Expected: `max_sentence_words=100`

**Step 3: Commit**

```bash
git add desktop/app/config.py
git commit -m "feat(desktop): add max_sentence_words config setting"
```

---

## Task 2: Add `WordTimestamp` dataclass and `words` field to `UtteranceInfo`

**Files:**
- Modify: `desktop/app/services/assemblyai_transcriber.py:9,32-38`

**Step 1: Add `WordTimestamp` dataclass**

In `desktop/app/services/assemblyai_transcriber.py`, add after the `SpeakerInfo` dataclass (after line 29):

```python
@dataclass
class WordTimestamp:
    """Timestamp information for a single word."""
    text: str
    start: float  # seconds
    end: float    # seconds
```

**Step 2: Add `words` field to `UtteranceInfo`**

Update the `UtteranceInfo` dataclass (lines 33-38) to include a `words` field:

```python
@dataclass
class UtteranceInfo:
    """Information about a single utterance."""
    text: str
    start: float
    end: float
    speaker_label: str
    words: List[WordTimestamp] = field(default_factory=list)
```

Add `field` to the import on line 9:

```python
from dataclasses import dataclass, field
```

**Step 3: Verify**

Run: `cd desktop && source ../venv/bin/activate && python -c "from app.services.assemblyai_transcriber import UtteranceInfo, WordTimestamp; print('OK')"`

Expected: `OK`

**Step 4: Commit**

```bash
git add desktop/app/services/assemblyai_transcriber.py
git commit -m "feat(desktop): add WordTimestamp dataclass and words field to UtteranceInfo"
```

---

## Task 3: Capture word-level timestamps in `_parse_transcript()`

**Files:**
- Modify: `desktop/app/services/assemblyai_transcriber.py:138-177`

**Step 1: Update `_parse_transcript()` to capture words**

Replace the `_parse_transcript()` method. The key changes are:
1. Build a list of all words from `transcript.words` with timestamps
2. Group words into utterances by matching time ranges
3. Attach matched words to each `UtteranceInfo`

```python
    def _parse_transcript(self, transcript: aai.Transcript) -> TranscriptionResult:
        """Parse AssemblyAI transcript into our data structures."""

        # Build word timestamps from transcript.words
        all_words = []
        if transcript.words:
            for w in transcript.words:
                all_words.append(WordTimestamp(
                    text=w.text,
                    start=w.start / 1000.0,
                    end=w.end / 1000.0,
                ))

        # Extract speakers and utterances
        speaker_labels = set()
        speaker_utterances: Dict[str, List[str]] = {}

        utterances = []

        if transcript.utterances:
            for utt in transcript.utterances:
                speaker_label = utt.speaker or "A"
                speaker_labels.add(speaker_label)

                # Collect utterances for evidence
                if speaker_label not in speaker_utterances:
                    speaker_utterances[speaker_label] = []
                speaker_utterances[speaker_label].append(utt.text)

                utt_start = utt.start / 1000.0
                utt_end = utt.end / 1000.0

                # Match words to this utterance by time overlap
                utt_words = [
                    w for w in all_words
                    if w.start >= utt_start - 0.01 and w.end <= utt_end + 0.01
                ]

                utterances.append(UtteranceInfo(
                    text=utt.text,
                    start=utt_start,
                    end=utt_end,
                    speaker_label=speaker_label,
                    words=utt_words,
                ))

        # Build speaker info
        speakers = []
        for label in sorted(speaker_labels):
            evidence = speaker_utterances.get(label, [])[:5]

            speakers.append(SpeakerInfo(
                label=label,
                display_name=None,
                confidence=0.0,
                evidence=evidence,
            ))

        return TranscriptionResult(speakers=speakers, utterances=utterances)
```

**Step 2: Verify**

Run: `cd desktop && source ../venv/bin/activate && python -c "from app.services.assemblyai_transcriber import AssemblyAITranscriber; print('Import OK')"`

Expected: `Import OK`

**Step 3: Commit**

```bash
git add desktop/app/services/assemblyai_transcriber.py
git commit -m "feat(desktop): capture word-level timestamps from AssemblyAI transcript"
```

---

## Task 4: Write tests for SentenceSplitter

**Files:**
- Create: `desktop/tests/test_sentence_splitter.py`

**Step 1: Write the test file**

```python
"""Tests for desktop/app/services/sentence_splitter.py."""

import pytest

from app.services.assemblyai_transcriber import UtteranceInfo, WordTimestamp
from app.services.sentence_splitter import SentenceSplitter


def _make_words(text: str, start: float = 0.0, word_duration: float = 0.3) -> list[WordTimestamp]:
    """Helper: create WordTimestamp list from text, evenly spaced."""
    words = []
    t = start
    for w in text.split():
        words.append(WordTimestamp(text=w, start=round(t, 3), end=round(t + word_duration, 3)))
        t += word_duration + 0.05  # small gap between words
    return words


def _make_utterance(text: str, start: float = 0.0, speaker: str = "A") -> UtteranceInfo:
    """Helper: create UtteranceInfo with auto-generated word timestamps."""
    words = _make_words(text, start)
    end = words[-1].end if words else start
    return UtteranceInfo(text=text, start=start, end=end, speaker_label=speaker, words=words)


class TestSentenceSplitter:
    """Tests for the SentenceSplitter class."""

    @pytest.fixture
    def splitter(self):
        return SentenceSplitter(max_words=10)  # Use 10 for easier testing

    # --- No splitting needed ---

    def test_short_utterance_unchanged(self, splitter):
        """Utterance under max_words should pass through unchanged."""
        utt = _make_utterance("Hallo wereld.")
        result = splitter.split_utterances([utt])
        assert len(result) == 1
        assert result[0].text == "Hallo wereld."

    def test_exact_max_words_not_split(self, splitter):
        """Utterance with exactly max_words should not be split."""
        text = " ".join(f"woord{i}" for i in range(10))
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 1

    def test_empty_list(self, splitter):
        """Empty input should return empty output."""
        assert splitter.split_utterances([]) == []

    # --- Sentence boundary splitting ---

    def test_split_on_period(self, splitter):
        """Should split on period followed by space and uppercase."""
        text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf."
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 2
        assert result[0].text == "Een twee drie vier vijf zes."
        assert result[1].text == "Zeven acht negen tien elf twaalf."

    def test_split_on_question_mark(self, splitter):
        """Should split on question mark followed by space and uppercase."""
        text = "Wat is dat? Dat is een heel lang verhaal over Nederland."
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 2
        assert result[0].text == "Wat is dat?"

    def test_split_on_exclamation(self, splitter):
        """Should split on exclamation mark."""
        text = "Stop nu! Ga niet verder met dat verhaal alstublieft."
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 2

    def test_no_split_on_abbreviation(self, splitter):
        """Should NOT split on abbreviation periods (no uppercase after)."""
        text = "Ik ga naar de d.w.z. winkel om boodschappen te doen vandaag"
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 1

    # --- Clause boundary splitting ---

    def test_split_on_comma_when_no_sentence_boundary(self, splitter):
        """Should split on comma when no sentence-ending punctuation available."""
        text = "een twee drie vier vijf zes zeven, acht negen tien elf twaalf"
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 2
        assert result[0].text == "een twee drie vier vijf zes zeven,"
        assert result[1].text == "acht negen tien elf twaalf"

    def test_clause_split_picks_closest_to_midpoint(self, splitter):
        """When multiple comma positions, pick closest to midpoint."""
        # 12 words, commas at word 3 and word 8
        text = "een twee drie, vier vijf zes zeven acht, negen tien elf twaalf"
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 2
        # Midpoint is word 6, comma at word 8 (after "acht,") is closer
        assert "acht," in result[0].text

    # --- Hard word split ---

    def test_hard_split_no_punctuation(self, splitter):
        """No punctuation at all should trigger hard split at max_words."""
        text = " ".join(f"woord{i}" for i in range(15))
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 2
        assert len(result[0].text.split()) == 10
        assert len(result[1].text.split()) == 5

    # --- Short segment merging ---

    def test_short_segment_merged_back(self, splitter):
        """Segments with <3 words should be merged with adjacent segment."""
        text = "Ja. Een twee drie vier vijf zes zeven acht negen tien twaalf."
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        # "Ja." is only 1 word, should be merged with next segment
        assert len(result) == 1 or all(len(r.text.split()) >= 3 for r in result)

    # --- Timestamp precision ---

    def test_split_preserves_original_start_end(self, splitter):
        """First segment should start at original start, last at original end."""
        text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf."
        utt = _make_utterance(text, start=5.0)
        result = splitter.split_utterances([utt])
        assert result[0].start == utt.start
        assert result[-1].end == utt.end

    def test_split_timestamps_from_words(self, splitter):
        """Split segments should get timestamps from their word boundaries."""
        text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf."
        utt = _make_utterance(text, start=5.0)
        result = splitter.split_utterances([utt])
        assert len(result) == 2
        # Second segment start should be >= first segment end
        assert result[1].start >= result[0].end

    # --- Speaker preservation ---

    def test_split_preserves_speaker_label(self, splitter):
        """All split segments should keep the original speaker label."""
        text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf."
        utt = _make_utterance(text, speaker="B")
        result = splitter.split_utterances([utt])
        for r in result:
            assert r.speaker_label == "B"

    # --- Multiple utterances ---

    def test_mixed_short_and_long(self, splitter):
        """Short utterances pass through, long ones get split."""
        short = _make_utterance("Hallo.", start=0.0)
        long_text = "Een twee drie vier vijf zes zeven acht negen tien elf twaalf."
        long_utt = _make_utterance(long_text, start=2.0)
        result = splitter.split_utterances([short, long_utt])
        assert len(result) >= 3  # 1 short + at least 2 from split

    # --- Words list carried through ---

    def test_split_segments_have_words(self, splitter):
        """Each split segment should have its own words list."""
        text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf."
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        for r in result:
            assert len(r.words) > 0
            # Words text joined should roughly match segment text
            words_text = " ".join(w.text for w in r.words)
            # Strip punctuation for comparison
            assert len(words_text.split()) == len(r.text.split())
```

**Step 2: Run tests to verify they fail**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/test_sentence_splitter.py -v 2>&1 | tail -5`

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.sentence_splitter'`

**Step 3: Commit**

```bash
git add desktop/tests/test_sentence_splitter.py
git commit -m "test(desktop): add tests for SentenceSplitter"
```

---

## Task 5: Implement SentenceSplitter

**Files:**
- Create: `desktop/app/services/sentence_splitter.py`

**Step 1: Create the implementation**

```python
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
CLAUSE_BOUNDARY_CHARS = {',', ';', ':', '—', '–'}

MIN_SEGMENT_WORDS = 3


class SentenceSplitter:
    """
    Splits long utterances into shorter segments.

    Strategy:
    1. Split on sentence-ending punctuation (. ? !) where followed by uppercase
    2. Split remaining long segments on clause boundaries (, ; : —)
    3. Hard split at max_words as last resort
    """

    def __init__(self, max_words: int = 100):
        self.max_words = max_words

    def split_utterances(self, utterances: List[UtteranceInfo]) -> List[UtteranceInfo]:
        """Split any utterance exceeding max_words into shorter segments."""
        result = []
        for utt in utterances:
            word_count = len(utt.text.split())
            if word_count <= self.max_words:
                result.append(utt)
            else:
                segments = self._split_utterance(utt)
                result.extend(segments)
        return result

    def _split_utterance(self, utt: UtteranceInfo) -> List[UtteranceInfo]:
        """Split a single long utterance into multiple shorter ones."""
        # Step 1: Split on sentence boundaries
        raw_segments = SENTENCE_BOUNDARY_RE.split(utt.text)
        raw_segments = [s.strip() for s in raw_segments if s.strip()]

        # Step 2: Split any still-long segments on clause boundaries
        refined = []
        for seg in raw_segments:
            if len(seg.split()) > self.max_words:
                refined.extend(self._split_on_clauses(seg))
            else:
                refined.append(seg)

        # Step 3: Hard-split any still-long segments
        final_texts = []
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
        """Split text on clause boundary punctuation, picking closest to midpoint."""
        words = text.split()
        total = len(words)

        if total <= self.max_words:
            return [text]

        # Find clause boundary positions (word index where word ends with clause punct)
        boundary_positions = []
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
        result = []
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
        """Split text at exactly max_words boundary."""
        words = text.split()
        segments = []
        for i in range(0, len(words), self.max_words):
            segment = " ".join(words[i:i + self.max_words])
            if segment:
                segments.append(segment)
        return segments

    def _merge_short_segments(self, segments: List[str]) -> List[str]:
        """Merge segments with fewer than MIN_SEGMENT_WORDS into neighbors."""
        if len(segments) <= 1:
            return segments

        merged = []
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
        """Map text segments back to UtteranceInfo objects with word timestamps."""
        words = original.words
        utterances = []
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
```

**Step 2: Run tests to verify they pass**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/test_sentence_splitter.py -v 2>&1 | tail -25`

Expected: All tests PASS

**Step 3: Fix any failures and re-run until green**

**Step 4: Commit**

```bash
git add desktop/app/services/sentence_splitter.py
git commit -m "feat(desktop): implement SentenceSplitter with punctuation-based splitting"
```

---

## Task 6: Wire SentenceSplitter into Processor pipeline

**Files:**
- Modify: `desktop/app/services/processor.py:15-20,160-175`

**Step 1: Add imports**

In `desktop/app/services/processor.py`, add after line 20 (the last import):

```python
from app.services.sentence_splitter import SentenceSplitter
```

**Step 2: Update `_transcribe_audio()` to split utterances**

In `_transcribe_audio()`, after getting the transcription result (line 141) and before the `try` block (line 144), add the splitting step:

Replace lines 161-175 (from `# Create Sentence records` to `project.total_sentences`):

```python
                # Split long utterances
                splitter = SentenceSplitter(max_words=settings.max_sentence_words)
                split_utterances = splitter.split_utterances(result.utterances)

                # Create Sentence records
                for idx, utterance in enumerate(split_utterances):
                    sentence = Sentence(
                        id=str(uuid.uuid4()),
                        project_id=project.id,
                        idx=idx,
                        text=utterance.text,
                        start_time=utterance.start,
                        end_time=utterance.end,
                        speaker_id=speaker_map.get(utterance.speaker_label),
                    )
                    db.add(sentence)

                # Update project
                project.total_sentences = len(split_utterances)
```

**Step 3: Verify**

Run: `cd desktop && source ../venv/bin/activate && python -c "from app.services.processor import Processor; print('Import OK')"`

Expected: `Import OK`

**Step 4: Run all existing tests**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -v 2>&1 | tail -10`

Expected: All tests pass (existing + new)

**Step 5: Commit**

```bash
git add desktop/app/services/processor.py
git commit -m "feat(desktop): wire SentenceSplitter into processing pipeline"
```

---

## Task 7: Final verification

**Step 1: Run full test suite**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -v 2>&1 | tail -15`

Expected: All tests pass

**Step 2: Verify imports work end-to-end**

Run: `cd desktop && source ../venv/bin/activate && python -c "
from app.config import settings
from app.services.sentence_splitter import SentenceSplitter
from app.services.assemblyai_transcriber import UtteranceInfo, WordTimestamp

# Quick integration smoke test
splitter = SentenceSplitter(max_words=settings.max_sentence_words)
words = [WordTimestamp(text=f'word{i}', start=i*0.5, end=i*0.5+0.4) for i in range(150)]
utt = UtteranceInfo(
    text=' '.join(w.text for w in words),
    start=0.0,
    end=words[-1].end,
    speaker_label='A',
    words=words,
)
result = splitter.split_utterances([utt])
print(f'Input: 1 utterance with 150 words')
print(f'Output: {len(result)} segments')
for i, r in enumerate(result):
    print(f'  Segment {i}: {len(r.text.split())} words, {r.start:.1f}s - {r.end:.1f}s')
assert all(len(r.text.split()) <= 100 for r in result)
print('All segments <= 100 words: OK')
"`

Expected: 2 segments, each ≤100 words, with correct timestamps

**Step 3: Commit**

```bash
git commit --allow-empty -m "chore: sentence splitting feature complete and verified"
```
