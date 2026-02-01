import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:dutch_learn_app/data/local/database.dart';
import 'package:dutch_learn_app/data/services/google_drive_service.dart';
import 'package:dutch_learn_app/domain/entities/project.dart';

/// Service for bidirectional sync between local database and Google Drive.
class SyncService {
  final GoogleDriveService _driveService;
  final AppDatabase _database;

  SyncService({
    required GoogleDriveService driveService,
    required AppDatabase database,
  })  : _driveService = driveService,
        _database = database;

  /// Performs full bidirectional sync.
  /// Returns a summary of sync results.
  Future<SyncResult> performSync({
    void Function(String status, double progress)? onProgress,
  }) async {
    final result = SyncResult();

    try {
      onProgress?.call('Uploading local changes...', 0.1);

      // Upload local projects
      final uploadResult = await uploadLocalProjects(
        onProgress: (p) => onProgress?.call('Uploading...', 0.1 + p * 0.4),
      );
      result.uploaded = uploadResult.uploaded;
      result.uploadErrors = uploadResult.errors;

      onProgress?.call('Downloading remote changes...', 0.5);

      // Download remote projects
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
      // Get projects from local database
      final projectDao = _database.projectDao;
      final projects = await projectDao.getAllProjects();

      final filteredProjects = projectIds != null
          ? projects.where((p) => projectIds.contains(p.id)).toList()
          : projects;

      for (var i = 0; i < filteredProjects.length; i++) {
        final project = filteredProjects[i];

        try {
          // Export project to JSON
          final exportData = await _exportProject(project.id);
          final jsonContent = jsonEncode(exportData);

          // Get audio file path
          final appDir = await getApplicationDocumentsDirectory();
          final audioFile = File('${appDir.path}/audio/${project.id}.mp3');

          // Upload to Drive
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
      // Get Dutch Learn folder
      final dutchLearnFolderId = await _driveService.getOrCreateDutchLearnFolder();

      // List project folders
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
          // List files in project folder
          final files = await _driveService.listFiles(folderId: folderId);

          // Find project.json
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

          // Download project.json
          final jsonBytes = await _driveService.downloadFile(jsonFile['id'] as String);
          final jsonString = utf8.decode(jsonBytes);
          final remoteData = jsonDecode(jsonString) as Map<String, dynamic>;

          // Check if project exists locally
          final localProject = await _database.projectDao.getProjectById(projectId);

          if (localProject != null) {
            // Merge progress
            final localData = await _exportProject(projectId);
            final mergedData = ProgressMerger.merge(localData, remoteData);
            await _importProject(mergedData);
            result.merged.add(projectId);
          } else {
            // New project - import entirely
            await _importProject(remoteData);

            // Download audio if available
            final audioFile = files.firstWhere(
              (f) => f['name'] == 'audio.mp3',
              orElse: () => <String, dynamic>{},
            );

            if (audioFile.isNotEmpty) {
              final audioBytes = await _driveService.downloadFile(audioFile['id'] as String);
              final appDir = await getApplicationDocumentsDirectory();
              final audioDir = Directory('${appDir.path}/audio');
              if (!audioDir.existsSync()) {
                audioDir.createSync(recursive: true);
              }
              final audioPath = File('${audioDir.path}/$projectId.mp3');
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
  Future<Map<String, dynamic>> _exportProject(String projectId) async {
    final project = await _database.projectDao.getProjectById(projectId);
    if (project == null) {
      throw Exception('Project not found: $projectId');
    }

    final sentences = await _database.sentenceDao.getSentencesByProjectId(projectId);
    final keywords = await _database.keywordDao.getKeywordsByProjectId(projectId);

    return {
      'id': project.id,
      'name': project.name,
      'status': project.status,
      'created_at': project.createdAt?.toIso8601String(),
      'updated_at': project.updatedAt?.toIso8601String(),
      'sentences': sentences.map((s) => {
        'id': s.id,
        'order': s.order,
        'text': s.text,
        'start_time': s.startTime,
        'end_time': s.endTime,
        'translation': s.translation,
        'explanation': s.explanation,
        'learned': s.learned,
        'learn_count': s.learnCount,
      }).toList(),
      'keywords': keywords.map((k) => {
        'id': k.id,
        'word': k.word,
        'translation': k.translation,
        'explanation': k.explanation,
        'sentence_id': k.sentenceId,
      }).toList(),
      'progress': {
        'total_sentences': sentences.length,
        'learned_sentences': sentences.where((s) => s.learned).length,
        'last_sync': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }

  /// Imports a project from a map.
  Future<void> _importProject(Map<String, dynamic> data) async {
    final projectId = data['id'] as String;

    // Create or update project
    final existingProject = await _database.projectDao.getProjectById(projectId);

    if (existingProject == null) {
      // Create new project
      final project = Project(
        id: projectId,
        name: data['name'] as String? ?? projectId,
        status: data['status'] as String? ?? 'completed',
        createdAt: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now(),
        updatedAt: DateTime.now(),
        sentenceCount: 0,
      );
      await _database.projectDao.insertProject(project);
    }

    // Update sentences
    final sentences = data['sentences'] as List<dynamic>? ?? [];
    for (final sData in sentences) {
      final sentenceId = sData['id'] as String;
      final existingSentence = await _database.sentenceDao.getSentenceById(sentenceId);

      if (existingSentence != null) {
        // Update learning progress
        await _database.sentenceDao.updateLearningProgress(
          sentenceId,
          learned: sData['learned'] as bool? ?? existingSentence.learned,
          learnCount: sData['learn_count'] as int? ?? existingSentence.learnCount,
        );
      } else {
        // Insert new sentence
        await _database.sentenceDao.insertSentenceFromMap(projectId, sData as Map<String, dynamic>);
      }
    }

    // Update keywords (keywords don't have learning progress)
    final keywords = data['keywords'] as List<dynamic>? ?? [];
    for (final kData in keywords) {
      final keywordId = kData['id'] as String;
      final existingKeyword = await _database.keywordDao.getKeywordById(keywordId);

      if (existingKeyword == null) {
        await _database.keywordDao.insertKeywordFromMap(projectId, kData as Map<String, dynamic>);
      }
    }
  }
}

/// Merges learning progress from local and remote data.
class ProgressMerger {
  /// Merges local and remote project data.
  /// Uses max strategy for learning progress.
  static Map<String, dynamic> merge(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = Map<String, dynamic>.from(local);

    // Merge sentences
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
        // Merge: use max values for learning progress
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

    // Sort by order
    mergedSentences.sort((a, b) =>
        (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0));

    merged['sentences'] = mergedSentences;

    // Recalculate progress
    merged['progress'] = {
      'total_sentences': mergedSentences.length,
      'learned_sentences':
          mergedSentences.where((s) => s['learned'] == true).length,
      'last_sync': DateTime.now().toUtc().toIso8601String(),
    };

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
