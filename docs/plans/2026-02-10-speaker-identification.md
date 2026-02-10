# Speaker Identification Design

**Date**: 2026-02-10
**Status**: Approved

## Goal

Automatically identify speaker names and roles from conversation context using GPT-5, so that "Speaker A" becomes "Jan (manager)" etc.

## Pipeline Change

Current: `extracting` → `transcribing` → `explaining` → `ready`
New:     `extracting` → `transcribing` → **`identifying`** → `explaining` → `ready`

The identifying stage runs after transcription produces speaker-labeled utterances and before explanation generation. This means speaker names are available during explanation, enabling context-aware explanations.

## New Service: `speaker_identifier.py`

**Location**: `desktop/app/services/speaker_identifier.py`

### Input
- Full transcript: list of sentences with speaker labels and text
- Project name (for context)

### Process
1. Format transcript as labeled dialogue: `[A] Waar vragen gesteld kunnen worden.`
2. Send to GPT-5 in a single API call with structured output prompt
3. Parse JSON response
4. Return mapping of label → {name, role, confidence, evidence}

### Prompt Strategy
```
You are analyzing a Dutch conversation transcript with speaker labels A-G.
Based on context clues (introductions, name mentions, job titles, how others
address them), identify each speaker.

<transcript>
[A] Waar vragen gesteld kunnen worden.
[A] Dat gaat nu vooral via de mail.
[B] Ja, dat klopt.
...
</transcript>

Return JSON:
{
  "speakers": [
    {
      "label": "A",
      "name": "Jan de Vries",
      "role": "IT Service Manager",
      "confidence": "high",
      "evidence": "Introduced himself at 0:15 and others refer to him as Jan"
    }
  ]
}

Rules:
- If you cannot determine a name, use a descriptive label like "de presentator"
- confidence: "high" = name explicitly mentioned, "medium" = inferred from context, "low" = guess
- evidence: brief explanation of how you determined the identity
```

### Output
```python
@dataclass
class SpeakerIdentification:
    label: str          # "A"
    name: str           # "Jan de Vries" or "de presentator"
    role: str           # "IT Service Manager" or ""
    confidence: str     # "high" | "medium" | "low"
    evidence: str       # reasoning
```

### Error Handling
- If GPT-5 call fails: log warning, continue pipeline. Speakers keep A/B/C labels.
- If response is malformed: log warning, skip identification.
- The identifying stage is **non-blocking** — failure never prevents the project from reaching `ready`.

## Changes to Existing Files

### 1. `config.py`
- Change default: `gpt_model: str = "gpt-5"` (from `gpt-4o-mini`)

### 2. `models/project.py`
- Add `'identifying'` to status CHECK constraint
- Add to `progress` dict: `'identifying': 40`
- Add to `current_stage_description`: `'identifying': 'Identifying speakers...'`

### 3. `processor.py`
Add new method `_identify_speakers()` called between `_transcribe()` and `_generate_explanations()`:

```python
async def _identify_speakers(self, project, db):
    """Identify speakers using AI analysis of transcript."""
    try:
        sentences = db.query(Sentence).filter(
            Sentence.project_id == project.id
        ).order_by(Sentence.idx).all()

        speakers = db.query(Speaker).filter(
            Speaker.project_id == project.id
        ).all()

        if not speakers:
            return

        identifier = SpeakerIdentifier()
        results = await identifier.identify(
            sentences=[(s.text, s.speaker_id) for s in sentences],
            speakers={s.id: s.label for s in speakers},
            project_name=project.name,
        )

        # Update speaker records
        for speaker in speakers:
            if speaker.label in results:
                r = results[speaker.label]
                speaker.display_name = r.name
                speaker.evidence = json.dumps({
                    "role": r.role,
                    "confidence": r.confidence,
                    "reasoning": r.evidence,
                })
        db.commit()

    except Exception as e:
        logger.warning(f"Speaker identification failed: {e}")
        # Non-blocking: continue to explanation stage
```

Update `_process()` flow:
```python
# Step 1: Extract audio
await self._extract_audio(...)

# Step 2: Transcribe
self._update_project_status(project, db, 'transcribing')
await self._transcribe(...)

# Step 3: Identify speakers (NEW)
self._update_project_status(project, db, 'identifying')
await self._identify_speakers(project, db)

# Step 4: Generate explanations
self._update_project_status(project, db, 'explaining')
await self._generate_explanations(...)
```

### 4. Frontend (`app.js`)
- Add `'identifying'` to any status display logic
- No other changes needed — speaker display_name is already rendered when present

### 5. Mobile app
- No changes needed — already reads `display_name` from sync data

## Testing

### Unit Tests (`test_speaker_identifier.py`)
1. Test prompt formatting with multi-speaker transcript
2. Test JSON response parsing (valid response)
3. Test malformed response handling (graceful fallback)
4. Test empty transcript handling
5. Test single-speaker handling

### Integration
- Process a real audio file and verify speakers get identified
- Verify pipeline continues if identification fails

## Files to Create/Modify

| File | Action |
|------|--------|
| `desktop/app/services/speaker_identifier.py` | **CREATE** — new service |
| `desktop/tests/test_speaker_identifier.py` | **CREATE** — unit tests |
| `desktop/app/config.py` | EDIT — change gpt_model default to gpt-5 |
| `desktop/app/models/project.py` | EDIT — add 'identifying' status |
| `desktop/app/services/processor.py` | EDIT — add identifying stage |
| `desktop/static/js/app.js` | EDIT — handle 'identifying' status display |

---

# Feature 2: Continuous Playback Mode

## Goal

When the user clicks play, audio should continue playing through subsequent sentences automatically (not stop after each sentence). The active sentence highlights and scrolls as playback progresses. Pause stops playback at the current position.

## Current Behavior

`AudioPlayer.playSegment(start, end)` plays one sentence's time range, then pauses at `end` (line 90-99 of `audio-player.js`). The user must manually click the next sentence to continue.

## New Behavior

Two playback modes, toggled by a button:

| Mode | Behavior | Icon |
|------|----------|------|
| **Continuous** (default) | Play from clicked sentence through the end of the file, auto-advancing the highlighted sentence as each one finishes | Play-all icon |
| **Single** | Current behavior — play one sentence, then pause | Repeat-one icon |

### Continuous Mode Flow
1. User clicks sentence #12 (or presses Space)
2. Audio starts at sentence #12's `start_time`
3. When `currentTime` passes sentence #13's `start_time`, the UI highlights sentence #13 and scrolls it into view
4. Playback continues until the user presses pause or the audio ends
5. No segment boundary — `currentSegment` is cleared so the player doesn't pause at segment end

### Single Mode Flow
- Same as current behavior: `playSegment(start, end)` → pause at end

## Implementation

### `audio-player.js` Changes

Add a `continuousMode` flag:
```javascript
this.continuousMode = true;  // default: continuous
```

Modify the `timeupdate` handler (line 90-99):
```javascript
if (this.currentSegment && currentTime >= this.currentSegment.end) {
    if (this.isLooping) {
        this.audio.currentTime = this.currentSegment.start;
    } else if (this.continuousMode) {
        // Don't pause — fire segmentEnd callback so UI can advance highlight
        this._segmentEndCallbacks.forEach(cb => cb(this.currentSegment));
        this.currentSegment = null;  // Clear so we don't keep triggering
    } else {
        // Single mode: pause at segment end
        this.audio.pause();
        this.audio.currentTime = this.currentSegment.end;
        this._segmentEndCallbacks.forEach(cb => cb(this.currentSegment));
        this.currentSegment = null;
    }
}
```

Add methods:
```javascript
setContinuousMode(enabled) { this.continuousMode = enabled; }
toggleContinuousMode() { this.continuousMode = !this.continuousMode; return this.continuousMode; }
getContinuousMode() { return this.continuousMode; }
```

### `app.js` Changes — Learn View

1. **Sentence tracking by time**: Instead of tracking by segment end, track by `timeupdate`:
```javascript
// Build sorted time index for sentence lookup
const sentenceTimeIndex = project.sentences.map((s, i) => ({
    index: i, start: s.start_time, end: s.end_time
}));

player.onTimeUpdate((currentTime) => {
    if (!player.getContinuousMode()) return;
    // Find which sentence is currently playing
    const active = sentenceTimeIndex.find(s =>
        currentTime >= s.start && currentTime < s.end
    );
    if (active && active.index !== currentHighlightIndex) {
        highlightSentence(active.index);
        scrollSentenceIntoView(active.index);
    }
});
```

2. **Play button behavior**: When clicking a sentence in continuous mode, don't set a segment — just seek and play:
```javascript
if (player.getContinuousMode()) {
    player.clearSegment();
    player.seek(sentence.start_time);
    player.play();
} else {
    player.playSegment(sentence.start_time, sentence.end_time);
}
```

3. **Mode toggle button**: Add next to the loop button in the audio controls bar:
```html
<button id="continuous-btn" title="Toggle continuous playback (C)">
    <!-- playlist icon when continuous, single-repeat icon when single -->
</button>
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play/Pause (existing) |
| `Left/Right` | Prev/Next sentence (existing) |
| `L` | Toggle loop (existing) |
| `C` | **Toggle continuous/single mode (NEW)** |

### UI Indicator

The continuous mode button in the audio bar shows the current state:
- **Active** (continuous): highlighted/colored icon
- **Inactive** (single): gray icon

## Files to Modify

| File | Change |
|------|--------|
| `desktop/static/js/audio-player.js` | Add `continuousMode` flag and methods |
| `desktop/static/js/app.js` | Add time-based sentence tracking, mode toggle button, `C` shortcut |

---

## Combined Files Summary

| File | Action | Feature |
|------|--------|---------|
| `desktop/app/services/speaker_identifier.py` | **CREATE** | Speaker ID |
| `desktop/tests/test_speaker_identifier.py` | **CREATE** | Speaker ID |
| `desktop/app/config.py` | EDIT | Speaker ID (gpt-5) |
| `desktop/app/models/project.py` | EDIT | Speaker ID (status) |
| `desktop/app/services/processor.py` | EDIT | Speaker ID (stage) |
| `desktop/static/js/audio-player.js` | EDIT | Continuous playback |
| `desktop/static/js/app.js` | EDIT | Both features |

## Cost Estimate

For a 1000-sentence transcript (~30k tokens input):
- GPT-5: ~$0.10-0.30 per project (one API call)
- Adds ~5-15 seconds to pipeline
