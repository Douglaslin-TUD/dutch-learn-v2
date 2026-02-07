/// Application-wide constants.
///
/// Contains all constant values used throughout the application
/// for consistent configuration.
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Dutch Learn';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'dutch_learn.db';
  static const int databaseVersion = 2;

  // Audio Settings
  static const double defaultPlaybackSpeed = 1.0;
  static const double minPlaybackSpeed = 0.5;
  static const double maxPlaybackSpeed = 2.0;
  static const double playbackSpeedStep = 0.25;
  static const List<double> playbackSpeedOptions = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  // Loop Settings
  static const bool defaultLoopEnabled = false;
  static const int defaultLoopCount = 1;
  static const int maxLoopCount = 10;

  // UI Settings
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 8.0;

  // UI Sizes
  static const double emptyStateIconSize = 80.0;
  static const double dialogMaxWidth = 400.0;
  static const double playPauseButtonSize = 64.0;
  static const double progressIndicatorSize = 16.0;
  static const double signInIconSize = 80.0;

  // Animation
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 350);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Google Drive
  static const List<String> googleDriveScopes = [
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/drive.file',
  ];
  static const String googleDriveJsonMimeType = 'application/json';
  static const String googleDriveMp3MimeType = 'audio/mpeg';

  // File Extensions
  static const String jsonExtension = '.json';
  static const String mp3Extension = '.mp3';
  static const String audioExtension = '.mp3';

  // Import
  static const String importJsonVersion = '1.0';
  static const int maxImportFileSize = 100 * 1024 * 1024; // 100 MB

  // Preferences Keys
  static const String prefKeyPlaybackSpeed = 'playback_speed';
  static const String prefKeyLoopEnabled = 'loop_enabled';
  static const String prefKeyLoopCount = 'loop_count';
  static const String prefKeyThemeMode = 'theme_mode';
  static const String prefKeyLastProjectId = 'last_project_id';
  static const String prefKeyShowTranslation = 'show_translation';
  static const String prefKeyShowExplanation = 'show_explanation';
  static const String prefKeyAutoAdvance = 'auto_advance';
  static const String prefKeyFontSize = 'font_size';
}

/// Error message constants.
class ErrorMessages {
  ErrorMessages._();

  // General
  static const String unknownError = 'An unknown error occurred';
  static const String networkError = 'Network connection failed';
  static const String timeoutError = 'Operation timed out';

  // Database
  static const String databaseOpenError = 'Failed to open database';
  static const String databaseWriteError = 'Failed to write to database';
  static const String databaseReadError = 'Failed to read from database';

  // Google Drive
  static const String driveAuthError = 'Failed to authenticate with Google';
  static const String driveListError = 'Failed to list files from Google Drive';
  static const String driveDownloadError = 'Failed to download file';
  static const String drivePermissionError = 'Permission denied for Google Drive';

  // Import
  static const String invalidJsonError = 'Invalid JSON format';
  static const String missingFieldError = 'Required field is missing';
  static const String versionMismatchError = 'Unsupported file version';
  static const String importFailedError = 'Failed to import project';

  // Audio
  static const String audioLoadError = 'Failed to load audio file';
  static const String audioPlayError = 'Failed to play audio';
  static const String audioFileNotFound = 'Audio file not found';

  // Project
  static const String projectNotFound = 'Project not found';
  static const String projectDeleteError = 'Failed to delete project';
}
