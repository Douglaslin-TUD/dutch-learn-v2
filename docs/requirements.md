# Dutch Language Learning Application - Requirements Document

## 1. Project Overview

### 1.1 Purpose
Build a web application that enables Dutch language learners to study from audio/video content by providing interactive transcriptions with explanations and vocabulary.

### 1.2 Target Users
- Dutch language learners (beginner to intermediate)
- People who want to learn Dutch from authentic content (movies, podcasts, lectures)

### 1.3 Core Value Proposition
Transform any Dutch audio/video content into an interactive learning resource with sentence-level playback, explanations, and vocabulary extraction.

---

## 2. Functional Requirements

### 2.1 Content Import (FR-001)
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-001.1 | Upload audio files (mp3, wav, m4a, flac) | Must Have |
| FR-001.2 | Upload video files (mkv, mp4, avi, webm) | Must Have |
| FR-001.3 | Support file duration from 1 minute to 3 hours | Must Have |
| FR-001.4 | Extract audio track from video files using FFmpeg | Must Have |
| FR-001.5 | Display upload progress indicator | Should Have |
| FR-001.6 | Validate file format before processing | Must Have |

### 2.2 Speech-to-Text Transcription (FR-002)
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-002.1 | Transcribe Dutch audio using OpenAI Whisper API | Must Have |
| FR-002.2 | Segment transcription into individual sentences | Must Have |
| FR-002.3 | Provide timestamp (start/end) for each sentence | Must Have |
| FR-002.4 | Handle various Dutch accents and dialects | Should Have |
| FR-002.5 | Display transcription progress | Should Have |

### 2.3 LLM Explanation Generation (FR-003)
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-003.1 | Generate Dutch explanation for each sentence | Must Have |
| FR-003.2 | Generate English explanation for each sentence | Must Have |
| FR-003.3 | Extract key vocabulary from each sentence | Must Have |
| FR-003.4 | Provide Dutch meaning for each vocabulary word | Must Have |
| FR-003.5 | Provide English meaning for each vocabulary word | Must Have |
| FR-003.6 | Batch process sentences efficiently | Should Have |
| FR-003.7 | Display explanation generation progress | Should Have |

### 2.4 Learning Interface (FR-004)
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-004.1 | Display all sentences in a scrollable list | Must Have |
| FR-004.2 | Click on sentence to play corresponding audio segment | Must Have |
| FR-004.3 | Click on sentence to show Dutch explanation | Must Have |
| FR-004.4 | Click on sentence to show English explanation | Must Have |
| FR-004.5 | Show vocabulary list with meanings | Must Have |
| FR-004.6 | Highlight currently playing sentence | Should Have |
| FR-004.7 | Keyboard shortcuts for playback control | Could Have |
| FR-004.8 | Adjustable playback speed | Could Have |

### 2.5 Project Management (FR-005)
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-005.1 | Create new project from uploaded file | Must Have |
| FR-005.2 | List all projects on home page | Must Have |
| FR-005.3 | Delete project and associated data | Must Have |
| FR-005.4 | Rename project | Should Have |
| FR-005.5 | Show project processing status | Must Have |

---

## 3. Non-Functional Requirements

### 3.1 Performance (NFR-001)
| ID | Requirement | Target |
|----|-------------|--------|
| NFR-001.1 | Page load time | < 2 seconds |
| NFR-001.2 | Audio segment playback latency | < 200ms |
| NFR-001.3 | Support files up to 500MB | Required |
| NFR-001.4 | Handle 100+ sentences per project | Required |

### 3.2 Usability (NFR-002)
| ID | Requirement |
|----|-------------|
| NFR-002.1 | Responsive design (desktop, tablet, mobile) |
| NFR-002.2 | Clear progress indicators during processing |
| NFR-002.3 | Intuitive navigation between sentences |
| NFR-002.4 | Accessible UI (WCAG 2.1 AA) |

### 3.3 Reliability (NFR-003)
| ID | Requirement |
|----|-------------|
| NFR-003.1 | Graceful handling of API failures |
| NFR-003.2 | Resume interrupted processing |
| NFR-003.3 | Data persistence across sessions |

### 3.4 Security (NFR-004)
| ID | Requirement |
|----|-------------|
| NFR-004.1 | Secure storage of API keys (environment variables) |
| NFR-004.2 | No exposure of API keys to client |
| NFR-004.3 | Input validation on all uploads |

---

## 4. Data Model

### 4.1 Project Entity
```
Project {
    id: UUID (primary key)
    name: String (max 255 chars)
    original_file: String (original filename)
    audio_file: String (path to extracted audio)
    status: Enum (pending, processing, ready, error)
    error_message: String (nullable)
    created_at: DateTime
    updated_at: DateTime
}
```

### 4.2 Sentence Entity
```
Sentence {
    id: UUID (primary key)
    project_id: UUID (foreign key -> Project)
    index: Integer (sentence order, 0-based)
    text: String (Dutch text)
    start_time: Float (seconds)
    end_time: Float (seconds)
    explanation_nl: Text (Dutch explanation)
    explanation_en: Text (English explanation)
    created_at: DateTime
}
```

### 4.3 Keyword Entity
```
Keyword {
    id: UUID (primary key)
    sentence_id: UUID (foreign key -> Sentence)
    word: String (Dutch word)
    meaning_nl: String (Dutch meaning)
    meaning_en: String (English meaning)
}
```

---

## 5. Processing Pipeline

### 5.1 Pipeline Stages
```
Stage 1: Upload & Validation
    Input: User uploads file
    Output: File stored locally

Stage 2: Audio Extraction (if video)
    Input: Video file
    Tool: FFmpeg
    Output: MP3 audio file

Stage 3: Transcription
    Input: Audio file
    Tool: OpenAI Whisper API
    Output: Sentences with timestamps

Stage 4: Explanation Generation
    Input: List of sentences
    Tool: OpenAI GPT API
    Output: Explanations + keywords for each sentence

Stage 5: Storage
    Input: All processed data
    Output: Data persisted in SQLite
```

### 5.2 Error Handling
- Each stage can fail independently
- Failed stages can be retried
- Partial progress is saved
- User is notified of errors with actionable messages

---

## 6. User Interface Mockups

### 6.1 Home Page
```
+------------------------------------------+
|  Dutch Audio Learning                    |
+------------------------------------------+
|  [+ New Project]                         |
|                                          |
|  My Projects:                            |
|  +--------------------------------------+|
|  | Project 1          | Ready    | [>] ||
|  | Project 2          | Processing 45% ||
|  | Project 3          | Ready    | [>] ||
|  +--------------------------------------+|
+------------------------------------------+
```

### 6.2 Learning View
```
+------------------------------------------+
|  < Back   Project Name                   |
+------------------------------------------+
|  [Audio Player Controls]  00:00 / 05:30  |
+------------------------------------------+
|  Sentences:                 | Details:   |
|  +-----------------------+  | +--------+ |
|  | 1. Hallo allemaal... | >| | Dutch:  | |
|  | 2. Vandaag gaan we...| | | Explain | |
|  | 3. Laten we beginnen | | |         | |
|  |    ...               | | | English:| |
|  +-----------------------+  | Explain | |
|                             |         | |
|                             | Words:  | |
|                             | - hallo | |
|                             | - gaan  | |
|                             +---------+ |
+------------------------------------------+
```

---

## 7. Technical Constraints

### 7.1 Required Dependencies
- Python 3.10+ (backend)
- FFmpeg (audio extraction)
- SQLite (database)
- OpenAI API (Whisper + GPT)

### 7.2 API Limits Consideration
- Whisper API: 25MB file limit per request
- GPT API: Token limits per request
- Rate limiting: Implement retry with backoff

### 7.3 Future Considerations
- Android app (React Native or Flutter)
- Cloud sync for cross-device access
- User accounts and authentication
- Spaced repetition for vocabulary

---

## 8. Acceptance Criteria

### 8.1 MVP Acceptance
1. User can upload an MP4 video file
2. Application extracts audio and transcribes to Dutch
3. Each sentence is clickable and plays the corresponding audio
4. Each sentence shows Dutch and English explanations
5. Vocabulary is extracted and displayed with meanings
6. Projects persist between sessions

### 8.2 Quality Gates
- All API calls have error handling
- UI is responsive and usable
- Processing status is always visible
- No API keys exposed in client code

---

## 9. Glossary

| Term | Definition |
|------|------------|
| Project | A single audio/video file with all its learning data |
| Sentence | A transcribed segment with timestamps and explanations |
| Keyword | An important vocabulary word extracted from a sentence |
| Whisper | OpenAI's speech-to-text API |

---

**Document Version:** 1.0
**Created:** 2024-12-30
**Status:** Approved for Implementation
