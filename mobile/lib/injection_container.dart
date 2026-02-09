import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dutch_learn_app/data/local/database.dart';
import 'package:dutch_learn_app/data/local/daos/keyword_dao.dart';
import 'package:dutch_learn_app/data/local/daos/project_dao.dart';
import 'package:dutch_learn_app/data/local/daos/sentence_dao.dart';
import 'package:dutch_learn_app/data/local/daos/speaker_dao.dart';
import 'package:dutch_learn_app/data/repositories/google_drive_repository_impl.dart';
import 'package:dutch_learn_app/data/repositories/project_repository_impl.dart';
import 'package:dutch_learn_app/data/repositories/settings_repository_impl.dart';
import 'package:dutch_learn_app/data/services/audio_service.dart';
import 'package:dutch_learn_app/data/services/google_drive_service.dart';
import 'package:dutch_learn_app/data/services/sync_service.dart';
import 'package:dutch_learn_app/domain/repositories/google_drive_repository.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';
import 'package:dutch_learn_app/domain/repositories/settings_repository.dart';

/// Provider for SharedPreferences instance.
///
/// Must be overridden in main.dart with the actual instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main');
});

/// Provider for AppDatabase instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Provider for ProjectDao.
final projectDaoProvider = Provider<ProjectDao>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return ProjectDao(database);
});

/// Provider for SentenceDao.
final sentenceDaoProvider = Provider<SentenceDao>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return SentenceDao(database);
});

/// Provider for KeywordDao.
final keywordDaoProvider = Provider<KeywordDao>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return KeywordDao(database);
});

/// Provider for SpeakerDao.
final speakerDaoProvider = Provider<SpeakerDao>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return SpeakerDao(database);
});

/// Provider for GoogleDriveService.
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

/// Provider for AudioService.
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

/// Provider for ProjectRepository.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final projectDao = ref.watch(projectDaoProvider);
  final sentenceDao = ref.watch(sentenceDaoProvider);
  final keywordDao = ref.watch(keywordDaoProvider);

  return ProjectRepositoryImpl(
    projectDao: projectDao,
    sentenceDao: sentenceDao,
    keywordDao: keywordDao,
  );
});

/// Provider for GoogleDriveRepository.
final googleDriveRepositoryProvider = Provider<GoogleDriveRepository>((ref) {
  final driveService = ref.watch(googleDriveServiceProvider);
  return GoogleDriveRepositoryImpl(driveService: driveService);
});

/// Provider for SettingsRepository.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepositoryImpl(prefs: prefs);
});

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
