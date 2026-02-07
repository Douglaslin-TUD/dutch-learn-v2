# Speaker Diarization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add speaker diarization to distinguish different speakers in audio, using AssemblyAI API to replace OpenAI Whisper.

**Architecture:**
- New `Speaker` model links to `Project`, with `Sentence` referencing `Speaker`
- Replace `Transcriber` service with `AssemblyAITranscriber` that returns speakers + utterances
- Frontend displays speaker labels with editable names

**Tech Stack:**
- AssemblyAI Python SDK
- SQLAlchemy (existing)
- FastAPI (existing)
- Vanilla JS frontend (existing)

---

## Phase 1: Data Model Changes

### Task 1: Create Speaker Model

**Files:**
- Create: `desktop/app/models/speaker.py`
- Modify: `desktop/app/models/__init__.py`
- Test: Manual database inspection

**Step 1: Write the Speaker model**

```python
# desktop/app/models/speaker.py
"""
Speaker model for storing identified speakers in audio transcriptions.
"""

import uuid
from sqlalchemy import Column, String, Float, Text, Boolean, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base


class Speaker(Base):
    """
    Represents a speaker identified in an audio transcription.

    Attributes:
        id: Unique identifier (UUID).
        project_id: Foreign key to parent Project.
        label: Original speaker label from diarization (A, B, C...).
        display_name: Human-readable name (auto-inferred or user-set).
        confidence: Confidence score for name inference (0.0-1.0).
        evidence: JSON string of evidence sentences for name inference.
        is_manual: Whether display_name was manually set by user.
    """

    __tablename__ = "speakers"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(
        String(36),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    label = Column(String(10), nullable=False)
    display_name = Column(String(100), nullable=True)
    confidence = Column(Float, default=0.0)
    evidence = Column(Text, nullable=True)  # JSON string
    is_manual = Column(Boolean, default=False)

    # Relationships
    project = relationship("Project", back_populates="speakers")
    sentences = relationship("Sentence", back_populates="speaker")

    def to_dict(self) -> dict:
        """Convert speaker to dictionary representation."""
        import json
        return {
            "id": self.id,
            "project_id": self.project_id,
            "label": self.label,
            "display_name": self.display_name or f"Speaker {self.label}",
            "confidence": self.confidence,
            "evidence": json.loads(self.evidence) if self.evidence else [],
            "is_manual": self.is_manual,
        }

    def __repr__(self) -> str:
        return f"<Speaker(id={self.id}, label={self.label}, name={self.display_name})>"
```

**Step 2: Update models __init__.py**

```python
# desktop/app/models/__init__.py
"""
Database models for the Dutch Language Learning Application.
"""

from app.models.project import Project
from app.models.speaker import Speaker
from app.models.sentence import Sentence
from app.models.keyword import Keyword

__all__ = ["Project", "Sentence", "Keyword", "Speaker"]
```

**Step 3: Commit**

```bash
git add desktop/app/models/speaker.py desktop/app/models/__init__.py
git commit -m "feat: add Speaker model for diarization"
```

---

### Task 2: Update Project Model with Speaker Relationship

**Files:**
- Modify: `desktop/app/models/project.py`

**Step 1: Add speakers relationship to Project**

Add after line 56 (after sentences relationship):

```python
    speakers = relationship(
        "Speaker",
        back_populates="project",
        cascade="all, delete-orphan",
    )
```

**Step 2: Update to_dict method**

Add `include_speakers` parameter. Modify the `to_dict` method (around line 107):

```python
    def to_dict(self, include_sentences: bool = False, include_speakers: bool = False) -> dict:
        """
        Convert project to dictionary representation.

        Args:
            include_sentences: Whether to include sentence data.
            include_speakers: Whether to include speaker data.

        Returns:
            dict: Project data as dictionary.
        """
        data = {
            "id": self.id,
            "name": self.name,
            "original_file": self.original_file,
            "audio_file": self.audio_file,
            "status": self.status,
            "error_message": self.error_message,
            "progress": self.progress,
            "current_stage": self.current_stage_description,
            "total_sentences": self.total_sentences,
            "processed_sentences": self.processed_sentences,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

        if include_speakers:
            data["speakers"] = [s.to_dict() for s in self.speakers]

        if include_sentences:
            data["sentences"] = [s.to_dict() for s in self.sentences]

        return data
```

**Step 3: Commit**

```bash
git add desktop/app/models/project.py
git commit -m "feat: add speakers relationship to Project model"
```

---

### Task 3: Update Sentence Model with Speaker Reference

**Files:**
- Modify: `desktop/app/models/sentence.py`

**Step 1: Add speaker_id column and relationship**

Add after line 46 (after `end_time` column):

```python
    speaker_id = Column(
        String(36),
        ForeignKey("speakers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
```

Add after line 54 (after keywords relationship):

```python
    speaker = relationship("Speaker", back_populates="sentences")
```

**Step 2: Update to_dict method**

Modify the `to_dict` method to include speaker info:

```python
    def to_dict(self, include_keywords: bool = True) -> dict:
        """
        Convert sentence to dictionary representation.

        Args:
            include_keywords: Whether to include keyword data.

        Returns:
            dict: Sentence data as dictionary.
        """
        data = {
            "id": self.id,
            "project_id": self.project_id,
            "index": self.idx,
            "text": self.text,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration": self.duration,
            "translation_en": self.translation_en,
            "explanation_nl": self.explanation_nl,
            "explanation_en": self.explanation_en,
            "has_explanation": self.has_explanation,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "speaker_id": self.speaker_id,
            "speaker": self.speaker.to_dict() if self.speaker else None,
        }

        if include_keywords:
            data["keywords"] = [k.to_dict() for k in self.keywords]

        return data
```

**Step 3: Commit**

```bash
git add desktop/app/models/sentence.py
git commit -m "feat: add speaker reference to Sentence model"
```

---

### Task 4: Update Database Initialization

**Files:**
- Modify: `desktop/app/database.py`

**Step 1: Import Speaker model in init_db**

Update the `init_db` function (around line 84):

```python
def init_db() -> None:
    """
    Initialize the database by creating all tables.

    This should be called once at application startup.
    """
    # Import models to register them with Base
    from app.models import project, speaker, sentence, keyword

    Base.metadata.create_all(bind=engine)
```

**Step 2: Commit**

```bash
git add desktop/app/database.py
git commit -m "feat: register Speaker model in database init"
```

---

## Phase 2: Configuration Changes

### Task 5: Add AssemblyAI Configuration

**Files:**
- Modify: `desktop/app/config.py`
- Modify: `desktop/.env.example`

**Step 1: Add AssemblyAI settings to config.py**

Add after line 17 (after `openai_api_key`):

```python
    # AssemblyAI API Configuration
    assemblyai_api_key: str = ""

    # Speaker diarization settings
    speakers_expected: Optional[int] = None  # None = auto-detect
```

Add import at top:

```python
from typing import Optional
```

Add validation method after `validate_openai_key`:

```python
    def validate_assemblyai_key(self) -> bool:
        """Check if AssemblyAI API key is configured."""
        return bool(self.assemblyai_api_key and self.assemblyai_api_key != "your_assemblyai_api_key_here")
```

**Step 2: Update .env.example**

Add to `.env.example`:

```
# AssemblyAI API Key (for transcription with speaker diarization)
ASSEMBLYAI_API_KEY=your_assemblyai_api_key_here
```

**Step 3: Commit**

```bash
git add desktop/app/config.py desktop/.env.example
git commit -m "feat: add AssemblyAI configuration"
```

---

## Phase 3: Service Layer Changes

### Task 6: Create AssemblyAI Transcriber Service

**Files:**
- Create: `desktop/app/services/assemblyai_transcriber.py`

**Step 1: Write the AssemblyAI transcriber**

```python
# desktop/app/services/assemblyai_transcriber.py
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
class UtteranceInfo:
    """Information about a single utterance."""
    text: str
    start: float
    end: float
    speaker_label: str


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

        # Extract speakers
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

                utterances.append(UtteranceInfo(
                    text=utt.text,
                    start=utt.start / 1000.0,  # Convert ms to seconds
                    end=utt.end / 1000.0,
                    speaker_label=speaker_label,
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
```

**Step 2: Update services __init__.py**

```python
# desktop/app/services/__init__.py
"""Services for the Dutch Language Learning Application."""

from app.services.audio_extractor import AudioExtractor
from app.services.assemblyai_transcriber import AssemblyAITranscriber, TranscriptionError
from app.services.explainer import Explainer
from app.services.processor import Processor

__all__ = [
    "AudioExtractor",
    "AssemblyAITranscriber",
    "TranscriptionError",
    "Explainer",
    "Processor",
]
```

**Step 3: Commit**

```bash
git add desktop/app/services/assemblyai_transcriber.py desktop/app/services/__init__.py
git commit -m "feat: add AssemblyAI transcriber with diarization"
```

---

### Task 7: Update Processor to Use AssemblyAI

**Files:**
- Modify: `desktop/app/services/processor.py`

**Step 1: Update imports**

Replace transcriber import at top:

```python
from app.services.assemblyai_transcriber import AssemblyAITranscriber, TranscriptionError
```

Add json import:

```python
import json
```

Add Speaker import:

```python
from app.models import Project, Sentence, Keyword, Speaker
```

**Step 2: Update __init__ method**

Replace transcriber initialization (around line 46):

```python
    def __init__(self):
        """Initialize the processor with all required services."""
        self.audio_extractor = AudioExtractor()
        self.transcriber: Optional[AssemblyAITranscriber] = None
        self.explainer: Optional[Explainer] = None
```

Update `_init_api_services`:

```python
    def _init_api_services(self) -> None:
        """Initialize API-dependent services lazily."""
        if self.transcriber is None:
            self.transcriber = AssemblyAITranscriber()
        if self.explainer is None:
            self.explainer = Explainer()
```

**Step 3: Replace _transcribe_audio method**

Replace the entire `_transcribe_audio` method (around line 118):

```python
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
                for idx, utterance in enumerate(result.utterances):
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
                project.total_sentences = len(result.utterances)
                project.processed_sentences = 0
                db.commit()

            except Exception as e:
                db.rollback()
                raise ProcessingError(f"Failed to save transcription: {str(e)}")

        except TranscriptionError as e:
            raise ProcessingError(f"Transcription failed: {str(e)}")
```

**Step 4: Commit**

```bash
git add desktop/app/services/processor.py
git commit -m "feat: update processor to use AssemblyAI with diarization"
```

---

## Phase 4: API Layer Changes

### Task 8: Add Speaker API Endpoints

**Files:**
- Modify: `desktop/app/routers/projects.py`

**Step 1: Add speaker update endpoint**

Add after existing endpoints (around line 150):

```python
@router.put("/{project_id}/speakers/{speaker_id}")
async def update_speaker(
    project_id: str,
    speaker_id: str,
    name: str = Body(..., embed=True),
    db: Session = Depends(get_db),
):
    """
    Update speaker display name.

    This marks the speaker as manually named, preventing auto-override.
    """
    from app.models import Speaker

    speaker = (
        db.query(Speaker)
        .filter(Speaker.id == speaker_id, Speaker.project_id == project_id)
        .first()
    )

    if not speaker:
        raise HTTPException(status_code=404, detail="Speaker not found")

    speaker.display_name = name
    speaker.is_manual = True
    db.commit()

    return {"success": True, "speaker": speaker.to_dict()}


@router.get("/{project_id}/speakers")
async def get_speakers(
    project_id: str,
    db: Session = Depends(get_db),
):
    """Get all speakers for a project."""
    from app.models import Speaker

    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    speakers = (
        db.query(Speaker)
        .filter(Speaker.project_id == project_id)
        .all()
    )

    return {"speakers": [s.to_dict() for s in speakers]}
```

**Step 2: Update get_project to include speakers**

Modify the existing get_project endpoint to include speakers:

```python
@router.get("/{project_id}")
async def get_project(
    project_id: str,
    db: Session = Depends(get_db),
):
    """Get a specific project with sentences and speakers."""
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    return project.to_dict(include_sentences=True, include_speakers=True)
```

**Step 3: Commit**

```bash
git add desktop/app/routers/projects.py
git commit -m "feat: add speaker API endpoints"
```

---

## Phase 5: Frontend Changes

### Task 9: Update Frontend to Display Speakers

**Files:**
- Modify: `desktop/static/js/app.js`

**Step 1: Update sentence list rendering**

Find the `renderLearnInterface` function (around line 1067) and update the sentence list to show speaker:

```javascript
    const sentencesList = project.sentences.map((sentence, index) => {
        const speakerName = sentence.speaker?.display_name || `Speaker ${sentence.speaker?.label || '?'}`;
        const speakerColor = getSpeakerColor(sentence.speaker?.label);

        return `
        <button class="sentence-item w-full text-left px-4 py-3 hover:bg-gray-50 border-b border-gray-100
                       transition-colors ${index === 0 ? 'bg-primary-50 border-l-4 border-l-primary-500' : ''}"
                data-index="${index}">
            <div class="flex items-start space-x-3">
                <span class="flex-shrink-0 w-8 h-8 rounded-full ${speakerColor} text-white text-sm
                             flex items-center justify-center font-medium sentence-number">
                    ${sentence.speaker?.label || index + 1}
                </span>
                <div class="flex-1 min-w-0">
                    <p class="text-xs text-gray-500 mb-1">${speakerName}</p>
                    <p class="text-gray-700 text-sm leading-relaxed sentence-text">${escapeHtml(sentence.text)}</p>
                </div>
            </div>
        </button>
    `}).join('');
```

**Step 2: Add speaker color helper function**

Add after the `escapeHtml` function:

```javascript
/**
 * Get color class for speaker label.
 * @param {string} label - Speaker label (A, B, C...)
 * @returns {string} - Tailwind color class
 */
function getSpeakerColor(label) {
    const colors = {
        'A': 'bg-blue-500',
        'B': 'bg-green-500',
        'C': 'bg-purple-500',
        'D': 'bg-orange-500',
        'E': 'bg-pink-500',
        'F': 'bg-teal-500',
    };
    return colors[label] || 'bg-gray-500';
}
```

**Step 3: Add speaker name editing UI**

Add a speaker panel in the learn interface. In `renderLearnInterface`, add after the sentence list panel:

```javascript
                <!-- Speaker Panel -->
                <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-4 mb-4">
                    <h4 class="text-sm font-semibold text-gray-700 mb-3">Speakers</h4>
                    <div id="speakers-list" class="flex flex-wrap gap-2">
                        ${(project.speakers || []).map(speaker => `
                            <div class="speaker-chip flex items-center gap-2 px-3 py-1.5 rounded-full ${getSpeakerColor(speaker.label)} bg-opacity-10 border border-current"
                                 data-speaker-id="${speaker.id}">
                                <span class="w-5 h-5 rounded-full ${getSpeakerColor(speaker.label)} text-white text-xs flex items-center justify-center">
                                    ${speaker.label}
                                </span>
                                <input type="text"
                                       class="speaker-name-input bg-transparent border-none text-sm text-gray-700 w-24 focus:outline-none focus:ring-1 focus:ring-primary-300 rounded"
                                       value="${escapeHtml(speaker.display_name || `Speaker ${speaker.label}`)}"
                                       data-speaker-id="${speaker.id}"
                                       data-original="${escapeHtml(speaker.display_name || '')}">
                                ${speaker.is_manual ? '<span class="text-xs text-gray-400">✓</span>' : ''}
                            </div>
                        `).join('')}
                    </div>
                </div>
```

**Step 4: Add speaker name save handler**

In `setupLearnHandlers`, add:

```javascript
    // Speaker name editing
    document.querySelectorAll('.speaker-name-input').forEach(input => {
        input.addEventListener('blur', async (e) => {
            const speakerId = e.target.dataset.speakerId;
            const newName = e.target.value.trim();
            const originalName = e.target.dataset.original;

            if (newName && newName !== originalName) {
                try {
                    const response = await fetch(`/api/projects/${project.id}/speakers/${speakerId}`, {
                        method: 'PUT',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ name: newName }),
                    });

                    if (response.ok) {
                        e.target.dataset.original = newName;
                        showToast('Speaker name updated', 'success', 2000);
                        // Refresh to update sentence list
                        renderLearnView(project.id);
                    }
                } catch (error) {
                    showToast('Failed to update speaker name', 'error');
                    e.target.value = originalName;
                }
            }
        });

        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.target.blur();
            }
        });
    });
```

**Step 5: Commit**

```bash
git add desktop/static/js/app.js
git commit -m "feat: add speaker display and editing in frontend"
```

---

## Phase 6: Sync Layer Updates

### Task 10: Update Sync Service for Speakers

**Files:**
- Modify: `desktop/app/services/sync_service.py`

**Step 1: Update _export_project to include speakers**

In the `_export_project` method, add speaker export:

```python
    def _export_project(self, project, db) -> dict:
        """Export a project to JSON format."""
        from app.models import Sentence, Keyword, Speaker

        sentences = db.query(Sentence).filter(Sentence.project_id == project.id).order_by(Sentence.idx).all()
        keywords = db.query(Keyword).filter(Keyword.sentence_id.in_([s.id for s in sentences])).all()
        speakers = db.query(Speaker).filter(Speaker.project_id == project.id).all()

        return {
            'id': project.id,
            'name': project.name,
            'status': project.status,
            'created_at': project.created_at.isoformat() if project.created_at else None,
            'updated_at': project.updated_at.isoformat() if project.updated_at else None,
            'speakers': [
                {
                    'id': sp.id,
                    'label': sp.label,
                    'display_name': sp.display_name,
                    'confidence': sp.confidence,
                    'evidence': sp.evidence,
                    'is_manual': sp.is_manual,
                }
                for sp in speakers
            ],
            'sentences': [
                {
                    'id': s.id,
                    'idx': s.idx,
                    'text': s.text,
                    'start_time': s.start_time,
                    'end_time': s.end_time,
                    'translation_en': s.translation_en,
                    'explanation_nl': s.explanation_nl,
                    'explanation_en': s.explanation_en,
                    'speaker_id': s.speaker_id,
                }
                for s in sentences
            ],
            'keywords': [
                {
                    'id': k.id,
                    'word': k.word,
                    'meaning_nl': k.meaning_nl,
                    'meaning_en': k.meaning_en,
                    'sentence_id': k.sentence_id,
                }
                for k in keywords
            ],
        }
```

**Step 2: Update _import_project to handle speakers**

Add speaker import logic:

```python
        # Import speakers
        for sp_data in data.get('speakers', []):
            speaker = db.query(Speaker).filter(Speaker.id == sp_data['id']).first()
            if speaker:
                # Only update if not manually set locally, or if remote is manual
                if not speaker.is_manual or sp_data.get('is_manual', False):
                    speaker.display_name = sp_data.get('display_name')
                    speaker.is_manual = sp_data.get('is_manual', False)
            else:
                speaker = Speaker(
                    id=sp_data['id'],
                    project_id=project_id,
                    label=sp_data['label'],
                    display_name=sp_data.get('display_name'),
                    confidence=sp_data.get('confidence', 0.0),
                    evidence=sp_data.get('evidence'),
                    is_manual=sp_data.get('is_manual', False),
                )
                db.add(speaker)
```

**Step 3: Commit**

```bash
git add desktop/app/services/sync_service.py
git commit -m "feat: add speaker sync support"
```

---

## Phase 7: Install Dependencies

### Task 11: Add AssemblyAI to Requirements

**Files:**
- Modify: `desktop/requirements.txt`

**Step 1: Add AssemblyAI SDK**

Add to requirements.txt:

```
assemblyai>=0.23.0
```

**Step 2: Install dependencies**

```bash
cd desktop && pip install -r requirements.txt
```

**Step 3: Commit**

```bash
git add desktop/requirements.txt
git commit -m "feat: add AssemblyAI SDK dependency"
```

---

## Phase 8: Testing

### Task 12: Manual Integration Test

**Steps:**

1. Set up environment:
```bash
cd /home/peng-lin/data/AI\ \ Tools/dutch-learn-v2/desktop
cp .env.example .env
# Edit .env and add ASSEMBLYAI_API_KEY
```

2. Delete old database to force schema recreation:
```bash
rm -f data/dutch_learning.db
```

3. Start the server:
```bash
source ../venv/bin/activate
python run.py
```

4. Test in browser:
   - Open http://localhost:8000
   - Upload a short Dutch audio/video file with 2+ speakers
   - Verify speakers are detected and displayed
   - Try editing a speaker name
   - Verify the name persists after page refresh

5. Commit test results:
```bash
git add -A
git commit -m "test: verify speaker diarization integration"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-4 | Data model changes (Speaker, Sentence, Project, Database) |
| 2 | 5 | Configuration (AssemblyAI API key) |
| 3 | 6-7 | Service layer (AssemblyAI Transcriber, Processor) |
| 4 | 8 | API endpoints (Speaker CRUD) |
| 5 | 9 | Frontend (Display + Edit speakers) |
| 6 | 10 | Sync layer (Export/Import speakers) |
| 7 | 11 | Dependencies (AssemblyAI SDK) |
| 8 | 12 | Integration testing |

**Total Tasks:** 14
**Estimated Commits:** 14

---

## Phase 9: Chrome MCP Validation and Iterative Improvement

### Task 13: Prepare Test Audio

**Files:**
- Create: Test audio clip from existing data

**Step 1: Create a 3-minute test audio clip**

Extract a segment from existing audio for testing:

```bash
cd "/home/peng-lin/data/AI  Tools/dutch-learn-v2"
# Use the smaller existing audio file or extract a segment
ffmpeg -i data/audio/8da595a6-ff03-4d6c-9609-bf8431ede2cd.mp3 -t 180 -acodec copy data/test_audio_3min.mp3
```

If the file is already short enough, use it directly.

**Step 2: Verify test audio exists**

```bash
ls -la data/test_audio_3min.mp3 || ls -la data/audio/8da595a6*.mp3
```

---

### Task 14: Chrome MCP End-to-End Validation

**Validation Loop Process:**

```
┌─────────────────────────────────────────────────────────────┐
│                    VALIDATION LOOP                          │
├─────────────────────────────────────────────────────────────┤
│  1. Start server                                            │
│  2. Open Chrome via MCP → http://localhost:8000             │
│  3. Upload test audio                                       │
│  4. Wait for processing                                     │
│  5. Verify results:                                         │
│     - Speakers detected? (check speaker chips)              │
│     - Sentences displayed with speaker labels?              │
│     - Can edit speaker names?                               │
│     - Audio playback works?                                 │
│  6. If PASS → Done                                          │
│  7. If FAIL → Analyze error → Fix code → Go to step 1       │
└─────────────────────────────────────────────────────────────┘
```

**Step 1: Start the server**

```bash
cd "/home/peng-lin/data/AI  Tools/dutch-learn-v2/desktop"
source ../venv/bin/activate
python run.py &
sleep 5
```

**Step 2: Use Chrome MCP to validate**

Using mcp__claude-in-chrome tools:
1. Navigate to http://localhost:8000
2. Take screenshot to verify home page loads
3. Click "New Project" or upload button
4. Upload test audio file
5. Wait for processing (poll status)
6. Navigate to project view
7. Take screenshot to verify:
   - Speaker labels are shown
   - Sentences are grouped by speaker
   - Speaker editing UI is visible

**Step 3: Validation Checklist**

| Check | Expected | Pass/Fail |
|-------|----------|-----------|
| Server starts without errors | No exceptions | |
| Home page loads | Shows project list | |
| Upload works | File accepted | |
| Processing completes | Status = "ready" | |
| Speakers detected | At least 1 speaker shown | |
| Sentences have speaker labels | Speaker A/B visible | |
| Speaker name editable | Input field works | |
| Audio plays correctly | Segment plays on click | |

**Step 4: If validation fails**

1. Capture error from console/logs
2. Analyze root cause
3. Fix the code
4. Restart server
5. Repeat validation

**Step 5: Document results**

```bash
git add -A
git commit -m "test: Chrome MCP validation - [PASS/FAIL with notes]"
```

---

## Validation Loop Commands Reference

**Start server:**
```bash
cd "/home/peng-lin/data/AI  Tools/dutch-learn-v2/desktop" && python run.py
```

**Check server logs:**
```bash
tail -f /tmp/dutch-learn-server.log
```

**Reset database (if needed):**
```bash
rm -f "/home/peng-lin/data/AI  Tools/dutch-learn-v2/data/dutch_learning.db"
```

**Kill server:**
```bash
pkill -f "python run.py"
```
