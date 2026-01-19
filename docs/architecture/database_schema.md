# SQLite Database Schema
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31

---

## 1. Schema Overview

The local SQLite database stores all learning content for offline access. The schema is optimized for:
- Fast sentence navigation during study
- Efficient vocabulary lookup
- Quick project list loading
- Minimal storage footprint

### Entity Relationship Diagram

```
+-------------------+       1:N       +-------------------+       1:N       +-------------------+
|     projects      |---------------->|    sentences      |---------------->|    keywords       |
+-------------------+                 +-------------------+                 +-------------------+
| PK id TEXT        |                 | PK id TEXT        |                 | PK id TEXT        |
|    source_id      |                 | FK project_id     |                 | FK sentence_id    |
|    name           |                 |    idx            |                 |    word           |
|    status         |                 |    text           |                 |    meaning_nl     |
|    total_sentences|                 |    start_time     |                 |    meaning_en     |
|    audio_path     |                 |    end_time       |                 +-------------------+
|    audio_duration |                 |    translation_en |
|    imported_at    |                 |    explanation_nl |
|    last_played_at |                 |    explanation_en |
|    last_sentence  |                 +-------------------+
|    storage_size   |
+-------------------+

+-------------------+
|   app_settings    |
+-------------------+
| PK key TEXT       |
|    value TEXT     |
+-------------------+
```

---

## 2. Table Definitions

### 2.1 projects

Stores imported project metadata.

```sql
CREATE TABLE projects (
    -- Primary key: locally generated UUID
    id TEXT PRIMARY KEY NOT NULL,

    -- Original project ID from web app (for duplicate detection)
    source_id TEXT,

    -- Project display name
    name TEXT NOT NULL,

    -- Status: 'ready', 'incomplete'
    status TEXT NOT NULL DEFAULT 'ready'
        CHECK (status IN ('ready', 'incomplete')),

    -- Total number of sentences in project
    total_sentences INTEGER NOT NULL DEFAULT 0
        CHECK (total_sentences >= 0),

    -- Relative path to audio file (null if no audio linked)
    audio_path TEXT,

    -- Audio duration in seconds (null if no audio)
    audio_duration REAL
        CHECK (audio_duration IS NULL OR audio_duration > 0),

    -- ISO 8601 timestamp when project was imported
    imported_at TEXT NOT NULL,

    -- ISO 8601 timestamp of last study session (null if never studied)
    last_played_at TEXT,

    -- Index of last studied sentence (for resume functionality)
    last_sentence_idx INTEGER
        CHECK (last_sentence_idx IS NULL OR last_sentence_idx >= 0),

    -- Original source filename from web app
    source_file TEXT,

    -- Original creation timestamp from web app
    created_at_source TEXT,

    -- Total storage used in bytes (JSON + audio)
    storage_size INTEGER
        CHECK (storage_size IS NULL OR storage_size >= 0)
);

-- Index for finding project by source ID (duplicate detection)
CREATE INDEX idx_project_source_id ON projects(source_id);

-- Index for sorting by name
CREATE INDEX idx_project_name ON projects(name COLLATE NOCASE);

-- Index for sorting by import date
CREATE INDEX idx_project_imported_at ON projects(imported_at DESC);
```

### 2.2 sentences

Stores individual transcribed sentences with timestamps and educational content.

```sql
CREATE TABLE sentences (
    -- Primary key: locally generated UUID
    id TEXT PRIMARY KEY NOT NULL,

    -- Foreign key to parent project
    project_id TEXT NOT NULL,

    -- Sentence index within project (0-based, for ordering)
    idx INTEGER NOT NULL
        CHECK (idx >= 0),

    -- Dutch sentence text
    text TEXT NOT NULL,

    -- Audio start time in seconds
    start_time REAL NOT NULL
        CHECK (start_time >= 0),

    -- Audio end time in seconds
    end_time REAL NOT NULL
        CHECK (end_time > start_time),

    -- English translation (optional)
    translation_en TEXT,

    -- Dutch grammar/usage explanation (optional)
    explanation_nl TEXT,

    -- English grammar/usage explanation (optional)
    explanation_en TEXT,

    -- Foreign key constraint with cascade delete
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,

    -- Ensure unique sentence index per project
    UNIQUE (project_id, idx)
);

-- Index for fetching sentences by project
CREATE INDEX idx_sentence_project ON sentences(project_id);

-- Composite index for navigating to specific sentence
CREATE INDEX idx_sentence_project_idx ON sentences(project_id, idx);

-- Index for finding sentence at specific time
CREATE INDEX idx_sentence_times ON sentences(project_id, start_time, end_time);

-- Full-text search index for sentence content (optional, for search feature)
-- CREATE VIRTUAL TABLE sentences_fts USING fts5(text, content='sentences', content_rowid='rowid');
```

### 2.3 keywords

Stores vocabulary words extracted from sentences.

```sql
CREATE TABLE keywords (
    -- Primary key: locally generated UUID
    id TEXT PRIMARY KEY NOT NULL,

    -- Foreign key to parent sentence
    sentence_id TEXT NOT NULL,

    -- Dutch word or phrase
    word TEXT NOT NULL,

    -- Dutch definition/meaning (optional)
    meaning_nl TEXT,

    -- English definition/meaning (optional)
    meaning_en TEXT,

    -- Foreign key constraint with cascade delete
    FOREIGN KEY (sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
);

-- Index for fetching keywords by sentence
CREATE INDEX idx_keyword_sentence ON keywords(sentence_id);

-- Index for word lookup (case-sensitive)
CREATE INDEX idx_keyword_word ON keywords(word);

-- Index for case-insensitive word lookup
CREATE INDEX idx_keyword_word_lower ON keywords(word COLLATE NOCASE);
```

### 2.4 app_settings

Key-value store for application preferences.

```sql
CREATE TABLE app_settings (
    -- Setting identifier
    key TEXT PRIMARY KEY NOT NULL,

    -- Setting value (JSON-encoded for complex types)
    value TEXT
);
```

---

## 3. Indexes

### 3.1 Index Summary

| Table | Index Name | Columns | Purpose |
|-------|------------|---------|---------|
| projects | idx_project_source_id | source_id | Duplicate detection |
| projects | idx_project_name | name COLLATE NOCASE | Alphabetical sorting |
| projects | idx_project_imported_at | imported_at DESC | Date sorting |
| sentences | idx_sentence_project | project_id | Fetch by project |
| sentences | idx_sentence_project_idx | project_id, idx | Navigate by index |
| sentences | idx_sentence_times | project_id, start_time, end_time | Find by timestamp |
| keywords | idx_keyword_sentence | sentence_id | Fetch by sentence |
| keywords | idx_keyword_word | word | Word lookup |
| keywords | idx_keyword_word_lower | word COLLATE NOCASE | Case-insensitive lookup |

### 3.2 Query Performance Expectations

| Query | Expected Time | Index Used |
|-------|---------------|------------|
| Get all projects | O(n) | - |
| Get project by source_id | O(1) | idx_project_source_id |
| Get sentences for project | O(n) | idx_sentence_project |
| Get sentence by index | O(1) | idx_sentence_project_idx |
| Get sentence at time | O(log n) | idx_sentence_times |
| Get keywords for sentence | O(k) | idx_keyword_sentence |
| Find keyword by word | O(1) | idx_keyword_word |

---

## 4. Common Queries

### 4.1 Project Queries

```sql
-- Get all projects sorted by import date (newest first)
SELECT * FROM projects ORDER BY imported_at DESC;

-- Get all projects sorted by name
SELECT * FROM projects ORDER BY name COLLATE NOCASE ASC;

-- Get project by ID
SELECT * FROM projects WHERE id = ?;

-- Check for duplicate by source ID
SELECT id FROM projects WHERE source_id = ?;

-- Update last played position
UPDATE projects
SET last_played_at = ?, last_sentence_idx = ?
WHERE id = ?;

-- Delete project (cascades to sentences and keywords)
DELETE FROM projects WHERE id = ?;

-- Get storage statistics
SELECT
    COUNT(*) as project_count,
    SUM(total_sentences) as total_sentences,
    SUM(storage_size) as total_storage
FROM projects;
```

### 4.2 Sentence Queries

```sql
-- Get all sentences for a project (ordered)
SELECT * FROM sentences
WHERE project_id = ?
ORDER BY idx;

-- Get single sentence by index
SELECT * FROM sentences
WHERE project_id = ? AND idx = ?;

-- Get sentence containing specific time
SELECT * FROM sentences
WHERE project_id = ?
  AND start_time <= ?
  AND end_time > ?
ORDER BY idx
LIMIT 1;

-- Get sentence count for project
SELECT COUNT(*) FROM sentences WHERE project_id = ?;

-- Get next sentence
SELECT * FROM sentences
WHERE project_id = ? AND idx = ?;

-- Get previous sentence
SELECT * FROM sentences
WHERE project_id = ? AND idx = ?;
```

### 4.3 Keyword Queries

```sql
-- Get keywords for a sentence
SELECT * FROM keywords WHERE sentence_id = ?;

-- Find keyword by word (exact match)
SELECT * FROM keywords
WHERE sentence_id = ? AND word = ?;

-- Find keyword by word (case-insensitive)
SELECT * FROM keywords
WHERE sentence_id = ? AND word = ? COLLATE NOCASE;

-- Get all unique keywords in a project
SELECT DISTINCT k.word, k.meaning_nl, k.meaning_en
FROM keywords k
JOIN sentences s ON k.sentence_id = s.id
WHERE s.project_id = ?
ORDER BY k.word COLLATE NOCASE;

-- Search vocabulary across all projects
SELECT k.*, s.project_id, p.name as project_name
FROM keywords k
JOIN sentences s ON k.sentence_id = s.id
JOIN projects p ON s.project_id = p.id
WHERE k.word LIKE ? COLLATE NOCASE
   OR k.meaning_en LIKE ? COLLATE NOCASE
ORDER BY k.word COLLATE NOCASE
LIMIT 50;
```

### 4.4 Settings Queries

```sql
-- Get setting
SELECT value FROM app_settings WHERE key = ?;

-- Set setting (upsert)
INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?);

-- Delete setting
DELETE FROM app_settings WHERE key = ?;

-- Get all settings
SELECT * FROM app_settings;
```

---

## 5. Migration Strategy

### 5.1 Migration Framework

```dart
class DatabaseMigrations {
  static const currentVersion = 1;

  static final Map<int, String> migrations = {
    1: _migration1,
    // 2: _migration2,
    // 3: _migration3,
  };

  static const String _migration1 = '''
    -- Initial schema v1.0

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

    CREATE TABLE keywords (
      id TEXT PRIMARY KEY NOT NULL,
      sentence_id TEXT NOT NULL,
      word TEXT NOT NULL,
      meaning_nl TEXT,
      meaning_en TEXT,
      FOREIGN KEY (sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
    );

    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT
    );

    -- Indexes
    CREATE INDEX idx_project_source_id ON projects(source_id);
    CREATE INDEX idx_project_name ON projects(name COLLATE NOCASE);
    CREATE INDEX idx_project_imported_at ON projects(imported_at DESC);
    CREATE INDEX idx_sentence_project ON sentences(project_id);
    CREATE INDEX idx_sentence_project_idx ON sentences(project_id, idx);
    CREATE INDEX idx_sentence_times ON sentences(project_id, start_time, end_time);
    CREATE INDEX idx_keyword_sentence ON keywords(sentence_id);
    CREATE INDEX idx_keyword_word ON keywords(word);
    CREATE INDEX idx_keyword_word_lower ON keywords(word COLLATE NOCASE);

    -- Default settings
    INSERT INTO app_settings (key, value) VALUES
      ('theme', '"system"'),
      ('font_size', '"medium"'),
      ('default_speed', '1.0'),
      ('auto_advance', 'true'),
      ('show_translation', 'true'),
      ('highlight_keywords', 'true'),
      ('background_playback', 'true'),
      ('project_sort', '"imported_desc"');
  ''';
}
```

### 5.2 Future Migration Example (v2)

```dart
static const String _migration2 = '''
  -- v2: Add bookmarks feature

  CREATE TABLE bookmarks (
    id TEXT PRIMARY KEY NOT NULL,
    sentence_id TEXT NOT NULL,
    note TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
  );

  CREATE INDEX idx_bookmark_sentence ON bookmarks(sentence_id);

  -- Add study tracking columns
  ALTER TABLE sentences ADD COLUMN times_played INTEGER DEFAULT 0;
  ALTER TABLE sentences ADD COLUMN last_played_at TEXT;
''';
```

### 5.3 Migration Execution

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  for (int version = oldVersion + 1; version <= newVersion; version++) {
    final migration = DatabaseMigrations.migrations[version];
    if (migration != null) {
      // Split by semicolon and execute each statement
      final statements = migration
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !s.startsWith('--'));

      for (final statement in statements) {
        await db.execute(statement);
      }
    }
  }
}
```

---

## 6. Data Import Transaction

### 6.1 Batch Import Strategy

For efficient import of large projects:

```dart
Future<void> importProject(ExportData data) async {
  final db = await database;

  await db.transaction((txn) async {
    // 1. Insert project
    final projectId = const Uuid().v4();
    await txn.insert('projects', {
      'id': projectId,
      'source_id': data.project['id'],
      'name': data.project['name'],
      'status': 'ready',
      'total_sentences': data.sentences.length,
      'imported_at': DateTime.now().toIso8601String(),
    });

    // 2. Batch insert sentences
    final sentencesBatch = txn.batch();
    final keywordsBatch = txn.batch();

    for (final sentenceData in data.sentences) {
      final sentenceId = const Uuid().v4();

      sentencesBatch.insert('sentences', {
        'id': sentenceId,
        'project_id': projectId,
        'idx': sentenceData['index'],
        'text': sentenceData['text'],
        'start_time': sentenceData['start_time'],
        'end_time': sentenceData['end_time'],
        'translation_en': sentenceData['translation_en'],
        'explanation_nl': sentenceData['explanation_nl'],
        'explanation_en': sentenceData['explanation_en'],
      });

      // Add keywords for this sentence
      final keywords = sentenceData['keywords'] as List? ?? [];
      for (final keywordData in keywords) {
        keywordsBatch.insert('keywords', {
          'id': const Uuid().v4(),
          'sentence_id': sentenceId,
          'word': keywordData['word'],
          'meaning_nl': keywordData['meaning_nl'],
          'meaning_en': keywordData['meaning_en'],
        });
      }
    }

    await sentencesBatch.commit(noResult: true);
    await keywordsBatch.commit(noResult: true);
  });
}
```

### 6.2 Performance Considerations

| Operation | Without Batch | With Batch | Improvement |
|-----------|---------------|------------|-------------|
| Import 500 sentences | ~5 seconds | ~0.5 seconds | 10x |
| Import 1000 sentences | ~12 seconds | ~1 second | 12x |

---

## 7. Default Settings

```sql
-- Initial settings values
INSERT INTO app_settings (key, value) VALUES
  ('theme', '"system"'),           -- "light", "dark", "system"
  ('font_size', '"medium"'),       -- "small", "medium", "large", "extra_large"
  ('default_speed', '1.0'),        -- 0.5 - 2.0
  ('auto_advance', 'true'),        -- boolean
  ('show_translation', 'true'),    -- boolean
  ('highlight_keywords', 'true'),  -- boolean
  ('background_playback', 'true'), -- boolean
  ('project_sort', '"imported_desc"'); -- "imported_desc", "imported_asc", "name_asc", "name_desc"
```

---

## 8. Storage Estimates

| Content | Size Estimate |
|---------|---------------|
| Empty database | ~50 KB |
| 100 sentences with keywords | ~200 KB |
| 500 sentences with keywords | ~1 MB |
| 1000 sentences with keywords | ~2 MB |
| Audio file (30 min @ 128kbps) | ~30 MB |
| Audio file (1 hour @ 128kbps) | ~60 MB |
| Typical project (500 sentences + audio) | ~35 MB |

---

## 9. Backup and Export

### 9.1 Database Backup

```dart
Future<String> backupDatabase() async {
  final dbPath = await getDatabasesPath();
  final sourcePath = join(dbPath, 'dutch_learn.db');
  final backupPath = join(
    (await getApplicationDocumentsDirectory()).path,
    'dutch_learn_backup_${DateTime.now().millisecondsSinceEpoch}.db'
  );

  await File(sourcePath).copy(backupPath);
  return backupPath;
}
```

### 9.2 Data Integrity Check

```dart
Future<bool> verifyDatabaseIntegrity() async {
  final db = await database;

  // Check foreign key integrity
  final result = await db.rawQuery('PRAGMA foreign_key_check');
  if (result.isNotEmpty) {
    return false;
  }

  // Check database integrity
  final integrityCheck = await db.rawQuery('PRAGMA integrity_check');
  return integrityCheck.first.values.first == 'ok';
}
```

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Solution Architect | Initial database schema |
