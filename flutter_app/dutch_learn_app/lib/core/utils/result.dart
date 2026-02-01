import 'package:dutch_learn_app/core/errors/failures.dart';

/// A functional result type for handling success and failure cases.
///
/// This class provides a type-safe way to handle operations that can
/// either succeed with a value of type [T] or fail with a [Failure].
///
/// Example:
/// ```dart
/// Result<User> result = await userRepository.getUser(id);
/// result.fold(
///   onSuccess: (user) => print('Got user: ${user.name}'),
///   onFailure: (failure) => print('Error: ${failure.message}'),
/// );
/// ```
sealed class Result<T> {
  const Result._();

  /// Creates a successful result with the given value.
  const factory Result.success(T value) = Success<T>;

  /// Creates a failed result with the given failure.
  const factory Result.failure(Failure failure) = Failure_<T>;

  /// Returns true if this is a success result.
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result.
  bool get isFailure => this is Failure_<T>;

  /// Pattern matches on the result and returns the result of the
  /// appropriate callback.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  });

  /// Returns the success value or null if this is a failure.
  T? get valueOrNull;

  /// Returns the failure or null if this is a success.
  Failure? get failureOrNull;

  /// Maps the success value to a new type.
  Result<R> map<R>(R Function(T value) mapper);

  /// Maps the success value to a new Result.
  Result<R> flatMap<R>(Result<R> Function(T value) mapper);

  /// Returns the success value or the provided default.
  T getOrElse(T defaultValue);

  /// Returns the success value or computes a default.
  T getOrElseCompute(T Function(Failure failure) compute);
}

/// Represents a successful result containing a value.
final class Success<T> extends Result<T> {
  /// The success value.
  final T value;

  const Success(this.value) : super._();

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    return onSuccess(value);
  }

  @override
  T? get valueOrNull => value;

  @override
  Failure? get failureOrNull => null;

  @override
  Result<R> map<R>(R Function(T value) mapper) {
    return Result.success(mapper(value));
  }

  @override
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) {
    return mapper(value);
  }

  @override
  T getOrElse(T defaultValue) => value;

  @override
  T getOrElseCompute(T Function(Failure failure) compute) => value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Success<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result containing a failure.
final class Failure_<T> extends Result<T> {
  /// The failure information.
  final Failure failure;

  const Failure_(this.failure) : super._();

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    return onFailure(failure);
  }

  @override
  T? get valueOrNull => null;

  @override
  Failure? get failureOrNull => failure;

  @override
  Result<R> map<R>(R Function(T value) mapper) {
    return Result.failure(failure);
  }

  @override
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) {
    return Result.failure(failure);
  }

  @override
  T getOrElse(T defaultValue) => defaultValue;

  @override
  T getOrElseCompute(T Function(Failure failure) compute) => compute(failure);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure_<T> && other.failure == failure;
  }

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Failure($failure)';
}
