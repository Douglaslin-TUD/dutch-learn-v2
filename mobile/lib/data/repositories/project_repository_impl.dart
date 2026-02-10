import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:dutch_learn_app/core/errors/exceptions.dart';
import 'package:dutch_learn_app/core/errors/failures.dart';
import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/data/local/daos/keyword_dao.dart';
import 'package:dutch_learn_app/data/local/daos/project_dao.dart';
import 'package:dutch_learn_app/data/local/daos/sentence_dao.dart';
import 'package:dutch_learn_app/data/local/daos/speaker_dao.dart';
import 'package:dutch_learn_app/data/models/keyword_model.dart';
import 'package:dutch_learn_app/data/models/project_model.dart';
import 'package:dutch_learn_app/data/models/sentence_model.dart';
import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';

/// Implementation of ProjectRepository using SQLite.
class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectDao _projectDao;
  final SentenceDao _sentenceDao;
  final KeywordDao _keywordDao;
  final SpeakerDao _speakerDao;
  final Uuid _uuid;

  ProjectRepositoryImpl({
    required ProjectDao projectDao,
    required SentenceDao sentenceDao,
    required KeywordDao keywordDao,
    required SpeakerDao speakerDao,
    Uuid? uuid,
  })  : _projectDao = projectDao,
        _sentenceDao = sentenceDao,
        _keywordDao = keywordDao,
        _speakerDao = speakerDao,
        _uuid = uuid ?? const Uuid();

  @override
  Future<Result<List<Project>>> getProjects() async {
    try {
      final models = await _projectDao.getAll();
      final projects = models.map((m) => m.toEntity()).toList();
      return Result.success(projects);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to get projects: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<Project>> getProjectById(String id) async {
    try {
      final model = await _projectDao.getById(id);
      if (model == null) {
        return const Result.failure(NotFoundFailure(
          message: 'Project not found',
        ));
      }
      return Result.success(model.toEntity());
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to get project: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<Project>> createProject(Project project) async {
    try {
      final model = ProjectModel.fromEntity(project);
      await _projectDao.insert(model);
      return Result.success(project);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to create project: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<Project>> updateProject(Project project) async {
    try {
      final model = ProjectModel.fromEntity(project);
      await _projectDao.update(model);
      return Result.success(project);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to update project: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> deleteProject(String id) async {
    try {
      // Get project to find audio path
      final project = await _projectDao.getById(id);

      // Delete keywords
      await _keywordDao.deleteByProjectId(id);

      // Delete sentences
      await _sentenceDao.deleteByProjectId(id);

      // Delete project
      await _projectDao.delete(id);

      // Delete audio file if exists
      if (project?.audioPath != null) {
        final audioFile = File(project!.audioPath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }

      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to delete project: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<List<Sentence>>> getSentences(String projectId) async {
    try {
      final sentenceModels = await _sentenceDao.getByProjectId(projectId);

      if (sentenceModels.isEmpty) {
        return const Result.success([]);
      }

      // Get all keywords for these sentences
      final sentenceIds = sentenceModels.map((s) => s.id).toList();
      final keywordMap = await _keywordDao.getBySentenceIds(sentenceIds);

      // Attach keywords to sentences
      final sentences = sentenceModels.map((s) {
        final keywords = keywordMap[s.id]?.map((k) => k.toEntity()).toList() ?? [];
        return s.withKeywords(keywords).toEntity();
      }).toList();

      return Result.success(sentences);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to get sentences: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<Sentence>> getSentenceById(String id) async {
    try {
      final model = await _sentenceDao.getById(id);
      if (model == null) {
        return const Result.failure(NotFoundFailure(
          message: 'Sentence not found',
        ));
      }

      final keywords = await _keywordDao.getBySentenceId(id);
      final sentence = model.withKeywords(
        keywords.map((k) => k.toEntity()).toList(),
      );

      return Result.success(sentence.toEntity());
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to get sentence: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<Sentence>> getSentenceByIndex(
    String projectId,
    int index,
  ) async {
    try {
      final model = await _sentenceDao.getByIndex(projectId, index);
      if (model == null) {
        return const Result.failure(NotFoundFailure(
          message: 'Sentence not found',
        ));
      }

      final keywords = await _keywordDao.getBySentenceId(model.id);
      final sentence = model.withKeywords(
        keywords.map((k) => k.toEntity()).toList(),
      );

      return Result.success(sentence.toEntity());
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to get sentence: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> updateLastPlayed(
    String projectId,
    DateTime lastPlayedAt,
    int lastSentenceIndex,
  ) async {
    try {
      await _projectDao.updateLastPlayed(
        projectId,
        lastPlayedAt,
        lastSentenceIndex,
      );
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to update last played: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<Project>> importProject(
    Map<String, dynamic> jsonData,
    String? audioPath,
  ) async {
    try {
      // Validate JSON structure
      if (!jsonData.containsKey('project') ||
          !jsonData.containsKey('sentences')) {
        throw const ImportException(
          message: 'Invalid JSON format: missing project or sentences',
        );
      }

      // Generate project ID
      final projectId = _uuid.v4();

      // Create project model
      final projectJson = jsonData['project'] as Map<String, dynamic>;
      final sentencesList = jsonData['sentences'] as List<dynamic>;

      final project = ProjectModel(
        id: projectId,
        sourceId: projectJson['id'] as String?,
        name: projectJson['name'] as String? ?? 'Unnamed Project',
        totalSentences: sentencesList.length,
        audioPath: audioPath,
        importedAt: DateTime.now(),
        lastPlayedAt: null,
        lastSentenceIndex: null,
      );

      // Insert project
      await _projectDao.insert(project);

      // Process sentences and keywords
      final sentenceModels = <SentenceModel>[];
      final keywordModels = <KeywordModel>[];
      final sentenceIdMap = <String, String>{}; // remote ID -> local ID

      for (final sentenceJson in sentencesList) {
        final sentenceMap = sentenceJson as Map<String, dynamic>;
        final sentenceId = _uuid.v4();
        final remoteSentenceId = sentenceMap['id'] as String?;
        if (remoteSentenceId != null) {
          sentenceIdMap[remoteSentenceId] = sentenceId;
        }

        final sentence = SentenceModel(
          id: sentenceId,
          projectId: projectId,
          index: sentenceMap['index'] as int? ?? sentenceMap['idx'] as int? ?? sentenceModels.length,
          text: sentenceMap['text'] as String? ?? '',
          startTime: (sentenceMap['start_time'] as num?)?.toDouble() ?? 0.0,
          endTime: (sentenceMap['end_time'] as num?)?.toDouble() ?? 0.0,
          translationEn: sentenceMap['translation_en'] as String?,
          explanationNl: sentenceMap['explanation_nl'] as String?,
          explanationEn: sentenceMap['explanation_en'] as String?,
          learned: sentenceMap['learned'] as bool? ?? false,
          learnCount: sentenceMap['learn_count'] as int? ?? 0,
          speakerId: sentenceMap['speaker_id'] as String?,
          isDifficult: sentenceMap['is_difficult'] as bool? ?? false,
          reviewCount: sentenceMap['review_count'] as int? ?? 0,
          lastReviewed: sentenceMap['last_reviewed'] != null
              ? DateTime.tryParse(sentenceMap['last_reviewed'] as String)
              : null,
        );
        sentenceModels.add(sentence);

        // Process keywords
        final keywords = sentenceMap['keywords'] as List<dynamic>?;
        if (keywords != null) {
          for (final keywordJson in keywords) {
            final keywordMap = keywordJson as Map<String, dynamic>;
            final keyword = KeywordModel(
              id: _uuid.v4(),
              sentenceId: sentenceId,
              word: keywordMap['word'] as String? ?? '',
              meaningNl: keywordMap['meaning_nl'] as String? ?? '',
              meaningEn: keywordMap['meaning_en'] as String? ?? '',
            );
            keywordModels.add(keyword);
          }
        }
      }

      // Also import from top-level keywords (desktop format)
      final topLevelKeywords = jsonData['keywords'] as List<dynamic>? ?? [];
      for (final kData in topLevelKeywords) {
        final kMap = kData as Map<String, dynamic>;
        final remoteSentenceId = kMap['sentence_id'] as String?;
        if (remoteSentenceId == null) continue;
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

      // Batch insert sentences
      await _sentenceDao.insertBatch(sentenceModels);

      // Batch insert keywords
      await _keywordDao.insertBatch(keywordModels);

      return Result.success(project.toEntity());
    } on ImportException catch (e) {
      return Result.failure(ImportFailure(message: e.message));
    } on Exception catch (e) {
      return Result.failure(ImportFailure(
        message: 'Failed to import project: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<bool>> projectExists(String sourceId) async {
    try {
      final exists = await _projectDao.existsBySourceId(sourceId);
      return Result.success(exists);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to check project: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<List<Sentence>>> searchSentences(
    String projectId,
    String query,
  ) async {
    try {
      final models = await _sentenceDao.search(projectId, query);
      final sentences = models.map((m) => m.toEntity()).toList();
      return Result.success(sentences);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to search sentences: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<int>> getSentenceCount(String projectId) async {
    try {
      final count = await _sentenceDao.countByProjectId(projectId);
      return Result.success(count);
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to get sentence count: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<Sentence?>> findSentenceAtPosition(
    String projectId,
    double positionSeconds,
  ) async {
    try {
      final model = await _sentenceDao.findAtPosition(projectId, positionSeconds);
      if (model == null) {
        return const Result.success(null);
      }

      final keywords = await _keywordDao.getBySentenceId(model.id);
      final sentence = model.withKeywords(
        keywords.map((k) => k.toEntity()).toList(),
      );

      return Result.success(sentence.toEntity());
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to find sentence: ${e.toString()}',
      ));
    }
  }

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
      final speakers = await _speakerDao.getByProjectId(projectId);

      return Result.success({
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
      });
    } on Exception catch (e) {
      return Result.failure(DatabaseFailure(
        message: 'Failed to export project: ${e.toString()}',
      ));
    }
  }
}
