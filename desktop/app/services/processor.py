"""
Pipeline processor for orchestrating audio processing, transcription, and explanation.

Coordinates the entire processing pipeline from file upload to final explanations.
"""

import asyncio
import json
import logging
from pathlib import Path
from typing import Optional
import uuid

from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db_context
from app.models import Project, Sentence, Keyword, Speaker
from app.services.audio_extractor import AudioExtractor, AudioExtractionError
from app.services.assemblyai_transcriber import AssemblyAITranscriber, TranscriptionError
from app.services.explainer import Explainer, ExplanationError
from app.services.sentence_splitter import SentenceSplitter
from app.services.speaker_identifier import SpeakerIdentifier
from app.utils.file_utils import is_video_file, get_audio_path, get_upload_path


logger = logging.getLogger(__name__)


class ProcessingError(Exception):
    """Raised when pipeline processing fails."""
    pass


class Processor:
    """
    Orchestrates the entire processing pipeline.

    Pipeline stages:
    1. Extract audio (if video file)
    2. Transcribe audio to text with timestamps
    3. Identify speakers via AI analysis
    4. Generate explanations and extract vocabulary
    5. Store everything in database

    Example:
        processor = Processor()
        await processor.process_project("project-uuid")
    """

    def __init__(self):
        """Initialize the processor with all required services."""
        self.audio_extractor = AudioExtractor()
        self.transcriber: Optional[AssemblyAITranscriber] = None
        self.explainer: Optional[Explainer] = None
        self.speaker_identifier: Optional[SpeakerIdentifier] = None

    def _init_api_services(self) -> None:
        """Initialize API-dependent services lazily."""
        if self.transcriber is None:
            self.transcriber = AssemblyAITranscriber()
        if self.explainer is None:
            self.explainer = Explainer()
        if self.speaker_identifier is None:
            self.speaker_identifier = SpeakerIdentifier()

    def _update_project_status(
        self,
        db: Session,
        project_id: str,
        status: str,
        error_message: Optional[str] = None,
        **kwargs,
    ) -> None:
        """
        Update project status in database.

        Args:
            db: Database session.
            project_id: Project UUID.
            status: New status value.
            error_message: Optional error message.
            **kwargs: Additional fields to update.
        """
        project = db.query(Project).filter(Project.id == project_id).first()
        if project:
            project.status = status
            if error_message:
                project.error_message = error_message
            for key, value in kwargs.items():
                if hasattr(project, key):
                    setattr(project, key, value)
            db.commit()

    async def _extract_audio(
        self,
        project: Project,
        db: Session,
    ) -> Path:
        """
        Extract audio from video file or copy audio file.

        Args:
            project: Project instance.
            db: Database session.

        Returns:
            Path: Path to the audio file.

        Raises:
            ProcessingError: If extraction fails.
        """
        input_path = get_upload_path(project.original_file)
        output_filename = f"{project.id}.mp3"
        output_path = get_audio_path(output_filename)

        try:
            await self.audio_extractor.extract(input_path, output_path)

            # Update project with audio file path
            project.audio_file = output_filename
            db.commit()

            return output_path

        except AudioExtractionError as e:
            raise ProcessingError(f"Audio extraction failed: {str(e)}")

    async def _transcribe_audio(
        self,
        audio_path: Path,
        project: Project,
        db: Session,
    ) -> None:
        """
        Transcribe audio with speaker diarization and store results.

        Args:
            audio_path: Path to audio file.
            project: Project instance.
            db: Database session.

        Raises:
            ProcessingError: If transcription fails.
        """
        try:
            result = await self.transcriber.transcribe_with_retry(
                audio_path,
                language="nl",
                max_retries=settings.max_retries,
            )

            # Split long utterances into shorter sentences
            splitter = SentenceSplitter(max_words=settings.max_sentence_words)
            utterances = splitter.split_utterances(result.utterances)

            # Use transaction to ensure consistency
            try:
                # Create Speaker records
                speaker_map = {}  # label -> speaker_id
                for speaker_info in result.speakers:
                    speaker = Speaker(
                        id=str(uuid.uuid4()),
                        project_id=project.id,
                        label=speaker_info.label,
                        display_name=speaker_info.display_name,
                        confidence=speaker_info.confidence,
                        evidence=json.dumps(speaker_info.evidence, ensure_ascii=False),
                        is_manual=False,
                    )
                    db.add(speaker)
                    db.flush()  # Get ID without committing
                    speaker_map[speaker_info.label] = speaker.id

                # Create Sentence records
                for idx, utterance in enumerate(utterances):
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
                project.total_sentences = len(utterances)
                project.processed_sentences = 0
                db.commit()

            except Exception as e:
                db.rollback()
                raise ProcessingError(f"Failed to save transcription: {str(e)}")

        except TranscriptionError as e:
            raise ProcessingError(f"Transcription failed: {str(e)}")

    async def _identify_speakers(self, project: Project, db: Session) -> None:
        """
        Identify speakers using AI analysis of the full transcript.

        This stage is non-blocking: if identification fails, the pipeline
        continues and speakers keep their A/B/C labels.

        Args:
            project: Project instance.
            db: Database session.
        """
        try:
            sentences = db.query(Sentence).filter(
                Sentence.project_id == project.id
            ).order_by(Sentence.idx).all()

            speakers = db.query(Speaker).filter(
                Speaker.project_id == project.id
            ).all()

            if not speakers or not sentences:
                return

            # Build speaker_id -> label mapping
            id_to_label = {s.id: s.label for s in speakers}

            # Build transcript for identification
            transcript = []
            for s in sentences:
                label = id_to_label.get(s.speaker_id, "?")
                transcript.append({"label": label, "text": s.text})

            # Call GPT for identification
            results = await self.speaker_identifier.identify(transcript, project.name)

            # Update speaker records
            for speaker in speakers:
                if speaker.label in results:
                    r = results[speaker.label]
                    speaker.display_name = r.name
                    speaker.evidence = json.dumps({
                        "role": r.role,
                        "confidence": r.confidence,
                        "reasoning": r.evidence,
                    }, ensure_ascii=False)
            db.commit()

            logger.info(f"Identified {len(results)} speakers for project {project.id}")

        except Exception as e:
            logger.warning(f"Speaker identification failed for project {project.id}: {e}")
            # Non-blocking: continue to explanation stage

    async def _generate_explanations(
        self,
        project: Project,
        db: Session,
    ) -> None:
        """
        Generate explanations for all sentences.

        Args:
            project: Project instance.
            db: Database session.

        Raises:
            ProcessingError: If explanation generation fails.
        """
        # Get all sentences for the project
        sentences = (
            db.query(Sentence)
            .filter(Sentence.project_id == project.id)
            .order_by(Sentence.idx)
            .all()
        )

        if not sentences:
            return

        sentence_texts = [s.text for s in sentences]
        batch_size = settings.explanation_batch_size

        try:
            for i in range(0, len(sentences), batch_size):
                batch_sentences = sentences[i:i + batch_size]
                batch_texts = sentence_texts[i:i + batch_size]

                # Generate explanations for batch
                explanations = await self.explainer.explain_with_retry(
                    batch_texts,
                    max_retries=settings.max_retries,
                )

                # Update sentences with explanations
                for sentence, explanation in zip(batch_sentences, explanations):
                    sentence.translation_en = explanation.get("translation_en", "")
                    sentence.explanation_nl = explanation.get("explanation_nl", "")
                    sentence.explanation_en = explanation.get("explanation_en", "")

                    # Add keywords
                    for kw_data in explanation.get("keywords", []):
                        keyword = Keyword(
                            id=str(uuid.uuid4()),
                            sentence_id=sentence.id,
                            word=kw_data.get("word", ""),
                            meaning_nl=kw_data.get("meaning_nl", ""),
                            meaning_en=kw_data.get("meaning_en", ""),
                        )
                        db.add(keyword)

                # Update progress
                project.processed_sentences = min(i + batch_size, len(sentences))
                db.commit()

                # Small delay between batches to avoid rate limiting
                if i + batch_size < len(sentences):
                    await asyncio.sleep(0.5)

        except ExplanationError as e:
            raise ProcessingError(f"Explanation generation failed: {str(e)}")

    async def process_project(self, project_id: str) -> None:
        """
        Process a project through the entire pipeline.

        Pipeline stages:
        1. pending -> extracting: Extract audio from video
        2. extracting -> transcribing: Transcribe audio to text
        3. transcribing -> identifying: Identify speakers via AI
        4. identifying -> explaining: Generate explanations
        5. explaining -> ready: Processing complete

        Args:
            project_id: UUID of the project to process.

        Raises:
            ProcessingError: If any stage fails.
        """
        try:
            # Initialize API services
            self._init_api_services()

            with get_db_context() as db:
                project = db.query(Project).filter(Project.id == project_id).first()

                if not project:
                    raise ProcessingError(f"Project not found: {project_id}")

                # Stage 1: Extract audio
                self._update_project_status(db, project_id, "extracting")
                audio_path = await self._extract_audio(project, db)

                # Stage 2: Transcribe
                self._update_project_status(db, project_id, "transcribing")
                await self._transcribe_audio(audio_path, project, db)

                # Stage 3: Identify speakers (AI-powered)
                self._update_project_status(db, project_id, "identifying")
                await self._identify_speakers(project, db)

                # Stage 4: Generate explanations
                self._update_project_status(db, project_id, "explaining")
                await self._generate_explanations(project, db)

                # Stage 5: Complete
                self._update_project_status(db, project_id, "ready")

        except ProcessingError as e:
            with get_db_context() as db:
                self._update_project_status(
                    db,
                    project_id,
                    "error",
                    error_message=str(e),
                )
            raise

        except Exception as e:
            with get_db_context() as db:
                self._update_project_status(
                    db,
                    project_id,
                    "error",
                    error_message=f"Unexpected error: {str(e)}",
                )
            raise ProcessingError(f"Processing failed: {str(e)}")


# Global processor instance
processor = Processor()


async def process_project_background(project_id: str) -> None:
    """
    Background task function for processing a project.

    This function is designed to be called from FastAPI's BackgroundTasks.

    Args:
        project_id: UUID of the project to process.
    """
    try:
        await processor.process_project(project_id)
    except ProcessingError as e:
        # Error already logged and stored in database
        print(f"Project {project_id} processing failed: {e}")
    except Exception as e:
        print(f"Unexpected error processing project {project_id}: {e}")
