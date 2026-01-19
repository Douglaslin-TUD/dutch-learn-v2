"""
File handling utilities for the Dutch Language Learning Application.

Provides functions for file validation, naming, and cleanup.
"""

import os
import uuid
from pathlib import Path
from typing import Optional

from app.config import settings


class FileValidationError(Exception):
    """Raised when file validation fails."""
    pass


def get_file_extension(filename: str) -> str:
    """
    Extract the file extension from a filename.

    Args:
        filename: The filename to extract extension from.

    Returns:
        str: Lowercase file extension including the dot (e.g., ".mp4").
    """
    return Path(filename).suffix.lower()


def validate_file_extension(filename: str) -> bool:
    """
    Check if the file has a supported extension.

    Args:
        filename: The filename to validate.

    Returns:
        bool: True if extension is supported.

    Raises:
        FileValidationError: If extension is not supported.
    """
    ext = get_file_extension(filename)
    if ext not in settings.all_supported_extensions:
        supported = ", ".join(sorted(settings.all_supported_extensions))
        raise FileValidationError(
            f"Unsupported file type: {ext}. Supported types: {supported}"
        )
    return True


def validate_file_size(size: int) -> bool:
    """
    Check if the file size is within limits.

    Args:
        size: File size in bytes.

    Returns:
        bool: True if size is within limits.

    Raises:
        FileValidationError: If file is too large.
    """
    if size > settings.max_file_size:
        max_mb = settings.max_file_size / (1024 * 1024)
        actual_mb = size / (1024 * 1024)
        raise FileValidationError(
            f"File too large: {actual_mb:.1f}MB. Maximum size: {max_mb:.0f}MB"
        )
    return True


def is_video_file(filename: str) -> bool:
    """
    Check if the file is a video file.

    Args:
        filename: The filename to check.

    Returns:
        bool: True if file is a video.
    """
    ext = get_file_extension(filename)
    return ext in settings.supported_video_extensions


def is_audio_file(filename: str) -> bool:
    """
    Check if the file is an audio file.

    Args:
        filename: The filename to check.

    Returns:
        bool: True if file is an audio file.
    """
    ext = get_file_extension(filename)
    return ext in settings.supported_audio_extensions


def generate_unique_filename(original_filename: str, prefix: Optional[str] = None) -> str:
    """
    Generate a unique filename preserving the original extension.

    Args:
        original_filename: The original filename.
        prefix: Optional prefix for the new filename.

    Returns:
        str: A unique filename with format: {prefix_}{uuid}{extension}
    """
    ext = get_file_extension(original_filename)
    unique_id = str(uuid.uuid4())[:8]

    if prefix:
        return f"{prefix}_{unique_id}{ext}"
    return f"{unique_id}{ext}"


def get_audio_filename(project_id: str) -> str:
    """
    Generate the audio filename for a project.

    Args:
        project_id: The project's UUID.

    Returns:
        str: Audio filename with .mp3 extension.
    """
    return f"{project_id}.mp3"


def get_upload_path(filename: str) -> Path:
    """
    Get the full path for an uploaded file.

    Args:
        filename: The filename.

    Returns:
        Path: Full path in the uploads directory.
    """
    return settings.upload_dir / filename


def get_audio_path(filename: str) -> Path:
    """
    Get the full path for an audio file.

    Args:
        filename: The filename.

    Returns:
        Path: Full path in the audio directory.
    """
    return settings.audio_dir / filename


def cleanup_file(filepath: Path) -> bool:
    """
    Safely delete a file if it exists.

    Args:
        filepath: Path to the file to delete.

    Returns:
        bool: True if file was deleted, False if it didn't exist.
    """
    try:
        if filepath.exists():
            filepath.unlink()
            return True
    except OSError as e:
        # Log error but don't raise - cleanup should be best-effort
        print(f"Warning: Failed to delete file {filepath}: {e}")
    return False


def cleanup_project_files(original_file: Optional[str], audio_file: Optional[str]) -> None:
    """
    Clean up all files associated with a project.

    Args:
        original_file: Path to original uploaded file (relative to upload_dir).
        audio_file: Path to extracted audio file (relative to audio_dir).
    """
    if original_file:
        cleanup_file(settings.upload_dir / original_file)

    if audio_file:
        cleanup_file(settings.audio_dir / audio_file)


def ensure_file_exists(filepath: Path) -> bool:
    """
    Check if a file exists.

    Args:
        filepath: Path to check.

    Returns:
        bool: True if file exists.

    Raises:
        FileNotFoundError: If file doesn't exist.
    """
    if not filepath.exists():
        raise FileNotFoundError(f"File not found: {filepath}")
    return True
