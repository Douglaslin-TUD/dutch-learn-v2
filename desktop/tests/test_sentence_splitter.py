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


def _make_utterance_with_fewer_words(
    text: str, skip_indices: list[int], start: float = 0.0, speaker: str = "A"
) -> UtteranceInfo:
    """Helper: create UtteranceInfo where words list has fewer entries than text.split().

    Simulates AssemblyAI returning fewer word timestamps than text tokens,
    e.g. due to time-overlap filtering missing some words.
    """
    words = []
    t = start
    for i, w in enumerate(text.split()):
        if i in skip_indices:
            continue
        words.append(WordTimestamp(text=w, start=round(t, 3), end=round(t + 0.3, 3)))
        t += 0.35
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
        """Should split on exclamation mark followed by uppercase."""
        text = "Stop nu meteen! Ga niet verder met dat verhaal alstublieft."
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 2
        assert result[0].text == "Stop nu meteen!"

    def test_no_split_on_abbreviation(self, splitter):
        """Should NOT split on abbreviation periods (no uppercase after)."""
        # Use 9 words to stay under max_words=10 (avoids hard-split interference)
        text = "Ik ga naar de d.w.z. winkel om boodschappen"
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
        """Segments with <3 words should be merged if neighbor has room."""
        # "Ja." (1 word) + 8-word sentence = 9 words after merge, under max_words=10
        text = "Ja. Een twee drie vier vijf zes zeven acht. Negen tien elf twaalf."
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        # "Ja." should be merged with next (8 words -> 9 words, under max_words)
        for r in result:
            assert len(r.text.split()) >= 3

    def test_merge_does_not_exceed_max_words(self, splitter):
        """Merging short segments must not create segments exceeding max_words."""
        # "Ja." (1 word) + 10-word sentence + 10-word sentence = 21 words
        # Without the fix, "Ja." merges into the 10-word segment making 11 words
        text = (
            "Ja. Een twee drie vier vijf zes zeven acht negen tien. "
            "Elf twaalf dertien veertien vijftien zestien zeventien achttien negentien twintig."
        )
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        for r in result:
            assert len(r.text.split()) <= splitter.max_words, (
                f"Segment has {len(r.text.split())} words, exceeds max_words={splitter.max_words}: {r.text!r}"
            )

    def test_merge_short_segment_kept_when_neighbors_full(self, splitter):
        """Short segment should be kept as-is if merging would exceed max_words."""
        text = (
            "Aaa bbb ccc ddd eee fff ggg hhh iii jjj. "
            "Ok. "
            "Kkk lll mmm nnn ooo ppp qqq rrr sss ttt."
        )
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        # "Ok." is 1 word. First seg is 10, last seg is 10.
        # Merging "Ok." into either would make 11 > max_words=10.
        # So "Ok." should be kept as standalone segment.
        assert any(r.text == "Ok." for r in result), (
            f"Expected standalone 'Ok.' segment but got: {[r.text for r in result]}"
        )

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
        short = _make_utterance("Hallo daar vriend.", start=0.0)
        long_text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf dertien."
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

    # --- Word count mismatch (C3 concern) ---

    def test_word_count_mismatch_no_drift(self, splitter):
        """When words list has fewer entries than text.split(), timestamps should not drift.

        This tests the C3 concern: AssemblyAI's word timestamps may not match
        Python's str.split() tokenization, causing word-to-segment misalignment.
        """
        text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf."
        # Skip words at indices 3 and 7 to simulate AssemblyAI missing some words
        utt = _make_utterance_with_fewer_words(text, skip_indices=[3, 7])

        assert len(utt.words) == 10  # 12 - 2 skipped
        assert len(text.split()) == 12

        result = splitter.split_utterances([utt])
        assert len(result) == 2

        # The last segment should get all remaining words (not have them stolen by first)
        # With the fix, the last segment gets leftover words instead of
        # being short-changed by strict text.split() counting
        total_words_assigned = sum(len(r.words) for r in result)
        assert total_words_assigned == len(utt.words), (
            f"Total words assigned ({total_words_assigned}) != original words ({len(utt.words)})"
        )

    def test_word_count_mismatch_last_segment_gets_remainder(self, splitter):
        """Last segment should receive all remaining word timestamps."""
        text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf."
        # Create utterance with only 8 word timestamps (4 missing)
        utt = _make_utterance_with_fewer_words(text, skip_indices=[2, 4, 8, 10])

        assert len(utt.words) == 8
        result = splitter.split_utterances([utt])
        assert len(result) == 2

        # Last segment should have remaining words, not be empty
        assert len(result[-1].words) > 0

    # --- Empty words list ---

    def test_empty_words_list_uses_fallback_timestamps(self, splitter):
        """Utterance with empty words list should use original start/end as fallback."""
        text = "Een twee drie vier vijf zes. Zeven acht negen tien elf twaalf."
        utt = UtteranceInfo(
            text=text, start=1.0, end=5.0, speaker_label="A", words=[]
        )
        result = splitter.split_utterances([utt])
        # With empty words, all segments should fall back to original timestamps
        assert result[0].start == 1.0
        assert result[-1].end == 5.0

    # --- Single word utterance ---

    def test_single_word_utterance_unchanged(self, splitter):
        """Single word utterance should pass through unchanged."""
        utt = _make_utterance("Ja")
        result = splitter.split_utterances([utt])
        assert len(result) == 1
        assert result[0].text == "Ja"
