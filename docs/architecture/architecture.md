# Flutter Architecture Design Document
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31
**Status:** Approved for Implementation

---

## 1. Architecture Overview

### 1.1 Architecture Pattern: Clean Architecture

The application follows **Clean Architecture** principles, ensuring separation of concerns, testability, and maintainability. The architecture is organized into three main layers with clear dependency rules.

```
+------------------------------------------------------------------+
|                        PRESENTATION LAYER                         |
|  +------------------------------------------------------------+  |
|  |  Screens (Pages)  |  Widgets  |  State Management (Riverpod)|  |
|  +------------------------------------------------------------+  |
+------------------------------------------------------------------+
                              |
                              | depends on
                              v
+------------------------------------------------------------------+
|                          DOMAIN LAYER                             |
|  +------------------------------------------------------------+  |
|  |   Entities   |   Use Cases   |   Repository Interfaces     |  |
|  +------------------------------------------------------------+  |
+------------------------------------------------------------------+
                              |
                              | depends on
                              v
+------------------------------------------------------------------+
|                           DATA LAYER                              |
|  +------------------------------------------------------------+  |
|  | Repository Impl | Data Sources | Models | Mappers          |  |
|  +------------------------------------------------------------+  |
+------------------------------------------------------------------+
                              |
                              v
+------------------------------------------------------------------+
|                        EXTERNAL SERVICES                          |
|  +------------------------------------------------------------+  |
|  | SQLite (sqflite) | Google Drive API | Audio Player | Files |  |
|  +------------------------------------------------------------+  |
+------------------------------------------------------------------+
```

### 1.2 Dependency Rule

Dependencies flow inward only:
- **Presentation** depends on **Domain**
- **Data** depends on **Domain** (implements interfaces)
- **Domain** depends on nothing (pure Dart, no Flutter imports)

### 1.3 Key Principles

| Principle | Application |
|-----------|-------------|
| **Single Responsibility** | Each class has one reason to change |
| **Dependency Inversion** | High-level modules don't depend on low-level modules |
| **Interface Segregation** | Multiple small interfaces over one large interface |
| **Open/Closed** | Open for extension, closed for modification |
| **Testability** | All business logic is testable without Flutter |

---

## 2. Layer Details

### 2.1 Presentation Layer

**Responsibilities:**
- Render UI based on state
- Handle user interactions
- Manage navigation
- Transform domain data for display

**Components:**

```
presentation/
+-- screens/              # Full-page screens
|   +-- home/             # Project list screen
|   +-- learning/         # Main study screen
|   +-- drive/            # Google Drive browser
|   +-- settings/         # App settings
|
+-- widgets/              # Reusable UI components
|   +-- audio_player/     # Audio controls widget
|   +-- sentence_card/    # Sentence display widget
|   +-- keyword_popup/    # Vocabulary popup
|
+-- providers/            # Riverpod providers (state)
|   +-- project_provider.dart
|   +-- audio_provider.dart
|   +-- settings_provider.dart
```

### 2.2 Domain Layer

**Responsibilities:**
- Define business entities (pure Dart classes)
- Define use cases (business operations)
- Define repository interfaces (contracts)

**Components:**

```
domain/
+-- entities/             # Business objects
|   +-- project.dart
|   +-- sentence.dart
|   +-- keyword.dart
|
+-- usecases/             # Business logic
|   +-- import_project.dart
|   +-- get_project_list.dart
|   +-- play_sentence.dart
|
+-- repositories/         # Abstract interfaces
    +-- project_repository.dart
    +-- audio_repository.dart
    +-- settings_repository.dart
```

### 2.3 Data Layer

**Responsibilities:**
- Implement repository interfaces
- Manage data sources (local DB, remote API)
- Handle data transformation (model <-> entity)

**Components:**

```
data/
+-- repositories/         # Concrete implementations
|   +-- project_repository_impl.dart
|   +-- audio_repository_impl.dart
|
+-- datasources/          # Data source abstractions
|   +-- local/
|   |   +-- database_helper.dart
|   |   +-- project_local_datasource.dart
|   +-- remote/
|       +-- google_drive_datasource.dart
|
+-- models/               # Data transfer objects
|   +-- project_model.dart
|   +-- sentence_model.dart
|   +-- keyword_model.dart
|
+-- mappers/              # Model <-> Entity conversion
    +-- project_mapper.dart
```

---

## 3. Component Interaction Diagram

### 3.1 Data Flow: Import Project from Google Drive

```
+-------------+    +------------------+    +-------------------+
|   UI Layer  |    |   Domain Layer   |    |    Data Layer     |
+-------------+    +------------------+    +-------------------+
      |                    |                       |
      |  1. User taps      |                       |
      |     "Import"       |                       |
      |                    |                       |
      +------------------->|                       |
      |   call usecase     |                       |
      |                    |                       |
      |                    |  2. ImportProjectUseCase
      |                    |     executes          |
      |                    |                       |
      |                    +---------------------->|
      |                    |  call repository      |
      |                    |                       |
      |                    |                       |  3. DriveDataSource
      |                    |                       |     downloads file
      |                    |                       |
      |                    |                       |  4. LocalDataSource
      |                    |                       |     saves to SQLite
      |                    |                       |
      |                    |<----------------------+
      |                    |  return Result<Project>
      |                    |                       |
      |<-------------------+                       |
      |  emit new state    |                       |
      |                    |                       |
      |  5. UI updates     |                       |
      |     to show        |                       |
      |     new project    |                       |
      +                    +                       +
```

### 3.2 Data Flow: Play Sentence Audio

```
+-------------+    +------------------+    +-------------------+
|   UI Layer  |    |   Domain Layer   |    |    Data Layer     |
+-------------+    +------------------+    +-------------------+
      |                    |                       |
      |  1. User taps      |                       |
      |     sentence       |                       |
      |                    |                       |
      +------------------->|                       |
      | PlaySentenceUseCase|                       |
      |                    |                       |
      |                    |  2. Get audio path    |
      |                    +---------------------->|
      |                    |  AudioRepository      |
      |                    |                       |
      |                    |<----------------------+
      |                    |  return path          |
      |                    |                       |
      |                    |  3. Seek & play       |
      |                    +---------------------->|
      |                    |  AudioPlayer seek     |
      |                    |  to start_time        |
      |                    |                       |
      |<-------------------+                       |
      |  emit playing state|                       |
      |                    |                       |
      |  4. Audio plays,   |                       |
      |     UI updates     |                       |
      |     progress       |                       |
      +                    +                       +
```

---

## 4. Dependency Injection Strategy

### 4.1 Tool: Riverpod

We use **Riverpod** for both state management and dependency injection. Riverpod provides:
- Compile-time safety
- No BuildContext required
- Easy testing with overrides
- Automatic disposal

### 4.2 Provider Hierarchy

```dart
// Data Sources (lowest level)
final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

final driveDataSourceProvider = Provider<GoogleDriveDataSource>((ref) {
  return GoogleDriveDataSource();
});

// Repositories (depend on data sources)
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final drive = ref.watch(driveDataSourceProvider);
  return ProjectRepositoryImpl(db, drive);
});

// Use Cases (depend on repositories)
final importProjectUseCaseProvider = Provider<ImportProjectUseCase>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return ImportProjectUseCase(repo);
});

// State Notifiers (depend on use cases)
final projectListProvider = StateNotifierProvider<ProjectListNotifier, ProjectListState>((ref) {
  final getProjects = ref.watch(getProjectListUseCaseProvider);
  final importProject = ref.watch(importProjectUseCaseProvider);
  return ProjectListNotifier(getProjects, importProject);
});
```

### 4.3 Scoped Providers

For screen-specific state:

```dart
// Learning screen state (scoped to project ID)
final learningStateProvider = StateNotifierProvider.family<
    LearningNotifier,
    LearningState,
    String  // projectId
>((ref, projectId) {
  final repo = ref.watch(projectRepositoryProvider);
  final audio = ref.watch(audioRepositoryProvider);
  return LearningNotifier(repo, audio, projectId);
});
```

---

## 5. Error Handling Approach

### 5.1 Result Type Pattern

All operations that can fail return a `Result` type:

```dart
// lib/core/result.dart
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);
}

// Usage in use case
class ImportProjectUseCase {
  Future<Result<Project>> execute(String driveFileId) async {
    try {
      final project = await repository.importFromDrive(driveFileId);
      return Success(project);
    } on NetworkException catch (e) {
      return Failure(AppException.network(e.message));
    } on StorageException catch (e) {
      return Failure(AppException.storage(e.message));
    }
  }
}
```

### 5.2 Exception Hierarchy

```dart
// lib/core/exceptions.dart
sealed class AppException implements Exception {
  final String message;
  final String? technicalDetails;

  const AppException(this.message, {this.technicalDetails});

  factory AppException.network(String msg) = NetworkException;
  factory AppException.storage(String msg) = StorageException;
  factory AppException.validation(String msg) = ValidationException;
  factory AppException.audio(String msg) = AudioException;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class StorageException extends AppException {
  const StorageException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class AudioException extends AppException {
  const AudioException(super.message);
}
```

### 5.3 Error Display

```dart
// In StateNotifier
void importProject(String fileId) async {
  state = state.copyWith(isLoading: true);

  final result = await importProjectUseCase.execute(fileId);

  switch (result) {
    case Success(:final data):
      state = state.copyWith(
        isLoading: false,
        projects: [...state.projects, data],
      );
    case Failure(:final exception):
      state = state.copyWith(
        isLoading: false,
        error: _mapExceptionToUserMessage(exception),
      );
  }
}

String _mapExceptionToUserMessage(AppException e) {
  return switch (e) {
    NetworkException() => 'Network error. Please check your connection.',
    StorageException() => 'Could not save data. Please check device storage.',
    ValidationException() => 'Invalid file format. Please check the JSON file.',
    AudioException() => 'Audio playback error. Please try again.',
  };
}
```

---

## 6. State Management Flow

### 6.1 State Flow Diagram

```
+------------------+     +-------------------+     +------------------+
|                  |     |                   |     |                  |
|   User Action    |---->|   StateNotifier   |---->|   Widget Rebuild |
|   (tap, swipe)   |     |   (business logic)|     |   (Consumer)     |
|                  |     |                   |     |                  |
+------------------+     +-------------------+     +------------------+
                               |     ^
                               |     |
                               v     |
                         +-----------+----------+
                         |                      |
                         |   Use Case / Repo    |
                         |   (async operation)  |
                         |                      |
                         +----------------------+
```

### 6.2 Unidirectional Data Flow

1. **User triggers action** (e.g., taps "Next Sentence")
2. **Widget calls method** on StateNotifier via `ref.read()`
3. **StateNotifier processes** action, calls use case if needed
4. **StateNotifier emits** new state
5. **Widgets listening** via `ref.watch()` rebuild with new state

---

## 7. Navigation Architecture

### 7.1 Navigation Pattern: GoRouter

```dart
// lib/presentation/navigation/app_router.dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/learning/:projectId',
        name: 'learning',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return LearningScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: '/drive',
        name: 'drive',
        builder: (context, state) => const DrivePickerScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
```

### 7.2 Navigation Flow

```
+-------------+          +-----------------+          +---------------+
|    Home     |  ---->   |   Drive Picker  |  ---->   |    Import     |
|  (projects) |          |   (browse/dl)   |          |   (progress)  |
+-------------+          +-----------------+          +---------------+
      |                                                      |
      |                                                      |
      v                                                      v
+-------------+          +-----------------+          +---------------+
|  Learning   |  <----   |     Home        |  <----   |    Success    |
|   Screen    |          |   (updated)     |          |   (confirm)   |
+-------------+          +-----------------+          +---------------+
      |
      v
+-------------+
|  Settings   |
|   Screen    |
+-------------+
```

---

## 8. Audio Architecture

### 8.1 Audio Service Pattern

```dart
// lib/data/services/audio_service.dart
class AudioService {
  final AudioPlayer _player;

  // Streams for reactive UI
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // Current state
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  bool get isPlaying => _player.playing;

  // Control methods
  Future<void> load(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setLoopMode(LoopMode mode);

  void dispose();
}
```

### 8.2 Sentence-Based Playback

```dart
// lib/domain/usecases/audio/play_sentence_usecase.dart
class PlaySentenceUseCase {
  final AudioService _audioService;
  final ProjectRepository _projectRepository;

  Future<Result<void>> execute(String projectId, int sentenceIdx) async {
    // 1. Get sentence data
    final sentence = await _projectRepository.getSentence(projectId, sentenceIdx);
    if (sentence == null) {
      return Failure(AppException.validation('Sentence not found'));
    }

    // 2. Seek to start time
    await _audioService.seek(Duration(
      milliseconds: (sentence.startTime * 1000).round()
    ));

    // 3. Play
    await _audioService.play();

    return Success(null);
  }
}
```

### 8.3 Auto-Advance Logic

```dart
// In LearningNotifier
void _setupAudioListeners() {
  _audioService.positionStream.listen((position) {
    final currentSentence = state.currentSentence;
    if (currentSentence == null) return;

    final endTime = Duration(
      milliseconds: (currentSentence.endTime * 1000).round()
    );

    if (position >= endTime) {
      if (state.isLooping) {
        // Loop: seek back to start
        _audioService.seek(Duration(
          milliseconds: (currentSentence.startTime * 1000).round()
        ));
      } else if (state.autoAdvance) {
        // Auto-advance: go to next sentence
        goToNextSentence();
      } else {
        // Stop at end
        _audioService.pause();
      }
    }

    // Update UI state
    state = state.copyWith(currentPosition: position);
  });
}
```

---

## 9. Offline-First Strategy

### 9.1 Data Availability

```
+-------------------+     +-------------------+     +-------------------+
|   Google Drive    |     |    Import Flow    |     |   Local SQLite    |
|   (remote)        | --> |   (one-time)      | --> |   (always used)   |
+-------------------+     +-------------------+     +-------------------+
                               |
                               v
                          +---------+
                          |  Audio  |
                          |  Files  |
                          +---------+
```

### 9.2 Network Requirement Matrix

| Feature | Online Required | Offline Available |
|---------|-----------------|-------------------|
| Browse Google Drive | Yes | No |
| Download files | Yes | No |
| Import JSON | No (local) | Yes |
| View projects | No | Yes |
| Study sentences | No | Yes |
| Play audio | No | Yes |
| Delete project | No | Yes |
| Change settings | No | Yes |

### 9.3 Network Detection

```dart
// lib/core/network/connectivity_service.dart
class ConnectivityService {
  final Connectivity _connectivity;

  Stream<bool> get connectivityStream =>
    _connectivity.onConnectivityChanged
      .map((status) => status != ConnectivityResult.none);

  Future<bool> get isOnline async {
    final status = await _connectivity.checkConnectivity();
    return status != ConnectivityResult.none;
  }
}

// Usage in Drive screen
class DrivePickerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);

    if (!isOnline) {
      return OfflineMessage(
        message: 'Connect to the internet to browse Google Drive',
        action: 'Go to Projects',
        onAction: () => context.go('/'),
      );
    }

    // Show Drive browser
    ...
  }
}
```

---

## 10. Testing Strategy

### 10.1 Test Layers

| Layer | Test Type | Tools | Coverage Target |
|-------|-----------|-------|-----------------|
| Domain | Unit | dart test | 90%+ |
| Data | Unit + Integration | dart test, mockito | 80%+ |
| Presentation | Widget + Integration | flutter_test | 70%+ |
| E2E | Integration | integration_test | Critical paths |

### 10.2 Mocking Strategy

```dart
// Test doubles for repositories
class MockProjectRepository extends Mock implements ProjectRepository {}

// Override in tests
void main() {
  testWidgets('shows projects from repository', (tester) async {
    final mockRepo = MockProjectRepository();
    when(() => mockRepo.getAllProjects())
        .thenAnswer((_) async => [testProject]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: MyApp(),
      ),
    );

    expect(find.text(testProject.name), findsOneWidget);
  });
}
```

---

## 11. Security Considerations

### 11.1 Secure Storage

```dart
// OAuth tokens stored securely
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

class AuthService {
  final FlutterSecureStorage _storage;

  Future<void> saveTokens(AuthTokens tokens) async {
    await _storage.write(key: 'access_token', value: tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: tokens.refreshToken);
  }

  Future<AuthTokens?> getTokens() async {
    final access = await _storage.read(key: 'access_token');
    final refresh = await _storage.read(key: 'refresh_token');
    if (access == null || refresh == null) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }
}
```

### 11.2 File Storage

- Audio files stored in app-private directory (`getApplicationDocumentsDirectory`)
- SQLite database in app-private directory
- No sensitive data in SharedPreferences

---

## 12. Performance Considerations

### 12.1 Lazy Loading

```dart
// Sentences loaded on demand, not all at once
class ProjectRepositoryImpl implements ProjectRepository {
  @override
  Future<Sentence?> getSentence(String projectId, int idx) async {
    // Single query, not loading all sentences
    return _db.querySingle(
      'SELECT * FROM sentences WHERE project_id = ? AND idx = ?',
      [projectId, idx],
    );
  }

  @override
  Stream<Sentence> getSentencesStream(String projectId) {
    // Stream for list view, loads as needed
    return _db.queryStream(
      'SELECT * FROM sentences WHERE project_id = ? ORDER BY idx',
      [projectId],
    ).map((row) => SentenceModel.fromMap(row));
  }
}
```

### 12.2 Memory Management

- Audio player reuses single instance
- Images (if any) use cached_network_image
- Large lists use ListView.builder (lazy rendering)
- Dispose resources in widget lifecycle

### 12.3 Database Optimization

- Indexes on frequently queried columns
- Batch inserts for import operations
- Prepared statements where possible

---

## Appendix A: Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Clean Architecture | Separation of concerns, testability |
| State Management | Riverpod | Type-safe, no context needed, easy testing |
| Navigation | GoRouter | Declarative, deep linking support |
| Database | sqflite | Mature, reliable, good performance |
| Audio | just_audio | Feature-rich, well-maintained |
| HTTP | dio | Interceptors, retry logic |
| DI | Riverpod | Combined with state management |
| Testing | mocktail | Simple syntax, null-safety |

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Solution Architect | Initial architecture design |
