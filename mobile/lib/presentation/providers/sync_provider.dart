import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/core/utils/file_utils.dart';
import 'package:dutch_learn_app/domain/entities/drive_file.dart';
import 'package:dutch_learn_app/domain/repositories/google_drive_repository.dart';
import 'package:dutch_learn_app/injection_container.dart';
import 'package:dutch_learn_app/presentation/providers/project_provider.dart';

/// State for sync screen.
class SyncState {
  final bool isSignedIn;
  final String? userEmail;
  final List<DriveFile> files;
  final List<DriveFile> folderStack;
  final String? currentFolderId;
  final bool isLoading;
  final bool isDownloading;
  final bool isSyncing;
  final double downloadProgress;
  final double syncProgress;
  final String? syncStatus;
  final String? error;
  final String? successMessage;

  const SyncState({
    this.isSignedIn = false,
    this.userEmail,
    this.files = const [],
    this.folderStack = const [],
    this.currentFolderId,
    this.isLoading = false,
    this.isDownloading = false,
    this.isSyncing = false,
    this.downloadProgress = 0,
    this.syncProgress = 0,
    this.syncStatus,
    this.error,
    this.successMessage,
  });

  SyncState copyWith({
    bool? isSignedIn,
    String? userEmail,
    List<DriveFile>? files,
    List<DriveFile>? folderStack,
    String? currentFolderId,
    bool? isLoading,
    bool? isDownloading,
    bool? isSyncing,
    double? downloadProgress,
    double? syncProgress,
    String? syncStatus,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearFolder = false,
    bool clearSyncStatus = false,
  }) {
    return SyncState(
      isSignedIn: isSignedIn ?? this.isSignedIn,
      userEmail: userEmail ?? this.userEmail,
      files: files ?? this.files,
      folderStack: folderStack ?? this.folderStack,
      currentFolderId: clearFolder ? null : (currentFolderId ?? this.currentFolderId),
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      isSyncing: isSyncing ?? this.isSyncing,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      syncProgress: syncProgress ?? this.syncProgress,
      syncStatus: clearSyncStatus ? null : (syncStatus ?? this.syncStatus),
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  /// Gets the current folder name.
  String get currentFolderName {
    if (folderStack.isEmpty) return 'My Drive';
    return folderStack.last.name;
  }

  /// Gets folders from the current file list.
  List<DriveFile> get folders =>
      files.where((f) => f.isFolder).toList();

  /// Gets JSON files from the current file list.
  List<DriveFile> get jsonFiles =>
      files.where((f) => f.isJson).toList();

  /// Gets audio files from the current file list.
  List<DriveFile> get audioFiles =>
      files.where((f) => f.isAudio).toList();
}

/// Notifier for managing sync state.
class SyncNotifier extends StateNotifier<SyncState> {
  final GoogleDriveRepository _driveRepository;
  final Ref _ref;

  SyncNotifier(this._driveRepository, this._ref) : super(const SyncState()) {
    checkSignInStatus();
  }

  @override
  void dispose() {
    // Cancel any pending operations
    super.dispose();
  }

  /// Returns true if running on desktop platform.
  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  /// Checks if the user is signed in.
  Future<void> checkSignInStatus() async {
    // Skip Google Sign-In check on desktop platforms (not supported)
    if (_isDesktop) return;

    final result = await _driveRepository.isSignedIn();
    result.fold(
      onSuccess: (signedIn) async {
        if (signedIn) {
          final emailResult = await _driveRepository.getCurrentUserEmail();
          emailResult.fold(
            onSuccess: (email) {
              state = state.copyWith(isSignedIn: true, userEmail: email);
              loadFiles();
            },
            onFailure: (_) {
              state = state.copyWith(isSignedIn: true);
              loadFiles();
            },
          );
        }
      },
      onFailure: (_) {},
    );
  }

  /// Signs in to Google.
  Future<void> signIn() async {
    // Show helpful message on desktop platforms
    if (_isDesktop) {
      state = state.copyWith(
        error: 'Google Sign-In is not available on desktop. Please use "Import from Local Folder" below.',
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _driveRepository.signIn();

    result.fold(
      onSuccess: (_) async {
        final emailResult = await _driveRepository.getCurrentUserEmail();
        emailResult.fold(
          onSuccess: (email) {
            state = state.copyWith(
              isSignedIn: true,
              userEmail: email,
              isLoading: false,
            );
            loadFiles();
          },
          onFailure: (_) {
            state = state.copyWith(isSignedIn: true, isLoading: false);
            loadFiles();
          },
        );
      },
      onFailure: (failure) {
        state = state.copyWith(error: failure.message, isLoading: false);
      },
    );
  }

  /// Signs out of Google.
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);

    final result = await _driveRepository.signOut();

    result.fold(
      onSuccess: (_) {
        state = const SyncState();
      },
      onFailure: (failure) {
        state = state.copyWith(error: failure.message, isLoading: false);
      },
    );
  }

  /// Loads files from the current folder.
  Future<void> loadFiles() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _driveRepository.listFiles(
      folderId: state.currentFolderId,
    );

    result.fold(
      onSuccess: (files) {
        state = state.copyWith(files: files, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(error: failure.message, isLoading: false);
      },
    );
  }

  /// Navigates into a folder.
  Future<void> openFolder(DriveFile folder) async {
    state = state.copyWith(
      currentFolderId: folder.id,
      folderStack: [...state.folderStack, folder],
    );
    await loadFiles();
  }

  /// Navigates to the parent folder.
  Future<void> goBack() async {
    if (state.folderStack.isEmpty) return;

    final newStack = List<DriveFile>.from(state.folderStack)..removeLast();
    state = state.copyWith(
      currentFolderId: newStack.isEmpty ? null : newStack.last.id,
      folderStack: newStack,
      clearFolder: newStack.isEmpty,
    );
    await loadFiles();
  }

  /// Navigates to a specific folder in the stack.
  Future<void> goToFolder(int index) async {
    if (index < 0) {
      // Go to root
      state = state.copyWith(
        clearFolder: true,
        folderStack: [],
      );
    } else if (index < state.folderStack.length) {
      final newStack = state.folderStack.sublist(0, index + 1);
      state = state.copyWith(
        currentFolderId: newStack.last.id,
        folderStack: newStack,
      );
    }
    await loadFiles();
  }

  /// Downloads and imports a JSON file with optional audio.
  Future<bool> importProject(DriveFile jsonFile, {DriveFile? audioFile}) async {
    state = state.copyWith(
      isDownloading: true,
      downloadProgress: 0,
      clearError: true,
      clearSuccess: true,
    );

    try {
      // Download JSON
      final jsonResult = await _driveRepository.downloadJson(jsonFile.id);

      if (jsonResult.isFailure) {
        state = state.copyWith(
          error: jsonResult.failureOrNull?.message ?? 'Failed to download JSON',
          isDownloading: false,
        );
        return false;
      }

      final jsonData = jsonResult.valueOrNull!;
      String? audioPath;

      // Download audio if provided
      if (audioFile != null) {
        state = state.copyWith(downloadProgress: 0.3);

        final audioDir = await FileUtils.getAudioDirectoryPath();
        audioPath = FileUtils.joinPath(audioDir, audioFile.name);

        final audioResult = await _driveRepository.downloadFileWithProgress(
          audioFile.id,
          audioPath,
          (progress) {
            state = state.copyWith(
              downloadProgress: 0.3 + (progress * 0.6),
            );
          },
        );

        if (audioResult.isFailure) {
          state = state.copyWith(
            error: audioResult.failureOrNull?.message ?? 'Failed to download audio',
            isDownloading: false,
          );
          return false;
        }

        audioPath = audioResult.valueOrNull;
      }

      state = state.copyWith(downloadProgress: 0.9);

      // Import project
      final projectNotifier = _ref.read(projectListProvider.notifier);
      final project = await projectNotifier.importProject(jsonData, audioPath);

      if (project == null) {
        state = state.copyWith(
          error: 'Failed to import project',
          isDownloading: false,
        );
        return false;
      }

      state = state.copyWith(
        isDownloading: false,
        downloadProgress: 1.0,
        successMessage: 'Successfully imported "${project.name}"',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Import failed: $e',
        isDownloading: false,
      );
      return false;
    }
  }

  /// Imports a project from local files (for desktop).
  Future<bool> importLocalProject(File jsonFile, {File? audioFile}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      // Read JSON file
      final jsonString = await jsonFile.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      String? audioPath;

      // Copy audio file if provided
      if (audioFile != null) {
        final audioDir = await FileUtils.getAudioDirectoryPath();
        audioPath = FileUtils.joinPath(audioDir, audioFile.uri.pathSegments.last);

        // Copy the file
        await audioFile.copy(audioPath);
      }

      // Import project
      final projectNotifier = _ref.read(projectListProvider.notifier);
      final project = await projectNotifier.importProject(jsonData, audioPath);

      if (project == null) {
        state = state.copyWith(
          error: 'Failed to import project',
          isLoading: false,
        );
        return false;
      }

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully imported "${project.name}"',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Import failed: $e',
        isLoading: false,
      );
      return false;
    }
  }

  /// Performs bidirectional sync with Google Drive.
  Future<void> performSync() async {
    if (!state.isSignedIn) {
      state = state.copyWith(error: 'Please sign in to sync');
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      syncProgress: 0,
      syncStatus: 'Starting sync...',
      clearError: true,
      clearSuccess: true,
    );

    try {
      // Upload local changes
      state = state.copyWith(
        syncStatus: 'Uploading local projects...',
        syncProgress: 0.1,
      );

      await _uploadLocalProjects();

      // Download remote changes
      state = state.copyWith(
        syncStatus: 'Downloading remote projects...',
        syncProgress: 0.5,
      );

      await _downloadAndMergeProjects();

      state = state.copyWith(
        isSyncing: false,
        syncProgress: 1.0,
        syncStatus: null,
        successMessage: 'Sync completed successfully',
      );

      // Refresh project list
      _ref.read(projectListProvider.notifier).loadProjects();
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        syncStatus: null,
        error: 'Sync failed: $e',
      );
    }
  }

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

  /// Clears error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clears success message.
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }
}

/// Provider for sync state.
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final driveRepository = ref.watch(googleDriveRepositoryProvider);
  return SyncNotifier(driveRepository, ref);
});
