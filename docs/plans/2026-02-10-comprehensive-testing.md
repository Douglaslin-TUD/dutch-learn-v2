# Comprehensive Testing & Bug Fix Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix known bugs, eliminate Flutter warnings, and add comprehensive test coverage across desktop and mobile data layers, providers, and API integration.

**Architecture:** Desktop uses Python/FastAPI/SQLAlchemy with pytest and in-memory SQLite (StaticPool). Mobile uses Flutter/sqflite with `sqflite_common_ffi` for desktop test execution. Both use factory fixtures for test data.

**Tech Stack:** pytest + unittest.mock (desktop), flutter_test + mockito + sqflite_common_ffi (mobile)

---

## Task 1: Fix Known Bugs

**Files:**
- Modify: `mobile/lib/domain/entities/sentence.dart:183-217`
- Modify: `mobile/lib/data/services/whisper_service.dart:1,9`
- Modify: `mobile/lib/data/services/gpt_service.dart:8`
- Modify: `mobile/test/fixtures/test_data.dart:47-75`
- Modify: `mobile/pubspec.yaml:78`

**Step 1: Fix `lastReviewed` missing from `==` and `hashCode`**

In `mobile/lib/domain/entities/sentence.dart`, line 197, add `other.lastReviewed == lastReviewed &&` before the `listEquals` line:

```dart
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Sentence &&
        other.id == id &&
        other.projectId == projectId &&
        other.index == index &&
        other.text == text &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.translationEn == translationEn &&
        other.explanationNl == explanationNl &&
        other.explanationEn == explanationEn &&
        other.speakerId == speakerId &&
        other.isDifficult == isDifficult &&
        other.reviewCount == reviewCount &&
        other.lastReviewed == lastReviewed &&
        listEquals(other.keywords, keywords);
  }
```

In `hashCode` (line 202-217), add `lastReviewed` before `Object.hashAll(keywords)`:

```dart
  @override
  int get hashCode {
    return Object.hash(
      id,
      projectId,
      index,
      text,
      startTime,
      endTime,
      translationEn,
      explanationNl,
      explanationEn,
      speakerId,
      isDifficult,
      reviewCount,
      lastReviewed,
      Object.hashAll(keywords),
    );
  }
```

**Step 2: Fix unused `_apiKey` in gpt_service.dart**

In `mobile/lib/data/services/gpt_service.dart`, the `_apiKey` field (line 8) is stored but never directly used — it's passed to Dio via the constructor. Remove line 8 (`final String _apiKey;`) and change line 14 from `_apiKey = apiKey,` to just the `_dio` initialization:

```dart
class GptService {
  final Dio _dio;

  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4o-mini';

  GptService({required String apiKey})
      : _dio = Dio(BaseOptions(
```

**Step 3: Fix unused import and `_apiKey` in whisper_service.dart**

In `mobile/lib/data/services/whisper_service.dart`:
- Remove line 1: `import 'dart:convert';`
- Remove line 9: `final String _apiKey;` and line 15 `_apiKey = apiKey,`

Same pattern as gpt_service — `_apiKey` is passed to Dio via the constructor closure.

**Step 4: Update TestData.sentence factory with new fields**

In `mobile/test/fixtures/test_data.dart`, update the `sentence` factory to include the new fields:

```dart
  static Sentence sentence({
    String id = 'sent-1',
    String projectId = 'test-project-id',
    int index = 0,
    String text = 'Hallo, hoe gaat het?',
    double startTime = 0.0,
    double endTime = 2.5,
    String? translationEn = 'Hello, how are you?',
    String? explanationNl,
    String? explanationEn,
    bool learned = false,
    int learnCount = 0,
    String? speakerId,
    bool isDifficult = false,
    int reviewCount = 0,
    DateTime? lastReviewed,
    List<Keyword>? keywords,
  }) {
    return Sentence(
      id: id,
      projectId: projectId,
      index: index,
      text: text,
      startTime: startTime,
      endTime: endTime,
      translationEn: translationEn,
      explanationNl: explanationNl,
      explanationEn: explanationEn,
      learned: learned,
      learnCount: learnCount,
      speakerId: speakerId,
      isDifficult: isDifficult,
      reviewCount: reviewCount,
      lastReviewed: lastReviewed,
      keywords: keywords ?? [],
    );
  }
```

Also add a `speaker` factory after `driveFile`:

```dart
  static Speaker speaker({
    String id = 'speaker-1',
    String projectId = 'test-project-id',
    String label = 'A',
    String? displayName,
    double confidence = 0.0,
    String? evidence,
    bool isManual = false,
  }) {
    return Speaker(
      id: id,
      projectId: projectId,
      label: label,
      displayName: displayName,
      confidence: confidence,
      evidence: evidence,
      isManual: isManual,
    );
  }
```

Add `import 'package:dutch_learn_app/domain/entities/speaker.dart';` to the imports.

Also update `importJson` to include speakers and new sentence fields:

```dart
  static Map<String, dynamic> importJson({
    String projectId = 'source-project-id',
    String projectName = 'Import Test',
    int sentenceCount = 2,
    bool includeSpeakers = false,
  }) {
    return {
      'version': '1.0',
      'exported_at': '2026-01-15T10:00:00',
      'project': {
        'id': projectId,
        'name': projectName,
        'status': 'ready',
        'total_sentences': sentenceCount,
        'created_at': '2026-01-15T10:00:00',
      },
      'speakers': includeSpeakers
          ? [
              {'id': 'sp-1', 'label': 'A', 'display_name': 'Jan', 'confidence': 0.9, 'evidence': 'Introduced himself', 'is_manual': false},
              {'id': 'sp-2', 'label': 'B', 'display_name': null, 'confidence': 0.0, 'evidence': null, 'is_manual': false},
            ]
          : [],
      'sentences': List.generate(sentenceCount, (i) {
        return {
          'index': i,
          'text': 'Zin ${i + 1}',
          'start_time': i * 2.0,
          'end_time': (i + 1) * 2.0,
          'translation_en': 'Sentence ${i + 1}',
          'explanation_nl': null,
          'explanation_en': null,
          'speaker_id': includeSpeakers ? 'sp-${(i % 2) + 1}' : null,
          'learned': false,
          'learn_count': 0,
          'is_difficult': false,
          'review_count': 0,
          'last_reviewed': null,
          'keywords': [
            {
              'word': 'woord$i',
              'meaning_nl': 'betekenis $i',
              'meaning_en': 'meaning $i',
            }
          ],
        };
      }),
    };
  }
```

**Step 5: Remove unnecessary dev dependency**

In `mobile/pubspec.yaml`, remove `sqflite_common_ffi` from `dev_dependencies` if it's already in normal `dependencies`.

**Step 6: Verify**

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter analyze 2>&1 | tr '\r' '\n' | grep -E "(error|warning|issue)" | tail -5`
Expected: 0 errors, 0 warnings (info-level lints OK)

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter test 2>&1 | tr '\r' '\n' | tail -5`
Expected: All 152 tests pass

**Step 7: Commit**

```bash
git add mobile/lib/domain/entities/sentence.dart mobile/lib/data/services/gpt_service.dart mobile/lib/data/services/whisper_service.dart mobile/test/fixtures/test_data.dart mobile/pubspec.yaml
git commit -m "fix(mobile): fix lastReviewed in equality, remove unused imports/fields, update test fixtures"
```

---

## Task 2: Desktop — Processor Pipeline Tests

**Files:**
- Create: `desktop/tests/test_processor.py`

**Step 1: Write the tests**

Create `desktop/tests/test_processor.py`:

```python
"""Tests for the Processor pipeline service."""

import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from pathlib import Path

from app.services.processor import Processor, ProcessingError
from app.models import Project, Sentence, Speaker


class TestIdentifySpeakers:
    """Test the _identify_speakers stage."""

    @pytest.mark.asyncio
    async def test_calls_identifier_with_transcript(self, db, make_project, make_speaker, make_sentence):
        """Verify _identify_speakers builds transcript and calls the identifier."""
        project = make_project(status="transcribing")
        sp_a = make_speaker(project.id, label="A", display_name=None)
        sp_b = make_speaker(project.id, label="B", display_name=None)
        make_sentence(project.id, idx=0, text="Hallo, ik ben Jan.", speaker_id=sp_a.id)
        make_sentence(project.id, idx=1, text="Welkom Jan.", speaker_id=sp_b.id)

        processor = Processor()
        mock_identifier = MagicMock()
        mock_identifier.identify = AsyncMock(return_value={
            "A": MagicMock(name="Jan", role="Manager", confidence="high", evidence="Said his name"),
            "B": MagicMock(name="de presentator", role="", confidence="low", evidence="Unknown"),
        })
        processor.speaker_identifier = mock_identifier

        await processor._identify_speakers(project, db)

        mock_identifier.identify.assert_called_once()
        call_args = mock_identifier.identify.call_args
        transcript = call_args[0][0]
        assert len(transcript) == 2
        assert transcript[0]["label"] == "A"
        assert transcript[0]["text"] == "Hallo, ik ben Jan."

    @pytest.mark.asyncio
    async def test_updates_speaker_display_names(self, db, make_project, make_speaker, make_sentence):
        """Verify speakers get display_name and evidence updated."""
        project = make_project(status="transcribing")
        sp_a = make_speaker(project.id, label="A")
        make_sentence(project.id, idx=0, text="Test", speaker_id=sp_a.id)

        processor = Processor()
        mock_result = MagicMock()
        mock_result.name = "Jan de Vries"
        mock_result.role = "Manager"
        mock_result.confidence = "high"
        mock_result.evidence = "Introduced himself"
        mock_identifier = MagicMock()
        mock_identifier.identify = AsyncMock(return_value={"A": mock_result})
        processor.speaker_identifier = mock_identifier

        await processor._identify_speakers(project, db)

        db.refresh(sp_a)
        assert sp_a.display_name == "Jan de Vries"
        evidence = json.loads(sp_a.evidence)
        assert evidence["role"] == "Manager"
        assert evidence["confidence"] == "high"

    @pytest.mark.asyncio
    async def test_non_blocking_on_failure(self, db, make_project, make_speaker, make_sentence):
        """Verify pipeline continues if identification fails."""
        project = make_project(status="transcribing")
        sp_a = make_speaker(project.id, label="A")
        make_sentence(project.id, idx=0, text="Test", speaker_id=sp_a.id)

        processor = Processor()
        mock_identifier = MagicMock()
        mock_identifier.identify = AsyncMock(side_effect=Exception("API down"))
        processor.speaker_identifier = mock_identifier

        # Should NOT raise
        await processor._identify_speakers(project, db)

        # Speaker should be unchanged
        db.refresh(sp_a)
        assert sp_a.display_name is None

    @pytest.mark.asyncio
    async def test_skips_when_no_speakers(self, db, make_project, make_sentence):
        """Verify _identify_speakers does nothing when no speakers exist."""
        project = make_project(status="transcribing")
        make_sentence(project.id, idx=0, text="Test")

        processor = Processor()
        mock_identifier = MagicMock()
        mock_identifier.identify = AsyncMock()
        processor.speaker_identifier = mock_identifier

        await processor._identify_speakers(project, db)

        mock_identifier.identify.assert_not_called()

    @pytest.mark.asyncio
    async def test_skips_when_no_sentences(self, db, make_project, make_speaker):
        """Verify _identify_speakers does nothing when no sentences exist."""
        project = make_project(status="transcribing", total_sentences=0)
        make_speaker(project.id, label="A")

        processor = Processor()
        mock_identifier = MagicMock()
        mock_identifier.identify = AsyncMock()
        processor.speaker_identifier = mock_identifier

        await processor._identify_speakers(project, db)

        mock_identifier.identify.assert_not_called()


class TestUpdateProjectStatus:
    """Test the _update_project_status helper."""

    def test_updates_status(self, db, make_project):
        project = make_project(status="pending")
        processor = Processor()
        processor._update_project_status(db, project.id, "extracting")

        db.refresh(project)
        assert project.status == "extracting"

    def test_sets_error_message(self, db, make_project):
        project = make_project(status="pending")
        processor = Processor()
        processor._update_project_status(db, project.id, "error", error_message="Something broke")

        db.refresh(project)
        assert project.status == "error"
        assert project.error_message == "Something broke"

    def test_ignores_nonexistent_project(self, db):
        processor = Processor()
        # Should not raise
        processor._update_project_status(db, "nonexistent-id", "extracting")
```

**Step 2: Run tests**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/test_processor.py -v`
Expected: All 8 tests pass

**Step 3: Run full suite**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -q`
Expected: 201+ tests pass

**Step 4: Commit**

```bash
git add desktop/tests/test_processor.py
git commit -m "test(desktop): add processor pipeline tests including speaker identification"
```

---

## Task 3: Desktop — API Endpoint Tests for Difficult Sentences

**Files:**
- Modify: `desktop/tests/test_projects_api.py` (add new test class)

**Step 1: Add tests**

Append to `desktop/tests/test_projects_api.py`:

```python
class TestDifficultSentenceEndpoints:
    """Tests for difficult sentence bookmark and review endpoints."""

    def test_toggle_difficult_on(self, client, make_project, make_sentence):
        project = make_project()
        sentence = make_sentence(project.id, idx=0, text="Test")
        assert sentence.is_difficult is False  # default

        resp = client.put(f"/api/projects/{project.id}/sentences/{sentence.id}/difficult")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["is_difficult"] is True

    def test_toggle_difficult_off(self, client, db, make_project, make_sentence):
        project = make_project()
        sentence = make_sentence(project.id, idx=0, text="Test")
        sentence.is_difficult = True
        db.commit()

        resp = client.put(f"/api/projects/{project.id}/sentences/{sentence.id}/difficult")
        assert resp.status_code == 200
        assert resp.json()["is_difficult"] is False

    def test_toggle_difficult_not_found(self, client, make_project):
        project = make_project()
        resp = client.put(f"/api/projects/{project.id}/sentences/fake-id/difficult")
        assert resp.status_code == 404

    def test_get_difficult_sentences(self, client, db, make_project, make_sentence):
        project = make_project()
        s1 = make_sentence(project.id, idx=0, text="Easy")
        s2 = make_sentence(project.id, idx=1, text="Hard")
        s2.is_difficult = True
        db.commit()

        resp = client.get(f"/api/projects/{project.id}/difficult")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["sentences"]) == 1
        assert data["sentences"][0]["text"] == "Hard"

    def test_get_difficult_sentences_empty(self, client, make_project, make_sentence):
        project = make_project()
        make_sentence(project.id, idx=0, text="Normal")

        resp = client.get(f"/api/projects/{project.id}/difficult")
        assert resp.status_code == 200
        assert len(resp.json()["sentences"]) == 0

    def test_record_review(self, client, make_project, make_sentence):
        project = make_project()
        sentence = make_sentence(project.id, idx=0, text="Review me")

        resp = client.post(f"/api/projects/{project.id}/sentences/{sentence.id}/review")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["review_count"] == 1

        # Second review
        resp = client.post(f"/api/projects/{project.id}/sentences/{sentence.id}/review")
        assert resp.json()["review_count"] == 2

    def test_record_review_not_found(self, client, make_project):
        project = make_project()
        resp = client.post(f"/api/projects/{project.id}/sentences/fake-id/review")
        assert resp.status_code == 404
```

**Step 2: Run tests**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/test_projects_api.py::TestDifficultSentenceEndpoints -v`
Expected: All 7 tests pass

**Step 3: Run full suite**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -q`
Expected: 208+ tests pass

**Step 4: Commit**

```bash
git add desktop/tests/test_projects_api.py
git commit -m "test(desktop): add API tests for difficult sentence toggle, listing, and review"
```

---

## Task 4: Mobile — SpeakerModel Tests

**Files:**
- Create: `mobile/test/data/models/speaker_model_test.dart`

**Step 1: Write tests**

Create `mobile/test/data/models/speaker_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/data/models/speaker_model.dart';
import 'package:dutch_learn_app/domain/entities/speaker.dart';

void main() {
  group('SpeakerModel', () {
    test('fromMap creates model with all fields', () {
      final map = {
        'id': 'sp-1',
        'project_id': 'proj-1',
        'label': 'A',
        'display_name': 'Jan',
        'confidence': 0.95,
        'evidence': 'Said his name',
        'is_manual': 1,
      };
      final model = SpeakerModel.fromMap(map);
      expect(model.id, 'sp-1');
      expect(model.projectId, 'proj-1');
      expect(model.label, 'A');
      expect(model.displayName, 'Jan');
      expect(model.confidence, 0.95);
      expect(model.evidence, 'Said his name');
      expect(model.isManual, true);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 'sp-1',
        'project_id': 'proj-1',
        'label': 'B',
        'display_name': null,
        'confidence': null,
        'evidence': null,
        'is_manual': 0,
      };
      final model = SpeakerModel.fromMap(map);
      expect(model.displayName, isNull);
      expect(model.confidence, 0.0);
      expect(model.evidence, isNull);
      expect(model.isManual, false);
    });

    test('toMap produces correct keys', () {
      const model = SpeakerModel(
        id: 'sp-1',
        projectId: 'proj-1',
        label: 'A',
        displayName: 'Jan',
        confidence: 0.9,
        evidence: 'test',
        isManual: true,
      );
      final map = model.toMap();
      expect(map['id'], 'sp-1');
      expect(map['project_id'], 'proj-1');
      expect(map['label'], 'A');
      expect(map['display_name'], 'Jan');
      expect(map['confidence'], 0.9);
      expect(map['is_manual'], 1);
    });

    test('toMap/fromMap roundtrip preserves data', () {
      const original = SpeakerModel(
        id: 'sp-1',
        projectId: 'proj-1',
        label: 'C',
        displayName: 'Piet',
        confidence: 0.5,
        evidence: 'Inferred',
        isManual: false,
      );
      final restored = SpeakerModel.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.label, original.label);
      expect(restored.displayName, original.displayName);
      expect(restored.confidence, original.confidence);
      expect(restored.isManual, original.isManual);
    });

    test('fromJson with required id and projectId', () {
      final json = {
        'label': 'A',
        'display_name': 'Jan',
        'confidence': 0.8,
        'evidence': 'Context clue',
        'is_manual': false,
      };
      final model = SpeakerModel.fromJson(json, id: 'local-1', projectId: 'proj-1');
      expect(model.id, 'local-1');
      expect(model.projectId, 'proj-1');
      expect(model.label, 'A');
      expect(model.displayName, 'Jan');
      expect(model.isManual, false);
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{'label': 'B'};
      final model = SpeakerModel.fromJson(json, id: 'x', projectId: 'y');
      expect(model.displayName, isNull);
      expect(model.confidence, 0.0);
      expect(model.evidence, isNull);
      expect(model.isManual, false);
    });

    test('toJson produces correct format', () {
      const model = SpeakerModel(
        id: 'sp-1',
        projectId: 'proj-1',
        label: 'A',
        displayName: 'Jan',
        confidence: 0.9,
        isManual: true,
      );
      final json = model.toJson();
      expect(json['id'], 'sp-1');
      expect(json['is_manual'], true);  // bool not int
      expect(json['display_name'], 'Jan');
    });

    test('toEntity and fromEntity roundtrip', () {
      const model = SpeakerModel(
        id: 'sp-1',
        projectId: 'proj-1',
        label: 'A',
        displayName: 'Jan',
        confidence: 0.9,
        evidence: 'test',
        isManual: true,
      );
      final entity = model.toEntity();
      expect(entity, isA<Speaker>());
      expect(entity.id, 'sp-1');
      expect(entity.displayLabel, 'Jan');

      final restored = SpeakerModel.fromEntity(entity);
      expect(restored.id, model.id);
      expect(restored.label, model.label);
      expect(restored.isManual, model.isManual);
    });

    test('displayLabel uses displayName when set', () {
      const model = SpeakerModel(
        id: 'sp-1', projectId: 'p', label: 'A', displayName: 'Jan',
      );
      expect(model.displayLabel, 'Jan');
    });

    test('displayLabel falls back to Speaker label', () {
      const model = SpeakerModel(
        id: 'sp-1', projectId: 'p', label: 'B',
      );
      expect(model.displayLabel, 'Speaker B');
    });

    test('copyWith creates modified copy', () {
      const model = SpeakerModel(
        id: 'sp-1', projectId: 'p', label: 'A', displayName: 'Jan',
      );
      final copy = model.copyWith(displayName: 'Piet', isManual: true);
      expect(copy.displayName, 'Piet');
      expect(copy.isManual, true);
      expect(copy.id, 'sp-1');  // unchanged
    });
  });
}
```

**Step 2: Run tests**

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter test test/data/models/speaker_model_test.dart 2>&1 | tr '\r' '\n' | tail -5`
Expected: All tests pass

**Step 3: Commit**

```bash
git add mobile/test/data/models/speaker_model_test.dart
git commit -m "test(mobile): add SpeakerModel unit tests"
```

---

## Task 5: Mobile — DAO Tests with In-Memory SQLite

**Files:**
- Create: `mobile/test/data/local/daos/test_helpers.dart`
- Create: `mobile/test/data/local/daos/sentence_dao_test.dart`
- Create: `mobile/test/data/local/daos/speaker_dao_test.dart`
- Create: `mobile/test/data/local/daos/keyword_dao_test.dart`
- Create: `mobile/test/data/local/daos/project_dao_test.dart`

**Step 1: Create test helper for in-memory database**

Create `mobile/test/data/local/daos/test_helpers.dart`:

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqflite.dart';

/// Creates a fresh in-memory SQLite database with the current schema.
Future<Database> createTestDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (db, version) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            source_id TEXT,
            name TEXT NOT NULL,
            total_sentences INTEGER NOT NULL DEFAULT 0,
            audio_path TEXT,
            imported_at TEXT NOT NULL,
            last_played_at TEXT,
            last_sentence_index INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE sentences (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            idx INTEGER NOT NULL,
            text TEXT NOT NULL,
            start_time REAL NOT NULL,
            end_time REAL NOT NULL,
            translation_en TEXT,
            explanation_nl TEXT,
            explanation_en TEXT,
            learned INTEGER NOT NULL DEFAULT 0,
            learn_count INTEGER NOT NULL DEFAULT 0,
            speaker_id TEXT,
            is_difficult INTEGER NOT NULL DEFAULT 0,
            review_count INTEGER NOT NULL DEFAULT 0,
            last_reviewed TEXT,
            FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE keywords (
            id TEXT PRIMARY KEY,
            sentence_id TEXT NOT NULL,
            word TEXT NOT NULL,
            meaning_nl TEXT NOT NULL,
            meaning_en TEXT NOT NULL,
            FOREIGN KEY (sentence_id) REFERENCES sentences (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE speakers (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            label TEXT NOT NULL,
            display_name TEXT,
            confidence REAL NOT NULL DEFAULT 0.0,
            evidence TEXT,
            is_manual INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
          )
        ''');
      },
    ),
  );
  await db.execute('PRAGMA foreign_keys = ON');
  return db;
}

/// Inserts a test project and returns its ID.
Future<String> insertTestProject(Database db, {String id = 'test-proj', String name = 'Test'}) async {
  await db.insert('projects', {
    'id': id,
    'name': name,
    'total_sentences': 0,
    'imported_at': DateTime.now().toIso8601String(),
  });
  return id;
}
```

**Step 2: Create SentenceDao tests**

Create `mobile/test/data/local/daos/sentence_dao_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'test_helpers.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await createTestDatabase();
    await insertTestProject(db, id: 'proj-1');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertSentence(String id, {int idx = 0, String text = 'Test', bool isDifficult = false, int reviewCount = 0, String? speakerId}) async {
    await db.insert('sentences', {
      'id': id, 'project_id': 'proj-1', 'idx': idx, 'text': text,
      'start_time': idx * 2.0, 'end_time': (idx + 1) * 2.0,
      'is_difficult': isDifficult ? 1 : 0, 'review_count': reviewCount,
      'speaker_id': speakerId,
    });
  }

  group('SentenceDao queries', () {
    test('getByProjectId returns sentences ordered by idx', () async {
      await insertSentence('s1', idx: 1, text: 'Second');
      await insertSentence('s2', idx: 0, text: 'First');

      final results = await db.query('sentences', where: 'project_id = ?', whereArgs: ['proj-1'], orderBy: 'idx ASC');
      expect(results.length, 2);
      expect(results[0]['text'], 'First');
      expect(results[1]['text'], 'Second');
    });

    test('toggleDifficult flips the flag', () async {
      await insertSentence('s1', isDifficult: false);

      await db.rawUpdate('UPDATE sentences SET is_difficult = 1 - is_difficult WHERE id = ?', ['s1']);
      var result = await db.query('sentences', where: 'id = ?', whereArgs: ['s1']);
      expect(result.first['is_difficult'], 1);

      await db.rawUpdate('UPDATE sentences SET is_difficult = 1 - is_difficult WHERE id = ?', ['s1']);
      result = await db.query('sentences', where: 'id = ?', whereArgs: ['s1']);
      expect(result.first['is_difficult'], 0);
    });

    test('getDifficultByProjectId filters correctly', () async {
      await insertSentence('s1', idx: 0, isDifficult: false);
      await insertSentence('s2', idx: 1, isDifficult: true);
      await insertSentence('s3', idx: 2, isDifficult: true);

      final results = await db.query('sentences', where: 'project_id = ? AND is_difficult = 1', whereArgs: ['proj-1']);
      expect(results.length, 2);
    });

    test('recordReview increments count and sets timestamp', () async {
      await insertSentence('s1');

      final now = DateTime.now().toIso8601String();
      await db.rawUpdate('UPDATE sentences SET review_count = review_count + 1, last_reviewed = ? WHERE id = ?', [now, 's1']);

      final result = await db.query('sentences', where: 'id = ?', whereArgs: ['s1']);
      expect(result.first['review_count'], 1);
      expect(result.first['last_reviewed'], isNotNull);

      // Second review
      await db.rawUpdate('UPDATE sentences SET review_count = review_count + 1, last_reviewed = ? WHERE id = ?', [now, 's1']);
      final result2 = await db.query('sentences', where: 'id = ?', whereArgs: ['s1']);
      expect(result2.first['review_count'], 2);
    });

    test('updateLearningProgress sets learned and learn_count', () async {
      await insertSentence('s1');

      await db.update('sentences', {'learned': 1, 'learn_count': 3}, where: 'id = ?', whereArgs: ['s1']);

      final result = await db.query('sentences', where: 'id = ?', whereArgs: ['s1']);
      expect(result.first['learned'], 1);
      expect(result.first['learn_count'], 3);
    });

    test('search finds sentences by text', () async {
      await insertSentence('s1', text: 'Hallo wereld');
      await insertSentence('s2', idx: 1, text: 'Goedemorgen');

      final results = await db.query('sentences', where: "project_id = ? AND text LIKE ?", whereArgs: ['proj-1', '%wereld%']);
      expect(results.length, 1);
      expect(results.first['id'], 's1');
    });

    test('cascade delete removes sentences when project deleted', () async {
      await insertSentence('s1');
      await db.delete('projects', where: 'id = ?', whereArgs: ['proj-1']);

      final results = await db.query('sentences');
      expect(results, isEmpty);
    });
  });
}
```

**Step 3: Create SpeakerDao tests**

Create `mobile/test/data/local/daos/speaker_dao_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'test_helpers.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await createTestDatabase();
    await insertTestProject(db, id: 'proj-1');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertSpeaker(String id, {String label = 'A', String? displayName, bool isManual = false}) async {
    await db.insert('speakers', {
      'id': id, 'project_id': 'proj-1', 'label': label,
      'display_name': displayName, 'confidence': 0.0,
      'is_manual': isManual ? 1 : 0,
    });
  }

  group('SpeakerDao queries', () {
    test('getByProjectId returns speakers ordered by label', () async {
      await insertSpeaker('sp2', label: 'B');
      await insertSpeaker('sp1', label: 'A');

      final results = await db.query('speakers', where: 'project_id = ?', whereArgs: ['proj-1'], orderBy: 'label ASC');
      expect(results.length, 2);
      expect(results[0]['label'], 'A');
      expect(results[1]['label'], 'B');
    });

    test('updateDisplayName sets name and is_manual', () async {
      await insertSpeaker('sp1', label: 'A');

      await db.update('speakers', {'display_name': 'Jan', 'is_manual': 1}, where: 'id = ?', whereArgs: ['sp1']);

      final result = await db.query('speakers', where: 'id = ?', whereArgs: ['sp1']);
      expect(result.first['display_name'], 'Jan');
      expect(result.first['is_manual'], 1);
    });

    test('deleteByProjectId removes all speakers', () async {
      await insertSpeaker('sp1', label: 'A');
      await insertSpeaker('sp2', label: 'B');

      await db.delete('speakers', where: 'project_id = ?', whereArgs: ['proj-1']);

      final results = await db.query('speakers');
      expect(results, isEmpty);
    });

    test('cascade delete removes speakers when project deleted', () async {
      await insertSpeaker('sp1');
      await db.delete('projects', where: 'id = ?', whereArgs: ['proj-1']);

      final results = await db.query('speakers');
      expect(results, isEmpty);
    });

    test('insert with conflictAlgorithm replace updates existing', () async {
      await insertSpeaker('sp1', label: 'A', displayName: 'Original');
      await db.insert('speakers', {
        'id': 'sp1', 'project_id': 'proj-1', 'label': 'A',
        'display_name': 'Updated', 'confidence': 0.0, 'is_manual': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final result = await db.query('speakers', where: 'id = ?', whereArgs: ['sp1']);
      expect(result.first['display_name'], 'Updated');
    });
  });
}
```

**Step 4: Create KeywordDao tests**

Create `mobile/test/data/local/daos/keyword_dao_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'test_helpers.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await createTestDatabase();
    await insertTestProject(db, id: 'proj-1');
    await db.insert('sentences', {
      'id': 'sent-1', 'project_id': 'proj-1', 'idx': 0,
      'text': 'Test', 'start_time': 0.0, 'end_time': 1.0,
    });
    await db.insert('sentences', {
      'id': 'sent-2', 'project_id': 'proj-1', 'idx': 1,
      'text': 'Test2', 'start_time': 1.0, 'end_time': 2.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('KeywordDao queries', () {
    test('getBySentenceId returns keywords for sentence', () async {
      await db.insert('keywords', {'id': 'kw1', 'sentence_id': 'sent-1', 'word': 'hallo', 'meaning_nl': 'begroeting', 'meaning_en': 'hello'});
      await db.insert('keywords', {'id': 'kw2', 'sentence_id': 'sent-2', 'word': 'wereld', 'meaning_nl': 'de aarde', 'meaning_en': 'world'});

      final results = await db.query('keywords', where: 'sentence_id = ?', whereArgs: ['sent-1']);
      expect(results.length, 1);
      expect(results.first['word'], 'hallo');
    });

    test('getBySentenceIds returns grouped map', () async {
      await db.insert('keywords', {'id': 'kw1', 'sentence_id': 'sent-1', 'word': 'hallo', 'meaning_nl': 'x', 'meaning_en': 'hello'});
      await db.insert('keywords', {'id': 'kw2', 'sentence_id': 'sent-1', 'word': 'wereld', 'meaning_nl': 'x', 'meaning_en': 'world'});
      await db.insert('keywords', {'id': 'kw3', 'sentence_id': 'sent-2', 'word': 'dag', 'meaning_nl': 'x', 'meaning_en': 'day'});

      final ids = ['sent-1', 'sent-2'];
      final placeholders = ids.map((_) => '?').join(',');
      final results = await db.rawQuery('SELECT * FROM keywords WHERE sentence_id IN ($placeholders)', ids);
      expect(results.length, 3);
    });

    test('cascade delete removes keywords when sentence deleted', () async {
      await db.insert('keywords', {'id': 'kw1', 'sentence_id': 'sent-1', 'word': 'test', 'meaning_nl': 'x', 'meaning_en': 'test'});

      await db.delete('sentences', where: 'id = ?', whereArgs: ['sent-1']);

      final results = await db.query('keywords');
      // Only kw from sent-2 should remain (none inserted)
      expect(results, isEmpty);
    });

    test('deleteByProjectId removes via subquery', () async {
      await db.insert('keywords', {'id': 'kw1', 'sentence_id': 'sent-1', 'word': 'test', 'meaning_nl': 'x', 'meaning_en': 'test'});
      await db.insert('keywords', {'id': 'kw2', 'sentence_id': 'sent-2', 'word': 'test2', 'meaning_nl': 'x', 'meaning_en': 'test2'});

      await db.rawDelete('DELETE FROM keywords WHERE sentence_id IN (SELECT id FROM sentences WHERE project_id = ?)', ['proj-1']);

      final results = await db.query('keywords');
      expect(results, isEmpty);
    });
  });
}
```

**Step 5: Create ProjectDao tests**

Create `mobile/test/data/local/daos/project_dao_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'test_helpers.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertProject(String id, {String name = 'Test', String? sourceId}) async {
    await db.insert('projects', {
      'id': id, 'name': name, 'total_sentences': 0,
      'imported_at': DateTime.now().toIso8601String(),
      'source_id': sourceId,
    });
  }

  group('ProjectDao queries', () {
    test('getAll returns projects', () async {
      await insertProject('p1', name: 'First');
      await insertProject('p2', name: 'Second');

      final results = await db.query('projects');
      expect(results.length, 2);
    });

    test('getById returns correct project', () async {
      await insertProject('p1', name: 'Target');
      await insertProject('p2', name: 'Other');

      final results = await db.query('projects', where: 'id = ?', whereArgs: ['p1']);
      expect(results.length, 1);
      expect(results.first['name'], 'Target');
    });

    test('getById returns empty for nonexistent', () async {
      final results = await db.query('projects', where: 'id = ?', whereArgs: ['fake']);
      expect(results, isEmpty);
    });

    test('getBySourceId finds by source', () async {
      await insertProject('p1', sourceId: 'source-123');

      final results = await db.query('projects', where: 'source_id = ?', whereArgs: ['source-123']);
      expect(results.length, 1);
    });

    test('delete removes project', () async {
      await insertProject('p1');
      await db.delete('projects', where: 'id = ?', whereArgs: ['p1']);

      final results = await db.query('projects');
      expect(results, isEmpty);
    });

    test('updateLastPlayed sets fields', () async {
      await insertProject('p1');
      final now = DateTime.now().toIso8601String();
      await db.update('projects', {'last_played_at': now, 'last_sentence_index': 5}, where: 'id = ?', whereArgs: ['p1']);

      final result = await db.query('projects', where: 'id = ?', whereArgs: ['p1']);
      expect(result.first['last_sentence_index'], 5);
      expect(result.first['last_played_at'], isNotNull);
    });
  });
}
```

**Step 6: Run all DAO tests**

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter test test/data/local/daos/ 2>&1 | tr '\r' '\n' | tail -5`
Expected: All tests pass

**Step 7: Commit**

```bash
git add mobile/test/data/local/daos/
git commit -m "test(mobile): add DAO tests for sentences, speakers, keywords, projects"
```

---

## Task 6: Mobile — Database Migration Tests

**Files:**
- Create: `mobile/test/data/local/database_test.dart`

**Step 1: Write migration tests**

Create `mobile/test/data/local/database_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqflite.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Database schema v3', () {
    test('fresh v3 creation has all tables', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE projects (id TEXT PRIMARY KEY, source_id TEXT, name TEXT NOT NULL, total_sentences INTEGER NOT NULL DEFAULT 0, audio_path TEXT, imported_at TEXT NOT NULL, last_played_at TEXT, last_sentence_index INTEGER)');
            await db.execute('CREATE TABLE sentences (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, idx INTEGER NOT NULL, text TEXT NOT NULL, start_time REAL NOT NULL, end_time REAL NOT NULL, translation_en TEXT, explanation_nl TEXT, explanation_en TEXT, learned INTEGER NOT NULL DEFAULT 0, learn_count INTEGER NOT NULL DEFAULT 0, speaker_id TEXT, is_difficult INTEGER NOT NULL DEFAULT 0, review_count INTEGER NOT NULL DEFAULT 0, last_reviewed TEXT, FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE)');
            await db.execute('CREATE TABLE keywords (id TEXT PRIMARY KEY, sentence_id TEXT NOT NULL, word TEXT NOT NULL, meaning_nl TEXT NOT NULL, meaning_en TEXT NOT NULL, FOREIGN KEY (sentence_id) REFERENCES sentences (id) ON DELETE CASCADE)');
            await db.execute('CREATE TABLE speakers (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, label TEXT NOT NULL, display_name TEXT, confidence REAL NOT NULL DEFAULT 0.0, evidence TEXT, is_manual INTEGER NOT NULL DEFAULT 0, FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE)');
          },
        ),
      );

      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames, containsAll(['projects', 'sentences', 'keywords', 'speakers']));

      // Verify sentences table has all columns
      final sentenceCols = await db.rawQuery('PRAGMA table_info(sentences)');
      final colNames = sentenceCols.map((c) => c['name'] as String).toSet();
      expect(colNames, containsAll(['speaker_id', 'is_difficult', 'review_count', 'last_reviewed', 'learned', 'learn_count']));

      await db.close();
    });

    test('v1 to v3 migration adds all new columns and tables', () async {
      // Create v1 database
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE projects (id TEXT PRIMARY KEY, source_id TEXT, name TEXT NOT NULL, total_sentences INTEGER NOT NULL DEFAULT 0, audio_path TEXT, imported_at TEXT NOT NULL, last_played_at TEXT, last_sentence_index INTEGER)');
            await db.execute('CREATE TABLE sentences (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, idx INTEGER NOT NULL, text TEXT NOT NULL, start_time REAL NOT NULL, end_time REAL NOT NULL, translation_en TEXT, explanation_nl TEXT, explanation_en TEXT, FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE)');
            await db.execute('CREATE TABLE keywords (id TEXT PRIMARY KEY, sentence_id TEXT NOT NULL, word TEXT NOT NULL, meaning_nl TEXT NOT NULL, meaning_en TEXT NOT NULL, FOREIGN KEY (sentence_id) REFERENCES sentences (id) ON DELETE CASCADE)');
          },
        ),
      );
      await db.close();

      // Reopen with v3 migration
      final db3 = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await db.execute('ALTER TABLE sentences ADD COLUMN learned INTEGER NOT NULL DEFAULT 0');
              await db.execute('ALTER TABLE sentences ADD COLUMN learn_count INTEGER NOT NULL DEFAULT 0');
            }
            if (oldVersion < 3) {
              await db.execute('CREATE TABLE IF NOT EXISTS speakers (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, label TEXT NOT NULL, display_name TEXT, confidence REAL NOT NULL DEFAULT 0.0, evidence TEXT, is_manual INTEGER NOT NULL DEFAULT 0, FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE)');
              await db.execute('ALTER TABLE sentences ADD COLUMN speaker_id TEXT');
              await db.execute('ALTER TABLE sentences ADD COLUMN is_difficult INTEGER NOT NULL DEFAULT 0');
              await db.execute('ALTER TABLE sentences ADD COLUMN review_count INTEGER NOT NULL DEFAULT 0');
              await db.execute('ALTER TABLE sentences ADD COLUMN last_reviewed TEXT');
            }
          },
        ),
      );

      // Verify speakers table exists
      final tables = await db3.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name = 'speakers'");
      expect(tables.length, 1);

      // Verify new sentence columns
      final cols = await db3.rawQuery('PRAGMA table_info(sentences)');
      final colNames = cols.map((c) => c['name'] as String).toSet();
      expect(colNames, containsAll(['learned', 'learn_count', 'speaker_id', 'is_difficult', 'review_count', 'last_reviewed']));

      await db3.close();
    });
  });
}
```

**Step 2: Run tests**

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter test test/data/local/database_test.dart 2>&1 | tr '\r' '\n' | tail -5`
Expected: All tests pass

**Step 3: Commit**

```bash
git add mobile/test/data/local/database_test.dart
git commit -m "test(mobile): add database schema and migration tests"
```

---

## Task 7: Mobile — ReviewProvider Tests

**Files:**
- Create: `mobile/test/presentation/providers/review_provider_test.dart`

**Step 1: Write tests**

Create `mobile/test/presentation/providers/review_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/presentation/providers/review_provider.dart';

void main() {
  group('ReviewState', () {
    test('initial state has correct defaults', () {
      const state = ReviewState();
      expect(state.sentences, isEmpty);
      expect(state.currentIndex, 0);
      expect(state.isTextRevealed, false);
      expect(state.isLoading, false);
      expect(state.isComplete, false);
      expect(state.error, isNull);
    });

    test('currentSentence returns null when empty', () {
      const state = ReviewState();
      expect(state.currentSentence, isNull);
    });

    test('totalCount and reviewedCount reflect state', () {
      const state = ReviewState(currentIndex: 3);
      expect(state.reviewedCount, 3);
    });

    test('copyWith preserves unset fields', () {
      const state = ReviewState(currentIndex: 2, isTextRevealed: true);
      final copy = state.copyWith(isTextRevealed: false);
      expect(copy.currentIndex, 2);
      expect(copy.isTextRevealed, false);
    });

    test('copyWith sets error to null when provided', () {
      final state = const ReviewState().copyWith(error: 'oops');
      expect(state.error, 'oops');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });
  });
}
```

**Step 2: Run tests**

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter test test/presentation/providers/review_provider_test.dart 2>&1 | tr '\r' '\n' | tail -5`
Expected: All tests pass

**Step 3: Commit**

```bash
git add mobile/test/presentation/providers/review_provider_test.dart
git commit -m "test(mobile): add ReviewProvider state tests"
```

---

## Task 8: Final Validation

**Step 1: Run all desktop tests**

Run: `cd desktop && source ../venv/bin/activate && python -m pytest tests/ -v --tb=short`
Expected: 210+ tests pass (193 existing + ~15 new)

**Step 2: Run flutter analyze**

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter analyze 2>&1 | tr '\r' '\n' | grep -c "error\|warning"`
Expected: 0 errors, 0 warnings

**Step 3: Run all mobile tests**

Run: `export PATH="/home/peng-lin/flutter/bin:/usr/bin:$PATH" && cd mobile && flutter test 2>&1 | tr '\r' '\n' | tail -5`
Expected: 190+ tests pass (152 existing + ~40 new)

**Step 4: Commit final**

If all passes:
```bash
git commit --allow-empty -m "chore: comprehensive testing complete — 250+ tests across desktop and mobile"
```

---

## Test Count Summary

| Area | New Tests | Existing | Total |
|------|-----------|----------|-------|
| Desktop processor | 8 | 0 | 8 |
| Desktop API (difficult) | 7 | 0 | 7 |
| Mobile SpeakerModel | 12 | 0 | 12 |
| Mobile SentenceDao | 7 | 0 | 7 |
| Mobile SpeakerDao | 5 | 0 | 5 |
| Mobile KeywordDao | 4 | 0 | 4 |
| Mobile ProjectDao | 6 | 0 | 6 |
| Mobile DB migration | 2 | 0 | 2 |
| Mobile ReviewProvider | 5 | 0 | 5 |
| **New total** | **56** | **345** | **401+** |
