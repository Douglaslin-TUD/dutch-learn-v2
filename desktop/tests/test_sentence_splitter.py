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
        """Should split on exclamation mark followed by uppercase."""
        text = "Stop nu meteen! Ga niet verder met dat verhaal alstublieft."
        utt = _make_utterance(text)
        result = splitter.split_utterances([utt])
        assert len(result) == 2
        assert result[0].text == "Stop nu meteen!"

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
        for r in result:
            assert len(r.text.split()) >= 3

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
