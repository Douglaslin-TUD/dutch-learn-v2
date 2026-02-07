// mobile/test/core/extensions/string_extension_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/core/extensions/string_extension.dart';

void main() {
  group('StringExtension', () {
    test('capitalize', () {
      expect('hello'.capitalize, 'Hello');
      expect(''.capitalize, '');
      expect('A'.capitalize, 'A');
    });

    test('titleCase', () {
      expect('hello world'.titleCase, 'Hello World');
    });

    test('truncate', () {
      expect('Hello World'.truncate(5), 'He...');
      expect('Hi'.truncate(10), 'Hi');
    });

    test('normalizeWhitespace', () {
      expect('  hello   world  '.normalizeWhitespace, 'hello world');
    });

    test('isNumeric', () {
      expect('123'.isNumeric, isTrue);
      // isNumeric only checks for digits (no dots)
      expect('12.5'.isNumeric, isFalse);
      expect('abc'.isNumeric, isFalse);
    });

    test('isBlank and isNotBlank', () {
      expect(''.isBlank, isTrue);
      expect('  '.isBlank, isTrue);
      expect('hi'.isBlank, isFalse);
      expect('hi'.isNotBlank, isTrue);
    });

    test('nullIfBlank', () {
      expect(''.nullIfBlank, isNull);
      expect('  '.nullIfBlank, isNull);
      expect('hi'.nullIfBlank, 'hi');
    });

    test('snakeToCamel', () {
      expect('hello_world'.snakeToCamel, 'helloWorld');
    });

    test('camelToSnake', () {
      expect('helloWorld'.camelToSnake, 'hello_world');
    });

    test('words splits by whitespace', () {
      expect('hello world'.words, ['hello', 'world']);
    });

    test('containsIgnoreCase', () {
      expect('Hello World'.containsIgnoreCase('hello'), isTrue);
      expect('Hello World'.containsIgnoreCase('xyz'), isFalse);
    });

    test('removeDiacritics returns string', () {
      // removeDiacritics performs character-level replacement
      final result = 'hello'.removeDiacritics;
      expect(result, 'hello');
    });
  });

  group('NullableStringExtension', () {
    test('isNullOrEmpty', () {
      String? nullStr;
      expect(nullStr.isNullOrEmpty, isTrue);
      expect(''.isNullOrEmpty, isTrue);
      expect('hi'.isNullOrEmpty, isFalse);
    });

    test('isNullOrBlank', () {
      String? nullStr;
      expect(nullStr.isNullOrBlank, isTrue);
      expect('  '.isNullOrBlank, isTrue);
    });

    test('orDefault', () {
      String? nullStr;
      expect(nullStr.orDefault('fallback'), 'fallback');
      expect('value'.orDefault('fallback'), 'value');
    });

    test('orEmpty', () {
      String? nullStr;
      expect(nullStr.orEmpty, '');
      expect('hi'.orEmpty, 'hi');
    });
  });
}
