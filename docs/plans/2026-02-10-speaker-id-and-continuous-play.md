# Speaker Identification & Continuous Playback Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add AI-powered speaker identification to the processing pipeline (using GPT-5) and continuous audio playback mode to the desktop frontend.

**Architecture:** Two independent features. Feature 1 adds a new `identifying` stage between transcription and explanation in the backend pipeline, calling GPT-5 to infer speaker names from transcript context. Feature 2 adds a continuous playback mode to the AudioPlayer that auto-advances through sentences without pausing.

**Tech Stack:** Python/FastAPI/OpenAI SDK (backend), Vanilla JS (frontend)

---

### Task 1: Update GPT Model Default to GPT-5

**Files:**
- Modify: `desktop/app/config.py:42`

**Step 1: Change the default model**

In `desktop/app/config.py`, change line 42:
```python
# Before:
gpt_model: str = "gpt-4o-mini"

# After:
gpt_model: str = "gpt-5"
```

**Step 2: Run existing tests to verify no breakage**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -q`
Expected: All 184 tests pass (model name is only used at runtime when calling the API)

**Step 3: Commit**

```bash
git add desktop/app/config.py
git commit -m "feat: upgrade default GPT model to gpt-5"
```

---

### Task 2: Add 'identifying' Status to Project Model

**Files:**
- Modify: `desktop/app/models/project.py:39-43,63-67,78-84,102-110`
- Modify: `desktop/app/database.py:105-111` (migration)

**Step 1: Update the Project model**

In `desktop/app/models/project.py`, make these changes:

1. Update the CHECK constraint (line 63-67):
```python
__table_args__ = (
    CheckConstraint(
        "status IN ('pending', 'extracting', 'transcribing', 'identifying', 'explaining', 'ready', 'error')",
        name="check_valid_status",
    ),
)
```

2. Update the `progress` property (line 78-84):
```python
stages = {
    "pending": 0,
    "extracting": 10,
    "transcribing": 30,
    "identifying": 40,
    "explaining": 50,
    "ready": 100,
    "error": 0,
}
```

3. Update the `explaining` progress calculation (line 88-90):
```python
if self.status == "explaining" and self.total_sentences > 0:
    explanation_progress = self.processed_sentences / self.total_sentences
    return 50 + int(explanation_progress * 45)
```
(This stays the same — explaining still starts at 50, just identifying fills the 30-50 gap)

4. Update `current_stage_description` (line 102-110):
```python
descriptions = {
    "pending": "Waiting to start...",
    "extracting": "Extracting audio from video...",
    "transcribing": "Transcribing audio to text...",
    "identifying": "Identifying speakers...",
    "explaining": f"Generating explanations ({self.processed_sentences}/{self.total_sentences})...",
    "ready": "Processing complete",
    "error": f"Error: {self.error_message or 'Unknown error'}",
}
```

**Step 2: Add database migration for existing DBs**

The CHECK constraint change doesn't apply to existing SQLite databases (SQLite doesn't enforce ALTER CHECK). But we should handle it gracefully. No migration SQL needed — SQLite CHECK constraints are only validated on INSERT/UPDATE, and the existing DB was created with `create_all()` which won't re-create existing tables.

**Step 3: Run tests**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -q`
Expected: All 184 tests pass

**Step 4: Commit**

```bash
git add desktop/app/models/project.py
git commit -m "feat: add 'identifying' status to Project model"
```

---

### Task 3: Create SpeakerIdentifier Service with Tests

**Files:**
- Create: `desktop/app/services/speaker_identifier.py`
- Create: `desktop/tests/test_speaker_identifier.py`

**Step 1: Write the failing tests**

Create `desktop/tests/test_speaker_identifier.py`:

```python
"""Tests for the SpeakerIdentifier service."""

import json
import pytest
from unittest.mock import AsyncMock, patch, MagicMock

from app.services.speaker_identifier import SpeakerIdentifier, SpeakerIdentification


class TestBuildPrompt:
    """Test prompt construction."""

    def test_formats_transcript_with_speaker_labels(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        transcript = [
            {"label": "A", "text": "Hallo, ik ben Jan."},
            {"label": "B", "text": "Welkom Jan."},
        ]
        prompt = identifier._build_prompt(transcript, "Test Project")
        assert "[A] Hallo, ik ben Jan." in prompt
        assert "[B] Welkom Jan." in prompt
        assert "Test Project" in prompt

    def test_empty_transcript_returns_prompt(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        prompt = identifier._build_prompt([], "Empty")
        assert "Empty" in prompt


class TestParseResponse:
    """Test response parsing."""

    def test_parses_valid_response(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        response_json = {
            "speakers": [
                {
                    "label": "A",
                    "name": "Jan de Vries",
                    "role": "Manager",
                    "confidence": "high",
                    "evidence": "Introduced himself at the start",
                },
                {
                    "label": "B",
                    "name": "de presentator",
                    "role": "",
                    "confidence": "low",
                    "evidence": "No name mentioned",
                },
            ]
        }
        results = identifier._parse_response(json.dumps(response_json))
        assert "A" in results
        assert results["A"].name == "Jan de Vries"
        assert results["A"].role == "Manager"
        assert results["A"].confidence == "high"
        assert "B" in results
        assert results["B"].name == "de presentator"

    def test_handles_malformed_json(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        results = identifier._parse_response("not valid json {{{")
        assert results == {}

    def test_handles_missing_speakers_key(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        results = identifier._parse_response('{"other": "data"}')
        assert results == {}

    def test_handles_incomplete_speaker_entry(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        response_json = {
            "speakers": [
                {"label": "A", "name": "Jan"},  # missing role, confidence, evidence
            ]
        }
        results = identifier._parse_response(json.dumps(response_json))
        assert "A" in results
        assert results["A"].name == "Jan"
        assert results["A"].role == ""
        assert results["A"].confidence == "low"


class TestIdentify:
    """Test the main identify method."""

    @pytest.mark.asyncio
    async def test_calls_openai_and_returns_results(self):
        identifier = SpeakerIdentifier(api_key="test-key")

        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = json.dumps({
            "speakers": [
                {
                    "label": "A",
                    "name": "Jan",
                    "role": "Developer",
                    "confidence": "high",
                    "evidence": "Said his name",
                }
            ]
        })

        with patch.object(identifier.client.chat.completions, 'create',
                          new_callable=AsyncMock, return_value=mock_response):
            transcript = [{"label": "A", "text": "Ik ben Jan."}]
            results = await identifier.identify(transcript, "Test")

        assert "A" in results
        assert results["A"].name == "Jan"

    @pytest.mark.asyncio
    async def test_returns_empty_on_api_error(self):
        identifier = SpeakerIdentifier(api_key="test-key")

        with patch.object(identifier.client.chat.completions, 'create',
                          new_callable=AsyncMock, side_effect=Exception("API down")):
            transcript = [{"label": "A", "text": "Hallo."}]
            results = await identifier.identify(transcript, "Test")

        assert results == {}

    @pytest.mark.asyncio
    async def test_empty_transcript_returns_empty(self):
        identifier = SpeakerIdentifier(api_key="test-key")
        results = await identifier.identify([], "Test")
        assert results == {}
```

**Step 2: Run tests to verify they fail**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/test_speaker_identifier.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.services.speaker_identifier'`

**Step 3: Write the implementation**

Create `desktop/app/services/speaker_identifier.py`:

```python
"""
Speaker identification service using OpenAI GPT API.

Analyzes conversation transcripts to identify speakers by name and role
based on contextual clues in the dialogue.
"""

import json
import logging
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from openai import AsyncOpenAI

from app.config import settings


logger = logging.getLogger(__name__)


class SpeakerIdentificationError(Exception):
    """Raised when speaker identification fails."""
    pass


@dataclass
class SpeakerIdentification:
    """Result of identifying a single speaker."""
    label: str
    name: str
    role: str = ""
    confidence: str = "low"
    evidence: str = ""


class SpeakerIdentifier:
    """
    Service for identifying speakers in a conversation transcript using GPT.

    Sends the full transcript to GPT and asks it to infer speaker identities
    based on contextual clues like introductions, name mentions, and job titles.
    """

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or settings.openai_api_key
        self.client = AsyncOpenAI(api_key=self.api_key)
        self.model = settings.gpt_model

    def _build_prompt(self, transcript: List[Dict[str, str]], project_name: str) -> str:
        """Build the prompt for speaker identification."""
        lines = [f"[{entry['label']}] {entry['text']}" for entry in transcript]
        transcript_text = "\n".join(lines)

        return f"""You are analyzing a Dutch conversation transcript titled "{project_name}".
The transcript has speaker labels (A, B, C, etc.) assigned by automatic diarization.

Based on context clues (introductions, name mentions, job titles, how others address them),
identify each speaker.

<transcript>
{transcript_text}
</transcript>

Return ONLY a valid JSON object in this exact format:
{{
  "speakers": [
    {{
      "label": "A",
      "name": "Jan de Vries",
      "role": "IT Service Manager",
      "confidence": "high",
      "evidence": "Introduced himself at the start and others refer to him as Jan"
    }}
  ]
}}

Rules:
- If you cannot determine a name, use a descriptive label in Dutch like "de presentator" or "de manager"
- confidence: "high" = name explicitly mentioned, "medium" = inferred from context, "low" = guess
- evidence: brief explanation of how you determined the identity
- Include ALL speaker labels found in the transcript"""

    def _parse_response(self, content: str) -> Dict[str, SpeakerIdentification]:
        """Parse the GPT response into SpeakerIdentification objects."""
        try:
            data = json.loads(content)
        except (json.JSONDecodeError, TypeError):
            logger.warning("Failed to parse speaker identification response as JSON")
            return {}

        speakers = data.get("speakers", [])
        if not isinstance(speakers, list):
            return {}

        results = {}
        for entry in speakers:
            if not isinstance(entry, dict) or "label" not in entry:
                continue
            label = entry["label"]
            results[label] = SpeakerIdentification(
                label=label,
                name=entry.get("name", f"Speaker {label}"),
                role=entry.get("role", ""),
                confidence=entry.get("confidence", "low"),
                evidence=entry.get("evidence", ""),
            )
        return results

    async def identify(
        self,
        transcript: List[Dict[str, str]],
        project_name: str,
    ) -> Dict[str, SpeakerIdentification]:
        """
        Identify speakers in a transcript.

        Args:
            transcript: List of dicts with 'label' and 'text' keys.
            project_name: Name of the project for context.

        Returns:
            Dict mapping speaker labels to SpeakerIdentification objects.
            Returns empty dict on any error.
        """
        if not transcript:
            return {}

        prompt = self._build_prompt(transcript, project_name)

        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                response_format={"type": "json_object"},
            )
            content = response.choices[0].message.content
            return self._parse_response(content)
        except Exception as e:
            logger.warning(f"Speaker identification API call failed: {e}")
            return {}
```

**Step 4: Run tests to verify they pass**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/test_speaker_identifier.py -v`
Expected: All 8 tests pass

**Step 5: Run full test suite**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -q`
Expected: 192+ tests pass (184 existing + 8 new)

**Step 6: Commit**

```bash
git add desktop/app/services/speaker_identifier.py desktop/tests/test_speaker_identifier.py
git commit -m "feat: add SpeakerIdentifier service with tests"
```

---

### Task 4: Integrate Speaker Identification into Processor Pipeline

**Files:**
- Modify: `desktop/app/services/processor.py:7-21,45-56,285-298`

**Step 1: Add import**

At the top of `desktop/app/services/processor.py`, add after line 21:
```python
from app.services.speaker_identifier import SpeakerIdentifier
```

**Step 2: Initialize SpeakerIdentifier in `_init_api_services()`**

Add to the `__init__` method (after line 49):
```python
self.speaker_identifier: Optional[SpeakerIdentifier] = None
```

Add to `_init_api_services()` (after line 56):
```python
if self.speaker_identifier is None:
    self.speaker_identifier = SpeakerIdentifier()
```

**Step 3: Add the `_identify_speakers` method**

Add after the `_transcribe_audio` method (before `_generate_explanations`):

```python
async def _identify_speakers(self, project: Project, db: Session) -> None:
    """
    Identify speakers using AI analysis of the full transcript.

    This stage is non-blocking: if identification fails, the pipeline
    continues and speakers keep their A/B/C labels.
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
```

**Step 4: Insert the stage into `process_project()`**

In the `process_project` method (around line 285-298), add the identifying stage between transcribing and explaining:

```python
# Stage 1: Extract audio
self._update_project_status(db, project_id, "extracting")
audio_path = await self._extract_audio(project, db)

# Stage 2: Transcribe
self._update_project_status(db, project_id, "transcribing")
await self._transcribe_audio(audio_path, project, db)

# Stage 3: Identify speakers (NEW)
self._update_project_status(db, project_id, "identifying")
await self._identify_speakers(project, db)

# Stage 4: Generate explanations
self._update_project_status(db, project_id, "explaining")
await self._generate_explanations(project, db)

# Stage 5: Complete
self._update_project_status(db, project_id, "ready")
```

**Step 5: Add logger import if not present**

Check if `logging` is imported. If not, add at the top:
```python
import logging
logger = logging.getLogger(__name__)
```

**Step 6: Run full test suite**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -q`
Expected: All tests pass (the processor tests mock external services)

**Step 7: Commit**

```bash
git add desktop/app/services/processor.py
git commit -m "feat: integrate speaker identification into processing pipeline"
```

---

### Task 5: Add Continuous Playback Mode to AudioPlayer

**Files:**
- Modify: `desktop/static/js/audio-player.js:45-101`

**Step 1: Add `continuousMode` property**

In `audio-player.js`, add to the constructor (after line 68, before `this._setupEventListeners()`):

```javascript
/** @type {boolean} */
this.continuousMode = true;  // Default: continuous playback
```

**Step 2: Modify the `timeupdate` handler**

Replace the segment-end logic in `_setupEventListeners()` (lines 90-101):

```javascript
// Check if we've reached the end of the current segment
if (this.currentSegment && currentTime >= this.currentSegment.end) {
    if (this.isLooping) {
        // Loop back to segment start
        this.audio.currentTime = this.currentSegment.start;
    } else if (this.continuousMode) {
        // Continuous mode: fire segment end but DON'T pause
        const endedSegment = this.currentSegment;
        this.currentSegment = null;
        this._segmentEndCallbacks.forEach(cb => cb(endedSegment));
    } else {
        // Single mode: pause at segment end
        this.audio.pause();
        this.audio.currentTime = this.currentSegment.end;
        this._segmentEndCallbacks.forEach(cb => cb(this.currentSegment));
        this.currentSegment = null;
    }
}
```

**Step 3: Add mode control methods**

Add after the `getLoop()` method (after line 319):

```javascript
/**
 * Set continuous playback mode.
 * @param {boolean} enabled
 */
setContinuousMode(enabled) {
    this.continuousMode = enabled;
}

/**
 * Toggle continuous playback mode.
 * @returns {boolean} New state
 */
toggleContinuousMode() {
    this.continuousMode = !this.continuousMode;
    return this.continuousMode;
}

/**
 * Check if continuous mode is enabled.
 * @returns {boolean}
 */
getContinuousMode() {
    return this.continuousMode;
}
```

**Step 4: Commit**

```bash
git add desktop/static/js/audio-player.js
git commit -m "feat: add continuous playback mode to AudioPlayer"
```

---

### Task 6: Wire Continuous Playback into Learn View

**Files:**
- Modify: `desktop/static/js/app.js` (multiple sections)

**Step 1: Add continuous mode toggle button to audio controls**

In `app.js`, find the loop button HTML (around line 1138-1143). Add a new button AFTER the loop button:

```html
<!-- Continuous Mode Button -->
<button id="continuous-btn" class="flex-shrink-0 p-2 rounded-lg text-primary-600 hover:bg-gray-100 transition-colors"
        title="Continuous playback (C)">
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M4 6h16M4 10h16M4 14h16M4 18h16"></path>
    </svg>
</button>
```

**Step 2: Update the shortcut help bar**

In the keyboard shortcuts section (around line 1237-1243), add after the Loop shortcut:

```html
<span class="mx-4">|</span>
<span class="inline-flex items-center px-2 py-1 bg-gray-100 rounded text-xs font-mono mr-2">C</span> Continuous Play
```

**Step 3: Add time-based sentence tracking in `setupLearnHandlers()`**

After the `sentencesList` variable declaration (around line 1440), add:

```javascript
const continuousBtn = document.getElementById('continuous-btn');

// Continuous mode: track which sentence is playing by time
player.onTimeUpdate((currentTime) => {
    if (!player.getContinuousMode() || !player.isPlaying()) return;
    if (player.getCurrentSegment()) return;  // Still in a segment, wait for it to end

    // Find which sentence contains the current time
    const activeIdx = project.sentences.findIndex((s, i) => {
        const next = project.sentences[i + 1];
        return currentTime >= s.start_time && currentTime < (next ? next.start_time : s.end_time + 1);
    });

    if (activeIdx >= 0 && activeIdx !== AppState.selectedSentenceIndex) {
        // Update highlight and detail panel without restarting playback
        const sentence = project.sentences[activeIdx];
        AppState.setState({ selectedSentence: sentence, selectedSentenceIndex: activeIdx });

        sentencesList.querySelectorAll('.sentence-item').forEach((item, i) => {
            if (i === activeIdx) {
                item.classList.add('bg-primary-50', 'border-l-4', 'border-l-primary-500');
                item.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            } else {
                item.classList.remove('bg-primary-50', 'border-l-4', 'border-l-primary-500');
            }
        });

        detailPanel.innerHTML = renderSentenceDetail(sentence);
        setupWordTooltips();
    }
});

// Continuous mode toggle
continuousBtn.addEventListener('click', () => {
    const enabled = player.toggleContinuousMode();
    continuousBtn.classList.toggle('text-primary-600', enabled);
    continuousBtn.classList.toggle('text-gray-500', !enabled);
    continuousBtn.title = enabled ? 'Continuous playback ON (C)' : 'Single sentence mode (C)';
});
```

**Step 4: Update `selectSentence()` for continuous mode**

In the `selectSentence` function (around line 1641-1642), change the play logic:

```javascript
// Play the segment
if (player.getContinuousMode()) {
    player.clearSegment();
    player.seek(sentence.start_time);
    player.play();
} else {
    player.playSegment(sentence.start_time, sentence.end_time);
}
```

**Step 5: Update Space key handler for continuous mode**

In the `handleKeyboard` function, update the Space case (around line 1726-1735):

```javascript
case 'Space':
    e.preventDefault();
    if (player.isPlaying()) {
        player.pause();
    } else {
        const sentence = AppState.selectedSentence;
        if (sentence) {
            if (player.getContinuousMode()) {
                player.clearSegment();
                player.seek(sentence.start_time);
                player.play();
            } else {
                player.playSegment(sentence.start_time, sentence.end_time);
            }
        }
    }
    break;
```

**Step 6: Add `C` keyboard shortcut**

In the `handleKeyboard` function, add a new case after `KeyL` (around line 1755):

```javascript
case 'KeyC':
    e.preventDefault();
    continuousBtn.click();
    break;
```

**Step 7: Test manually**

1. Start server: `cd desktop && source ../venv/bin/activate && python run.py`
2. Open `http://localhost:8000` and navigate to a project
3. Click any sentence — audio should play continuously through subsequent sentences
4. Press `C` — should toggle to single-sentence mode
5. Press `Space` — should play/pause correctly in both modes
6. Press `C` again — back to continuous mode

**Step 8: Commit**

```bash
git add desktop/static/js/app.js
git commit -m "feat: add continuous playback mode with C keyboard shortcut"
```

---

### Task 7: Handle 'identifying' Status in Frontend

**Files:**
- Modify: `desktop/static/js/app.js` (status polling section)

**Step 1: Find the status polling logic**

Search for where the frontend handles project status display (the polling view during processing). Look for references to `extracting`, `transcribing`, `explaining` in the status/progress display.

The `identifying` status is already handled generically — the backend returns `progress` and `current_stage` from the model's properties. The frontend just displays whatever the API returns. So no frontend changes should be needed for the status polling view.

**Step 2: Verify by checking the status endpoint response**

The `GET /api/projects/{id}/status` endpoint returns:
```json
{
    "id": "...",
    "status": "identifying",
    "progress": 40,
    "current_stage": "Identifying speakers...",
    "error_message": null
}
```

The frontend renders `current_stage` directly, so "Identifying speakers..." will display automatically.

**Step 3: Commit (if any changes were needed)**

If no changes needed, skip this commit.

---

### Task 8: Final Integration Test

**Step 1: Run full desktop test suite**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -v`
Expected: All tests pass (192+)

**Step 2: Run full mobile test suite**

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter test`
Expected: All 152 tests pass (no mobile changes in this plan)

**Step 3: Manual end-to-end test**

1. Start server with a fresh project
2. Upload an audio file
3. Monitor status — should progress through: pending → extracting → transcribing → **identifying** → explaining → ready
4. Verify speakers have `display_name` set (not null)
5. Open the project — verify speaker names show in the UI
6. Test continuous playback: click a sentence, audio should play through
7. Test `C` key toggles between continuous and single mode
8. Test `Space` play/pause in both modes
9. Test `L` loop still works in single mode

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: speaker identification and continuous playback

- Add SpeakerIdentifier service using GPT-5 for speaker name inference
- Add 'identifying' pipeline stage between transcription and explanation
- Add continuous playback mode (default) with C keyboard shortcut
- Upgrade default GPT model from gpt-4o-mini to gpt-5"
```
