import 'dart:convert';
import 'dart:io';

import 'package:dutch_learn_app/core/utils/file_utils.dart';
import 'package:dutch_learn_app/data/local/daos/keyword_dao.dart';
import 'package:dutch_learn_app/data/local/daos/project_dao.dart';
import 'package:dutch_learn_app/data/local/daos/sentence_dao.dart';
import 'package:dutch_learn_app/data/local/daos/speaker_dao.dart';
import 'package:dutch_learn_app/data/models/keyword_model.dart';
import 'package:dutch_learn_app/data/models/project_model.dart';
import 'package:dutch_learn_app/data/models/sentence_model.dart';
import 'package:dutch_learn_app/data/models/speaker_model.dart';
import 'package:dutch_learn_app/data/services/google_drive_service.dart';
import 'package:uuid/uuid.dart';

/// Service for bidirectional sync between local database and Google Drive.
class SyncService {
  final GoogleDriveService _driveService;
  final ProjectDao _projectDao;
  final SentenceDao _sentenceDao;
  final KeywordDao _keywordDao;
  final SpeakerDao _speakerDao;
  final _uuid = const Uuid();

  SyncService({
    required GoogleDriveService driveService,
    required ProjectDao projectDao,
    required SentenceDao sentenceDao,
    required KeywordDao keywordDao,
    required SpeakerDao speakerDao,
  })  : _driveService = driveService,
        _projectDao = projectDao,
        _sentenceDao = sentenceDao,
        _keywordDao = keywordDao,
        _speakerDao = speakerDao;

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
    final speakers = await _speakerDao.getByProjectId(projectId);

    return {
      'version': '1.0',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'project': {
        'id': project.id,
        'name': project.name,
        'total_sentences': project.totalSentences,
      },
      'speakers': speakers.map((sp) => sp.toJson()).toList(),
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
          'speaker_id': s.speakerId,
          'is_difficult': s.isDifficult,
          'review_count': s.reviewCount,
          'last_reviewed': s.lastReviewed?.toIso8601String(),
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

    // Import speakers
    final speakersList = data['speakers'] as List<dynamic>? ?? [];
    final speakerModels = <SpeakerModel>[];
    final speakerIdMap = <String, String>{}; // remote ID -> local ID

    for (final spData in speakersList) {
      final spMap = spData as Map<String, dynamic>;
      final localSpeakerId = _uuid.v4();
      final remoteId = spMap['id'] as String? ?? '';
      if (remoteId.isNotEmpty) {
        speakerIdMap[remoteId] = localSpeakerId;
      }
      speakerModels.add(SpeakerModel(
        id: localSpeakerId,
        projectId: projectId,
        label: spMap['label'] as String? ?? '',
        displayName: spMap['display_name'] as String?,
        confidence: (spMap['confidence'] as num?)?.toDouble() ?? 0.0,
        evidence: spMap['evidence'] as String?,
        isManual: spMap['is_manual'] as bool? ?? false,
      ));
    }
    if (speakerModels.isNotEmpty) {
      await _speakerDao.insertBatch(speakerModels);
    }

    // Import sentences
    final sentenceModels = <SentenceModel>[];
    final keywordModels = <KeywordModel>[];
    final sentenceIdMap = <String, String>{}; // remote ID -> local ID

    for (final sData in sentencesList) {
      final sMap = sData as Map<String, dynamic>;
      final sentenceId = _uuid.v4();
      final remoteSentenceId = sMap['id'] as String?;
      if (remoteSentenceId != null) {
        sentenceIdMap[remoteSentenceId] = sentenceId;
      }

      // Map remote speaker ID to local speaker ID
      final remoteSpeakerId = sMap['speaker_id'] as String?;
      final localSpeakerId = remoteSpeakerId != null
          ? speakerIdMap[remoteSpeakerId]
          : null;

      sentenceModels.add(SentenceModel(
        id: sentenceId,
        projectId: projectId,
        index: sMap['index'] as int? ?? sMap['idx'] as int? ?? sentenceModels.length,
        text: sMap['text'] as String? ?? '',
        startTime: (sMap['start_time'] as num?)?.toDouble() ?? 0.0,
        endTime: (sMap['end_time'] as num?)?.toDouble() ?? 0.0,
        translationEn: sMap['translation_en'] as String?,
        explanationNl: sMap['explanation_nl'] as String?,
        explanationEn: sMap['explanation_en'] as String?,
        learned: sMap['learned'] as bool? ?? false,
        learnCount: sMap['learn_count'] as int? ?? 0,
        speakerId: localSpeakerId,
        isDifficult: sMap['is_difficult'] as bool? ?? false,
        reviewCount: sMap['review_count'] as int? ?? 0,
        lastReviewed: sMap['last_reviewed'] != null
            ? DateTime.tryParse(sMap['last_reviewed'] as String)
            : null,
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

    // Also import keywords from top-level flat format (desktop compatibility)
    final topLevelKeywords = data['keywords'] as List<dynamic>? ?? [];
    for (final kData in topLevelKeywords) {
      final kMap = kData as Map<String, dynamic>;
      final remoteSentenceId = kMap['sentence_id'] as String?;
      if (remoteSentenceId == null) continue;
      // Map remote sentence_id to local sentence_id
      final localSentenceId = sentenceIdMap[remoteSentenceId];
      if (localSentenceId == null) continue;
      keywordModels.add(KeywordModel(
        id: _uuid.v4(),
        sentenceId: localSentenceId,
        word: kMap['word'] as String? ?? '',
        meaningNl: kMap['meaning_nl'] as String? ?? '',
        meaningEn: kMap['meaning_en'] as String? ?? '',
      ));
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
        await _sentenceDao.updateReviewProgress(
          sentenceId,
          isDifficult: sMap['is_difficult'] as bool? ?? localSentence.isDifficult,
          reviewCount: sMap['review_count'] as int? ?? localSentence.reviewCount,
          lastReviewed: sMap['last_reviewed'] != null
              ? DateTime.tryParse(sMap['last_reviewed'] as String)
              : localSentence.lastReviewed,
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
        mergedS['is_difficult'] = (localS['is_difficult'] as bool? ?? false) ||
            (remoteS['is_difficult'] as bool? ?? false);
        mergedS['review_count'] = _max(
          localS['review_count'] as int? ?? 0,
          remoteS['review_count'] as int? ?? 0,
        );
        final localLR = localS['last_reviewed'] as String?;
        final remoteLR = remoteS['last_reviewed'] as String?;
        if (localLR != null && remoteLR != null) {
          final localDt = DateTime.tryParse(localLR);
          final remoteDt = DateTime.tryParse(remoteLR);
          mergedS['last_reviewed'] = (localDt != null && remoteDt != null && localDt.isAfter(remoteDt))
              ? localLR
              : remoteLR;
        } else {
          mergedS['last_reviewed'] = localLR ?? remoteLR;
        }
        mergedSentences.add(mergedS);
      } else {
        mergedSentences.add(localS ?? remoteS!);
      }
    }

    mergedSentences.sort((a, b) =>
        (a['index'] as int? ?? a['idx'] as int? ?? 0)
            .compareTo(b['index'] as int? ?? b['idx'] as int? ?? 0));

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
