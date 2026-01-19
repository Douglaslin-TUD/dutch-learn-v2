# Flutter Project Folder Structure
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31

---

## 1. Complete Project Structure

```
dutch_learn_app/
|
+-- android/                          # Android platform-specific code
|   +-- app/
|   |   +-- src/
|   |   |   +-- main/
|   |   |       +-- AndroidManifest.xml
|   |   |       +-- kotlin/.../MainActivity.kt
|   |   +-- build.gradle.kts
|   +-- build.gradle.kts
|   +-- settings.gradle.kts
|
+-- lib/                              # Main Dart source code
|   |
|   +-- main.dart                     # App entry point
|   +-- app.dart                      # MaterialApp configuration
|   |
|   +-- core/                         # Cross-cutting concerns
|   |   +-- constants/
|   |   |   +-- app_constants.dart    # App-wide constants
|   |   |   +-- storage_keys.dart     # Database/storage keys
|   |   |
|   |   +-- errors/
|   |   |   +-- exceptions.dart       # Custom exception classes
|   |   |   +-- failures.dart         # Failure types for Result
|   |   |
|   |   +-- result/
|   |   |   +-- result.dart           # Result<T> sealed class
|   |   |
|   |   +-- extensions/
|   |   |   +-- string_extensions.dart
|   |   |   +-- duration_extensions.dart
|   |   |   +-- context_extensions.dart
|   |   |
|   |   +-- utils/
|   |   |   +-- logger.dart           # Logging utility
|   |   |   +-- validators.dart       # Input validation
|   |   |   +-- formatters.dart       # Time/text formatting
|   |   |
|   |   +-- network/
|   |       +-- connectivity_service.dart
|   |
|   +-- domain/                       # Business logic layer (pure Dart)
|   |   |
|   |   +-- entities/                 # Business objects
|   |   |   +-- project.dart
|   |   |   +-- sentence.dart
|   |   |   +-- keyword.dart
|   |   |   +-- app_settings.dart
|   |   |
|   |   +-- repositories/             # Repository interfaces (abstract)
|   |   |   +-- project_repository.dart
|   |   |   +-- sentence_repository.dart
|   |   |   +-- keyword_repository.dart
|   |   |   +-- settings_repository.dart
|   |   |   +-- audio_repository.dart
|   |   |   +-- drive_repository.dart
|   |   |
|   |   +-- usecases/                 # Business operations
|   |       +-- project/
|   |       |   +-- get_all_projects.dart
|   |       |   +-- get_project.dart
|   |       |   +-- import_project.dart
|   |       |   +-- delete_project.dart
|   |       |   +-- update_project_progress.dart
|   |       |
|   |       +-- sentence/
|   |       |   +-- get_sentence.dart
|   |       |   +-- get_sentences_for_project.dart
|   |       |   +-- find_sentence_at_time.dart
|   |       |
|   |       +-- keyword/
|   |       |   +-- get_keywords_for_sentence.dart
|   |       |   +-- search_vocabulary.dart
|   |       |
|   |       +-- audio/
|   |       |   +-- play_sentence.dart
|   |       |   +-- pause_audio.dart
|   |       |   +-- seek_to_time.dart
|   |       |   +-- set_playback_speed.dart
|   |       |
|   |       +-- drive/
|   |           +-- connect_drive.dart
|   |           +-- disconnect_drive.dart
|   |           +-- list_drive_files.dart
|   |           +-- download_file.dart
|   |
|   +-- data/                         # Data access layer
|   |   |
|   |   +-- models/                   # Data transfer objects
|   |   |   +-- project_model.dart
|   |   |   +-- sentence_model.dart
|   |   |   +-- keyword_model.dart
|   |   |   +-- drive_file_model.dart
|   |   |   +-- export_json_model.dart
|   |   |
|   |   +-- mappers/                  # Model <-> Entity conversion
|   |   |   +-- project_mapper.dart
|   |   |   +-- sentence_mapper.dart
|   |   |   +-- keyword_mapper.dart
|   |   |
|   |   +-- datasources/              # Data source implementations
|   |   |   +-- local/
|   |   |   |   +-- database_helper.dart
|   |   |   |   +-- project_local_datasource.dart
|   |   |   |   +-- sentence_local_datasource.dart
|   |   |   |   +-- keyword_local_datasource.dart
|   |   |   |   +-- settings_local_datasource.dart
|   |   |   |
|   |   |   +-- remote/
|   |   |       +-- google_drive_datasource.dart
|   |   |       +-- google_auth_service.dart
|   |   |
|   |   +-- repositories/             # Repository implementations
|   |   |   +-- project_repository_impl.dart
|   |   |   +-- sentence_repository_impl.dart
|   |   |   +-- keyword_repository_impl.dart
|   |   |   +-- settings_repository_impl.dart
|   |   |   +-- audio_repository_impl.dart
|   |   |   +-- drive_repository_impl.dart
|   |   |
|   |   +-- services/                 # Platform services
|   |       +-- audio_service.dart
|   |       +-- file_service.dart
|   |       +-- secure_storage_service.dart
|   |
|   +-- presentation/                 # UI layer
|   |   |
|   |   +-- navigation/
|   |   |   +-- app_router.dart       # GoRouter configuration
|   |   |   +-- route_names.dart      # Route name constants
|   |   |
|   |   +-- theme/
|   |   |   +-- app_theme.dart        # ThemeData definitions
|   |   |   +-- app_colors.dart       # Color palette
|   |   |   +-- app_text_styles.dart  # Text styles
|   |   |   +-- app_dimensions.dart   # Spacing, sizing
|   |   |
|   |   +-- providers/                # Riverpod providers
|   |   |   +-- core_providers.dart   # Database, services
|   |   |   +-- repository_providers.dart
|   |   |   +-- usecase_providers.dart
|   |   |   +-- project_providers.dart
|   |   |   +-- learning_providers.dart
|   |   |   +-- audio_providers.dart
|   |   |   +-- drive_providers.dart
|   |   |   +-- settings_providers.dart
|   |   |
|   |   +-- state/                    # State classes
|   |   |   +-- project_list_state.dart
|   |   |   +-- learning_state.dart
|   |   |   +-- audio_state.dart
|   |   |   +-- drive_browser_state.dart
|   |   |   +-- import_state.dart
|   |   |
|   |   +-- notifiers/                # StateNotifier classes
|   |   |   +-- project_list_notifier.dart
|   |   |   +-- learning_notifier.dart
|   |   |   +-- audio_notifier.dart
|   |   |   +-- drive_browser_notifier.dart
|   |   |   +-- import_notifier.dart
|   |   |   +-- settings_notifier.dart
|   |   |
|   |   +-- screens/                  # Full-page screens
|   |   |   +-- home/
|   |   |   |   +-- home_screen.dart
|   |   |   |   +-- widgets/
|   |   |   |       +-- project_card.dart
|   |   |   |       +-- empty_projects.dart
|   |   |   |       +-- project_list.dart
|   |   |   |
|   |   |   +-- learning/
|   |   |   |   +-- learning_screen.dart
|   |   |   |   +-- widgets/
|   |   |   |       +-- sentence_display.dart
|   |   |   |       +-- translation_section.dart
|   |   |   |       +-- explanation_section.dart
|   |   |   |       +-- keywords_section.dart
|   |   |   |       +-- navigation_controls.dart
|   |   |   |
|   |   |   +-- drive/
|   |   |   |   +-- drive_picker_screen.dart
|   |   |   |   +-- widgets/
|   |   |   |       +-- drive_file_item.dart
|   |   |   |       +-- folder_breadcrumbs.dart
|   |   |   |       +-- download_progress.dart
|   |   |   |
|   |   |   +-- import/
|   |   |   |   +-- import_screen.dart
|   |   |   |   +-- widgets/
|   |   |   |       +-- import_progress.dart
|   |   |   |       +-- import_complete.dart
|   |   |   |       +-- audio_link_prompt.dart
|   |   |   |
|   |   |   +-- sentences/
|   |   |   |   +-- sentence_list_screen.dart
|   |   |   |   +-- widgets/
|   |   |   |       +-- sentence_list_item.dart
|   |   |   |
|   |   |   +-- vocabulary/
|   |   |   |   +-- vocabulary_screen.dart
|   |   |   |   +-- widgets/
|   |   |   |       +-- vocabulary_item.dart
|   |   |   |
|   |   |   +-- settings/
|   |   |       +-- settings_screen.dart
|   |   |       +-- widgets/
|   |   |           +-- settings_section.dart
|   |   |           +-- theme_selector.dart
|   |   |           +-- font_size_selector.dart
|   |   |           +-- storage_info.dart
|   |   |
|   |   +-- widgets/                  # Shared/reusable widgets
|   |       +-- audio/
|   |       |   +-- audio_player_bar.dart
|   |       |   +-- play_pause_button.dart
|   |       |   +-- speed_selector.dart
|   |       |   +-- loop_button.dart
|   |       |   +-- seek_bar.dart
|   |       |
|   |       +-- common/
|   |       |   +-- loading_indicator.dart
|   |       |   +-- error_display.dart
|   |       |   +-- confirmation_dialog.dart
|   |       |   +-- offline_banner.dart
|   |       |   +-- app_bar_action.dart
|   |       |
|   |       +-- vocabulary/
|   |           +-- keyword_popup.dart
|   |           +-- tappable_text.dart
|   |
|   +-- di/                           # Dependency injection setup
|       +-- injection.dart            # Provider overrides for testing
|
+-- test/                             # Test files
|   +-- unit/
|   |   +-- domain/
|   |   |   +-- usecases/
|   |   |       +-- import_project_test.dart
|   |   |       +-- play_sentence_test.dart
|   |   |
|   |   +-- data/
|   |       +-- repositories/
|   |       |   +-- project_repository_test.dart
|   |       +-- datasources/
|   |           +-- database_helper_test.dart
|   |
|   +-- widget/
|   |   +-- screens/
|   |   |   +-- home_screen_test.dart
|   |   |   +-- learning_screen_test.dart
|   |   +-- widgets/
|   |       +-- audio_player_bar_test.dart
|   |       +-- keyword_popup_test.dart
|   |
|   +-- integration/
|   |   +-- import_flow_test.dart
|   |   +-- learning_flow_test.dart
|   |
|   +-- mocks/
|   |   +-- mock_repositories.dart
|   |   +-- mock_services.dart
|   |   +-- test_data.dart
|   |
|   +-- fixtures/
|       +-- sample_project.json
|       +-- sample_sentences.json
|
+-- integration_test/                 # E2E tests
|   +-- app_test.dart
|   +-- import_test.dart
|   +-- learning_test.dart
|
+-- assets/                           # Static assets
|   +-- images/
|   |   +-- logo.png
|   |   +-- empty_state.svg
|   |
|   +-- fonts/                        # Custom fonts (if any)
|
+-- pubspec.yaml                      # Dependencies
+-- pubspec.lock
+-- analysis_options.yaml             # Linter configuration
+-- .gitignore
+-- README.md
```

---

## 2. Directory Descriptions

### 2.1 Root Level

| Directory | Purpose |
|-----------|---------|
| `android/` | Android platform code, Gradle configuration, manifest |
| `lib/` | Main Dart source code - all app logic lives here |
| `test/` | Unit and widget tests |
| `integration_test/` | Full app integration tests |
| `assets/` | Static resources (images, fonts) |

### 2.2 lib/core/

**Purpose:** Cross-cutting concerns used across all layers.

| Directory | Contents |
|-----------|----------|
| `constants/` | App-wide constant values |
| `errors/` | Custom exception and failure classes |
| `result/` | Result<T> type for error handling |
| `extensions/` | Dart extension methods |
| `utils/` | Utility functions (logging, formatting) |
| `network/` | Network connectivity detection |

**Example file - `lib/core/result/result.dart`:**

```dart
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
    Success(:final data) => data,
    Failure() => null,
  };

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final exception) => failure(exception),
    };
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);
}
```

### 2.3 lib/domain/

**Purpose:** Pure business logic, no Flutter dependencies.

| Directory | Contents |
|-----------|----------|
| `entities/` | Business domain objects |
| `repositories/` | Abstract repository interfaces |
| `usecases/` | Single-purpose business operations |

**Example file - `lib/domain/entities/project.dart`:**

```dart
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
  final int? storageSize;

  const Project({
    required this.id,
    this.sourceId,
    required this.name,
    required this.status,
    required this.totalSentences,
    this.audioPath,
    this.audioDuration,
    required this.importedAt,
    this.lastPlayedAt,
    this.lastSentenceIdx,
    this.storageSize,
  });

  bool get hasAudio => audioPath != null;
  bool get isComplete => status == 'ready';

  Project copyWith({
    String? audioPath,
    double? audioDuration,
    DateTime? lastPlayedAt,
    int? lastSentenceIdx,
  }) { ... }
}
```

**Example file - `lib/domain/repositories/project_repository.dart`:**

```dart
abstract class ProjectRepository {
  Future<List<Project>> getAllProjects();
  Future<Project?> getProject(String id);
  Future<Project?> getProjectBySourceId(String sourceId);
  Future<void> saveProject(Project project);
  Future<void> deleteProject(String id);
  Future<void> updateProgress(String id, int sentenceIdx);
}
```

**Example file - `lib/domain/usecases/project/import_project.dart`:**

```dart
class ImportProjectUseCase {
  final ProjectRepository _projectRepository;
  final SentenceRepository _sentenceRepository;
  final KeywordRepository _keywordRepository;

  ImportProjectUseCase(
    this._projectRepository,
    this._sentenceRepository,
    this._keywordRepository,
  );

  Future<Result<Project>> execute(ExportData exportData) async {
    try {
      // 1. Check for duplicates
      final existing = await _projectRepository.getProjectBySourceId(
        exportData.project.sourceId,
      );
      if (existing != null) {
        return Failure(AppException.validation('Project already exists'));
      }

      // 2. Create project
      final project = Project(
        id: Uuid().v4(),
        sourceId: exportData.project.id,
        name: exportData.project.name,
        status: 'ready',
        totalSentences: exportData.sentences.length,
        importedAt: DateTime.now(),
      );
      await _projectRepository.saveProject(project);

      // 3. Import sentences with keywords
      for (final sentenceData in exportData.sentences) {
        final sentence = Sentence(
          id: Uuid().v4(),
          projectId: project.id,
          idx: sentenceData.index,
          text: sentenceData.text,
          startTime: sentenceData.startTime,
          endTime: sentenceData.endTime,
          translationEn: sentenceData.translationEn,
          explanationNl: sentenceData.explanationNl,
          explanationEn: sentenceData.explanationEn,
        );
        await _sentenceRepository.saveSentence(sentence);

        for (final keywordData in sentenceData.keywords) {
          final keyword = Keyword(
            id: Uuid().v4(),
            sentenceId: sentence.id,
            word: keywordData.word,
            meaningNl: keywordData.meaningNl,
            meaningEn: keywordData.meaningEn,
          );
          await _keywordRepository.saveKeyword(keyword);
        }
      }

      return Success(project);
    } on Exception catch (e) {
      return Failure(AppException.storage('Import failed: $e'));
    }
  }
}
```

### 2.4 lib/data/

**Purpose:** Data access implementation, external service integration.

| Directory | Contents |
|-----------|----------|
| `models/` | Data transfer objects (JSON serialization) |
| `mappers/` | Model-to-Entity conversion |
| `datasources/local/` | SQLite database operations |
| `datasources/remote/` | Google Drive API calls |
| `repositories/` | Concrete repository implementations |
| `services/` | Platform services (audio, files) |

**Example file - `lib/data/models/project_model.dart`:**

```dart
class ProjectModel {
  final String id;
  final String? sourceId;
  final String name;
  final String status;
  final int totalSentences;
  final String? audioPath;
  final double? audioDuration;
  final String importedAt;
  final String? lastPlayedAt;
  final int? lastSentenceIdx;
  final int? storageSize;

  ProjectModel({
    required this.id,
    this.sourceId,
    required this.name,
    required this.status,
    required this.totalSentences,
    this.audioPath,
    this.audioDuration,
    required this.importedAt,
    this.lastPlayedAt,
    this.lastSentenceIdx,
    this.storageSize,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'],
      sourceId: map['source_id'],
      name: map['name'],
      status: map['status'],
      totalSentences: map['total_sentences'],
      audioPath: map['audio_path'],
      audioDuration: map['audio_duration'],
      importedAt: map['imported_at'],
      lastPlayedAt: map['last_played_at'],
      lastSentenceIdx: map['last_sentence_idx'],
      storageSize: map['storage_size'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_id': sourceId,
      'name': name,
      'status': status,
      'total_sentences': totalSentences,
      'audio_path': audioPath,
      'audio_duration': audioDuration,
      'imported_at': importedAt,
      'last_played_at': lastPlayedAt,
      'last_sentence_idx': lastSentenceIdx,
      'storage_size': storageSize,
    };
  }
}
```

**Example file - `lib/data/datasources/local/database_helper.dart`:**

```dart
class DatabaseHelper {
  static const _databaseName = 'dutch_learn.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabasesPath();
    final dbPath = join(path, _databaseName);

    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
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
        storage_size INTEGER
      )
    ''');

    await db.execute('''
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
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE keywords (
        id TEXT PRIMARY KEY NOT NULL,
        sentence_id TEXT NOT NULL,
        word TEXT NOT NULL,
        meaning_nl TEXT,
        meaning_en TEXT,
        FOREIGN KEY (sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_project_source_id ON projects(source_id)');
    await db.execute('CREATE INDEX idx_sentence_project ON sentences(project_id)');
    await db.execute('CREATE INDEX idx_sentence_project_idx ON sentences(project_id, idx)');
    await db.execute('CREATE INDEX idx_keyword_sentence ON keywords(sentence_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations
  }
}
```

### 2.5 lib/presentation/

**Purpose:** UI layer - screens, widgets, state management.

| Directory | Contents |
|-----------|----------|
| `navigation/` | GoRouter setup, route definitions |
| `theme/` | App theme, colors, text styles |
| `providers/` | Riverpod provider definitions |
| `state/` | Immutable state classes |
| `notifiers/` | StateNotifier implementations |
| `screens/` | Full-page screens with widgets |
| `widgets/` | Reusable widget components |

**Example file - `lib/presentation/providers/core_providers.dart`:**

```dart
// Database
final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

// Services
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (result) => result != ConnectivityResult.none,
  );
});
```

**Example file - `lib/presentation/state/learning_state.dart`:**

```dart
@freezed
class LearningState with _$LearningState {
  const factory LearningState({
    required String projectId,
    Project? project,
    Sentence? currentSentence,
    List<Keyword>? currentKeywords,
    @Default(0) int currentIndex,
    @Default(false) bool isLoading,
    @Default(false) bool isPlaying,
    @Default(false) bool isLooping,
    @Default(1.0) double playbackSpeed,
    @Default(Duration.zero) Duration currentPosition,
    @Default(Duration.zero) Duration totalDuration,
    String? error,
  }) = _LearningState;

  const LearningState._();

  bool get hasNext => project != null && currentIndex < project!.totalSentences - 1;
  bool get hasPrevious => currentIndex > 0;
  bool get hasAudio => project?.hasAudio ?? false;

  String get progressText => project != null
      ? '${currentIndex + 1} / ${project!.totalSentences}'
      : '';
}
```

---

## 3. File Naming Conventions

| Category | Convention | Example |
|----------|------------|---------|
| Dart files | snake_case | `project_repository.dart` |
| Classes | PascalCase | `ProjectRepository` |
| Providers | camelCase + Provider | `projectRepositoryProvider` |
| State classes | PascalCase + State | `LearningState` |
| Notifiers | PascalCase + Notifier | `LearningNotifier` |
| Screens | PascalCase + Screen | `LearningScreen` |
| Widgets | PascalCase | `AudioPlayerBar` |
| Tests | file_test.dart | `project_repository_test.dart` |

---

## 4. Import Organization

Imports should be organized in this order:

```dart
// 1. Dart SDK imports
import 'dart:async';
import 'dart:convert';

// 2. Flutter imports
import 'package:flutter/material.dart';

// 3. Third-party package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

// 4. Project imports - core
import 'package:dutch_learn_app/core/result/result.dart';
import 'package:dutch_learn_app/core/errors/exceptions.dart';

// 5. Project imports - domain
import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';

// 6. Project imports - data
import 'package:dutch_learn_app/data/models/project_model.dart';

// 7. Project imports - presentation
import 'package:dutch_learn_app/presentation/widgets/common/loading_indicator.dart';
```

---

## 5. Feature-Based Alternative Structure

For larger teams or more complex apps, consider feature-based organization:

```
lib/
+-- core/                     # Shared core functionality
+-- features/
|   +-- projects/
|   |   +-- domain/
|   |   +-- data/
|   |   +-- presentation/
|   |
|   +-- learning/
|   |   +-- domain/
|   |   +-- data/
|   |   +-- presentation/
|   |
|   +-- drive/
|   |   +-- domain/
|   |   +-- data/
|   |   +-- presentation/
|   |
|   +-- settings/
|       +-- domain/
|       +-- data/
|       +-- presentation/
|
+-- shared/                   # Shared widgets and utilities
```

For this app, the layer-based structure is recommended due to:
- Small team size
- Moderate complexity
- Shared entities across features
- Easier navigation for developers

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Solution Architect | Initial folder structure |
