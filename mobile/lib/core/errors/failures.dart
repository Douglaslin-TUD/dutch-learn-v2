/// Base failure class for domain layer error handling.
///
/// All failures extend this abstract class to provide consistent
/// error handling across the application.
abstract class Failure {
  /// Human-readable error message for display to users.
  final String message;

  /// Optional error code for programmatic error handling.
  final String? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

/// Failure related to database operations.
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
  });
}

/// Failure related to file system operations.
class FileSystemFailure extends Failure {
  const FileSystemFailure({
    required super.message,
    super.code,
  });
}

/// Failure related to network operations.
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
  });
}

/// Failure related to Google Drive operations.
class GoogleDriveFailure extends Failure {
  const GoogleDriveFailure({
    required super.message,
    super.code,
  });
}

/// Failure related to authentication.
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    required super.message,
    super.code,
  });
}

/// Failure related to JSON parsing or import.
class ImportFailure extends Failure {
  const ImportFailure({
    required super.message,
    super.code,
  });
}

/// Failure related to audio playback.
class AudioFailure extends Failure {
  const AudioFailure({
    required super.message,
    super.code,
  });
}

/// Failure for validation errors.
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code,
  });
}

/// Failure when a resource is not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.message,
    super.code,
  });
}

/// Failure for cache-related operations.
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.code,
  });
}
