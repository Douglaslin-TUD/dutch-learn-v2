# desktop/tests/test_audio_utils.py
"""Tests for audio router utility functions (desktop/app/routers/audio.py)."""

import pytest

from app.routers.audio import get_content_type, parse_range_header


class TestGetContentType:
    """Tests for the get_content_type function."""

    def test_mp3(self):
        assert get_content_type("audio.mp3") == "audio/mpeg"

    def test_wav(self):
        assert get_content_type("audio.wav") == "audio/wav"

    def test_m4a(self):
        assert get_content_type("audio.m4a") == "audio/mp4"

    def test_flac(self):
        assert get_content_type("audio.flac") == "audio/flac"

    def test_ogg(self):
        assert get_content_type("audio.ogg") == "audio/ogg"

    def test_unknown_defaults_to_audio_mpeg(self):
        """Unknown extensions default to audio/mpeg."""
        assert get_content_type("file.xyz") == "audio/mpeg"

    def test_case_insensitive(self):
        """Extension matching should be case-insensitive."""
        assert get_content_type("audio.MP3") == "audio/mpeg"
        assert get_content_type("audio.FLAC") == "audio/flac"

    def test_path_with_directory(self):
        """Should work with paths containing directories."""
        assert get_content_type("/some/path/audio.wav") == "audio/wav"


class TestParseRangeHeader:
    """Tests for the parse_range_header function."""

    def test_valid_range(self):
        """Standard byte range should be parsed correctly."""
        start, end = parse_range_header("bytes=0-999", 5000)
        assert start == 0
        assert end == 999

    def test_open_ended_range(self):
        """Open-ended range (bytes=1000-) should go to end of file."""
        start, end = parse_range_header("bytes=1000-", 5000)
        assert start == 1000
        assert end == 4999

    def test_end_clamped_to_file_size(self):
        """End byte should be clamped to file_size - 1."""
        start, end = parse_range_header("bytes=0-9999", 5000)
        assert start == 0
        assert end == 4999

    def test_start_equals_end(self):
        """A range requesting a single byte should work."""
        start, end = parse_range_header("bytes=100-100", 5000)
        assert start == 100
        assert end == 100

    def test_invalid_range_start_exceeds_file_size(self):
        """When start >= file_size, ValueError should be raised."""
        with pytest.raises(ValueError, match="Invalid range"):
            parse_range_header("bytes=5000-6000", 5000)

    def test_invalid_range_format_no_bytes_prefix(self):
        """Missing 'bytes=' prefix should raise ValueError."""
        with pytest.raises(ValueError, match="Invalid range header format"):
            parse_range_header("0-999", 5000)

    def test_invalid_range_format_no_dash(self):
        """Missing dash separator should raise ValueError."""
        with pytest.raises(ValueError, match="Invalid range header format"):
            parse_range_header("bytes=999", 5000)

    def test_full_file_range(self):
        """Requesting the full file range should return (0, file_size-1)."""
        start, end = parse_range_header("bytes=0-4999", 5000)
        assert start == 0
        assert end == 4999

    def test_suffix_range_treated_as_zero_start(self):
        """bytes=-500 with empty start_str is treated as start=0."""
        # The actual implementation: empty start_str -> start=0, end=min(500,4999)=500
        start, end = parse_range_header("bytes=-500", 5000)
        assert start == 0
        assert end == 500
