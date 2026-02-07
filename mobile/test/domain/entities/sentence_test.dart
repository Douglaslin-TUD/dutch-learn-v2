// mobile/test/domain/entities/sentence_test.dart
import 'package:flutter_test/flutter_test.dart';
import '../../fixtures/test_data.dart';

void main() {
  group('Sentence Entity - Extended', () {
    test('duration calculation', () {
      final s = TestData.sentence(startTime: 1.5, endTime: 4.0);
      expect(s.duration, closeTo(2.5, 0.001));
    });

    test('displayNumber is 1-indexed', () {
      expect(TestData.sentence(index: 0).displayNumber, 1);
      expect(TestData.sentence(index: 9).displayNumber, 10);
    });

    test('hasTranslation', () {
      expect(TestData.sentence(translationEn: 'Hello').hasTranslation, isTrue);
      expect(TestData.sentence(translationEn: null).hasTranslation, isFalse);
    });

    test('hasExplanation', () {
      expect(TestData.sentence(explanationNl: 'uitleg').hasExplanation, isTrue);
      expect(TestData.sentence(explanationEn: 'explain').hasExplanation, isTrue);
      expect(TestData.sentence().hasExplanation, isFalse);
    });

    test('hasKeywords', () {
      expect(TestData.sentence(keywords: []).hasKeywords, isFalse);
      expect(TestData.sentence(keywords: [TestData.keyword()]).hasKeywords, isTrue);
    });

    test('words splits text', () {
      final s = TestData.sentence(text: 'Hallo hoe gaat het');
      expect(s.words, ['Hallo', 'hoe', 'gaat', 'het']);
    });

    test('containsPosition works at boundaries', () {
      final s = TestData.sentence(startTime: 2.0, endTime: 5.0);
      expect(s.containsPosition(2.0), isTrue);
      expect(s.containsPosition(3.5), isTrue);
      // endTime is exclusive: position < endTime
      expect(s.containsPosition(5.0), isFalse);
      expect(s.containsPosition(1.9), isFalse);
      expect(s.containsPosition(5.1), isFalse);
    });

    test('findKeyword finds case-insensitively', () {
      final kw = TestData.keyword(word: 'Fiets');
      final s = TestData.sentence(keywords: [kw]);
      expect(s.findKeyword('fiets')?.word, 'Fiets');
      expect(s.findKeyword('FIETS')?.word, 'Fiets');
      expect(s.findKeyword('auto'), isNull);
    });

    test('isKeyword returns bool', () {
      final kw = TestData.keyword(word: 'fiets');
      final s = TestData.sentence(keywords: [kw]);
      expect(s.isKeyword('fiets'), isTrue);
      expect(s.isKeyword('auto'), isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final original = TestData.sentence(text: 'original');
      final copied = original.copyWith(text: 'modified');
      expect(copied.text, 'modified');
      expect(copied.id, original.id);
      expect(copied.startTime, original.startTime);
    });

    test('equality by value', () {
      final a = TestData.sentence(id: 'same', text: 'same');
      final b = TestData.sentence(id: 'same', text: 'same');
      expect(a, equals(b));
    });
  });
}
