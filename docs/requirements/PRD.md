# Product Requirements Document (PRD)
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31
**Status:** Draft

---

## 1. Executive Summary

This document defines the requirements for a Flutter-based Android mobile application designed to facilitate Dutch language learning through audio-based sentence study. The app serves as a companion to an existing FastAPI web application that processes audio/video content, transcribes Dutch speech, and generates educational content including translations, explanations, and vocabulary.

The mobile app enables learners to study Dutch anywhere, offline, by syncing project data via Google Drive. Users export processed content (JSON) and corresponding audio files (MP3) from the web app, upload them to Google Drive, and then import them into the mobile app for structured, sentence-by-sentence learning.

---

## 2. Goals and Objectives

### 2.1 Primary Goals

| Goal | Description | Success Metric |
|------|-------------|----------------|
| **G1: Offline Learning** | Enable full Dutch learning functionality without internet connection | 100% feature availability offline after initial sync |
| **G2: Audio-Sentence Integration** | Seamlessly link audio playback with sentence display and study | Audio seek accuracy within 100ms of timestamp |
| **G3: Simple Distribution** | Distribute app via APK, avoiding Play Store requirements | APK installable on Android 8.0+ devices |
| **G4: Effortless Sync** | Easy data synchronization via Google Drive | Sync complete within 60 seconds for typical project |

### 2.2 Business Objectives

1. **Extend Web Platform Reach**: Provide mobile access to content created by the web application
2. **Support Self-Paced Learning**: Enable users to study at their own pace, anywhere
3. **Maintain Data Portability**: Ensure users own their learning data via open JSON format
4. **Minimize Infrastructure Costs**: Use Google Drive (user's storage) instead of server-side sync

### 2.3 Non-Goals (Out of Scope)

- Content creation/processing (handled by web app)
- User authentication/accounts (personal device only)
- Social features or leaderboards
- Spaced repetition algorithms (future version)
- iOS support (future version)
- Play Store distribution (future version)

---

## 3. Target Users

### 3.1 Primary Persona: Dutch Language Learner

**Demographics:**
- Age: 25-55 years old
- Technical proficiency: Intermediate (comfortable with APK installation)
- Language level: A1-B2 Dutch learners

**Behaviors:**
- Uses web app to process Dutch audio/video content
- Studies during commute, breaks, or dedicated study time
- Prefers mobile for consumption, desktop for content preparation
- Values offline access for study in areas with poor connectivity

**Needs:**
- Quick access to sentence audio with translations
- Vocabulary lookup without interrupting study flow
- Progress tracking across multiple projects
- Reliable audio playback with looping capability

### 3.2 User Journey

```
Web App                          Google Drive                    Mobile App
   |                                  |                              |
   |---(1) Process audio/video------->|                              |
   |---(2) Export JSON--------------->|                              |
   |---(3) Upload MP3---------------->|                              |
   |                                  |                              |
   |                                  |<---(4) Connect to Drive------|
   |                                  |<---(5) Download JSON + MP3---|
   |                                  |                              |
   |                                  |                              |---(6) Study offline
   |                                  |                              |---(7) Delete when done
```

---

## 4. Functional Requirements

### 4.1 Google Drive Integration

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-1.1 | App shall authenticate with Google Drive using OAuth 2.0 | P0 | One-time setup per device |
| FR-1.2 | App shall browse user's Google Drive folders | P0 | Show file list with names, sizes, dates |
| FR-1.3 | App shall download JSON files from Google Drive | P0 | Parse and validate v1.0 format |
| FR-1.4 | App shall download MP3 audio files from Google Drive | P0 | Store in app-private storage |
| FR-1.5 | App shall show download progress indicator | P1 | Percentage and bytes transferred |
| FR-1.6 | App shall handle network errors gracefully | P1 | Retry option, offline detection |
| FR-1.7 | App shall disconnect from Google Drive on user request | P2 | Clear tokens, preserve local data |

### 4.2 Data Import and Storage

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-2.1 | App shall parse JSON export format v1.0 | P0 | Validate required fields |
| FR-2.2 | App shall store project metadata in local SQLite database | P0 | Using sqflite package |
| FR-2.3 | App shall store sentences with all fields from JSON | P0 | Including timestamps, translations |
| FR-2.4 | App shall store keywords linked to sentences | P0 | Dutch word, NL/EN meanings |
| FR-2.5 | App shall store MP3 audio in device storage | P0 | One MP3 per project |
| FR-2.6 | App shall detect and skip duplicate project imports | P1 | Based on project ID |
| FR-2.7 | App shall support import of large projects (1000+ sentences) | P1 | Progress indication |

### 4.3 Project Management

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-3.1 | App shall display list of imported projects | P0 | Name, sentence count, date imported |
| FR-3.2 | App shall allow deletion of individual projects | P0 | Confirm dialog, delete audio too |
| FR-3.3 | App shall show project details (sentence count, duration) | P1 | Total audio duration if available |
| FR-3.4 | App shall sort projects by name or import date | P2 | User preference saved |
| FR-3.5 | App shall search projects by name | P2 | Fuzzy matching |

### 4.4 Audio Playback

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-4.1 | App shall play MP3 audio files | P0 | Using just_audio or audioplayers |
| FR-4.2 | App shall seek to specific timestamp | P0 | Jump to sentence start_time |
| FR-4.3 | App shall auto-advance to next sentence on completion | P0 | Based on end_time |
| FR-4.4 | App shall loop current sentence on demand | P0 | Toggle button, loop until disabled |
| FR-4.5 | App shall support playback speed control | P0 | 0.5x, 0.75x, 1.0x, 1.25x, 1.5x |
| FR-4.6 | App shall display current playback position | P1 | Progress bar with time |
| FR-4.7 | App shall support play/pause with media button | P1 | Physical or Bluetooth |
| FR-4.8 | App shall continue playback when screen is off | P1 | Foreground service |
| FR-4.9 | App shall remember last played position per project | P1 | Resume on re-open |

### 4.5 Learning Interface

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-5.1 | App shall display current Dutch sentence prominently | P0 | Large, readable font |
| FR-5.2 | App shall display English translation below Dutch | P0 | Slightly smaller font |
| FR-5.3 | App shall show Dutch explanation (expandable) | P0 | Collapse by default |
| FR-5.4 | App shall show English explanation (expandable) | P0 | Collapse by default |
| FR-5.5 | App shall display sentence navigation (prev/next) | P0 | Buttons or swipe |
| FR-5.6 | App shall display sentence index (e.g., "15/810") | P0 | Progress indicator |
| FR-5.7 | App shall enable word tap for vocabulary lookup | P0 | Popup with meanings |
| FR-5.8 | App shall display keywords list for current sentence | P1 | Below explanations |
| FR-5.9 | App shall support sentence list view with jump | P1 | Quick navigation |
| FR-5.10 | App shall support swipe gestures for navigation | P2 | Left/right for prev/next |

### 4.6 Vocabulary Features

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-6.1 | App shall display keyword popup when word is tapped | P0 | If word is in keywords |
| FR-6.2 | App shall show Dutch and English meanings in popup | P0 | Both meaning_nl and meaning_en |
| FR-6.3 | App shall highlight words that have definitions | P1 | Visual indicator (underline/color) |
| FR-6.4 | App shall provide project vocabulary list | P2 | All unique keywords |
| FR-6.5 | App shall support vocabulary search | P2 | Search across all projects |

---

## 5. Non-Functional Requirements

### 5.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-1.1 | App cold start time | < 3 seconds |
| NFR-1.2 | Sentence navigation response | < 100ms |
| NFR-1.3 | Audio seek latency | < 200ms |
| NFR-1.4 | Project list load time | < 500ms for 50 projects |
| NFR-1.5 | Memory usage (learning screen) | < 150MB |
| NFR-1.6 | Download speed | Limited only by network |

### 5.2 Reliability

| ID | Requirement | Description |
|----|-------------|-------------|
| NFR-2.1 | Crash-free rate | > 99.5% of sessions |
| NFR-2.2 | Data integrity | Zero data loss on app crash |
| NFR-2.3 | Audio sync accuracy | Within 100ms of timestamps |
| NFR-2.4 | Offline functionality | 100% feature availability |

### 5.3 Security

| ID | Requirement | Description |
|----|-------------|-------------|
| NFR-3.1 | Google OAuth tokens | Stored securely (flutter_secure_storage) |
| NFR-3.2 | Local database | No encryption required (personal device) |
| NFR-3.3 | Audio files | Stored in app-private directory |
| NFR-3.4 | No analytics/tracking | Privacy-focused, no data collection |

### 5.4 Compatibility

| ID | Requirement | Description |
|----|-------------|-------------|
| NFR-4.1 | Minimum Android version | Android 8.0 (API 26) |
| NFR-4.2 | Target Android version | Android 14 (API 34) |
| NFR-4.3 | Screen sizes | Support phones and tablets |
| NFR-4.4 | Orientation | Portrait primary, landscape optional |
| NFR-4.5 | MP3 codec | Standard MP3 (44.1kHz, 128-320kbps) |

### 5.5 Usability

| ID | Requirement | Description |
|----|-------------|-------------|
| NFR-5.1 | Learning curve | Basic usage within 5 minutes |
| NFR-5.2 | Accessibility | Support system font scaling |
| NFR-5.3 | Error messages | Clear, actionable error messages |
| NFR-5.4 | Offline indication | Visual indicator when offline |

---

## 6. Constraints and Assumptions

### 6.1 Technical Constraints

| Constraint | Description | Impact |
|------------|-------------|--------|
| Flutter framework | Cross-platform development | May limit some native features |
| APK distribution | No auto-updates | Users must manually update |
| Google Drive API | Quota limits apply | May affect bulk downloads |
| SQLite storage | 2GB practical limit | Sufficient for text data |
| Device storage | User-dependent | Large audio files may fill storage |

### 6.2 Assumptions

1. **Users have Google accounts**: Required for Google Drive access
2. **Users can install APKs**: Device allows unknown sources
3. **Web app exports are valid**: JSON conforms to v1.0 schema
4. **MP3 files are named consistently**: Match project identification
5. **One audio file per project**: Single MP3 contains all sentences
6. **Sentence timestamps are accurate**: From Whisper transcription
7. **Device has adequate storage**: At least 500MB free for typical use

### 6.3 Dependencies

| Dependency | Purpose | Risk Level |
|------------|---------|------------|
| Google Drive API | File synchronization | Medium (API changes) |
| Flutter SDK | App development | Low (stable) |
| just_audio package | Audio playback | Low (well-maintained) |
| sqflite package | Local database | Low (stable) |
| googleapis package | Google Drive client | Medium (version updates) |

---

## 7. Success Metrics

### 7.1 Quantitative Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Successful imports | > 95% | Import success/attempt ratio |
| Audio playback errors | < 1% | Error count / playback sessions |
| App crashes | < 0.5% | Crash-free sessions |
| APK size | < 30MB | Build output |
| Average session duration | > 10 minutes | (Future: optional analytics) |

### 7.2 Qualitative Success Criteria

1. **User Satisfaction**: Users find the app intuitive and useful
2. **Learning Effectiveness**: Audio-sentence sync enhances comprehension
3. **Reliability**: App works consistently across different devices
4. **Offline Confidence**: Users trust offline functionality

---

## 8. Release Criteria

### 8.1 Minimum Viable Product (MVP)

The following features constitute the MVP for initial release:

- [ ] Google Drive authentication and file browsing
- [ ] JSON + MP3 download and import
- [ ] Project list with delete functionality
- [ ] Sentence display with translations
- [ ] Audio playback with seek to sentence
- [ ] Sentence navigation (prev/next)
- [ ] Loop current sentence
- [ ] Playback speed control
- [ ] Expandable explanations
- [ ] Word tap vocabulary popup
- [ ] Offline functionality

### 8.2 Post-MVP Features (v1.1+)

- Vocabulary list and search
- Sentence bookmarking
- Study statistics
- Dark mode
- Tablet-optimized layout
- Multiple project simultaneous download
- Background sync

---

## 9. Appendix

### 9.1 Export JSON Schema (v1.0)

```json
{
  "version": "1.0",
  "exported_at": "ISO 8601 timestamp",
  "project": {
    "id": "UUID string",
    "name": "Project display name",
    "status": "ready",
    "total_sentences": 810,
    "created_at": "ISO 8601 timestamp"
  },
  "sentences": [
    {
      "index": 0,
      "text": "Dutch sentence text",
      "start_time": 0.0,
      "end_time": 2.5,
      "translation_en": "English translation",
      "explanation_nl": "Dutch explanation",
      "explanation_en": "English explanation",
      "keywords": [
        {
          "word": "dutch_word",
          "meaning_nl": "Dutch meaning",
          "meaning_en": "English meaning"
        }
      ]
    }
  ]
}
```

### 9.2 Glossary

| Term | Definition |
|------|------------|
| **Project** | A collection of sentences from a single audio/video file |
| **Sentence** | A transcribed segment with timestamps and educational content |
| **Keyword** | A vocabulary word with Dutch and English definitions |
| **Timestamp** | Start/end time in seconds for audio synchronization |
| **Export** | JSON file containing processed project data |
| **Sync** | Download and import of project data via Google Drive |

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Requirements Analyst | Initial draft |
