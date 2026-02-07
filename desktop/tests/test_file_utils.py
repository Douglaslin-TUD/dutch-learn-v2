# desktop/tests/test_file_utils.py
"""Tests for desktop/app/utils/file_utils.py."""

import pytest
from pathlib import Path
from unittest.mock import patch, PropertyMock

from app.utils.file_utils import (
    FileValidationError,
    get_file_extension,
    validate_file_extension,
    validate_file_size,
    is_video_file,
    is_audio_file,
    generate_unique_filename,
    get_audio_filename,
    get_upload_path,
    get_audio_path,
    cleanup_file,
    cleanup_project_files,
    ensure_file_exists,
)


class TestGetFileExtension:
    """Tests for get_file_extension()."""

    def test_mp3(self):
        assert get_file_extension("song.mp3") == ".mp3"

    def test_uppercase(self):
        assert get_file_extension("VIDEO.MKV") == ".mkv"

    def test_no_extension(self):
        assert get_file_extension("noext") == ""

    def test_double_extension(self):
        assert get_file_extension("archive.tar.gz") == ".gz"

    def test_dotfile(self):
        assert get_file_extension(".gitignore") == ""

    def test_path_with_directories(self):
        assert get_file_extension("some/path/to/file.wav") == ".wav"


class TestValidateFileExtension:
    """Tests for validate_file_extension()."""

    def test_valid_audio(self):
        assert validate_file_extension("track.mp3") is True
        assert validate_file_extension("track.wav") is True
        assert validate_file_extension("track.m4a") is True
        assert validate_file_extension("track.flac") is True

    def test_valid_video(self):
        assert validate_file_extension("clip.mp4") is True
        assert validate_file_extension("clip.mkv") is True
        assert validate_file_extension("clip.avi") is True
        assert validate_file_extension("clip.webm") is True
        assert validate_file_extension("clip.mov") is True

    def test_invalid_raises_error(self):
        with pytest.raises(FileValidationError, match="Unsupported file type"):
            validate_file_extension("doc.pdf")
        with pytest.raises(FileValidationError, match="Unsupported file type"):
            validate_file_extension("img.jpg")

    def test_case_insensitive(self):
        assert validate_file_extension("track.MP3") is True
        assert validate_file_extension("clip.MKV") is True

    def test_no_extension_raises_error(self):
        with pytest.raises(FileValidationError):
            validate_file_extension("noext")


class TestValidateFileSize:
    """Tests for validate_file_size()."""

    def test_within_limit(self):
        assert validate_file_size(1000) is True

    def test_at_limit(self):
        assert validate_file_size(524288000) is True

    def test_over_limit_raises_error(self):
        with pytest.raises(FileValidationError, match="File too large"):
            validate_file_size(524288001)

    def test_zero(self):
        assert validate_file_size(0) is True

    def test_one_byte(self):
        assert validate_file_size(1) is True


class TestIsVideoFile:
    """Tests for is_video_file()."""

    def test_video_extensions(self):
        assert is_video_file("clip.mp4") is True
        assert is_video_file("clip.mkv") is True
        assert is_video_file("clip.avi") is True
        assert is_video_file("clip.webm") is True
        assert is_video_file("clip.mov") is True

    def test_audio_is_not_video(self):
        assert is_video_file("track.mp3") is False
        assert is_video_file("track.flac") is False

    def test_unknown_is_not_video(self):
        assert is_video_file("doc.pdf") is False

    def test_case_insensitive(self):
        assert is_video_file("CLIP.MP4") is True


class TestIsAudioFile:
    """Tests for is_audio_file()."""

    def test_audio_extensions(self):
        assert is_audio_file("track.mp3") is True
        assert is_audio_file("track.wav") is True
        assert is_audio_file("track.m4a") is True
        assert is_audio_file("track.flac") is True

    def test_video_is_not_audio(self):
        assert is_audio_file("clip.mp4") is False
        assert is_audio_file("clip.mkv") is False

    def test_unknown_is_not_audio(self):
        assert is_audio_file("doc.pdf") is False

    def test_case_insensitive(self):
        assert is_audio_file("TRACK.WAV") is True


class TestGenerateUniqueFilename:
    """Tests for generate_unique_filename()."""

    def test_preserves_extension(self):
        result = generate_unique_filename("song.mp3")
        assert result.endswith(".mp3")

    def test_unique(self):
        a = generate_unique_filename("song.mp3")
        b = generate_unique_filename("song.mp3")
        assert a != b

    def test_with_prefix(self):
        result = generate_unique_filename("song.mp3", prefix="audio")
        assert result.startswith("audio_")
        assert result.endswith(".mp3")

    def test_without_prefix(self):
        result = generate_unique_filename("video.mp4")
        assert "_" not in result or result.count("_") == 0
        # Without prefix, format is {uuid8}.ext - no underscore prefix
        assert result.endswith(".mp4")

    def test_uppercase_extension_normalized(self):
        result = generate_unique_filename("SONG.MP3")
        assert result.endswith(".mp3")


class TestGetAudioFilename:
    """Tests for get_audio_filename()."""

    def test_format(self):
        result = get_audio_filename("abc-123")
        assert result == "abc-123.mp3"

    def test_uuid_format(self):
        project_id = "550e8400-e29b-41d4-a716-446655440000"
        result = get_audio_filename(project_id)
        assert result == f"{project_id}.mp3"


class TestGetUploadPath:
    """Tests for get_upload_path()."""

    def test_returns_path_in_upload_dir(self):
        from app.config import settings
        result = get_upload_path("test.mp3")
        assert result == settings.upload_dir / "test.mp3"
        assert isinstance(result, Path)


class TestGetAudioPath:
    """Tests for get_audio_path()."""

    def test_returns_path_in_audio_dir(self):
        from app.config import settings
        result = get_audio_path("test.mp3")
        assert result == settings.audio_dir / "test.mp3"
        assert isinstance(result, Path)


class TestCleanupFile:
    """Tests for cleanup_file()."""

    def test_cleanup_existing(self, tmp_path):
        f = tmp_path / "temp.txt"
        f.write_text("data")
        assert cleanup_file(f) is True
        assert not f.exists()

    def test_cleanup_nonexistent(self, tmp_path):
        f = tmp_path / "missing.txt"
        assert cleanup_file(f) is False

    def test_cleanup_oserror_returns_false(self, tmp_path):
        """When unlink raises OSError, cleanup_file returns False."""
        f = tmp_path / "locked.txt"
        f.write_text("data")
        with patch.object(Path, "unlink", side_effect=OSError("Permission denied")):
            assert cleanup_file(f) is False


class TestCleanupProjectFiles:
    """Tests for cleanup_project_files()."""

    def test_cleanup_both_files(self, tmp_path):
        from app.config import settings

        original = "upload.mp4"
        audio = "audio.mp3"

        # Create temporary files
        upload_file = settings.upload_dir / original
        audio_file = settings.audio_dir / audio
        upload_file.parent.mkdir(parents=True, exist_ok=True)
        audio_file.parent.mkdir(parents=True, exist_ok=True)
        upload_file.write_text("video data")
        audio_file.write_text("audio data")

        cleanup_project_files(original, audio)

        assert not upload_file.exists()
        assert not audio_file.exists()

    def test_cleanup_none_values(self):
        """Passing None for both files should not raise."""
        cleanup_project_files(None, None)

    def test_cleanup_only_original(self, tmp_path):
        from app.config import settings

        original = "upload_only.mp4"
        upload_file = settings.upload_dir / original
        upload_file.parent.mkdir(parents=True, exist_ok=True)
        upload_file.write_text("data")

        cleanup_project_files(original, None)
        assert not upload_file.exists()


class TestEnsureFileExists:
    """Tests for ensure_file_exists()."""

    def test_exists(self, tmp_path):
        f = tmp_path / "real.txt"
        f.write_text("data")
        assert ensure_file_exists(f) is True

    def test_not_exists_raises_error(self, tmp_path):
        f = tmp_path / "missing.txt"
        with pytest.raises(FileNotFoundError, match="File not found"):
            ensure_file_exists(f)
