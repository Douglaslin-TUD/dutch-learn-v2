import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/core/constants/app_constants.dart';
import 'package:dutch_learn_app/domain/repositories/settings_repository.dart';
import 'package:dutch_learn_app/injection_container.dart';

/// State for app settings.
class SettingsState {
  final double playbackSpeed;
  final bool loopEnabled;
  final int loopCount;
  final bool showTranslation;
  final bool showExplanation;
  final bool autoAdvance;
  final double fontSize;
  final ThemeMode themeMode;
  final bool isLoading;

  const SettingsState({
    this.playbackSpeed = 1.0,
    this.loopEnabled = false,
    this.loopCount = 1,
    this.showTranslation = true,
    this.showExplanation = true,
    this.autoAdvance = true,
    this.fontSize = 16.0,
    this.themeMode = ThemeMode.system,
    this.isLoading = false,
  });

  SettingsState copyWith({
    double? playbackSpeed,
    bool? loopEnabled,
    int? loopCount,
    bool? showTranslation,
    bool? showExplanation,
    bool? autoAdvance,
    double? fontSize,
    ThemeMode? themeMode,
    bool? isLoading,
  }) {
    return SettingsState(
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      loopEnabled: loopEnabled ?? this.loopEnabled,
      loopCount: loopCount ?? this.loopCount,
      showTranslation: showTranslation ?? this.showTranslation,
      showExplanation: showExplanation ?? this.showExplanation,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier for managing settings state.
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(const SettingsState()) {
    loadSettings();
  }

  /// Loads all settings from storage.
  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true);

    final speedResult = await _repository.getPlaybackSpeed();
    final loopEnabledResult = await _repository.getLoopEnabled();
    final loopCountResult = await _repository.getLoopCount();
    final showTransResult = await _repository.getShowTranslation();
    final showExplResult = await _repository.getShowExplanation();
    final autoAdvResult = await _repository.getAutoAdvance();
    final fontSizeResult = await _repository.getFontSize();
    final themeModeResult = await _repository.getThemeMode();

    state = SettingsState(
      playbackSpeed: speedResult.valueOrNull ?? AppConstants.defaultPlaybackSpeed,
      loopEnabled: loopEnabledResult.valueOrNull ?? AppConstants.defaultLoopEnabled,
      loopCount: loopCountResult.valueOrNull ?? AppConstants.defaultLoopCount,
      showTranslation: showTransResult.valueOrNull ?? true,
      showExplanation: showExplResult.valueOrNull ?? true,
      autoAdvance: autoAdvResult.valueOrNull ?? true,
      fontSize: fontSizeResult.valueOrNull ?? 16.0,
      themeMode: _themeModeFromInt(themeModeResult.valueOrNull ?? 0),
      isLoading: false,
    );
  }

  ThemeMode _themeModeFromInt(int value) {
    switch (value) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  int _themeModeToInt(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
      case ThemeMode.system:
        return 0;
    }
  }

  /// Sets the playback speed.
  Future<void> setPlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _repository.setPlaybackSpeed(speed);
  }

  /// Sets whether loop is enabled.
  Future<void> setLoopEnabled(bool enabled) async {
    state = state.copyWith(loopEnabled: enabled);
    await _repository.setLoopEnabled(enabled);
  }

  /// Sets the loop count.
  Future<void> setLoopCount(int count) async {
    state = state.copyWith(loopCount: count);
    await _repository.setLoopCount(count);
  }

  /// Sets whether to show translation.
  Future<void> setShowTranslation(bool show) async {
    state = state.copyWith(showTranslation: show);
    await _repository.setShowTranslation(show);
  }

  /// Sets whether to show explanation.
  Future<void> setShowExplanation(bool show) async {
    state = state.copyWith(showExplanation: show);
    await _repository.setShowExplanation(show);
  }

  /// Sets whether to auto-advance.
  Future<void> setAutoAdvance(bool autoAdvance) async {
    state = state.copyWith(autoAdvance: autoAdvance);
    await _repository.setAutoAdvance(autoAdvance);
  }

  /// Sets the font size.
  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    await _repository.setFontSize(size);
  }

  /// Sets the theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repository.setThemeMode(_themeModeToInt(mode));
  }

  /// Resets all settings to defaults.
  Future<void> resetToDefaults() async {
    await _repository.clearAll();
    await loadSettings();
  }
}

/// Provider for settings state.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repository);
});

/// Provider for theme mode.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});
