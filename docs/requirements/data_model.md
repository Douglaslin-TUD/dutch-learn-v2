# Mobile Data Model Specification
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31

---

## 1. Overview

This document specifies the data model for the Flutter mobile application's local SQLite database. The model is designed to:

1. Store imported project data from JSON exports
2. Support efficient sentence navigation and vocabulary lookup
3. Enable full offline functionality
4. Maintain referential integrity between entities

---

## 2. Entity-Relationship Diagram

```
+-------------------+       1:N       +-------------------+       1:N       +-------------------+
|      Project      |---------------->|     Sentence      |---------------->|     Keyword       |
+-------------------+                 +-------------------+                 +-------------------+
| PK id             |                 | PK id             |                 | PK id             |
|    name           |                 | FK project_id     |                 | FK sentence_id    |
|    source_id      |                 |    idx            |                 |    word           |
|    status         |                 |    text           |                 |    meaning_nl     |
|    total_sentences|                 |    start_time     |                 |    meaning_en     |
|    audio_path     |                 |    end_time       |                 +-------------------+
|    audio_duration |                 |    translation_en |
|    imported_at    |                 |    explanation_nl |
|    last_played_at |                 |    explanation_en |
|    last_sentence  |                 +-------------------+
|    source_file    |
|    created_at_src |
+-------------------+

+-------------------+
|   AppSettings     |
+-------------------+
| PK key            |
|   value           |
+-------------------+
```

---

## 3. Entity Definitions

### 3.1 Project

Represents an imported learning project containing sentences from a single audio source.

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `id` | TEXT (PK) | No | Auto-generated UUID for local storage |
| `source_id` | TEXT | Yes | Original project ID from web app (for duplicate detection) |
| `name` | TEXT | No | Project display name |
| `status` | TEXT | No | Project status: 'ready', 'incomplete' |
| `total_sentences` | INTEGER | No | Total number of sentences |
| `audio_path` | TEXT | Yes | Relative path to audio file (null if no audio) |
| `audio_duration` | REAL | Yes | Audio duration in seconds (null if no audio) |
| `imported_at` | TEXT | No | ISO 8601 timestamp of import |
| `last_played_at` | TEXT | Yes | ISO 8601 timestamp of last study session |
| `last_sentence_idx` | INTEGER | Yes | Index of last studied sentence (for resume) |
| `source_file` | TEXT | Yes | Original filename from web app |
| `created_at_source` | TEXT | Yes | Original creation timestamp from web app |
| `storage_size` | INTEGER | Yes | Total storage used in bytes (JSON + audio) |

**Indexes:**
- `idx_project_name` on `name`
- `idx_project_imported_at` on `imported_at`
- `idx_project_source_id` on `source_id`

**Constraints:**
- `name` must be non-empty
- `total_sentences` must be >= 0
- `status` must be in ('ready', 'incomplete')

---

### 3.2 Sentence

Represents a single transcribed sentence with timestamps and educational content.

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `id` | TEXT (PK) | No | Auto-generated UUID |
| `project_id` | TEXT (FK) | No | Reference to parent Project |
| `idx` | INTEGER | No | Sentence index within project (0-based) |
| `text` | TEXT | No | Dutch sentence text |
| `start_time` | REAL | No | Audio start time in seconds |
| `end_time` | REAL | No | Audio end time in seconds |
| `translation_en` | TEXT | Yes | English translation |
| `explanation_nl` | TEXT | Yes | Dutch explanation of grammar/usage |
| `explanation_en` | TEXT | Yes | English explanation of grammar/usage |

**Indexes:**
- `idx_sentence_project` on `project_id`
- `idx_sentence_project_idx` on `(project_id, idx)` UNIQUE
- `idx_sentence_times` on `(project_id, start_time, end_time)`

**Constraints:**
- `project_id` must reference existing Project
- `idx` must be >= 0
- `start_time` must be >= 0
- `end_time` must be > `start_time`
- `text` must be non-empty
- Combination of `(project_id, idx)` must be unique

---

### 3.3 Keyword

Represents a vocabulary word extracted from a sentence.

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `id` | TEXT (PK) | No | Auto-generated UUID |
| `sentence_id` | TEXT (FK) | No | Reference to parent Sentence |
| `word` | TEXT | No | Dutch word or phrase |
| `meaning_nl` | TEXT | Yes | Dutch definition/meaning |
| `meaning_en` | TEXT | Yes | English definition/meaning |

**Indexes:**
- `idx_keyword_sentence` on `sentence_id`
- `idx_keyword_word` on `word`
- `idx_keyword_word_lower` on `LOWER(word)` (for case-insensitive lookup)

**Constraints:**
- `sentence_id` must reference existing Sentence
- `word` must be non-empty
- At least one of `meaning_nl` or `meaning_en` should be non-empty

---

### 3.4 AppSettings

Key-value store for application settings.

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `key` | TEXT (PK) | No | Setting identifier |
| `value` | TEXT | Yes | Setting value (JSON-encoded for complex types) |

**Predefined Keys:**
| Key | Value Type | Default | Description |
|-----|------------|---------|-------------|
| `theme` | STRING | "system" | "light", "dark", "system" |
| `font_size` | STRING | "medium" | "small", "medium", "large", "extra_large" |
| `default_speed` | REAL | 1.0 | Playback speed |
| `auto_advance` | BOOLEAN | true | Auto-advance to next sentence |
| `show_translation` | BOOLEAN | true | Show translation by default |
| `highlight_keywords` | BOOLEAN | true | Highlight tappable words |
| `background_playback` | BOOLEAN | true | Allow background audio |
| `project_sort` | STRING | "imported_desc" | Sort order for project list |
| `google_drive_connected` | BOOLEAN | false | Google Drive connection status |
| `last_sync_at` | STRING | null | Last sync timestamp |

---

## 4. Field Specifications

### 4.1 Text Fields

| Entity | Field | Max Length | Character Set | Notes |
|--------|-------|------------|---------------|-------|
| Project | name | 255 | UTF-8 | Display name |
| Project | source_id | 36 | ASCII | UUID format |
| Project | audio_path | 512 | UTF-8 | Relative path |
| Sentence | text | 10000 | UTF-8 | Dutch text with special chars |
| Sentence | translation_en | 10000 | UTF-8 | English translation |
| Sentence | explanation_nl | 50000 | UTF-8 | Detailed explanations |
| Sentence | explanation_en | 50000 | UTF-8 | Detailed explanations |
| Keyword | word | 100 | UTF-8 | Single word or short phrase |
| Keyword | meaning_nl | 1000 | UTF-8 | Definition |
| Keyword | meaning_en | 1000 | UTF-8 | Definition |

### 4.2 Timestamp Fields

All timestamps stored as ISO 8601 strings: `YYYY-MM-DDTHH:MM:SS.sssZ`

Example: `2025-12-31T14:30:00.000Z`

### 4.3 Time Fields (Audio)

Audio times stored as REAL (floating point) in seconds with millisecond precision.

Examples:
- `0.0` - Start of audio
- `2.567` - 2 seconds, 567 milliseconds
- `3723.5` - 1 hour, 2 minutes, 3.5 seconds

---

## 5. Relationships

### 5.1 Project -> Sentence (One-to-Many)

- One Project contains multiple Sentences
- Sentences are ordered by `idx` field
- Deleting a Project cascades to delete all Sentences

```dart
// Dart relationship
class Project {
  List<Sentence> sentences; // Loaded on demand
}

class Sentence {
  String projectId; // Foreign key
}
```

### 5.2 Sentence -> Keyword (One-to-Many)

- One Sentence can have multiple Keywords
- Keywords are not ordered
- Deleting a Sentence cascades to delete all Keywords

```dart
// Dart relationship
class Sentence {
  List<Keyword> keywords; // Loaded on demand
}

class Keyword {
  String sentenceId; // Foreign key
}
```

---

## 6. Database Schema (SQL)

```sql
-- Projects table
CREATE TABLE projects (
    id TEXT PRIMARY KEY NOT NULL,
    source_id TEXT,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ready',
    total_sentences INTEGER NOT NULL DEFAULT 0,
    audio_path TEXT,
    audio_duration REAL,
    imported_at TEXT NOT NULL,
    last_played_at TEXT,
    last_sentence_idx INTEGER,
    source_file TEXT,
    created_at_source TEXT,
    storage_size INTEGER,
    CHECK (status IN ('ready', 'incomplete')),
    CHECK (total_sentences >= 0)
);

CREATE INDEX idx_project_name ON projects(name);
CREATE INDEX idx_project_imported_at ON projects(imported_at);
CREATE INDEX idx_project_source_id ON projects(source_id);

-- Sentences table
CREATE TABLE sentences (
    id TEXT PRIMARY KEY NOT NULL,
    project_id TEXT NOT NULL,
    idx INTEGER NOT NULL,
    text TEXT NOT NULL,
    start_time REAL NOT NULL,
    end_time REAL NOT NULL,
    translation_en TEXT,
    explanation_nl TEXT,
    explanation_en TEXT,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    UNIQUE (project_id, idx),
    CHECK (idx >= 0),
    CHECK (start_time >= 0),
    CHECK (end_time > start_time)
);

CREATE INDEX idx_sentence_project ON sentences(project_id);
CREATE INDEX idx_sentence_project_idx ON sentences(project_id, idx);
CREATE INDEX idx_sentence_times ON sentences(project_id, start_time, end_time);

-- Keywords table
CREATE TABLE keywords (
    id TEXT PRIMARY KEY NOT NULL,
    sentence_id TEXT NOT NULL,
    word TEXT NOT NULL,
    meaning_nl TEXT,
    meaning_en TEXT,
    FOREIGN KEY (sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
);

CREATE INDEX idx_keyword_sentence ON keywords(sentence_id);
CREATE INDEX idx_keyword_word ON keywords(word);
CREATE INDEX idx_keyword_word_lower ON keywords(LOWER(word));

-- App settings table
CREATE TABLE app_settings (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT
);

-- Initialize default settings
INSERT INTO app_settings (key, value) VALUES
    ('theme', '"system"'),
    ('font_size', '"medium"'),
    ('default_speed', '1.0'),
    ('auto_advance', 'true'),
    ('show_translation', 'true'),
    ('highlight_keywords', 'true'),
    ('background_playback', 'true'),
    ('project_sort', '"imported_desc"'),
    ('google_drive_connected', 'false');
```

---

## 7. Dart Model Classes

### 7.1 Project Model

```dart
import 'package:uuid/uuid.dart';

class Project {
  final String id;
  final String? sourceId;
  final String name;
  final String status;
  final int totalSentences;
  final String? audioPath;
  final double? audioDuration;
  final DateTime importedAt;
  final DateTime? lastPlayedAt;
  final int? lastSentenceIdx;
  final String? sourceFile;
  final DateTime? createdAtSource;
  final int? storageSize;

  Project({
    String? id,
    this.sourceId,
    required this.name,
    this.status = 'ready',
    this.totalSentences = 0,
    this.audioPath,
    this.audioDuration,
    DateTime? importedAt,
    this.lastPlayedAt,
    this.lastSentenceIdx,
    this.sourceFile,
    this.createdAtSource,
    this.storageSize,
  })  : id = id ?? const Uuid().v4(),
        importedAt = importedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_id': sourceId,
      'name': name,
      'status': status,
      'total_sentences': totalSentences,
      'audio_path': audioPath,
      'audio_duration': audioDuration,
      'imported_at': importedAt.toIso8601String(),
      'last_played_at': lastPlayedAt?.toIso8601String(),
      'last_sentence_idx': lastSentenceIdx,
      'source_file': sourceFile,
      'created_at_source': createdAtSource?.toIso8601String(),
      'storage_size': storageSize,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      sourceId: map['source_id'],
      name: map['name'],
      status: map['status'] ?? 'ready',
      totalSentences: map['total_sentences'] ?? 0,
      audioPath: map['audio_path'],
      audioDuration: map['audio_duration'],
      importedAt: DateTime.parse(map['imported_at']),
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.parse(map['last_played_at'])
          : null,
      lastSentenceIdx: map['last_sentence_idx'],
      sourceFile: map['source_file'],
      createdAtSource: map['created_at_source'] != null
          ? DateTime.parse(map['created_at_source'])
          : null,
      storageSize: map['storage_size'],
    );
  }

  /// Create from JSON export format
  factory Project.fromExportJson(Map<String, dynamic> json, String exportedAt) {
    return Project(
      sourceId: json['id'],
      name: json['name'],
      status: json['status'] ?? 'ready',
      totalSentences: json['total_sentences'] ?? 0,
      sourceFile: json['name'],
      createdAtSource: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Project copyWith({
    String? audioPath,
    double? audioDuration,
    DateTime? lastPlayedAt,
    int? lastSentenceIdx,
    int? storageSize,
  }) {
    return Project(
      id: id,
      sourceId: sourceId,
      name: name,
      status: status,
      totalSentences: totalSentences,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      importedAt: importedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastSentenceIdx: lastSentenceIdx ?? this.lastSentenceIdx,
      sourceFile: sourceFile,
      createdAtSource: createdAtSource,
      storageSize: storageSize ?? this.storageSize,
    );
  }
}
```

### 7.2 Sentence Model

```dart
import 'package:uuid/uuid.dart';

class Sentence {
  final String id;
  final String projectId;
  final int idx;
  final String text;
  final double startTime;
  final double endTime;
  final String? translationEn;
  final String? explanationNl;
  final String? explanationEn;

  // Not stored in DB, loaded separately
  List<Keyword>? keywords;

  Sentence({
    String? id,
    required this.projectId,
    required this.idx,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.translationEn,
    this.explanationNl,
    this.explanationEn,
    this.keywords,
  }) : id = id ?? const Uuid().v4();

  /// Duration of this sentence in seconds
  double get duration => endTime - startTime;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'idx': idx,
      'text': text,
      'start_time': startTime,
      'end_time': endTime,
      'translation_en': translationEn,
      'explanation_nl': explanationNl,
      'explanation_en': explanationEn,
    };
  }

  factory Sentence.fromMap(Map<String, dynamic> map) {
    return Sentence(
      id: map['id'],
      projectId: map['project_id'],
      idx: map['idx'],
      text: map['text'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      translationEn: map['translation_en'],
      explanationNl: map['explanation_nl'],
      explanationEn: map['explanation_en'],
    );
  }

  /// Create from JSON export format
  factory Sentence.fromExportJson(
    Map<String, dynamic> json,
    String projectId,
  ) {
    return Sentence(
      projectId: projectId,
      idx: json['index'],
      text: json['text'],
      startTime: (json['start_time'] as num).toDouble(),
      endTime: (json['end_time'] as num).toDouble(),
      translationEn: json['translation_en'],
      explanationNl: json['explanation_nl'],
      explanationEn: json['explanation_en'],
    );
  }
}
```

### 7.3 Keyword Model

```dart
import 'package:uuid/uuid.dart';

class Keyword {
  final String id;
  final String sentenceId;
  final String word;
  final String? meaningNl;
  final String? meaningEn;

  Keyword({
    String? id,
    required this.sentenceId,
    required this.word,
    this.meaningNl,
    this.meaningEn,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sentence_id': sentenceId,
      'word': word,
      'meaning_nl': meaningNl,
      'meaning_en': meaningEn,
    };
  }

  factory Keyword.fromMap(Map<String, dynamic> map) {
    return Keyword(
      id: map['id'],
      sentenceId: map['sentence_id'],
      word: map['word'],
      meaningNl: map['meaning_nl'],
      meaningEn: map['meaning_en'],
    );
  }

  /// Create from JSON export format
  factory Keyword.fromExportJson(
    Map<String, dynamic> json,
    String sentenceId,
  ) {
    return Keyword(
      sentenceId: sentenceId,
      word: json['word'],
      meaningNl: json['meaning_nl'],
      meaningEn: json['meaning_en'],
    );
  }
}
```

---

## 8. Data Access Patterns

### 8.1 Common Queries

```dart
// Get all projects sorted by import date
SELECT * FROM projects ORDER BY imported_at DESC;

// Get project by source ID (for duplicate detection)
SELECT * FROM projects WHERE source_id = ?;

// Get sentences for a project
SELECT * FROM sentences WHERE project_id = ? ORDER BY idx;

// Get single sentence by index
SELECT * FROM sentences WHERE project_id = ? AND idx = ?;

// Get sentence containing a specific time
SELECT * FROM sentences
WHERE project_id = ? AND start_time <= ? AND end_time > ?
ORDER BY idx LIMIT 1;

// Get keywords for a sentence
SELECT * FROM keywords WHERE sentence_id = ?;

// Get keyword by word (case-insensitive)
SELECT * FROM keywords
WHERE sentence_id = ? AND LOWER(word) = LOWER(?);

// Get all unique keywords in a project
SELECT DISTINCT k.word, k.meaning_nl, k.meaning_en
FROM keywords k
JOIN sentences s ON k.sentence_id = s.id
WHERE s.project_id = ?
ORDER BY k.word;

// Search vocabulary across all projects
SELECT k.*, s.project_id, p.name as project_name
FROM keywords k
JOIN sentences s ON k.sentence_id = s.id
JOIN projects p ON s.project_id = p.id
WHERE LOWER(k.word) LIKE ? OR LOWER(k.meaning_en) LIKE ?
ORDER BY k.word;

// Update last played position
UPDATE projects
SET last_played_at = ?, last_sentence_idx = ?
WHERE id = ?;
```

### 8.2 Import Transaction

```dart
Future<void> importProject(Map<String, dynamic> exportData) async {
  await database.transaction((txn) async {
    // 1. Insert project
    final projectJson = exportData['project'];
    final project = Project.fromExportJson(
      projectJson,
      exportData['exported_at'],
    );
    await txn.insert('projects', project.toMap());

    // 2. Insert sentences and keywords
    final sentences = exportData['sentences'] as List;
    for (final sentenceJson in sentences) {
      final sentence = Sentence.fromExportJson(sentenceJson, project.id);
      await txn.insert('sentences', sentence.toMap());

      // Insert keywords for this sentence
      final keywords = sentenceJson['keywords'] as List? ?? [];
      for (final keywordJson in keywords) {
        final keyword = Keyword.fromExportJson(keywordJson, sentence.id);
        await txn.insert('keywords', keyword.toMap());
      }
    }
  });
}
```

---

## 9. Local Storage Considerations

### 9.1 File Storage Structure

```
app_data/
├── databases/
│   └── dutch_learn.db          # SQLite database
├── audio/
│   ├── {project_id_1}.mp3      # Audio file per project
│   ├── {project_id_2}.mp3
│   └── ...
└── cache/
    └── drive/                   # Temporary download cache
        └── {download_id}.tmp
```

### 9.2 Storage Estimates

| Content | Size Estimate |
|---------|--------------|
| Database per 1000 sentences | ~2-5 MB |
| Audio file (1 hour) | 50-100 MB |
| Typical project (500 sentences, 30 min audio) | 30-60 MB |
| App with 10 projects | 300-600 MB |

### 9.3 Database Migrations

```dart
// Migration strategy for future versions
final migrations = {
  1: '''
    -- Initial schema (v1.0)
    CREATE TABLE projects (...);
    CREATE TABLE sentences (...);
    CREATE TABLE keywords (...);
    CREATE TABLE app_settings (...);
  ''',
  2: '''
    -- Future: Add bookmarks table
    CREATE TABLE bookmarks (
      id TEXT PRIMARY KEY,
      sentence_id TEXT NOT NULL,
      note TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
    );
  ''',
  3: '''
    -- Future: Add study progress tracking
    ALTER TABLE sentences ADD COLUMN times_played INTEGER DEFAULT 0;
    ALTER TABLE sentences ADD COLUMN last_played_at TEXT;
  ''',
};
```

---

## 10. Data Validation Rules

### 10.1 Import Validation

```dart
class ImportValidator {
  static ValidationResult validate(Map<String, dynamic> json) {
    final errors = <String>[];

    // Version check
    if (json['version'] != '1.0') {
      errors.add('Unsupported export version: ${json['version']}');
    }

    // Project validation
    final project = json['project'];
    if (project == null) {
      errors.add('Missing project data');
    } else {
      if (project['name']?.isEmpty ?? true) {
        errors.add('Project name is required');
      }
    }

    // Sentences validation
    final sentences = json['sentences'] as List?;
    if (sentences == null || sentences.isEmpty) {
      errors.add('At least one sentence is required');
    } else {
      for (int i = 0; i < sentences.length; i++) {
        final s = sentences[i];
        if (s['text']?.isEmpty ?? true) {
          errors.add('Sentence $i: text is required');
        }
        if (s['start_time'] == null) {
          errors.add('Sentence $i: start_time is required');
        }
        if (s['end_time'] == null) {
          errors.add('Sentence $i: end_time is required');
        }
        if (s['start_time'] != null && s['end_time'] != null) {
          if (s['start_time'] >= s['end_time']) {
            errors.add('Sentence $i: end_time must be after start_time');
          }
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
```

---

## Appendix: JSON to Model Mapping

| JSON Field (Export) | Model Class | Model Field |
|---------------------|-------------|-------------|
| `project.id` | Project | sourceId |
| `project.name` | Project | name |
| `project.status` | Project | status |
| `project.total_sentences` | Project | totalSentences |
| `project.created_at` | Project | createdAtSource |
| `sentences[].index` | Sentence | idx |
| `sentences[].text` | Sentence | text |
| `sentences[].start_time` | Sentence | startTime |
| `sentences[].end_time` | Sentence | endTime |
| `sentences[].translation_en` | Sentence | translationEn |
| `sentences[].explanation_nl` | Sentence | explanationNl |
| `sentences[].explanation_en` | Sentence | explanationEn |
| `sentences[].keywords[].word` | Keyword | word |
| `sentences[].keywords[].meaning_nl` | Keyword | meaningNl |
| `sentences[].keywords[].meaning_en` | Keyword | meaningEn |

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Requirements Analyst | Initial data model |
