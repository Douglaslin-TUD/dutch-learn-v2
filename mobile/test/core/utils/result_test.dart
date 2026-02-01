import 'package:flutter_test/flutter_test.dart';

import 'package:dutch_learn_app/core/errors/failures.dart';
import 'package:dutch_learn_app/core/utils/result.dart';

void main() {
  group('Result', () {
    group('Success', () {
      test('should create success result with value', () {
        const result = Result.success('test value');

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.valueOrNull, 'test value');
        expect(result.failureOrNull, null);
      });

      test('fold should call onSuccess callback', () {
        const result = Result.success(42);
        var called = false;
        int? receivedValue;

        result.fold(
          onSuccess: (value) {
            called = true;
            receivedValue = value;
            return value;
          },
          onFailure: (failure) => -1,
        );

        expect(called, true);
        expect(receivedValue, 42);
      });

      test('map should transform success value', () {
        const result = Result.success(10);
        final mapped = result.map((value) => value * 2);

        expect(mapped.isSuccess, true);
        expect(mapped.valueOrNull, 20);
      });

      test('flatMap should chain results', () {
        const result = Result<int>.success(5);
        final chained = result.flatMap((value) => Result.success(value.toString()));

        expect(chained.isSuccess, true);
        expect(chained.valueOrNull, '5');
      });

      test('getOrElse should return success value', () {
        const result = Result.success('success');
        final value = result.getOrElse('default');

        expect(value, 'success');
      });

      test('getOrElseCompute should return success value', () {
        const result = Result.success('success');
        final value = result.getOrElseCompute((f) => 'computed');

        expect(value, 'success');
      });
    });

    group('Failure', () {
      test('should create failure result with failure', () {
        const failure = DatabaseFailure(message: 'Database error');
        const result = Result<String>.failure(failure);

        expect(result.isSuccess, false);
        expect(result.isFailure, true);
        expect(result.valueOrNull, null);
        expect(result.failureOrNull, failure);
      });

      test('fold should call onFailure callback', () {
        const failure = DatabaseFailure(message: 'Error');
        const result = Result<int>.failure(failure);
        var called = false;
        Failure? receivedFailure;

        result.fold(
          onSuccess: (value) => value,
          onFailure: (f) {
            called = true;
            receivedFailure = f;
            return -1;
          },
        );

        expect(called, true);
        expect(receivedFailure, failure);
      });

      test('map should preserve failure', () {
        const failure = DatabaseFailure(message: 'Error');
        const result = Result<int>.failure(failure);
        final mapped = result.map((value) => value * 2);

        expect(mapped.isFailure, true);
        expect(mapped.failureOrNull, failure);
      });

      test('flatMap should preserve failure', () {
        const failure = DatabaseFailure(message: 'Error');
        const result = Result<int>.failure(failure);
        final chained = result.flatMap((value) => Result.success(value.toString()));

        expect(chained.isFailure, true);
        expect(chained.failureOrNull, failure);
      });

      test('getOrElse should return default value', () {
        const failure = DatabaseFailure(message: 'Error');
        const result = Result<String>.failure(failure);
        final value = result.getOrElse('default');

        expect(value, 'default');
      });

      test('getOrElseCompute should compute default value', () {
        const failure = DatabaseFailure(message: 'Error');
        const result = Result<String>.failure(failure);
        final value = result.getOrElseCompute((f) => 'computed: ${f.message}');

        expect(value, 'computed: Error');
      });
    });

    group('Equality', () {
      test('two success results with same value should be equal', () {
        const result1 = Result.success(42);
        const result2 = Result.success(42);

        expect(result1, equals(result2));
      });

      test('two success results with different values should not be equal', () {
        const result1 = Result.success(42);
        const result2 = Result.success(43);

        expect(result1, isNot(equals(result2)));
      });

      test('two failure results with same failure should be equal', () {
        const failure = DatabaseFailure(message: 'Error');
        const result1 = Result<int>.failure(failure);
        const result2 = Result<int>.failure(failure);

        expect(result1, equals(result2));
      });

      test('success and failure results should not be equal', () {
        const success = Result.success(42);
        const failure = Result<int>.failure(DatabaseFailure(message: 'Error'));

        expect(success, isNot(equals(failure)));
      });
    });
  });
}
