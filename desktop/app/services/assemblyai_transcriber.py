"""
Transcription service using AssemblyAI API.

Provides transcription with speaker diarization and identification.
"""

import asyncio
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Dict, Any, Optional, Callable

import assemblyai as aai

from app.config import settings


class TranscriptionError(Exception):
    """Raised when transcription fails."""
    pass


@dataclass
class SpeakerInfo:
    """Information about an identified speaker."""
    label: str
    display_name: Optional[str] = None
    confidence: float = 0.0
    evidence: List[str] = field(default_factory=list)


@dataclass
class WordTimestamp:
    """Timestamp information for a single word."""
    text: str
    start: float  # seconds
    end: float    # seconds


@dataclass
class UtteranceInfo:
    """Information about a single utterance."""
    text: str
    start: float
    end: float
    speaker_label: str
    words: List[WordTimestamp] = field(default_factory=list)


@dataclass
class TranscriptionResult:
    """Result of transcription with diarization."""
    speakers: List[SpeakerInfo]
    utterances: List[UtteranceInfo]


class AssemblyAITranscriber:
    """
    Service for transcribing audio using AssemblyAI API.

    Provides speaker diarization and optional speaker identification.
    """

    def __init__(self, api_key: Optional[str] = None):
        """Initialize the transcriber."""
        self.api_key = api_key or settings.assemblyai_api_key

        if not self.api_key:
            raise TranscriptionError(
                "AssemblyAI API key not configured. Set ASSEMBLYAI_API_KEY in .env file."
            )

        aai.settings.api_key = self.api_key

    async def transcribe(
        self,
        audio_path: Path,
        language: str = "nl",
        speakers_expected: Optional[int] = None,
        on_progress: Optional[Callable[[str, int], None]] = None,
    ) -> TranscriptionResult:
        """
        Transcribe audio with speaker diarization.

        Args:
            audio_path: Path to audio file.
            language: Language code (default: "nl" for Dutch).
            speakers_expected: Expected number of speakers (None = auto-detect).
            on_progress: Optional callback for progress updates (stage, percent).

        Returns:
            TranscriptionResult with speakers and utterances.

        Raises:
            TranscriptionError: If transcription fails.
        """
        if not audio_path.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_path}")

        if on_progress:
            on_progress("uploading", 5)

        try:
            # Configure transcription
            config = aai.TranscriptionConfig(
                language_code=language,
                speaker_labels=True,
                speakers_expected=speakers_expected or settings.speakers_expected,
            )

            # Create transcriber
            transcriber = aai.Transcriber(config=config)

            if on_progress:
                on_progress("transcribing", 10)

            # Run transcription in thread pool (AssemblyAI SDK is sync)
            loop = asyncio.get_event_loop()
            transcript = await loop.run_in_executor(
                None,
                lambda: transcriber.transcribe(str(audio_path))
            )

            # Poll for completion with progress updates
            if on_progress:
                on_progress("processing", 30)

            if transcript.status == aai.TranscriptStatus.error:
                raise TranscriptionError(f"Transcription failed: {transcript.error}")

            if on_progress:
                on_progress("parsing", 90)

            # Parse result
            result = self._parse_transcript(transcript)

            if on_progress:
                on_progress("completed", 100)

            return result

        except Exception as e:
            if isinstance(e, (TranscriptionError, FileNotFoundError)):
                raise
            raise TranscriptionError(f"Transcription failed: {str(e)}")

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
            # Get first few utterances as evidence for potential name inference
            evidence = speaker_utterances.get(label, [])[:5]

            speakers.append(SpeakerInfo(
                label=label,
                display_name=None,  # Will be set by speaker identification or user
                confidence=0.0,
                evidence=evidence,
            ))

        return TranscriptionResult(speakers=speakers, utterances=utterances)

    async def transcribe_with_retry(
        self,
        audio_path: Path,
        language: str = "nl",
        speakers_expected: Optional[int] = None,
        max_retries: int = 3,
        retry_delay: float = 2.0,
        on_progress: Optional[Callable[[str, int], None]] = None,
    ) -> TranscriptionResult:
        """Transcribe with automatic retry on failure."""
        last_error = None

        for attempt in range(max_retries):
            try:
                return await self.transcribe(
                    audio_path, language, speakers_expected, on_progress
                )
            except TranscriptionError as e:
                last_error = e
                if attempt < max_retries - 1:
                    delay = retry_delay * (2 ** attempt)
                    print(f"Transcription attempt {attempt + 1} failed, retrying in {delay}s...")
                    await asyncio.sleep(delay)

        raise TranscriptionError(
            f"Transcription failed after {max_retries} attempts: {last_error}"
        )
