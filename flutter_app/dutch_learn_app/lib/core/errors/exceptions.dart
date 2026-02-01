/// Base exception class for data layer error handling.
///
/// All exceptions extend this abstract class to provide consistent
/// error handling in the data layer before converting to failures.
abstract class AppException implements Exception {
  /// Error message describing what went wrong.
  final String message;

  /// Optional error code for categorization.
  final String? code;

  /// Original exception if this wraps another exception.
  final Object? originalException;

  const AppException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

/// Exception for database operations.
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception for file system operations.
class FileSystemException extends AppException {
  const FileSystemException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception for network operations.
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception for Google Drive operations.
class GoogleDriveException extends AppException {
  const GoogleDriveException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception for authentication operations.
class AuthenticationException extends AppException {
  const AuthenticationException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception for JSON parsing or import operations.
class ImportException extends AppException {
  const ImportException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception for audio playback operations.
class AudioException extends AppException {
  const AudioException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception for validation errors.
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception when a resource is not found.
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Exception for cache operations.
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code,
    super.originalException,
  });
}
