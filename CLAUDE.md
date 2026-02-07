# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HearLoop** - Dutch Language Learning Application - enables users to study Dutch from audio/video content by providing interactive transcriptions with AI-powered explanations and vocabulary extraction.

**Architecture:** Two separate applications sharing data via Google Drive sync:
- **Desktop (Web App)** - Python FastAPI backend + Vanilla JS frontend (`desktop/`)
- **Mobile (Flutter App)** - Cross-platform mobile app (`mobile/`)

## Project Structure

```
/
├── desktop/               ← 🖥️ 电脑端 Web 应用
│   ├── app/               ← Python FastAPI 后端
│   ├── static/            ← HTML/JS/CSS 前端
│   ├── requirements.txt
│   └── run.py
│
├── mobile/                ← 📱 手机端 Flutter 应用
│   ├── lib/               ← Dart 源代码
│   ├── android/
│   ├── pubspec.yaml
│   └── ...
│
├── docs/                  ← 📚 项目文档
├── scripts/               ← 🔧 工具脚本
└── data/                  ← 💾 运行时数据
```

## Common Commands

### Desktop (Web App)

```bash
cd desktop

# Start the server
source ../venv/bin/activate
python run.py
# Access at http://localhost:8000
# API docs at http://localhost:8000/docs
```

### Mobile (Flutter App)

```bash
cd mobile

# Get dependencies
flutter pub get

# Run development
flutter run

# Run a single test file
flutter test test/data/models/project_model_test.dart

# Run all tests
flutter test

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Analyze code
flutter analyze
```

## Architecture

### Processing Pipeline

```
Upload → Extract (FFmpeg) → Transcribe (Whisper API) → Explain (GPT API) → Ready
```

Project status flows through: `pending` → `extracting` → `transcribing` → `explaining` → `ready` (or `error`)

The `Processor` class in `desktop/app/services/processor.py` orchestrates this pipeline, coordinating `AudioExtractor`, `Transcriber`, and `Explainer` services. Processing runs as a background task initiated by the projects router.

### Desktop Backend Structure (`desktop/app/`)

- `main.py` - FastAPI entry point, mounts routers and static files
- `config.py` - Pydantic Settings loading from `.env`
- `database.py` - SQLAlchemy setup with SQLite
- `models/` - ORM models: Project, Sentence, Keyword (1:N:N relationship)
- `routers/` - API endpoints: projects.py, audio.py, sync.py
- `services/` - Business logic:
  - `processor.py` - Pipeline orchestration, coordinates all services
  - `audio_extractor.py` - FFmpeg audio extraction from video
  - `transcriber.py` - OpenAI Whisper API integration
  - `explainer.py` - GPT explanation generation (batches of 5 sentences)
  - `sync_service.py` - Google Drive bidirectional sync
  - `progress_merger.py` - Merges learning progress between desktop/mobile
  - `config_encryptor.py` - Encrypts API key for secure mobile transfer

### Desktop Frontend Structure (`desktop/static/`)

- `index.html` - SPA HTML (Tailwind CSS via CDN)
- `js/app.js` - Main SPA logic, hash-based routing (#/, #/upload, #/project/:id)
- `js/api.js` - API client wrapper
- `js/audio-player.js` - HTML5 Audio component with segment playback

### Mobile App Structure (`mobile/lib/`)

Clean architecture with three layers:
- `domain/` - Entities, repository interfaces, use cases
- `data/` - Repository implementations, models, DAOs, services
- `presentation/` - Screens, widgets, Riverpod providers

Key files:
- `injection_container.dart` - Riverpod dependency injection setup
- `data/local/database.dart` - SQLite database (sqflite_common_ffi for desktop)
- `data/services/sync_service.dart` - Google Drive sync logic

### Data Flow

1. Desktop web app processes audio/video → stores in SQLite + files in `data/`
2. Export creates JSON bundle with sentences, keywords, progress
3. Google Drive sync uploads/downloads between platforms
4. Mobile app imports JSON + audio files, maintains local SQLite

## Key Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENAI_API_KEY` | OpenAI API key (required) | - |
| `APP_HOST` | Server host | `0.0.0.0` |
| `APP_PORT` | Server port | `8000` |
| `WHISPER_MODEL` | Whisper model | `whisper-1` |
| `GPT_MODEL` | GPT model | `gpt-4o-mini` |

## External Dependencies

- **FFmpeg** - Required for audio extraction from video files
- **OpenAI API** - Whisper (transcription) and GPT (explanations)
- **Google Drive API** - Cloud sync between desktop/mobile

## Database Schema

```
projects (1) ──→ sentences (N) ──→ keywords (N)
```

Projects track processing status and progress. Sentences have timestamps for audio segment playback. Keywords are extracted vocabulary with Dutch/English meanings.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/projects` | List all projects |
| `POST` | `/api/projects` | Upload new project (multipart form) |
| `GET` | `/api/projects/{id}` | Get project with sentences |
| `DELETE` | `/api/projects/{id}` | Delete project |
| `GET` | `/api/projects/{id}/status` | Get processing status |
| `GET` | `/api/audio/{project_id}` | Stream project audio |
| `POST` | `/api/sync/export` | Export project for sync |
| `POST` | `/api/sync/import` | Import synced project |
