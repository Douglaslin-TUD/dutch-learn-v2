# State Management Design
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31

---

## 1. State Management Choice: Riverpod

### 1.1 Why Riverpod?

| Criteria | Riverpod | Provider | Bloc | GetX |
|----------|----------|----------|------|------|
| Compile-time safety | Yes | No | Partial | No |
| No BuildContext needed | Yes | No | No | Yes |
| Testing/Mocking | Excellent | Good | Good | Poor |
| Boilerplate | Low | Low | High | Low |
| Null safety | Native | Native | Native | Issues |
| Dependency injection | Built-in | Manual | Manual | Built-in |
| Community support | Strong | Strong | Strong | Medium |

**Key reasons for Riverpod:**

1. **Compile-time safety** - Catches errors before runtime
2. **Provider overrides** - Easy mocking for tests
3. **No context required** - Access state anywhere
4. **Auto-dispose** - Automatic resource cleanup
5. **Family modifiers** - Easy parameterized providers
6. **Combined DI + State** - Single solution for both concerns

### 1.2 Riverpod Version

Using Riverpod 2.x with code generation:

```yaml
dependencies:
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

dev_dependencies:
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.7
```

---

## 2. Provider Architecture

### 2.1 Provider Hierarchy

```
+------------------------------------------------------------------+
|                        APPLICATION LAYER                          |
|  (Providers that live for app lifetime)                          |
|------------------------------------------------------------------|
|  databaseProvider  |  audioServiceProvider  |  connectivityProvider|
+------------------------------------------------------------------+
                               |
                               v
+------------------------------------------------------------------+
|                        REPOSITORY LAYER                           |
|  (Providers for data access)                                      |
|------------------------------------------------------------------|
|  projectRepositoryProvider  |  sentenceRepositoryProvider         |
|  keywordRepositoryProvider  |  driveRepositoryProvider            |
+------------------------------------------------------------------+
                               |
                               v
+------------------------------------------------------------------+
|                         USE CASE LAYER                            |
|  (Providers for business logic)                                   |
|------------------------------------------------------------------|
|  importProjectUseCaseProvider  |  deleteProjectUseCaseProvider    |
|  playSentenceUseCaseProvider   |  searchVocabularyUseCaseProvider |
+------------------------------------------------------------------+
                               |
                               v
+------------------------------------------------------------------+
|                          STATE LAYER                              |
|  (StateNotifier providers for UI state)                           |
|------------------------------------------------------------------|
|  projectListProvider  |  learningProvider  |  audioProvider       |
|  driveBrowserProvider |  settingsProvider  |  importProvider      |
+------------------------------------------------------------------+
```

### 2.2 Provider Types Used

| Type | Use Case | Example |
|------|----------|---------|
| `Provider` | Services, repositories, use cases | `databaseProvider` |
| `StateNotifierProvider` | Mutable UI state | `projectListProvider` |
| `StreamProvider` | Reactive streams | `audioPositionProvider` |
| `FutureProvider` | Async initialization | `initialSettingsProvider` |
| `Family` | Parameterized providers | `learningProvider.family` |

---

## 3. Core Providers

### 3.1 Infrastructure Providers

```dart
// lib/presentation/providers/core_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Database singleton
final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

/// Audio player service
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Secure storage for OAuth tokens
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

/// Network connectivity stream
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((result) => result != ConnectivityResult.none);
});

/// Current connectivity status
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
        data: (isOnline) => isOnline,
        orElse: () => true, // Assume online by default
      );
});
```

### 3.2 Repository Providers

```dart
// lib/presentation/providers/repository_providers.dart

/// Project repository
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProjectRepositoryImpl(db);
});

/// Sentence repository
final sentenceRepositoryProvider = Provider<SentenceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SentenceRepositoryImpl(db);
});

/// Keyword repository
final keywordRepositoryProvider = Provider<KeywordRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return KeywordRepositoryImpl(db);
});

/// Google Drive repository
final driveRepositoryProvider = Provider<DriveRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final fileService = ref.watch(fileServiceProvider);
  return DriveRepositoryImpl(storage, fileService);
});

/// Settings repository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsRepositoryImpl(db);
});

/// Audio repository
final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return AudioRepositoryImpl(audioService, projectRepo);
});
```

### 3.3 Use Case Providers

```dart
// lib/presentation/providers/usecase_providers.dart

/// Import project use case
final importProjectUseCaseProvider = Provider<ImportProjectUseCase>((ref) {
  return ImportProjectUseCase(
    ref.watch(projectRepositoryProvider),
    ref.watch(sentenceRepositoryProvider),
    ref.watch(keywordRepositoryProvider),
  );
});

/// Delete project use case
final deleteProjectUseCaseProvider = Provider<DeleteProjectUseCase>((ref) {
  return DeleteProjectUseCase(
    ref.watch(projectRepositoryProvider),
    ref.watch(fileServiceProvider),
  );
});

/// Play sentence use case
final playSentenceUseCaseProvider = Provider<PlaySentenceUseCase>((ref) {
  return PlaySentenceUseCase(
    ref.watch(audioRepositoryProvider),
    ref.watch(sentenceRepositoryProvider),
  );
});

/// Get project list use case
final getProjectListUseCaseProvider = Provider<GetProjectListUseCase>((ref) {
  return GetProjectListUseCase(ref.watch(projectRepositoryProvider));
});
```

---

## 4. State Classes

### 4.1 Project List State

```dart
// lib/presentation/state/project_list_state.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_list_state.freezed.dart';

@freezed
class ProjectListState with _$ProjectListState {
  const factory ProjectListState({
    @Default([]) List<Project> projects,
    @Default(false) bool isLoading,
    @Default(ProjectSort.importedDesc) ProjectSort sortOrder,
    String? searchQuery,
    String? error,
  }) = _ProjectListState;

  const ProjectListState._();

  List<Project> get filteredProjects {
    var result = projects;

    // Apply search filter
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      result = result.where((p) => p.name.toLowerCase().contains(query)).toList();
    }

    // Apply sort
    result = [...result];
    switch (sortOrder) {
      case ProjectSort.importedDesc:
        result.sort((a, b) => b.importedAt.compareTo(a.importedAt));
      case ProjectSort.importedAsc:
        result.sort((a, b) => a.importedAt.compareTo(b.importedAt));
      case ProjectSort.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case ProjectSort.nameDesc:
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    return result;
  }

  bool get isEmpty => projects.isEmpty;
  bool get hasError => error != null;
}

enum ProjectSort { importedDesc, importedAsc, nameAsc, nameDesc }
```

### 4.2 Learning State

```dart
// lib/presentation/state/learning_state.dart

@freezed
class LearningState with _$LearningState {
  const factory LearningState({
    required String projectId,
    Project? project,
    Sentence? currentSentence,
    @Default([]) List<Keyword> currentKeywords,
    @Default(0) int currentIndex,
    @Default(false) bool isLoading,
    @Default(false) bool showTranslation,
    @Default(false) bool showExplanationNl,
    @Default(false) bool showExplanationEn,
    @Default(false) bool showKeywords,
    String? error,
  }) = _LearningState;

  const LearningState._();

  bool get hasProject => project != null;
  bool get hasSentence => currentSentence != null;
  bool get hasAudio => project?.hasAudio ?? false;
  bool get hasKeywords => currentKeywords.isNotEmpty;

  bool get canGoNext => hasProject && currentIndex < project!.totalSentences - 1;
  bool get canGoPrevious => currentIndex > 0;

  String get progressText => hasProject
      ? '${currentIndex + 1} / ${project!.totalSentences}'
      : '';

  double get progressPercent => hasProject && project!.totalSentences > 0
      ? (currentIndex + 1) / project!.totalSentences
      : 0.0;
}
```

### 4.3 Audio State

```dart
// lib/presentation/state/audio_state.dart

@freezed
class AudioState with _$AudioState {
  const factory AudioState({
    @Default(false) bool isPlaying,
    @Default(false) bool isLooping,
    @Default(false) bool isLoading,
    @Default(1.0) double speed,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default(true) bool autoAdvance,
    String? error,
  }) = _AudioState;

  const AudioState._();

  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  String get positionText => _formatDuration(position);
  String get durationText => _formatDuration(duration);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
```

### 4.4 Drive Browser State

```dart
// lib/presentation/state/drive_browser_state.dart

@freezed
class DriveBrowserState with _$DriveBrowserState {
  const factory DriveBrowserState({
    @Default(false) bool isConnected,
    @Default(false) bool isLoading,
    @Default([]) List<DriveFile> files,
    @Default([]) List<String> pathStack, // folder IDs for breadcrumbs
    @Default([]) List<String> pathNames, // folder names for display
    String? currentFolderId,
    DriveFile? selectedFile,
    DownloadProgress? downloadProgress,
    String? error,
  }) = _DriveBrowserState;

  const DriveBrowserState._();

  bool get isRoot => currentFolderId == null || pathStack.isEmpty;
  bool get hasSelection => selectedFile != null;
  bool get isDownloading => downloadProgress != null;

  String get currentPath => pathNames.isEmpty ? 'My Drive' : pathNames.join(' / ');
}

@freezed
class DownloadProgress with _$DownloadProgress {
  const factory DownloadProgress({
    required String fileName,
    required int bytesDownloaded,
    required int totalBytes,
  }) = _DownloadProgress;

  const DownloadProgress._();

  double get percent => totalBytes > 0 ? bytesDownloaded / totalBytes : 0.0;
  String get percentText => '${(percent * 100).toStringAsFixed(0)}%';
}
```

### 4.5 Import State

```dart
// lib/presentation/state/import_state.dart

@freezed
class ImportState with _$ImportState {
  const factory ImportState({
    @Default(ImportPhase.idle) ImportPhase phase,
    @Default(0.0) double progress,
    String? projectName,
    int? sentenceCount,
    Project? importedProject,
    String? error,
  }) = _ImportState;

  const ImportState._();

  bool get isImporting => phase == ImportPhase.importing;
  bool get isComplete => phase == ImportPhase.complete;
  bool get hasError => phase == ImportPhase.error;
  bool get needsAudio => phase == ImportPhase.needsAudio;
}

enum ImportPhase {
  idle,
  validating,
  importing,
  needsAudio,
  linkingAudio,
  complete,
  error,
}
```

---

## 5. StateNotifier Classes

### 5.1 Project List Notifier

```dart
// lib/presentation/notifiers/project_list_notifier.dart

class ProjectListNotifier extends StateNotifier<ProjectListState> {
  final GetProjectListUseCase _getProjects;
  final DeleteProjectUseCase _deleteProject;

  ProjectListNotifier(this._getProjects, this._deleteProject)
      : super(const ProjectListState()) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _getProjects.execute();

    result.when(
      success: (projects) {
        state = state.copyWith(
          isLoading: false,
          projects: projects,
        );
      },
      failure: (exception) {
        state = state.copyWith(
          isLoading: false,
          error: exception.message,
        );
      },
    );
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortOrder(ProjectSort order) {
    state = state.copyWith(sortOrder: order);
  }

  Future<void> deleteProject(String projectId) async {
    final result = await _deleteProject.execute(projectId);

    result.when(
      success: (_) {
        state = state.copyWith(
          projects: state.projects.where((p) => p.id != projectId).toList(),
        );
      },
      failure: (exception) {
        state = state.copyWith(error: exception.message);
      },
    );
  }

  void addProject(Project project) {
    state = state.copyWith(
      projects: [...state.projects, project],
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final projectListProvider =
    StateNotifierProvider<ProjectListNotifier, ProjectListState>((ref) {
  return ProjectListNotifier(
    ref.watch(getProjectListUseCaseProvider),
    ref.watch(deleteProjectUseCaseProvider),
  );
});
```

### 5.2 Learning Notifier

```dart
// lib/presentation/notifiers/learning_notifier.dart

class LearningNotifier extends StateNotifier<LearningState> {
  final ProjectRepository _projectRepository;
  final SentenceRepository _sentenceRepository;
  final KeywordRepository _keywordRepository;
  final AudioNotifier _audioNotifier;

  LearningNotifier(
    this._projectRepository,
    this._sentenceRepository,
    this._keywordRepository,
    this._audioNotifier,
    String projectId,
  ) : super(LearningState(projectId: projectId)) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      // Load project
      final project = await _projectRepository.getProject(state.projectId);
      if (project == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Project not found',
        );
        return;
      }

      // Resume from last position or start at 0
      final startIndex = project.lastSentenceIdx ?? 0;

      state = state.copyWith(
        project: project,
        currentIndex: startIndex,
        isLoading: false,
      );

      // Load first sentence
      await _loadSentence(startIndex);

      // Initialize audio if available
      if (project.hasAudio) {
        await _audioNotifier.loadAudio(project.audioPath!);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load project: $e',
      );
    }
  }

  Future<void> _loadSentence(int index) async {
    final sentence = await _sentenceRepository.getSentence(
      state.projectId,
      index,
    );

    if (sentence == null) {
      state = state.copyWith(error: 'Sentence not found');
      return;
    }

    final keywords = await _keywordRepository.getKeywordsForSentence(
      sentence.id,
    );

    state = state.copyWith(
      currentSentence: sentence,
      currentKeywords: keywords,
      currentIndex: index,
    );

    // Save progress
    await _projectRepository.updateProgress(state.projectId, index);
  }

  Future<void> goToSentence(int index) async {
    if (index < 0 || (state.project != null && index >= state.project!.totalSentences)) {
      return;
    }

    await _loadSentence(index);

    // Seek audio to sentence start
    if (state.hasAudio && state.currentSentence != null) {
      await _audioNotifier.seekToTime(state.currentSentence!.startTime);
    }
  }

  Future<void> goToNextSentence() async {
    if (state.canGoNext) {
      await goToSentence(state.currentIndex + 1);
    }
  }

  Future<void> goToPreviousSentence() async {
    if (state.canGoPrevious) {
      await goToSentence(state.currentIndex - 1);
    }
  }

  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }

  void toggleExplanationNl() {
    state = state.copyWith(showExplanationNl: !state.showExplanationNl);
  }

  void toggleExplanationEn() {
    state = state.copyWith(showExplanationEn: !state.showExplanationEn);
  }

  void toggleKeywords() {
    state = state.copyWith(showKeywords: !state.showKeywords);
  }

  Keyword? findKeywordForWord(String word) {
    return state.currentKeywords.firstWhereOrNull(
      (k) => k.word.toLowerCase() == word.toLowerCase(),
    );
  }
}

// Family provider (parameterized by projectId)
final learningProvider = StateNotifierProvider.family<
    LearningNotifier,
    LearningState,
    String>((ref, projectId) {
  return LearningNotifier(
    ref.watch(projectRepositoryProvider),
    ref.watch(sentenceRepositoryProvider),
    ref.watch(keywordRepositoryProvider),
    ref.watch(audioNotifierProvider.notifier),
    projectId,
  );
});
```

### 5.3 Audio Notifier

```dart
// lib/presentation/notifiers/audio_notifier.dart

class AudioNotifier extends StateNotifier<AudioState> {
  final AudioService _audioService;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  // Callback for sentence boundary detection
  void Function(double currentTime)? onTimeUpdate;

  AudioNotifier(this._audioService) : super(const AudioState()) {
    _setupListeners();
  }

  void _setupListeners() {
    _positionSubscription = _audioService.positionStream.listen((position) {
      state = state.copyWith(position: position);

      // Notify for sentence auto-advance
      onTimeUpdate?.call(position.inMilliseconds / 1000.0);
    });

    _playerStateSubscription = _audioService.playerStateStream.listen((playerState) {
      state = state.copyWith(isPlaying: playerState.playing);

      if (playerState.processingState == ProcessingState.completed) {
        if (state.isLooping) {
          // Loop: handled elsewhere with seek
        } else {
          state = state.copyWith(isPlaying: false);
        }
      }
    });
  }

  Future<void> loadAudio(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _audioService.load(filePath);
      state = state.copyWith(
        isLoading: false,
        duration: _audioService.duration,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load audio: $e',
      );
    }
  }

  Future<void> play() async {
    await _audioService.play();
  }

  Future<void> pause() async {
    await _audioService.pause();
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekToTime(double seconds) async {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    await _audioService.seek(duration);
  }

  Future<void> seekToPosition(Duration position) async {
    await _audioService.seek(position);
  }

  void setSpeed(double speed) {
    _audioService.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  void toggleLoop() {
    state = state.copyWith(isLooping: !state.isLooping);
  }

  void setAutoAdvance(bool value) {
    state = state.copyWith(autoAdvance: value);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}

// Provider
final audioNotifierProvider =
    StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  return AudioNotifier(ref.watch(audioServiceProvider));
});
```

---

## 6. State Flow Diagrams

### 6.1 Project Import Flow

```
+---------------+       +------------------+       +------------------+
| DriveBrowser  |       | ImportNotifier   |       | ProjectList      |
| State         |       | State            |       | Notifier         |
+---------------+       +------------------+       +------------------+
       |                        |                          |
       | 1. User selects        |                          |
       |    JSON file           |                          |
       |                        |                          |
       | 2. Download starts     |                          |
       |    (progress stream)   |                          |
       |                        |                          |
       v                        |                          |
  [downloading]                 |                          |
       |                        |                          |
       | 3. Download complete   |                          |
       +----------------------->|                          |
       |                        |                          |
       |                        | 4. Validate JSON         |
       |                        v                          |
       |                   [validating]                    |
       |                        |                          |
       |                        | 5. Import project        |
       |                        v                          |
       |                   [importing]                     |
       |                        |                          |
       |                        | 6. Import complete       |
       |                        |   (needsAudio or         |
       |                        |    complete)             |
       |                        +------------------------->|
       |                        |                          |
       |                        |           7. Add project |
       |                        |              to list     |
       |                        |                          v
       |                        |              [projects updated]
```

### 6.2 Learning Screen State Flow

```
+---------------+       +------------------+       +------------------+
| Learning      |       | Audio            |       | UI               |
| Notifier      |       | Notifier         |       | (Consumer)       |
+---------------+       +------------------+       +------------------+
       |                        |                          |
       | 1. Initialize          |                          |
       |    load project        |                          |
       |                        |                          |
       | 2. Load audio          |                          |
       +----------------------->|                          |
       |                        |                          |
       | 3. Load sentence       |                          |
       |    & keywords          |                          |
       |                        |                          |
       |<-------------------------------------------+      |
       |           4. User taps play                |      |
       |                        |                   |      |
       +----------------------->|                          |
       |    seek to start_time  |                          |
       |                        |                          |
       |                        | 5. Play audio            |
       |                        +------------------------->|
       |                        |   [isPlaying: true]      |
       |                        |                          |
       |                        | 6. Position updates      |
       |<-----------------------+   (stream)               |
       |   check end_time       |                          |
       |                        |                          |
       | 7. If past end_time    |                          |
       |    and auto-advance:   |                          |
       |    goToNextSentence()  |                          |
       |                        |                          |
       | 8. Update state        |                          |
       +-------------------------------------------------->|
       |                                [sentence changed] |
```

---

## 7. Widget Consumption Patterns

### 7.1 Reading State

```dart
// In a ConsumerWidget
class LearningScreen extends ConsumerWidget {
  final String projectId;

  const LearningScreen({required this.projectId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch state for rebuilds
    final learningState = ref.watch(learningProvider(projectId));
    final audioState = ref.watch(audioNotifierProvider);

    if (learningState.isLoading) {
      return const LoadingIndicator();
    }

    if (learningState.error != null) {
      return ErrorDisplay(
        message: learningState.error!,
        onRetry: () => ref.refresh(learningProvider(projectId)),
      );
    }

    return Column(
      children: [
        // Sentence display
        SentenceDisplay(sentence: learningState.currentSentence!),

        // Audio controls
        AudioPlayerBar(
          isPlaying: audioState.isPlaying,
          position: audioState.position,
          duration: audioState.duration,
          onPlayPause: () => ref.read(audioNotifierProvider.notifier).togglePlayPause(),
          onSeek: (pos) => ref.read(audioNotifierProvider.notifier).seekToPosition(pos),
        ),

        // Navigation
        NavigationControls(
          canGoNext: learningState.canGoNext,
          canGoPrevious: learningState.canGoPrevious,
          progressText: learningState.progressText,
          onNext: () => ref.read(learningProvider(projectId).notifier).goToNextSentence(),
          onPrevious: () => ref.read(learningProvider(projectId).notifier).goToPreviousSentence(),
        ),
      ],
    );
  }
}
```

### 7.2 Triggering Actions

```dart
// Using ref.read for one-time actions
class ProjectCard extends ConsumerWidget {
  final Project project;

  const ProjectCard({required this.project, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(project.name),
        subtitle: Text('${project.totalSentences} sentences'),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _showDeleteDialog(context, ref),
        ),
        onTap: () => context.push('/learning/${project.id}'),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete "${project.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Use ref.read for one-time action
              ref.read(projectListProvider.notifier).deleteProject(project.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
```

### 7.3 Selective Rebuilds

```dart
// Select specific fields to minimize rebuilds
class ProgressIndicator extends ConsumerWidget {
  final String projectId;

  const ProgressIndicator({required this.projectId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuilds when progressText changes
    final progressText = ref.watch(
      learningProvider(projectId).select((s) => s.progressText),
    );

    return Text(progressText);
  }
}
```

---

## 8. Testing with Riverpod

### 8.1 Mocking Providers

```dart
void main() {
  group('ProjectListNotifier', () {
    late MockGetProjectListUseCase mockGetProjects;
    late MockDeleteProjectUseCase mockDeleteProject;

    setUp(() {
      mockGetProjects = MockGetProjectListUseCase();
      mockDeleteProject = MockDeleteProjectUseCase();
    });

    test('loads projects on initialization', () async {
      // Arrange
      when(() => mockGetProjects.execute())
          .thenAnswer((_) async => Success([testProject]));

      // Act
      final container = ProviderContainer(
        overrides: [
          getProjectListUseCaseProvider.overrideWithValue(mockGetProjects),
          deleteProjectUseCaseProvider.overrideWithValue(mockDeleteProject),
        ],
      );

      // Let it initialize
      await Future.delayed(Duration.zero);

      // Assert
      final state = container.read(projectListProvider);
      expect(state.projects, hasLength(1));
      expect(state.projects.first.id, testProject.id);
    });
  });
}
```

### 8.2 Widget Testing

```dart
testWidgets('shows project list', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectListProvider.overrideWith((ref) {
          return MockProjectListNotifier([testProject1, testProject2]);
        }),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );

  expect(find.text(testProject1.name), findsOneWidget);
  expect(find.text(testProject2.name), findsOneWidget);
});
```

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Solution Architect | Initial state management design |
