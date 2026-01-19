# Dutch Language Learning Application - Architecture Document

## 1. System Overview

### 1.1 Architecture Style
**Monolithic Web Application** with clear separation of concerns:
- Frontend: HTML + CSS + JavaScript (Vanilla)
- Backend: Python with FastAPI
- Database: SQLite
- Processing: Background task queue

### 1.2 High-Level Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                         Browser (Client)                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────────┐ │
│  │  Upload   │  │  Project  │  │  Learning │  │    Audio      │ │
│  │   Page    │  │   List    │  │    View   │  │    Player     │ │
│  └───────────┘  └───────────┘  └───────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │ HTTP/REST
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Python Backend (FastAPI)                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   REST API  │  │   Static    │  │   Background Workers    │  │
│  │  Endpoints  │  │   Files     │  │   (Processing Queue)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
        │                  │                      │
        ▼                  ▼                      ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐
│   SQLite     │  │  File System │  │     External APIs        │
│   Database   │  │   Storage    │  │  (Whisper, GPT)          │
└──────────────┘  └──────────────┘  └──────────────────────────┘
```

---

## 2. Technology Stack

### 2.1 Backend
| Component | Technology | Justification |
|-----------|------------|---------------|
| Web Framework | FastAPI | Async support, automatic OpenAPI docs, type hints |
| Database | SQLite + SQLAlchemy | Simple, no server needed, sufficient for local use |
| Task Queue | asyncio + BackgroundTasks | Simple background processing, no Redis needed |
| Audio Processing | FFmpeg (subprocess) | Industry standard, reliable |

### 2.2 Frontend
| Component | Technology | Justification |
|-----------|------------|---------------|
| Framework | Vanilla JS + HTML | Simple, no build step needed |
| Styling | Tailwind CSS (CDN) | Rapid development, responsive |
| Audio Player | HTML5 Audio API | Native, no dependencies |
| HTTP Client | Fetch API | Native browser support |

### 2.3 External Services
| Service | API | Purpose |
|---------|-----|---------|
| OpenAI Whisper | REST API | Speech-to-text transcription |
| OpenAI GPT-4 | REST API | Explanation and vocabulary generation |

---

## 3. Directory Structure

```
/data/AI  Tools/Audio for Dutch Learn/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app entry point
│   ├── config.py               # Configuration management
│   ├── database.py             # Database connection & models
│   │
│   ├── models/
│   │   ├── __init__.py
│   │   ├── project.py          # Project model
│   │   ├── sentence.py         # Sentence model
│   │   └── keyword.py          # Keyword model
│   │
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── projects.py         # Project CRUD endpoints
│   │   └── audio.py            # Audio streaming endpoint
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── audio_extractor.py  # FFmpeg audio extraction
│   │   ├── transcriber.py      # Whisper API integration
│   │   ├── explainer.py        # GPT explanation generation
│   │   └── processor.py        # Pipeline orchestration
│   │
│   └── utils/
│       ├── __init__.py
│       └── file_utils.py       # File handling utilities
│
├── static/
│   ├── css/
│   │   └── style.css
│   ├── js/
│   │   ├── app.js              # Main application logic
│   │   ├── audio-player.js     # Audio player component
│   │   └── api.js              # API client
│   └── index.html              # Main HTML page
│
├── data/
│   ├── uploads/                # Original uploaded files
│   ├── audio/                  # Extracted audio files
│   └── dutch_learning.db       # SQLite database
│
├── docs/
│   ├── requirements.md
│   └── architecture.md
│
├── tests/
│   ├── __init__.py
│   ├── test_audio_extractor.py
│   ├── test_transcriber.py
│   └── test_api.py
│
├── .env                        # Environment variables (API keys)
├── .env.example                # Example environment file
├── requirements.txt            # Python dependencies
├── README.md                   # Project documentation
└── run.py                      # Application runner
```

---

## 4. Database Schema

### 4.1 Entity Relationship Diagram
```
┌─────────────────────────────────────┐
│              projects               │
├─────────────────────────────────────┤
│ id          TEXT PRIMARY KEY        │
│ name        TEXT NOT NULL           │
│ original_file TEXT NOT NULL         │
│ audio_file  TEXT                    │
│ status      TEXT DEFAULT 'pending'  │
│ error_message TEXT                  │
│ total_sentences INTEGER DEFAULT 0   │
│ processed_sentences INTEGER DEFAULT 0│
│ created_at  TIMESTAMP               │
│ updated_at  TIMESTAMP               │
└─────────────────────────────────────┘
              │
              │ 1:N
              ▼
┌─────────────────────────────────────┐
│             sentences               │
├─────────────────────────────────────┤
│ id          TEXT PRIMARY KEY        │
│ project_id  TEXT FOREIGN KEY        │
│ idx         INTEGER NOT NULL        │
│ text        TEXT NOT NULL           │
│ start_time  REAL NOT NULL           │
│ end_time    REAL NOT NULL           │
│ explanation_nl TEXT                 │
│ explanation_en TEXT                 │
│ created_at  TIMESTAMP               │
└─────────────────────────────────────┘
              │
              │ 1:N
              ▼
┌─────────────────────────────────────┐
│              keywords               │
├─────────────────────────────────────┤
│ id          TEXT PRIMARY KEY        │
│ sentence_id TEXT FOREIGN KEY        │
│ word        TEXT NOT NULL           │
│ meaning_nl  TEXT NOT NULL           │
│ meaning_en  TEXT NOT NULL           │
└─────────────────────────────────────┘
```

### 4.2 SQL Schema
```sql
CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    original_file TEXT NOT NULL,
    audio_file TEXT,
    status TEXT DEFAULT 'pending'
        CHECK(status IN ('pending', 'extracting', 'transcribing', 'explaining', 'ready', 'error')),
    error_message TEXT,
    total_sentences INTEGER DEFAULT 0,
    processed_sentences INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sentences (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    idx INTEGER NOT NULL,
    text TEXT NOT NULL,
    start_time REAL NOT NULL,
    end_time REAL NOT NULL,
    explanation_nl TEXT,
    explanation_en TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE keywords (
    id TEXT PRIMARY KEY,
    sentence_id TEXT NOT NULL,
    word TEXT NOT NULL,
    meaning_nl TEXT NOT NULL,
    meaning_en TEXT NOT NULL,
    FOREIGN KEY (sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
);

CREATE INDEX idx_sentences_project ON sentences(project_id);
CREATE INDEX idx_keywords_sentence ON keywords(sentence_id);
```

---

## 5. API Design

### 5.1 REST Endpoints

#### Projects
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/projects` | List all projects |
| POST | `/api/projects` | Create new project (upload file) |
| GET | `/api/projects/{id}` | Get project details with sentences |
| DELETE | `/api/projects/{id}` | Delete project |
| GET | `/api/projects/{id}/status` | Get processing status |

#### Audio
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/audio/{project_id}` | Stream project audio file |

### 5.2 API Response Schemas

```python
# Project List Response
{
    "projects": [
        {
            "id": "uuid",
            "name": "string",
            "status": "pending|extracting|transcribing|explaining|ready|error",
            "created_at": "ISO8601"
        }
    ]
}

# Project Detail Response
{
    "id": "uuid",
    "name": "string",
    "status": "ready",
    "sentences": [
        {
            "id": "uuid",
            "index": 0,
            "text": "Dutch sentence text",
            "start_time": 0.0,
            "end_time": 5.5,
            "explanation_nl": "Dutch explanation",
            "explanation_en": "English explanation",
            "keywords": [
                {
                    "word": "woord",
                    "meaning_nl": "Dutch meaning",
                    "meaning_en": "English meaning"
                }
            ]
        }
    ]
}

# Processing Status Response
{
    "id": "uuid",
    "status": "transcribing",
    "progress": 45,
    "current_stage": "Transcribing audio...",
    "error_message": null
}
```

---

## 6. Processing Pipeline Design

### 6.1 Pipeline Flow
```
┌──────────────────────────────────────────────────────────────────┐
│                     Processing Pipeline                           │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────┐
│  1. UPLOAD       │  ← User uploads file
│                  │  → Store in /data/uploads/
│  Status: pending │  → Create project record
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  2. EXTRACT      │  ← Read uploaded file
│                  │  → FFmpeg extract audio to MP3
│  Status:         │  → Store in /data/audio/
│  extracting      │  → Update project.audio_file
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  3. TRANSCRIBE   │  ← Read audio file
│                  │  → Split if > 25MB
│  Status:         │  → Call Whisper API
│  transcribing    │  → Parse segments to sentences
│                  │  → Store sentences in DB
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  4. EXPLAIN      │  ← Read sentences from DB
│                  │  → Batch sentences (5 per call)
│  Status:         │  → Call GPT API for explanations
│  explaining      │  → Extract keywords
│                  │  → Update sentences in DB
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  5. COMPLETE     │
│                  │  → Update status to 'ready'
│  Status: ready   │
└──────────────────┘
```

### 6.2 Error Handling Strategy
```python
MAX_RETRIES = 3
RETRY_DELAYS = [1, 5, 15]  # seconds

async def process_with_retry(func, *args):
    for attempt in range(MAX_RETRIES):
        try:
            return await func(*args)
        except Exception as e:
            if attempt == MAX_RETRIES - 1:
                raise
            await asyncio.sleep(RETRY_DELAYS[attempt])
```

### 6.3 Progress Tracking
```python
def calculate_progress(project):
    stages = {
        'pending': 0,
        'extracting': 10,
        'transcribing': 30,
        'explaining': 50,
        'ready': 100,
        'error': 0
    }
    base = stages.get(project.status, 0)

    if project.status == 'explaining' and project.total_sentences > 0:
        progress = project.processed_sentences / project.total_sentences
        return 50 + int(progress * 45)

    return base
```

---

## 7. Service Layer Design

### 7.1 Audio Extractor Service
```python
class AudioExtractor:
    SUPPORTED_VIDEO = {'.mkv', '.mp4', '.avi', '.webm', '.mov'}
    SUPPORTED_AUDIO = {'.mp3', '.wav', '.m4a', '.flac'}

    async def extract(self, input_path: Path, output_path: Path) -> Path:
        """Extract audio to MP3 format using FFmpeg."""
        cmd = [
            'ffmpeg', '-i', str(input_path),
            '-vn',                    # No video
            '-acodec', 'libmp3lame',  # MP3 codec
            '-ab', '128k',            # 128kbps bitrate
            '-ar', '16000',           # 16kHz (Whisper optimal)
            '-y',                     # Overwrite
            str(output_path)
        ]
        # Execute via subprocess
```

### 7.2 Transcriber Service
```python
class Transcriber:
    MAX_FILE_SIZE = 25 * 1024 * 1024  # 25MB

    async def transcribe(self, audio_path: Path) -> list[dict]:
        """Transcribe audio file to segments with timestamps."""
        # Call OpenAI Whisper API
        # Return list of {text, start, end}
```

### 7.3 Explainer Service
```python
class Explainer:
    BATCH_SIZE = 5

    async def explain_batch(self, sentences: list[str]) -> list[dict]:
        """Generate explanations for a batch of sentences."""
        prompt = self._build_prompt(sentences)
        # Call OpenAI GPT API
        # Return list of {explanation_nl, explanation_en, keywords}

    def _build_prompt(self, sentences: list[str]) -> str:
        return f"""You are a Dutch language teacher. For each sentence:
1. Provide a simple explanation in Dutch (1-2 sentences)
2. Provide an explanation in English (1-2 sentences)
3. Extract 2-4 key vocabulary words with Dutch and English meanings

Respond in JSON format:
{{
  "sentences": [
    {{
      "explanation_nl": "...",
      "explanation_en": "...",
      "keywords": [
        {{"word": "...", "meaning_nl": "...", "meaning_en": "..."}}
      ]
    }}
  ]
}}

Sentences:
{json.dumps(sentences, ensure_ascii=False)}"""
```

---

## 8. Frontend Architecture

### 8.1 Component Structure
```
App Shell
├── Router (hash-based)
│   ├── #/           → HomeView (project list)
│   ├── #/upload     → UploadView
│   └── #/project/:id → LearnView
│
└── Views
    ├── HomeView
    │   └── ProjectList component
    │
    ├── UploadView
    │   ├── DropZone component
    │   └── ProgressBar component
    │
    └── LearnView
        ├── AudioPlayer component
        ├── SentenceList component
        └── DetailPanel component
```

### 8.2 State Management
```javascript
const AppState = {
    projects: [],
    currentProject: null,
    selectedSentence: null,
    isPlaying: false,

    subscribers: new Set(),

    setState(updates) {
        Object.assign(this, updates);
        this.notify();
    },

    subscribe(fn) {
        this.subscribers.add(fn);
        return () => this.subscribers.delete(fn);
    },

    notify() {
        this.subscribers.forEach(fn => fn(this));
    }
};
```

### 8.3 Audio Player Component
```javascript
class AudioPlayer {
    constructor(audioElement) {
        this.audio = audioElement;
        this.currentSegment = null;

        this.audio.addEventListener('timeupdate', () => {
            if (this.currentSegment &&
                this.audio.currentTime >= this.currentSegment.end) {
                this.audio.pause();
                this.currentSegment = null;
            }
        });
    }

    playSegment(startTime, endTime) {
        this.audio.currentTime = startTime;
        this.currentSegment = { start: startTime, end: endTime };
        this.audio.play();
    }

    setPlaybackRate(rate) {
        this.audio.playbackRate = rate;
    }
}
```

---

## 9. Security Considerations

### 9.1 API Key Protection
- Store in `.env` file (not committed to git)
- Load via `python-dotenv`
- Never expose to frontend

### 9.2 File Upload Security
```python
ALLOWED_EXTENSIONS = {
    '.mp4', '.mkv', '.avi', '.webm', '.mov',
    '.mp3', '.wav', '.m4a', '.flac'
}
MAX_FILE_SIZE = 500 * 1024 * 1024  # 500MB

def validate_upload(filename: str, size: int):
    ext = Path(filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise ValueError(f"Unsupported file type: {ext}")
    if size > MAX_FILE_SIZE:
        raise ValueError("File too large (max 500MB)")
```

---

## 10. Deployment

### 10.1 Development Setup
```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or: venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your OpenAI API key

# Run development server
python run.py
```

### 10.2 Requirements
```
# requirements.txt
fastapi>=0.104.0
uvicorn>=0.24.0
python-dotenv>=1.0.0
python-multipart>=0.0.6
aiofiles>=23.2.1
openai>=1.3.0
pydantic>=2.5.0
pydantic-settings>=2.1.0
```

---

## 11. Future Considerations

### 11.1 Android Migration Path
1. Keep backend API unchanged
2. Deploy backend to cloud (e.g., Railway, Render)
3. Build Android app using React Native or Flutter
4. Connect to same API endpoints

### 11.2 Scalability
- Add user authentication
- Move to PostgreSQL for multi-user
- Use Redis for task queue
- Add cloud storage for audio files

---

**Document Version:** 1.0
**Created:** 2024-12-30
**Status:** Approved for Implementation
