import 'package:dutch_learn_app/core/utils/result.dart';

/// Repository interface for app settings.
///
/// Defines the contract for storing and retrieving
/// user preferences and settings.
abstract class SettingsRepository {
  /// Gets the playback speed setting.
  Future<Result<double>> getPlaybackSpeed();

  /// Sets the playback speed setting.
  Future<Result<void>> setPlaybackSpeed(double speed);

  /// Gets whether loop mode is enabled.
  Future<Result<bool>> getLoopEnabled();

  /// Sets whether loop mode is enabled.
  Future<Result<void>> setLoopEnabled(bool enabled);

  /// Gets the loop count setting.
  Future<Result<int>> getLoopCount();

  /// Sets the loop count setting.
  Future<Result<void>> setLoopCount(int count);

  /// Gets whether to show translations by default.
  Future<Result<bool>> getShowTranslation();

  /// Sets whether to show translations by default.
  Future<Result<void>> setShowTranslation(bool show);

  /// Gets whether to show explanations by default.
  Future<Result<bool>> getShowExplanation();

  /// Sets whether to show explanations by default.
  Future<Result<void>> setShowExplanation(bool show);

  /// Gets whether to auto-advance to next sentence.
  Future<Result<bool>> getAutoAdvance();

  /// Sets whether to auto-advance to next sentence.
  Future<Result<void>> setAutoAdvance(bool autoAdvance);

  /// Gets the font size setting.
  Future<Result<double>> getFontSize();

  /// Sets the font size setting.
  Future<Result<void>> setFontSize(double size);

  /// Gets the theme mode (0=system, 1=light, 2=dark).
  Future<Result<int>> getThemeMode();

  /// Sets the theme mode.
  Future<Result<void>> setThemeMode(int mode);

  /// Gets the last opened project ID.
  Future<Result<String?>> getLastProjectId();

  /// Sets the last opened project ID.
  Future<Result<void>> setLastProjectId(String? projectId);

  /// Clears all settings.
  Future<Result<void>> clearAll();
}
