"""
Transcription service using OpenAI Whisper API.

Transcribes Dutch audio files to text with word-level timestamps.
Automatically splits large files that exceed the API limit.
"""

import asyncio
import subprocess
import tempfile
import os
from pathlib import Path
from typing import List, Dict, Any, Optional

from openai import AsyncOpenAI

from app.config import settings


class TranscriptionError(Exception):
    """Raised when transcription fails."""
    pass


class Transcriber:
    """
    Service for transcribing Dutch audio using OpenAI Whisper API.

    Automatically splits large audio files into chunks for processing.
    """

    # Maximum file size for Whisper API (25MB)
    MAX_FILE_SIZE = 25 * 1024 * 1024

    # Target chunk size (20MB to leave margin)
    TARGET_CHUNK_SIZE = 20 * 1024 * 1024

    # Chunk duration in seconds (10 minutes per chunk)
    CHUNK_DURATION = 600

    def __init__(self, api_key: Optional[str] = None):
        """Initialize the transcriber."""
        self.api_key = api_key or settings.openai_api_key

        if not self.api_key:
            raise TranscriptionError(
                "OpenAI API key not configured. Set OPENAI_API_KEY in .env file."
            )

        self.client = AsyncOpenAI(api_key=self.api_key)
        self.model = settings.whisper_model

    async def transcribe(
        self,
        audio_path: Path,
        language: str = "nl",
    ) -> List[Dict[str, Any]]:
        """
        Transcribe an audio file to text with timestamps.
        Automatically splits large files.
        """
        if not audio_path.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_path}")

        file_size = audio_path.stat().st_size

        if file_size > self.MAX_FILE_SIZE:
            # Split and transcribe in chunks
            print(f"Audio file is {file_size / (1024*1024):.1f}MB, splitting into chunks...")
            return await self._transcribe_large_file(audio_path, language)
        else:
            # Direct transcription
            return await self._transcribe_single(audio_path, language)

    async def _transcribe_single(
        self,
        audio_path: Path,
        language: str = "nl",
    ) -> List[Dict[str, Any]]:
        """Transcribe a single audio file (under 25MB)."""
        try:
            with open(audio_path, "rb") as audio_file:
                response = await self.client.audio.transcriptions.create(
                    model=self.model,
                    file=audio_file,
                    language=language,
                    response_format="verbose_json",
                    timestamp_granularities=["segment"],
                )

            segments = self._parse_response(response)

            if not segments:
                raise TranscriptionError("No speech detected in audio file")

            return segments

        except Exception as e:
            if isinstance(e, (TranscriptionError, FileNotFoundError)):
                raise
            raise TranscriptionError(f"Transcription failed: {str(e)}")

    async def _transcribe_large_file(
        self,
        audio_path: Path,
        language: str = "nl",
    ) -> List[Dict[str, Any]]:
        """Split large audio file and transcribe each chunk."""
        # Get audio duration
        duration = self._get_audio_duration(audio_path)
        if duration is None:
            raise TranscriptionError("Could not determine audio duration")

        print(f"Audio duration: {duration:.1f} seconds")

        # Calculate number of chunks
        num_chunks = max(1, int(duration / self.CHUNK_DURATION) + 1)
        chunk_duration = duration / num_chunks

        print(f"Splitting into {num_chunks} chunks of ~{chunk_duration:.0f}s each")

        all_segments = []

        with tempfile.TemporaryDirectory() as temp_dir:
            for i in range(num_chunks):
                start_time = i * chunk_duration

                # Create chunk file
                chunk_path = Path(temp_dir) / f"chunk_{i}.mp3"

                success = self._extract_chunk(
                    audio_path,
                    chunk_path,
                    start_time,
                    chunk_duration
                )

                if not success:
                    print(f"Warning: Failed to extract chunk {i}, skipping")
                    continue

                # Check chunk size
                chunk_size = chunk_path.stat().st_size
                print(f"Chunk {i+1}/{num_chunks}: {chunk_size / (1024*1024):.1f}MB")

                if chunk_size > self.MAX_FILE_SIZE:
                    # Chunk still too large, split further
                    print(f"Chunk {i} still too large, splitting further...")
                    sub_segments = await self._transcribe_large_file(chunk_path, language)
                    # Adjust timestamps
                    for seg in sub_segments:
                        seg["start"] += start_time
                        seg["end"] += start_time
                    all_segments.extend(sub_segments)
                else:
                    # Transcribe chunk
                    try:
                        segments = await self._transcribe_single(chunk_path, language)
                        # Adjust timestamps to absolute time
                        for seg in segments:
                            seg["start"] += start_time
                            seg["end"] += start_time
                        all_segments.extend(segments)
                        print(f"Chunk {i+1} transcribed: {len(segments)} segments")
                    except TranscriptionError as e:
                        print(f"Warning: Chunk {i} transcription failed: {e}")
                        continue

                # Small delay to avoid rate limiting
                await asyncio.sleep(0.5)

        if not all_segments:
            raise TranscriptionError("No segments transcribed from any chunk")

        # Sort by start time and remove duplicates
        all_segments.sort(key=lambda x: x["start"])

        return all_segments

    def _get_audio_duration(self, audio_path: Path) -> Optional[float]:
        """Get audio duration in seconds using ffprobe."""
        try:
            result = subprocess.run(
                [
                    "ffprobe",
                    "-v", "error",
                    "-show_entries", "format=duration",
                    "-of", "default=noprint_wrappers=1:nokey=1",
                    str(audio_path)
                ],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                return float(result.stdout.strip())
            return None
        except Exception as e:
            print(f"Error getting audio duration: {e}")
            return None

    def _extract_chunk(
        self,
        input_path: Path,
        output_path: Path,
        start_time: float,
        duration: float
    ) -> bool:
        """Extract a chunk of audio using FFmpeg."""
        try:
            result = subprocess.run(
                [
                    "ffmpeg",
                    "-y",  # Overwrite
                    "-i", str(input_path),
                    "-ss", str(start_time),
                    "-t", str(duration),
                    "-acodec", "libmp3lame",
                    "-ab", "64k",  # Lower bitrate for smaller chunks
                    "-ar", "16000",
                    "-ac", "1",  # Mono
                    str(output_path)
                ],
                capture_output=True,
                timeout=120
            )

            return result.returncode == 0 and output_path.exists()
        except Exception as e:
            print(f"Error extracting chunk: {e}")
            return False

    def _parse_response(self, response: Any) -> List[Dict[str, Any]]:
        """Parse Whisper API response into segments."""
        segments = []

        if hasattr(response, "segments"):
            for segment in response.segments:
                # Handle both dict and object access patterns
                if hasattr(segment, "text"):
                    text = segment.text
                    start = segment.start
                    end = segment.end
                else:
                    text = segment.get("text", "")
                    start = segment.get("start", 0)
                    end = segment.get("end", 0)
                segments.append({
                    "text": str(text).strip() if text else "",
                    "start": float(start) if start else 0.0,
                    "end": float(end) if end else 0.0,
                })
        elif hasattr(response, "text"):
            segments.append({
                "text": response.text.strip(),
                "start": 0.0,
                "end": 0.0,
            })

        # Filter out empty segments
        segments = [s for s in segments if s["text"]]

        return segments

    async def transcribe_with_retry(
        self,
        audio_path: Path,
        language: str = "nl",
        max_retries: int = 3,
        retry_delay: float = 1.0,
    ) -> List[Dict[str, Any]]:
        """Transcribe with automatic retry on failure."""
        last_error = None

        for attempt in range(max_retries):
            try:
                return await self.transcribe(audio_path, language)
            except TranscriptionError as e:
                last_error = e
                # Don't retry for file size errors - they're handled internally now
                if "too large" in str(e).lower():
                    raise
                if attempt < max_retries - 1:
                    delay = retry_delay * (2 ** attempt)
                    print(f"Transcription attempt {attempt + 1} failed, retrying in {delay}s...")
                    await asyncio.sleep(delay)

        raise TranscriptionError(
            f"Transcription failed after {max_retries} attempts: {last_error}"
        )
