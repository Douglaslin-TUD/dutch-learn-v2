import 'package:shared_preferences/shared_preferences.dart';

import 'package:dutch_learn_app/core/constants/app_constants.dart';
import 'package:dutch_learn_app/core/errors/failures.dart';
import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/repositories/settings_repository.dart';

/// Implementation of SettingsRepository using SharedPreferences.
class SettingsRepositoryImpl implements SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepositoryImpl({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  @override
  Future<Result<double>> getPlaybackSpeed() async {
    try {
      final speed = _prefs.getDouble(AppConstants.prefKeyPlaybackSpeed) ??
          AppConstants.defaultPlaybackSpeed;
      return Result.success(speed);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get playback speed: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setPlaybackSpeed(double speed) async {
    try {
      await _prefs.setDouble(AppConstants.prefKeyPlaybackSpeed, speed);
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set playback speed: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<bool>> getLoopEnabled() async {
    try {
      final enabled = _prefs.getBool(AppConstants.prefKeyLoopEnabled) ??
          AppConstants.defaultLoopEnabled;
      return Result.success(enabled);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get loop enabled: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setLoopEnabled(bool enabled) async {
    try {
      await _prefs.setBool(AppConstants.prefKeyLoopEnabled, enabled);
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set loop enabled: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<int>> getLoopCount() async {
    try {
      final count = _prefs.getInt(AppConstants.prefKeyLoopCount) ??
          AppConstants.defaultLoopCount;
      return Result.success(count);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get loop count: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setLoopCount(int count) async {
    try {
      await _prefs.setInt(AppConstants.prefKeyLoopCount, count);
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set loop count: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<bool>> getShowTranslation() async {
    try {
      final show = _prefs.getBool(AppConstants.prefKeyShowTranslation) ?? true;
      return Result.success(show);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get show translation: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setShowTranslation(bool show) async {
    try {
      await _prefs.setBool(AppConstants.prefKeyShowTranslation, show);
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set show translation: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<bool>> getShowExplanation() async {
    try {
      final show = _prefs.getBool(AppConstants.prefKeyShowExplanation) ?? true;
      return Result.success(show);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get show explanation: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setShowExplanation(bool show) async {
    try {
      await _prefs.setBool(AppConstants.prefKeyShowExplanation, show);
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set show explanation: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<bool>> getAutoAdvance() async {
    try {
      final autoAdvance =
          _prefs.getBool(AppConstants.prefKeyAutoAdvance) ?? true;
      return Result.success(autoAdvance);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get auto advance: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setAutoAdvance(bool autoAdvance) async {
    try {
      await _prefs.setBool(AppConstants.prefKeyAutoAdvance, autoAdvance);
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set auto advance: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<double>> getFontSize() async {
    try {
      final size = _prefs.getDouble(AppConstants.prefKeyFontSize) ?? 16.0;
      return Result.success(size);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get font size: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setFontSize(double size) async {
    try {
      await _prefs.setDouble(AppConstants.prefKeyFontSize, size);
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set font size: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<int>> getThemeMode() async {
    try {
      final mode = _prefs.getInt(AppConstants.prefKeyThemeMode) ?? 0;
      return Result.success(mode);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get theme mode: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setThemeMode(int mode) async {
    try {
      await _prefs.setInt(AppConstants.prefKeyThemeMode, mode);
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set theme mode: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<String?>> getLastProjectId() async {
    try {
      final projectId = _prefs.getString(AppConstants.prefKeyLastProjectId);
      return Result.success(projectId);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to get last project id: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> setLastProjectId(String? projectId) async {
    try {
      if (projectId == null) {
        await _prefs.remove(AppConstants.prefKeyLastProjectId);
      } else {
        await _prefs.setString(AppConstants.prefKeyLastProjectId, projectId);
      }
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to set last project id: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> clearAll() async {
    try {
      await _prefs.clear();
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(CacheFailure(
        message: 'Failed to clear settings: ${e.toString()}',
      ));
    }
  }
}
