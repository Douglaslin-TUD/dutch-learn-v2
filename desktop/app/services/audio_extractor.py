"""
Audio extraction service using FFmpeg.

Extracts audio from video files and converts to MP3 format optimized for Whisper.
"""

import asyncio
import subprocess
from pathlib import Path
from typing import Optional

from app.config import settings


class AudioExtractionError(Exception):
    """Raised when audio extraction fails."""
    pass


class AudioExtractor:
    """
    Service for extracting and converting audio using FFmpeg.

    Extracts audio from video files and converts audio files to MP3 format
    optimized for the Whisper API (16kHz, mono, 128kbps).

    Example:
        extractor = AudioExtractor()
        output_path = await extractor.extract(
            input_path=Path("/path/to/video.mp4"),
            output_path=Path("/path/to/audio.mp3")
        )
    """

    # FFmpeg settings optimized for Whisper
    AUDIO_CODEC = "libmp3lame"
    AUDIO_BITRATE = "128k"
    SAMPLE_RATE = "16000"
    AUDIO_CHANNELS = "1"  # Mono

    def __init__(self):
        """Initialize the audio extractor."""
        self._verify_ffmpeg()

    def _verify_ffmpeg(self) -> None:
        """
        Verify that FFmpeg is installed and accessible.

        Raises:
            AudioExtractionError: If FFmpeg is not found.
        """
        try:
            result = subprocess.run(
                ["ffmpeg", "-version"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode != 0:
                raise AudioExtractionError("FFmpeg returned non-zero exit code")
        except FileNotFoundError:
            raise AudioExtractionError(
                "FFmpeg not found. Please install FFmpeg and ensure it's in PATH."
            )
        except subprocess.TimeoutExpired:
            raise AudioExtractionError("FFmpeg version check timed out")

    def _build_ffmpeg_command(
        self,
        input_path: Path,
        output_path: Path,
    ) -> list[str]:
        """
        Build the FFmpeg command for audio extraction.

        Args:
            input_path: Path to input file.
            output_path: Path for output MP3 file.

        Returns:
            list[str]: FFmpeg command as list of arguments.
        """
        return [
            "ffmpeg",
            "-i", str(input_path),
            "-vn",  # No video
            "-acodec", self.AUDIO_CODEC,
            "-ab", self.AUDIO_BITRATE,
            "-ar", self.SAMPLE_RATE,
            "-ac", self.AUDIO_CHANNELS,
            "-y",  # Overwrite output
            str(output_path),
        ]

    async def extract(
        self,
        input_path: Path,
        output_path: Path,
        timeout: int = 600,
    ) -> Path:
        """
        Extract audio from a video/audio file and convert to MP3.

        Args:
            input_path: Path to the input video/audio file.
            output_path: Path for the output MP3 file.
            timeout: Maximum time in seconds for extraction (default: 600s/10min).

        Returns:
            Path: Path to the extracted audio file.

        Raises:
            AudioExtractionError: If extraction fails.
            FileNotFoundError: If input file doesn't exist.
        """
        # Validate input file exists
        if not input_path.exists():
            raise FileNotFoundError(f"Input file not found: {input_path}")

        # Ensure output directory exists
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Build FFmpeg command
        cmd = self._build_ffmpeg_command(input_path, output_path)

        try:
            # Run FFmpeg asynchronously
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            # Wait for completion with timeout
            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=timeout,
            )

            # Check for errors
            if process.returncode != 0:
                error_msg = stderr.decode("utf-8", errors="replace")
                raise AudioExtractionError(
                    f"FFmpeg failed with code {process.returncode}: {error_msg}"
                )

            # Verify output file was created
            if not output_path.exists():
                raise AudioExtractionError(
                    f"FFmpeg completed but output file not found: {output_path}"
                )

            return output_path

        except asyncio.TimeoutError:
            raise AudioExtractionError(
                f"Audio extraction timed out after {timeout} seconds"
            )
        except Exception as e:
            if isinstance(e, AudioExtractionError):
                raise
            raise AudioExtractionError(f"Audio extraction failed: {str(e)}")

    async def get_duration(self, file_path: Path) -> float:
        """
        Get the duration of an audio/video file in seconds.

        Args:
            file_path: Path to the media file.

        Returns:
            float: Duration in seconds.

        Raises:
            AudioExtractionError: If duration cannot be determined.
        """
        cmd = [
            "ffprobe",
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            str(file_path),
        ]

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=30,
            )

            if process.returncode != 0:
                raise AudioExtractionError(
                    f"Failed to get duration: {stderr.decode('utf-8', errors='replace')}"
                )

            duration = float(stdout.decode("utf-8").strip())
            return duration

        except (ValueError, asyncio.TimeoutError) as e:
            raise AudioExtractionError(f"Failed to parse duration: {str(e)}")
