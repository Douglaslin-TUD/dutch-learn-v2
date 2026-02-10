# Sync & Recording Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all 27 compilation errors in mobile app by fully implementing sync, recording import, and database infrastructure, then build release APK.

**Architecture:** Rewrite SyncService to use DAOs directly (injected via constructor), add `learned`/`learn_count` columns via DB migration v1→v2, add missing methods to DAOs/providers, fix JSON format mismatches between ProcessedProject and importProject, and wire new SyncService into Riverpod DI.

**Tech Stack:** Flutter/Dart, sqflite, Riverpod, Google Drive API (googleapis), Clean Architecture (domain/data/presentation layers)

---

### Task 1: Database Migration — Add learned/learn_count to sentences

**Files:**
- Modify: `mobile/lib/core/constants/app_constants.dart:54` (bump databaseVersion)
- Modify: `mobile/lib/data/local/database.dart:53-66,95-105` (add columns + migration)

**Step 1: Bump database version**

In `mobile/lib/core/constants/app_constants.dart`, change:
```dart
static const int databaseVersion = 1;
```
to:
```dart
static const int databaseVersion = 2;
```

**Step 2: Add columns to _onCreate**

In `mobile/lib/data/local/database.dart`, update the sentences CREATE TABLE (line 53-66) to include two new columns before the FOREIGN KEY:
```sql
learned INTEGER NOT NULL DEFAULT 0,
learn_count INTEGER NOT NULL DEFAULT 0,
```

**Step 3: Add migration to _onUpgrade**

Replace the empty `_onUpgrade` body (lines 100-104) with:
```dart
if (oldVersion < 2) {
  await db.execute('ALTER TABLE sentences ADD COLUMN learned INTEGER NOT NULL DEFAULT 0');
  await db.execute('ALTER TABLE sentences ADD COLUMN learn_count INTEGER NOT NULL DEFAULT 0');
}
```

**Step 4: Verify**

Run: `cd mobile && flutter analyze 2>&1 | head -5`
Expected: no new errors introduced (same 27 as before since nothing references new columns yet)

**Step 5: Commit**

```bash
git add mobile/lib/core/constants/app_constants.dart mobile/lib/data/local/database.dart
git commit -m "feat(mobile): add learned/learn_count columns via DB migration v1→v2"
```

---

### Task 2: Update Sentence Entity and Model for learned/learnCount

**Files:**
- Modify: `mobile/lib/domain/entities/sentence.dart:12-53,56-80`
- Modify: `mobile/lib/data/models/sentence_model.dart:7-36,39-56,59-72,77-89,92-105,108-121,124-137`
- Modify: `mobile/test/fixtures/test_data.dart:47-71`

**Step 1: Add fields to Sentence entity**

In `mobile/lib/domain/entities/sentence.dart`, add two fields after `explanationEn` (around line 33):
```dart
/// Whether this sentence has been learned.
final bool learned;

/// Number of times this sentence has been studied.
final int learnCount;
```

Update the constructor (around line 42-53) to include:
```dart
this.learned = false,
this.learnCount = 0,
```

Update `copyWith` (around line 56-80) to include:
```dart
bool? learned,
int? learnCount,
```
and in the return:
```dart
learned: learned ?? this.learned,
learnCount: learnCount ?? this.learnCount,
```

**Step 2: Update SentenceModel serialization**

In `mobile/lib/data/models/sentence_model.dart`:

Add constructor params after `explanationEn`:
```dart
super.learned = false,
super.learnCount = 0,
```

Update `fromMap` to read new DB columns:
```dart
learned: (map['learned'] as int? ?? 0) == 1,
learnCount: map['learn_count'] as int? ?? 0,
```

Update `fromJson` to read new JSON fields:
```dart
learned: json['learned'] as bool? ?? false,
learnCount: json['learn_count'] as int? ?? 0,
```

Update `fromEntity` to copy new fields:
```dart
learned: entity.learned,
learnCount: entity.learnCount,
```

Update `toMap` to write new DB columns:
```dart
'learned': learned ? 1 : 0,
'learn_count': learnCount,
```

Update `toJson` to write new JSON fields:
```dart
'learned': learned,
'learn_count': learnCount,
```

Update `toEntity` to include new fields:
```dart
learned: learned,
learnCount: learnCount,
```

Update `withKeywords` to preserve new fields:
```dart
learned: learned,
learnCount: learnCount,
```

**Step 3: Update test fixtures**

In `mobile/test/fixtures/test_data.dart`, update `TestData.sentence()` factory to include:
```dart
bool learned = false,
int learnCount = 0,
```
and pass them to the Sentence constructor.

**Step 4: Verify**

Run: `cd mobile && flutter analyze 2>&1 | grep -c "error"` — should still be ~27 (no new errors)

Run: `cd mobile && flutter test test/data/models/sentence_model_test.dart` — existing tests should still pass

**Step 5: Commit**

```bash
git add mobile/lib/domain/entities/sentence.dart mobile/lib/data/models/sentence_model.dart mobile/test/fixtures/test_data.dart
git commit -m "feat(mobile): add learned/learnCount fields to Sentence entity and model"
```

---

### Task 3: Add SentenceDao.updateLearningProgress method

**Files:**
- Modify: `mobile/lib/data/local/daos/sentence_dao.dart` (add method at end)

**Step 1: Add updateLearningProgress method**

Add at end of `SentenceDao` class (before closing brace), after `countByProjectId`:
```dart
/// Updates learning progress for a sentence.
Future<int> updateLearningProgress(
  String id, {
  required bool learned,
  required int learnCount,
}) async {
  final db = await _database.database;
  return db.update(
    'sentences',
    {
      'learned': learned ? 1 : 0,
      'learn_count': learnCount,
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}
```

**Step 2: Verify**

Run: `cd mobile && flutter analyze 2>&1 | head -5`

**Step 3: Commit**

```bash
git add mobile/lib/data/local/daos/sentence_dao.dart
git commit -m "feat(mobile): add updateLearningProgress to SentenceDao"
```

---

### Task 4: Add KeywordDao.getByProjectId method

**Files:**
- Modify: `mobile/lib/data/local/daos/keyword_dao.dart` (add method at end)

**Step 1: Add getByProjectId method**

Add at end of `KeywordDao` class (before closing brace):
```dart
/// Gets all keywords for a project (via sentence JOIN).
Future<List<KeywordModel>> getByProjectId(String projectId) async {
  final db = await _database.database;
  final results = await db.rawQuery(
    'SELECT k.* FROM keywords k '
    'INNER JOIN sentences s ON k.sentence_id = s.id '
    'WHERE s.project_id = ? '
    'ORDER BY s.idx ASC',
    [projectId],
  );
  return results.map((map) => KeywordModel.fromMap(map)).toList();
}
```

**Step 2: Verify**

Run: `cd mobile && flutter analyze 2>&1 | head -5`

**Step 3: Commit**

```bash
git add mobile/lib/data/local/daos/keyword_dao.dart
git commit -m "feat(mobile): add getByProjectId to KeywordDao"
```

---

### Task 5: Add exportProject to ProjectRepository and implementation

**Files:**
- Modify: `mobile/lib/domain/repositories/project_repository.dart` (add method signature)
- Modify: `mobile/lib/data/repositories/project_repository_impl.dart` (add implementation)

**Step 1: Add interface method**

In `mobile/lib/domain/repositories/project_repository.dart`, add before closing brace:
```dart
/// Exports a project with all sentences and keywords as a JSON-compatible map.
Future<Result<Map<String, dynamic>>> exportProject(String projectId);
```

**Step 2: Add implementation**

In `mobile/lib/data/repositories/project_repository_impl.dart`, add at end of class:
```dart
@override
Future<Result<Map<String, dynamic>>> exportProject(String projectId) async {
  try {
    final project = await _projectDao.getById(projectId);
    if (project == null) {
      return const Result.failure(NotFoundFailure(message: 'Project not found'));
    }

    final sentences = await _sentenceDao.getByProjectId(projectId);
    final keywordMap = await _keywordDao.getBySentenceIds(
      sentences.map((s) => s.id).toList(),
    );

    return Result.success({
      'version': '1.0',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'project': {
        'id': project.id,
        'name': project.name,
        'total_sentences': project.totalSentences,
      },
      'sentences': sentences.map((s) {
        final keywords = keywordMap[s.id] ?? [];
        return {
          'id': s.id,
          'index': s.index,
          'text': s.text,
          'start_time': s.startTime,
          'end_time': s.endTime,
          'translation_en': s.translationEn,
          'explanation_nl': s.explanationNl,
          'explanation_en': s.explanationEn,
          'learned': s.learned,
          'learn_count': s.learnCount,
          'keywords': keywords.map((k) => {
            'word': k.word,
            'meaning_nl': k.meaningNl,
            'meaning_en': k.meaningEn,
          }).toList(),
        };
      }).toList(),
    });
  } on Exception catch (e) {
    return Result.failure(DatabaseFailure(
      message: 'Failed to export project: ${e.toString()}',
    ));
  }
}
```

**Step 3: Verify**

Run: `cd mobile && flutter analyze 2>&1 | head -5`

**Step 4: Commit**

```bash
git add mobile/lib/domain/repositories/project_repository.dart mobile/lib/data/repositories/project_repository_impl.dart
git commit -m "feat(mobile): add exportProject to ProjectRepository"
```

---

### Task 6: Add exportProject and importOrMergeProject to ProjectListNotifier

**Files:**
- Modify: `mobile/lib/presentation/providers/project_provider.dart:35-104`

**Step 1: Add exportProject method**

In `ProjectListNotifier` (after `importProject`, before `clearError`), add:
```dart
/// Exports a project as a JSON-compatible map.
Future<Map<String, dynamic>?> exportProject(String projectId) async {
  final result = await _repository.exportProject(projectId);
  return result.fold(
    onSuccess: (data) => data,
    onFailure: (failure) {
      state = state.copyWith(error: failure.message);
      return null;
    },
  );
}
```

**Step 2: Add importOrMergeProject method**

Add after `exportProject`:
```dart
/// Imports a project, merging if it already exists (by source_id).
Future<Project?> importOrMergeProject(Map<String, dynamic> jsonData) async {
  // Wrap remote data in expected import format if needed
  final Map<String, dynamic> importData;
  if (jsonData.containsKey('project') && jsonData.containsKey('sentences')) {
    importData = jsonData;
  } else {
    // Flat format — wrap it
    importData = {
      'project': jsonData,
      'sentences': jsonData['sentences'] ?? [],
    };
  }
  return importProject(importData, null);
}
```

**Step 3: Verify**

Run: `cd mobile && flutter analyze 2>&1 | head -5`

**Step 4: Commit**

```bash
git add mobile/lib/presentation/providers/project_provider.dart
git commit -m "feat(mobile): add exportProject and importOrMergeProject to ProjectListNotifier"
```

---

### Task 7: Fix RecordScreen — ProcessedProject import

**Files:**
- Modify: `mobile/lib/presentation/screens/record_screen.dart:480-482`

**Step 1: Fix the import call**

Replace line 482:
```dart
await projectNotifier.importProcessedProject(project);
```

With a conversion that wraps ProcessedProject.toJson() into the expected import format:
```dart
final projectJson = project.toJson();
final importData = {
  'project': {
    'id': projectJson['id'],
    'name': projectJson['name'],
    'total_sentences': project.sentences.length,
  },
  'sentences': project.sentences.map((s) => {
    'index': s.order,
    'text': s.text,
    'start_time': s.startTime,
    'end_time': s.endTime,
    'translation_en': s.translationEn,
    'explanation_nl': s.explanationNl,
    'explanation_en': s.explanationEn,
    'keywords': s.keywords.map((k) => {
      'word': k.word,
      'meaning_nl': k.meaningNl,
      'meaning_en': k.meaningEn,
    }).toList(),
  }).toList(),
};
await projectNotifier.importProject(importData, project.audioFile.path);
```

**Step 2: Verify**

Run: `cd mobile && flutter analyze 2>&1 | grep "record_screen"` — should show 0 errors for this file

**Step 3: Commit**

```bash
git add mobile/lib/presentation/screens/record_screen.dart
git commit -m "fix(mobile): fix RecordScreen import by converting ProcessedProject to expected format"
```

---

### Task 8: Add upload methods to GoogleDriveRepository

**Files:**
- Modify: `mobile/lib/domain/repositories/google_drive_repository.dart` (add 2 method signatures)
- Modify: `mobile/lib/data/repositories/google_drive_repository_impl.dart` (add implementations)

**Step 1: Add interface methods**

In `mobile/lib/domain/repositories/google_drive_repository.dart`, add before closing brace:
```dart
/// Gets or creates the Dutch Learn folder in Drive.
Future<Result<String>> getOrCreateDutchLearnFolder();

/// Uploads a project to Google Drive.
Future<Result<void>> uploadProject({
  required String projectId,
  required String jsonContent,
  File? audioFile,
});
```

Add `import 'dart:io';` at top of file.

**Step 2: Add implementations**

In `mobile/lib/data/repositories/google_drive_repository_impl.dart`, add at end of class:
```dart
@override
Future<Result<String>> getOrCreateDutchLearnFolder() async {
  try {
    final folderId = await _driveService.getOrCreateDutchLearnFolder();
    return Result.success(folderId);
  } on Exception catch (e) {
    return Result.failure(GoogleDriveFailure(
      message: 'Failed to get Dutch Learn folder: ${e.toString()}',
    ));
  }
}

@override
Future<Result<void>> uploadProject({
  required String projectId,
  required String jsonContent,
  File? audioFile,
}) async {
  try {
    await _driveService.uploadProject(
      projectId: projectId,
      jsonContent: jsonContent,
      audioFile: audioFile,
    );
    return const Result.success(null);
  } on Exception catch (e) {
    return Result.failure(GoogleDriveFailure(
      message: 'Failed to upload project: ${e.toString()}',
    ));
  }
}
```

**Step 3: Verify**

Run: `cd mobile && flutter analyze 2>&1 | head -5`

**Step 4: Commit**

```bash
git add mobile/lib/domain/repositories/google_drive_repository.dart mobile/lib/data/repositories/google_drive_repository_impl.dart
git commit -m "feat(mobile): add upload methods to GoogleDriveRepository"
```

---

### Task 9: Rewrite SyncService to use DAOs directly

This is the biggest task — replace the broken SyncService with one that uses injected DAOs and correct field names.

**Files:**
- Rewrite: `mobile/lib/data/services/sync_service.dart`

**Step 1: Rewrite SyncService**

Replace the entire file content with:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:dutch_learn_app/core/utils/file_utils.dart';
import 'package:dutch_learn_app/data/local/daos/keyword_dao.dart';
import 'package:dutch_learn_app/data/local/daos/project_dao.dart';
import 'package:dutch_learn_app/data/local/daos/sentence_dao.dart';
import 'package:dutch_learn_app/data/models/keyword_model.dart';
import 'package:dutch_learn_app/data/models/project_model.dart';
import 'package:dutch_learn_app/data/models/sentence_model.dart';
import 'package:dutch_learn_app/data/services/google_drive_service.dart';
import 'package:uuid/uuid.dart';

/// Service for bidirectional sync between local database and Google Drive.
class SyncService {
  final GoogleDriveService _driveService;
  final ProjectDao _projectDao;
  final SentenceDao _sentenceDao;
  final KeywordDao _keywordDao;
  final _uuid = const Uuid();

  SyncService({
    required GoogleDriveService driveService,
    required ProjectDao projectDao,
    required SentenceDao sentenceDao,
    required KeywordDao keywordDao,
  })  : _driveService = driveService,
        _projectDao = projectDao,
        _sentenceDao = sentenceDao,
        _keywordDao = keywordDao;

  /// Performs full bidirectional sync.
  Future<SyncResult> performSync({
    void Function(String status, double progress)? onProgress,
  }) async {
    final result = SyncResult();

    try {
      onProgress?.call('Uploading local changes...', 0.1);

      final uploadResult = await uploadLocalProjects(
        onProgress: (p) => onProgress?.call('Uploading...', 0.1 + p * 0.4),
      );
      result.uploaded = uploadResult.uploaded;
      result.uploadErrors = uploadResult.errors;

      onProgress?.call('Downloading remote changes...', 0.5);

      final downloadResult = await downloadRemoteProjects(
        onProgress: (p) => onProgress?.call('Downloading...', 0.5 + p * 0.4),
      );
      result.downloaded = downloadResult.downloaded;
      result.merged = downloadResult.merged;
      result.newProjects = downloadResult.newProjects;
      result.downloadErrors = downloadResult.errors;

      onProgress?.call('Sync complete', 1.0);
    } catch (e) {
      result.error = e.toString();
    }

    return result;
  }

  /// Uploads all local projects to Google Drive.
  Future<UploadResult> uploadLocalProjects({
    List<String>? projectIds,
    void Function(double progress)? onProgress,
  }) async {
    final result = UploadResult();

    try {
      final projects = await _projectDao.getAll();

      final filteredProjects = projectIds != null
          ? projects.where((p) => projectIds.contains(p.id)).toList()
          : projects;

      for (var i = 0; i < filteredProjects.length; i++) {
        final project = filteredProjects[i];

        try {
          final exportData = await exportProject(project.id);
          final jsonContent = jsonEncode(exportData);

          final audioDir = await FileUtils.getAudioDirectoryPath();
          final audioFile = File(FileUtils.joinPath(audioDir, '${project.id}.mp3'));

          await _driveService.uploadProject(
            projectId: project.id,
            jsonContent: jsonContent,
            audioFile: audioFile.existsSync() ? audioFile : null,
          );

          result.uploaded.add(project.id);
        } catch (e) {
          result.errors.add(SyncError(projectId: project.id, error: e.toString()));
        }

        onProgress?.call((i + 1) / filteredProjects.length);
      }
    } catch (e) {
      result.errors.add(SyncError(projectId: null, error: e.toString()));
    }

    return result;
  }

  /// Downloads and merges remote projects from Google Drive.
  Future<DownloadResult> downloadRemoteProjects({
    List<String>? projectIds,
    void Function(double progress)? onProgress,
  }) async {
    final result = DownloadResult();

    try {
      final dutchLearnFolderId = await _driveService.getOrCreateDutchLearnFolder();

      final projectFolders = await _driveService.listFiles(
        folderId: dutchLearnFolderId,
        mimeType: 'application/vnd.google-apps.folder',
      );

      final filteredFolders = projectIds != null
          ? projectFolders.where((f) => projectIds.contains(f['name'])).toList()
          : projectFolders;

      for (var i = 0; i < filteredFolders.length; i++) {
        final folder = filteredFolders[i];
        final projectId = folder['name'] as String;
        final folderId = folder['id'] as String;

        try {
          final files = await _driveService.listFiles(folderId: folderId);

          final jsonFile = files.firstWhere(
            (f) => f['name'] == 'project.json',
            orElse: () => <String, dynamic>{},
          );

          if (jsonFile.isEmpty) {
            result.errors.add(SyncError(
              projectId: projectId,
              error: 'project.json not found',
            ));
            continue;
          }

          final jsonBytes = await _driveService.downloadFile(jsonFile['id'] as String);
          final jsonString = utf8.decode(jsonBytes);
          final remoteData = jsonDecode(jsonString) as Map<String, dynamic>;

          final localProject = await _projectDao.getBySourceId(projectId);

          if (localProject != null) {
            final localData = await exportProject(localProject.id);
            final mergedData = ProgressMerger.merge(localData, remoteData);
            await _importMergedProgress(localProject.id, mergedData);
            result.merged.add(projectId);
          } else {
            await _importNewProject(projectId, remoteData);

            // Download audio if available
            final audioFile = files.firstWhere(
              (f) => f['name'] == 'audio.mp3',
              orElse: () => <String, dynamic>{},
            );

            if (audioFile.isNotEmpty) {
              final audioBytes = await _driveService.downloadFile(audioFile['id'] as String);
              final audioDir = await FileUtils.getAudioDirectoryPath();
              final dir = Directory(audioDir);
              if (!dir.existsSync()) {
                dir.createSync(recursive: true);
              }
              final audioPath = File(FileUtils.joinPath(audioDir, '$projectId.mp3'));
              await audioPath.writeAsBytes(audioBytes);
            }

            result.newProjects.add(projectId);
          }

          result.downloaded.add(projectId);
        } catch (e) {
          result.errors.add(SyncError(projectId: projectId, error: e.toString()));
        }

        onProgress?.call((i + 1) / filteredFolders.length);
      }
    } catch (e) {
      result.errors.add(SyncError(projectId: null, error: e.toString()));
    }

    return result;
  }

  /// Exports a project to a map for JSON serialization.
  Future<Map<String, dynamic>> exportProject(String projectId) async {
    final project = await _projectDao.getById(projectId);
    if (project == null) {
      throw Exception('Project not found: $projectId');
    }

    final sentences = await _sentenceDao.getByProjectId(projectId);
    final keywordMap = await _keywordDao.getBySentenceIds(
      sentences.map((s) => s.id).toList(),
    );

    return {
      'version': '1.0',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'project': {
        'id': project.id,
        'name': project.name,
        'total_sentences': project.totalSentences,
      },
      'sentences': sentences.map((s) {
        final keywords = keywordMap[s.id] ?? [];
        return {
          'id': s.id,
          'index': s.index,
          'text': s.text,
          'start_time': s.startTime,
          'end_time': s.endTime,
          'translation_en': s.translationEn,
          'explanation_nl': s.explanationNl,
          'explanation_en': s.explanationEn,
          'learned': s.learned,
          'learn_count': s.learnCount,
          'keywords': keywords.map((k) => {
            'word': k.word,
            'meaning_nl': k.meaningNl,
            'meaning_en': k.meaningEn,
          }).toList(),
        };
      }).toList(),
    };
  }

  /// Imports a completely new project from remote data.
  Future<void> _importNewProject(
    String sourceId,
    Map<String, dynamic> data,
  ) async {
    // Handle both wrapped {project, sentences} and flat format
    final Map<String, dynamic> projectData;
    final List<dynamic> sentencesList;

    if (data.containsKey('project') && data.containsKey('sentences')) {
      projectData = data['project'] as Map<String, dynamic>;
      sentencesList = data['sentences'] as List<dynamic>;
    } else {
      projectData = data;
      sentencesList = data['sentences'] as List<dynamic>? ?? [];
    }

    final projectId = _uuid.v4();

    final project = ProjectModel(
      id: projectId,
      sourceId: sourceId,
      name: projectData['name'] as String? ?? sourceId,
      totalSentences: sentencesList.length,
      audioPath: null,
      importedAt: DateTime.now(),
    );
    await _projectDao.insert(project);

    final sentenceModels = <SentenceModel>[];
    final keywordModels = <KeywordModel>[];

    for (final sData in sentencesList) {
      final sMap = sData as Map<String, dynamic>;
      final sentenceId = _uuid.v4();

      sentenceModels.add(SentenceModel(
        id: sentenceId,
        projectId: projectId,
        index: sMap['index'] as int? ?? sMap['order'] as int? ?? sentenceModels.length,
        text: sMap['text'] as String? ?? '',
        startTime: (sMap['start_time'] as num?)?.toDouble() ?? 0.0,
        endTime: (sMap['end_time'] as num?)?.toDouble() ?? 0.0,
        translationEn: sMap['translation_en'] as String?,
        explanationNl: sMap['explanation_nl'] as String?,
        explanationEn: sMap['explanation_en'] as String?,
        learned: sMap['learned'] as bool? ?? false,
        learnCount: sMap['learn_count'] as int? ?? 0,
      ));

      final keywords = sMap['keywords'] as List<dynamic>?;
      if (keywords != null) {
        for (final kData in keywords) {
          final kMap = kData as Map<String, dynamic>;
          keywordModels.add(KeywordModel(
            id: _uuid.v4(),
            sentenceId: sentenceId,
            word: kMap['word'] as String? ?? '',
            meaningNl: kMap['meaning_nl'] as String? ?? '',
            meaningEn: kMap['meaning_en'] as String? ?? '',
          ));
        }
      }
    }

    await _sentenceDao.insertBatch(sentenceModels);
    await _keywordDao.insertBatch(keywordModels);
  }

  /// Merges learning progress into an existing local project.
  Future<void> _importMergedProgress(
    String localProjectId,
    Map<String, dynamic> mergedData,
  ) async {
    final sentencesList = mergedData['sentences'] as List<dynamic>? ?? [];
    final localSentences = await _sentenceDao.getByProjectId(localProjectId);
    final localById = {for (var s in localSentences) s.id: s};

    for (final sData in sentencesList) {
      final sMap = sData as Map<String, dynamic>;
      final sentenceId = sMap['id'] as String?;
      if (sentenceId == null) continue;

      final localSentence = localById[sentenceId];
      if (localSentence != null) {
        await _sentenceDao.updateLearningProgress(
          sentenceId,
          learned: sMap['learned'] as bool? ?? localSentence.learned,
          learnCount: sMap['learn_count'] as int? ?? localSentence.learnCount,
        );
      }
    }
  }
}

/// Merges learning progress from local and remote data.
class ProgressMerger {
  /// Merges local and remote project data.
  /// Strategy: learned = OR, learn_count = max.
  static Map<String, dynamic> merge(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = Map<String, dynamic>.from(local);

    final localSentences = (local['sentences'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final remoteSentences = (remote['sentences'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final localById = {for (var s in localSentences) s['id']: s};
    final remoteById = {for (var s in remoteSentences) s['id']: s};

    final allIds = {...localById.keys, ...remoteById.keys};

    final mergedSentences = <Map<String, dynamic>>[];
    for (final id in allIds) {
      final localS = localById[id];
      final remoteS = remoteById[id];

      if (localS != null && remoteS != null) {
        final mergedS = Map<String, dynamic>.from(localS);
        mergedS['learned'] = (localS['learned'] as bool? ?? false) ||
            (remoteS['learned'] as bool? ?? false);
        mergedS['learn_count'] = _max(
          localS['learn_count'] as int? ?? 0,
          remoteS['learn_count'] as int? ?? 0,
        );
        mergedSentences.add(mergedS);
      } else {
        mergedSentences.add(localS ?? remoteS!);
      }
    }

    mergedSentences.sort((a, b) =>
        (a['index'] as int? ?? 0).compareTo(b['index'] as int? ?? 0));

    merged['sentences'] = mergedSentences;

    return merged;
  }

  static int _max(int a, int b) => a > b ? a : b;
}

/// Result of a sync operation.
class SyncResult {
  List<String> uploaded = [];
  List<String> downloaded = [];
  List<String> merged = [];
  List<String> newProjects = [];
  List<SyncError> uploadErrors = [];
  List<SyncError> downloadErrors = [];
  String? error;

  bool get success =>
      error == null && uploadErrors.isEmpty && downloadErrors.isEmpty;

  String get message {
    final parts = <String>[];
    if (uploaded.isNotEmpty) parts.add('${uploaded.length} uploaded');
    if (downloaded.isNotEmpty) parts.add('${downloaded.length} downloaded');
    if (merged.isNotEmpty) parts.add('${merged.length} merged');
    if (newProjects.isNotEmpty) parts.add('${newProjects.length} new');

    final errorCount = uploadErrors.length + downloadErrors.length;
    if (errorCount > 0) parts.add('$errorCount errors');

    return parts.isEmpty ? 'No changes' : parts.join(', ');
  }
}

/// Result of an upload operation.
class UploadResult {
  List<String> uploaded = [];
  List<SyncError> errors = [];
}

/// Result of a download operation.
class DownloadResult {
  List<String> downloaded = [];
  List<String> merged = [];
  List<String> newProjects = [];
  List<SyncError> errors = [];
}

/// Error during sync.
class SyncError {
  final String? projectId;
  final String error;

  SyncError({required this.projectId, required this.error});
}
```

**Step 2: Verify**

Run: `cd mobile && flutter analyze 2>&1 | grep "sync_service"` — should show 0 errors for this file

**Step 3: Commit**

```bash
git add mobile/lib/data/services/sync_service.dart
git commit -m "feat(mobile): rewrite SyncService to use DAOs directly with correct field names"
```

---

### Task 10: Wire SyncService into DI container

**Files:**
- Modify: `mobile/lib/injection_container.dart`

**Step 1: Add SyncService import and provider**

Add import at top:
```dart
import 'package:dutch_learn_app/data/services/sync_service.dart';
```

Add provider after `settingsRepositoryProvider` (at end of file):
```dart
/// Provider for SyncService.
final syncServiceProvider = Provider<SyncService>((ref) {
  final driveService = ref.watch(googleDriveServiceProvider);
  final projectDao = ref.watch(projectDaoProvider);
  final sentenceDao = ref.watch(sentenceDaoProvider);
  final keywordDao = ref.watch(keywordDaoProvider);
  return SyncService(
    driveService: driveService,
    projectDao: projectDao,
    sentenceDao: sentenceDao,
    keywordDao: keywordDao,
  );
});
```

**Step 2: Verify**

Run: `cd mobile && flutter analyze 2>&1 | head -5`

**Step 3: Commit**

```bash
git add mobile/lib/injection_container.dart
git commit -m "feat(mobile): wire SyncService into Riverpod DI container"
```

---

### Task 11: Fix SyncProvider — replace broken references

**Files:**
- Modify: `mobile/lib/presentation/providers/sync_provider.dart`

This task fixes all remaining compilation errors in sync_provider.dart. The sync provider currently:
1. Accesses `_driveRepository.driveService` (line 463, 482) — private field
2. Reads `projectListProvider` as List (line 443) — it's `ProjectListState`
3. Calls `projectNotifier.exportProject()` (line 457) — didn't exist, now added in Task 6
4. Calls `projectNotifier.importOrMergeProject()` (line 522) — didn't exist, now added in Task 6

**Step 1: Fix _uploadLocalProjects**

Replace `_uploadLocalProjects` method (lines 442-477) with:
```dart
/// Uploads local projects to Google Drive.
Future<void> _uploadLocalProjects() async {
  final projectState = _ref.read(projectListProvider);
  final projects = projectState.projects;
  if (projects.isEmpty) return;

  for (var i = 0; i < projects.length; i++) {
    final project = projects[i];

    state = state.copyWith(
      syncStatus: 'Uploading: ${project.name}',
      syncProgress: 0.1 + (i / projects.length) * 0.35,
    );

    try {
      final projectNotifier = _ref.read(projectListProvider.notifier);
      final exportData = await projectNotifier.exportProject(project.id);
      if (exportData == null) continue;

      final jsonContent = json.encode(exportData);

      final audioDir = await FileUtils.getAudioDirectoryPath();
      final audioFile = File(FileUtils.joinPath(audioDir, '${project.id}.mp3'));

      final uploadResult = await _driveRepository.uploadProject(
        projectId: project.id,
        jsonContent: jsonContent,
        audioFile: audioFile.existsSync() ? audioFile : null,
      );

      uploadResult.fold(
        onSuccess: (_) {},
        onFailure: (failure) {
          debugPrint('Failed to upload project ${project.id}: ${failure.message}');
        },
      );
    } catch (e) {
      debugPrint('Failed to upload project ${project.id}: $e');
    }
  }
}
```

**Step 2: Fix _downloadAndMergeProjects**

Replace `_downloadAndMergeProjects` method (lines 480 to end of method) with:
```dart
/// Downloads and merges remote projects from Google Drive.
Future<void> _downloadAndMergeProjects() async {
  try {
    final folderResult = await _driveRepository.getOrCreateDutchLearnFolder();
    final dutchLearnFolderId = folderResult.fold(
      onSuccess: (id) => id,
      onFailure: (failure) => throw Exception(failure.message),
    );

    final foldersResult = await _driveRepository.listFiles(folderId: dutchLearnFolderId);
    final allFiles = foldersResult.fold(
      onSuccess: (files) => files,
      onFailure: (failure) => throw Exception(failure.message),
    );

    // Filter to folders only
    final projectFolders = allFiles.where((f) => f.isFolder).toList();

    for (var i = 0; i < projectFolders.length; i++) {
      final folder = projectFolders[i];

      state = state.copyWith(
        syncStatus: 'Processing: ${folder.name}',
        syncProgress: 0.5 + (i / projectFolders.length) * 0.45,
      );

      try {
        final filesResult = await _driveRepository.listFiles(folderId: folder.id);
        final files = filesResult.fold(
          onSuccess: (f) => f,
          onFailure: (failure) => throw Exception(failure.message),
        );

        // Find project.json
        final jsonFiles = files.where((f) => f.name == 'project.json').toList();
        if (jsonFiles.isEmpty) continue;

        // Download project.json
        final jsonResult = await _driveRepository.downloadJson(jsonFiles.first.id);
        final remoteData = jsonResult.fold(
          onSuccess: (data) => data,
          onFailure: (failure) => throw Exception(failure.message),
        );

        // Import or merge project
        final projectNotifier = _ref.read(projectListProvider.notifier);
        await projectNotifier.importOrMergeProject(remoteData);

        // Download audio if needed
        final audioFiles = files.where((f) => f.name == 'audio.mp3').toList();
        if (audioFiles.isNotEmpty) {
          final audioDir = await FileUtils.getAudioDirectoryPath();
          final audioPath = FileUtils.joinPath(audioDir, '${folder.name}.mp3');
          final audioLocalFile = File(audioPath);
          if (!audioLocalFile.existsSync()) {
            await _driveRepository.downloadFileToPath(audioFiles.first.id, audioPath);
          }
        }
      } catch (e) {
        debugPrint('Failed to process remote project ${folder.name}: $e');
      }
    }
  } catch (e) {
    debugPrint('Failed to download remote projects: $e');
  }
}
```

**Step 3: Ensure imports are correct**

Check the imports at top of sync_provider.dart. Ensure these are present:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/core/utils/file_utils.dart';
import 'package:dutch_learn_app/domain/repositories/google_drive_repository.dart';
import 'package:dutch_learn_app/presentation/providers/project_provider.dart';
```

Remove any import of `sync_service.dart` if present (the provider no longer uses SyncService directly — it goes through the repository layer).

**Step 4: Verify**

Run: `cd mobile && flutter analyze 2>&1 | grep "sync_provider"` — should show 0 errors

**Step 5: Commit**

```bash
git add mobile/lib/presentation/providers/sync_provider.dart
git commit -m "fix(mobile): rewrite sync_provider upload/download to use repository pattern"
```

---

### Task 12: Final verification — flutter analyze clean

**Files:** None (verification only)

**Step 1: Run full analysis**

Run: `cd mobile && flutter analyze`
Expected: 0 errors, 0 warnings (or only pre-existing warnings unrelated to our changes)

**Step 2: Run existing tests**

Run: `cd mobile && flutter test`
Expected: All tests pass

**Step 3: If errors remain, fix them**

If `flutter analyze` still shows errors, read each error carefully and fix. Common issues:
- Missing imports
- Type mismatches
- Unused imports that need removal

**Step 4: Commit any remaining fixes**

```bash
git add -A
git commit -m "fix(mobile): resolve remaining compilation errors"
```

---

### Task 13: Code Review & Evaluation (评价)

**Files:** All modified files from Tasks 1-12

**Goal:** Systematically review all changes for correctness, consistency, and completeness before building.

**Step 1: Review all modified files for correctness**

Check each modified file against the plan:
```bash
cd mobile && git diff --stat HEAD~12..HEAD
```
Verify:
- [ ] All 27 original compilation errors are resolved
- [ ] No new compilation errors introduced
- [ ] Entity/Model field names are consistent (snake_case in DB/JSON, camelCase in Dart)
- [ ] All DAO methods match their callers' expectations (parameter names, return types)
- [ ] SyncService and SyncProvider don't have duplicate/conflicting logic
- [ ] DI wiring in injection_container.dart is complete (no missing providers)

**Step 2: Review data flow consistency**

Trace the full data flow and verify consistency:
1. **Import path:** RecordScreen → ProcessedProject.toJson() → importProject → DAO inserts
2. **Export path:** exportProject → DAO reads → JSON map → Google Drive upload
3. **Sync path:** SyncProvider → repository methods → SyncService → DAOs
4. Verify JSON field names match between export and import (e.g., `start_time`, `learn_count`)

**Step 3: Review test coverage**

```bash
cd mobile && flutter test --coverage
```
Check:
- [ ] Existing tests still pass
- [ ] New DAO methods (updateLearningProgress, getByProjectId) have test coverage
- [ ] SentenceModel serialization with new learned/learnCount fields is tested
- [ ] If coverage gaps exist, note them for Task 15

**Step 4: Document evaluation findings**

Create a brief evaluation report:
```bash
cat > docs/validation/2026-02-08-sync-evaluation.md << 'EOF'
# Sync & Recording Implementation Evaluation
## Date: [current date]
## Status: [PASS/FAIL/NEEDS_FIXES]
## Findings:
- [list findings here]
## Action items:
- [list items for debugging if needed]
EOF
```

---

### Task 14: Debug & Fix Issues (调试)

**Files:** Depends on issues found in Task 13

**Goal:** Fix all issues discovered during evaluation. This task is conditional — skip if Task 13 found no issues.

**Step 1: Address each finding from evaluation report**

For each issue found in Task 13:
1. Read the relevant source file
2. Understand the root cause
3. Implement the fix
4. Verify the fix with `flutter analyze`

**Step 2: Run targeted tests**

For each fix, run the relevant test file:
```bash
cd mobile && flutter test test/data/models/sentence_model_test.dart
cd mobile && flutter test test/data/repositories/  # if repo tests exist
```

**Step 3: Run full test suite after all fixes**

```bash
cd mobile && flutter test
cd mobile && flutter analyze
```

**Step 4: Commit fixes**

```bash
git add -A
git commit -m "fix(mobile): address issues found during code evaluation"
```

---

### Task 15: Re-evaluation (重新评价)

**Files:** All modified files

**Goal:** Verify that all issues from Task 13 are resolved and no regressions were introduced.

**Step 1: Re-run full analysis**

```bash
cd mobile && flutter analyze
```
Expected: 0 errors

**Step 2: Re-run full test suite**

```bash
cd mobile && flutter test
```
Expected: All tests pass, no regressions

**Step 3: Verify all Task 13 findings are resolved**

Go through each finding from the evaluation report (docs/validation/2026-02-08-sync-evaluation.md) and confirm it's fixed. Update the report status to PASS.

**Step 4: Smoke test the data flows**

Manually verify key data flows compile correctly by tracing imports:
1. `record_screen.dart` → `project_provider.dart` → `project_repository_impl.dart` → DAOs
2. `sync_provider.dart` → `google_drive_repository.dart` → `sync_service.dart` → DAOs
3. `injection_container.dart` references all providers correctly

**Step 5: Update evaluation report**

```bash
# Update docs/validation/2026-02-08-sync-evaluation.md
# Set status to PASS, note all issues resolved
```

**Step 6: If new issues found, loop back to Task 14**

If re-evaluation finds new issues:
1. Update the evaluation report with new findings
2. Return to Task 14 to fix them
3. Come back to Task 15 to re-evaluate
4. Repeat until clean

---

### Task 16: Build release APK

**Files:** None (build only)

**Step 1: Build release APK**

Run: `cd mobile && flutter build apk --release`
Expected: BUILD SUCCESSFUL, APK at `build/app/outputs/flutter-apk/app-release.apk`

**Step 2: Check APK size**

Run: `ls -lh mobile/build/app/outputs/flutter-apk/app-release.apk`

**Step 3: Report APK path to user**

The APK will be at: `mobile/build/app/outputs/flutter-apk/app-release.apk`
User can copy it to their Android phone and install.
