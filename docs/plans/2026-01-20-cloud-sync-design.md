# Cloud Sync Design - Dutch Learn App

**Date:** 2026-01-20
**Status:** Approved

---

## 1. Overview

Enable bidirectional sync between desktop (FastAPI) and mobile (Flutter) via Google Drive.

### Design Decisions

| Item | Decision |
|------|----------|
| Trigger | Manual (click sync button) |
| Data Scope | Project data + Learning progress |
| Conflict Resolution | Auto-merge (union) |
| Cloud Storage | Google Drive |
| Architecture | Separate data and progress files (Plan B) |
| Mobile Processing | Yes (after API Key sync from desktop) |

---

## 2. Architecture

### 2.1 Overall Architecture

```
┌─────────────┐                    ┌─────────────┐
│   Desktop   │                    │   Mobile    │
│  (FastAPI)  │                    │  (Flutter)  │
└──────┬──────┘                    └──────┬──────┘
       │                                  │
       │  ┌──────────────────────────┐    │
       └──►     Google Drive         ◄────┘
            │                        │
            │  📁 Dutch Learn/       │
            │  ├── 📁 project-uuid1/ │
            │  │   ├── project.json  │  ← Project data
            │  │   ├── progress.json │  ← Learning progress
            │  │   └── audio.mp3     │  ← Audio file
            │  ├── 📁 project-uuid2/ │
            │  └── sync_meta.json    │  ← Sync metadata
            └────────────────────────┘
```

---

## 3. File Structures

### 3.1 project.json (immutable after processing)

```json
{
  "id": "uuid",
  "name": "project name",
  "created_at": "2026-01-19T22:19:20",
  "audio_duration": 1661,
  "sentences": [
    {
      "id": 1,
      "start_time": 0.0,
      "end_time": 7.0,
      "dutch_text": "...",
      "translation": "...",
      "dutch_explanation": "...",
      "english_explanation": "...",
      "keywords": [
        {"word": "kijken", "meaning": "to look", "synonym": "zien"}
      ]
    }
  ]
}
```

### 3.2 progress.json (frequently updated)

```json
{
  "project_id": "uuid",
  "last_modified": "2026-01-20T10:30:00",
  "device_id": "phone-abc123",
  "learned_sentences": [1, 2, 3, 5, 8],
  "bookmarked_sentences": [3, 15],
  "current_position": 8,
  "notes": {
    "3": "Important grammar point",
    "15": "Review this word"
  }
}
```

### 3.3 sync_meta.json (root level)

```json
{
  "last_sync": "2026-01-20T10:00:00",
  "projects": {
    "uuid1": {"version": 3, "last_modified": "2026-01-20T09:00:00"},
    "uuid2": {"version": 1, "last_modified": "2026-01-19T15:00:00"}
  }
}
```

---

## 4. Sync Flow

### 4.1 Upload (Desktop → Cloud)

```
1. Click "Sync to Cloud"
         │
         ▼
2. Scan local projects
         │
         ▼
3. Compare with cloud sync_meta.json
         │
         ├── New project? → Upload project.json + audio.mp3 + progress.json
         │
         └── Exists? → Compare progress.json timestamps
                      │
                      ├── Local newer → Download cloud progress → Merge → Upload
                      │
                      └── Cloud newer → Download → Merge locally → Upload merged
```

### 4.2 Sync (Mobile ↔ Cloud)

```
1. Click "Sync"
         │
         ▼
2. Get cloud project list
         │
         ├── New project? → Download project.json + audio.mp3 + progress.json
         │
         └── Exists? → Compare progress.json timestamps
                      │
                      └── Merge progress → Upload merged progress.json
```

---

## 5. Progress Merge Logic

### 5.1 Merge Rules

| Field | Strategy | Example |
|-------|----------|---------|
| `learned_sentences` | Union | `[1,2,3] + [2,3,4] = [1,2,3,4]` |
| `bookmarked_sentences` | Union | Keep all bookmarks |
| `current_position` | Max | Keep furthest position |
| `notes` | Merge dict | Same sentence: keep latest |
| `last_modified` | Update | Set to current time |

### 5.2 Merge Example

```python
# Local (desktop)
local = {
    "learned_sentences": [1, 2, 3, 5],
    "bookmarked_sentences": [3],
    "current_position": 5,
    "notes": {"3": "grammar", "5": "desktop note"}
}

# Cloud (from mobile)
cloud = {
    "learned_sentences": [1, 2, 4, 6],
    "bookmarked_sentences": [4, 6],
    "current_position": 6,
    "notes": {"4": "mobile note"}
}

# Merged result
merged = {
    "learned_sentences": [1, 2, 3, 4, 5, 6],
    "bookmarked_sentences": [3, 4, 6],
    "current_position": 6,
    "notes": {"3": "grammar", "4": "mobile note", "5": "desktop note"}
}
```

---

## 6. Implementation Plan

### 6.1 Desktop (FastAPI)

**New files:**
- `app/services/sync_service.py` - Sync core logic
- `app/services/progress_merger.py` - Progress merge logic
- `app/routers/sync.py` - API endpoints

**API endpoints:**
```
POST /api/sync/upload   - Upload local projects to Drive
POST /api/sync/download - Pull updates from Drive
GET  /api/sync/status   - Get sync status
```

**Web UI:**
- Add sync button to header
- Show last sync time and pending count

### 6.2 Mobile (Flutter)

**New files:**
- `lib/data/services/sync_service.dart`
- `lib/presentation/screens/sync_screen.dart`
- `lib/presentation/widgets/sync_button.dart`

**Modifications:**
- `google_drive_datasource.dart` - Add upload capability

**OAuth scope change:**
```dart
// From: drive.readonly
// To: drive.file (read/write app-created files only)
```

---

## 7. Security

- OAuth scope: `drive.file` (only access app-created files)
- Tokens stored securely (Keyring on desktop, SecureStorage on mobile)
- No sensitive data in project files

---

## 8. API Key Secure Transfer (One-time Setup)

### 8.1 Purpose

Enable mobile app to process audio independently by securely transferring OpenAI API Key from desktop.

### 8.2 Transfer Flow

```
┌─────────────────────────────────────────────────────────────┐
│  One-time setup (first sync)                                │
│                                                             │
│  Desktop:                                                   │
│    1. Read OPENAI_API_KEY from .env                         │
│    2. Generate encryption key (device-specific)             │
│    3. Encrypt API Key → config.encrypted                    │
│    4. Upload to Drive: Dutch Learn/.config/config.encrypted │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Mobile (first sync):                                       │
│    1. Download config.encrypted from Drive                  │
│    2. Decrypt using device key                              │
│    3. Store in Flutter SecureStorage                        │
│    4. Delete config.encrypted from Drive (optional)         │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 Encryption Method

```python
# Desktop: encrypt API key
from cryptography.fernet import Fernet

def encrypt_api_key(api_key: str, device_id: str) -> bytes:
    # Derive key from device_id + app secret
    key = derive_key(device_id, APP_SECRET)
    fernet = Fernet(key)
    return fernet.encrypt(api_key.encode())
```

```dart
// Mobile: decrypt API key
import 'package:encrypt/encrypt.dart';

Future<String> decryptApiKey(Uint8List encrypted, String deviceId) async {
  final key = deriveKey(deviceId, APP_SECRET);
  final fernet = Fernet(key);
  return fernet.decrypt(encrypted);
}
```

### 8.4 config.encrypted Structure

```json
{
  "version": 1,
  "created_at": "2026-01-20T10:00:00",
  "encrypted_data": "base64-encoded-encrypted-api-key"
}
```

---

## 9. Mobile Audio Processing

### 9.1 Prerequisites

- API Key transferred from desktop (Section 8)
- `ffmpeg_kit_flutter` package for audio conversion

### 9.2 Processing Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Mobile Processing Flow                                     │
│                                                             │
│  1. User selects/records audio                              │
│         ↓                                                   │
│  2. Convert to MP3 (ffmpeg_kit_flutter)                     │
│         ↓                                                   │
│  3. Upload to OpenAI Whisper API → Dutch transcription      │
│         ↓                                                   │
│  4. Send to GPT API → Translations + Explanations           │
│         ↓                                                   │
│  5. Save project locally                                    │
│         ↓                                                   │
│  6. Sync to Drive (on next sync)                            │
└─────────────────────────────────────────────────────────────┘
```

### 9.3 Implementation

**New Flutter files:**
- `lib/data/services/audio_processor.dart` - Audio processing service
- `lib/data/services/whisper_service.dart` - OpenAI Whisper API client
- `lib/data/services/gpt_service.dart` - OpenAI GPT API client
- `lib/presentation/screens/record_screen.dart` - Recording UI

**Dependencies to add:**
```yaml
# pubspec.yaml
dependencies:
  ffmpeg_kit_flutter: ^6.0.3
  record: ^5.0.4  # For audio recording
  encrypt: ^5.0.1  # For API key decryption
```

### 9.4 Mobile Processing UI

```
┌─────────────────────────────┐
│  ←  New Project             │
├─────────────────────────────┤
│                             │
│  ┌─────────────────────┐    │
│  │  🎤 Record Audio    │    │
│  └─────────────────────┘    │
│                             │
│  ┌─────────────────────┐    │
│  │  📁 Select File     │    │
│  └─────────────────────┘    │
│                             │
├─────────────────────────────┤
│  Processing...              │
│  [=====>              ] 30% │
│  Transcribing audio...      │
└─────────────────────────────┘
```

### 9.5 Limitations

- Large files (>25MB) need chunking (same as desktop)
- Processing uses mobile data/WiFi
- Battery consumption during processing
- Recommended: WiFi + charging for long audio

---

## 10. Future Enhancements (Out of Scope)

- Real-time sync
- Conflict UI for manual resolution
- Sync over local network (no cloud)
- Multi-user sharing

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-20 | Claude + User | Initial design |
| 1.1 | 2026-01-20 | Claude + User | Added API Key transfer + Mobile processing |
