# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HearLoop** - Dutch Language Learning Application - enables users to study Dutch from audio/video content by providing interactive transcriptions with AI-powered explanations and vocabulary extraction.

**Architecture:** Two separate applications sharing data via Google Drive sync:
- **Desktop (Web App)** - Python FastAPI backend + Vanilla JS frontend (`desktop/`)
- **Mobile (Flutter App)** - Cross-platform mobile app (`mobile/`)

## Common Commands

### Desktop (Web App)

```bash
cd desktop
source ../venv/bin/activate
python run.py                    # Start server at http://localhost:8000
                                 # API docs at http://localhost:8000/docs
```

No test suite exists for the desktop backend yet.

### Mobile (Flutter App)

```bash
cd mobile
flutter pub get                  # Install dependencies
flutter test                     # Run all tests
flutter test test/data/models/project_model_test.dart  # Run single test
flutter analyze                  # Static analysis
flutter build apk --release      # Build APK → build/app/outputs/flutter-apk/app-release.apk
```

## Architecture

### Processing Pipeline

```
Upload → Extract (FFmpeg) → Transcribe (AssemblyAI) → Explain (GPT) → Ready
```

Status state machine: `pending` → `extracting` → `transcribing` → `explaining` → `ready` (or `error` from any step)

The `Processor` class (`desktop/app/services/processor.py`) orchestrates this pipeline as a FastAPI `BackgroundTask`, coordinating `AudioExtractor`, `AssemblyAITranscriber`, and `Explainer` services.

### Desktop Backend (`desktop/app/`)

**Key patterns:**
- **Global singleton services**: `Processor`, `SyncService` use module-level singleton instances
- **Two DB session patterns**: `get_db()` for FastAPI dependency injection, `get_db_context()` context manager for background tasks
- **Lazy service init**: API-dependent services initialized only when processing starts (in `Processor._init_api_services()`)
- **Retry with exponential backoff**: Both `Transcriber` and `Explainer` have `*_with_retry()` methods
- **Batch processing**: Explanations generated in batches of 5 sentences (`explanation_batch_size`)
- **Pydantic response schemas**: Defined inline in routers with `from_attributes = True` for ORM conversion
- **UUID primary keys**: All models use `str(uuid.uuid4())`
- **Cascade deletes**: SQLAlchemy relationships use `cascade="all, delete-orphan"`
- **`to_dict()` serialization**: All ORM models implement `to_dict()` with optional include flags

**Services:**
- `processor.py` - Pipeline orchestration
- `assemblyai_transcriber.py` - AssemblyAI transcription with speaker diarization
- `explainer.py` - GPT explanation generation
- `audio_extractor.py` - FFmpeg audio extraction from video
- `sync_service.py` - Google Drive bidirectional sync
- `progress_merger.py` - Merges learning progress between desktop/mobile
- `config_encryptor.py` - API key encryption for mobile transfer

### Desktop Frontend (`desktop/static/`)

- Single-page app with hash-based routing (`#/`, `#/upload`, `#/project/:id`)
- Tailwind CSS via CDN
- `js/app.js` - Main SPA logic and routing
- `js/api.js` - API client wrapper
- `js/audio-player.js` - HTML5 Audio with segment playback
- `static/data/dictionary.json` - Dutch-English dictionary for word hover definitions

### Mobile App (`mobile/lib/`)

Clean architecture with three layers:
- `domain/` - Pure Dart entities, repository interfaces, use cases
- `data/` - Repository implementations, models, DAOs, services
- `presentation/` - Screens, widgets, Riverpod providers

Key patterns:
- **Riverpod** for DI and state management (`injection_container.dart`)
- **`Result<T>` type** (`core/utils/result.dart`) for error handling instead of exceptions
- **`sqflite_common_ffi`** for desktop SQLite support

### Data Models

```
projects (1) ──→ sentences (N) ──→ keywords (N)
                ──→ speakers (N)
```

Sentences have timestamps for audio segment playback. Keywords have Dutch/English meanings. Speakers have labels (A, B, C...), display names, and confidence scores.

### Data Flow

1. Desktop processes audio/video → stores in SQLite + files in `data/`
2. Export creates JSON bundle with sentences, keywords, progress
3. Google Drive sync uploads/downloads between platforms
4. Mobile imports JSON + audio files, maintains local SQLite

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/projects` | List all projects |
| `POST` | `/api/projects` | Upload new project (multipart form) |
| `GET` | `/api/projects/{id}` | Get project with sentences |
| `DELETE` | `/api/projects/{id}` | Delete project |
| `GET` | `/api/projects/{id}/status` | Get processing status |
| `GET` | `/api/projects/{id}/speakers` | Get speakers for a project |
| `PUT` | `/api/projects/{id}/speakers/{speaker_id}` | Update speaker display name |
| `GET` | `/api/audio/{project_id}` | Stream project audio |
| `POST` | `/api/sync/export` | Export project for sync |
| `POST` | `/api/sync/import` | Import synced project |

## Key Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENAI_API_KEY` | OpenAI API key for GPT explanations | - |
| `ASSEMBLYAI_API_KEY` | AssemblyAI key for transcription + speaker diarization | - |
| `APP_HOST` | Server host | `0.0.0.0` |
| `APP_PORT` | Server port | `8000` |
| `WHISPER_MODEL` | Whisper model | `whisper-1` |
| `GPT_MODEL` | GPT model | `gpt-4o-mini` |
| `SPEAKERS_EXPECTED` | Expected speaker count (None = auto-detect) | `None` |

## External Dependencies

- **FFmpeg** - Required for audio extraction from video files
- **OpenAI API** - GPT for explanations and vocabulary extraction
- **AssemblyAI API** - Transcription with speaker diarization
- **Google Drive API** - Cloud sync between desktop/mobile
