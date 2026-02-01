import 'package:flutter_test/flutter_test.dart';

import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';

void main() {
  group('Project Entity', () {
    test('should create a project with required fields', () {
      final project = Project(
        id: 'test-id',
        name: 'Test Project',
        totalSentences: 10,
        importedAt: DateTime(2024, 1, 1),
      );

      expect(project.id, 'test-id');
      expect(project.name, 'Test Project');
      expect(project.totalSentences, 10);
      expect(project.hasAudio, false);
      expect(project.hasBeenPlayed, false);
    });

    test('should calculate progress correctly', () {
      final project = Project(
        id: 'test-id',
        name: 'Test Project',
        totalSentences: 10,
        importedAt: DateTime(2024, 1, 1),
        lastSentenceIndex: 4,
      );

      expect(project.progressPercent, 50.0);
    });

    test('copyWith should create a new instance with updated fields', () {
      final original = Project(
        id: 'test-id',
        name: 'Original',
        totalSentences: 10,
        importedAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(name: 'Updated');

      expect(updated.name, 'Updated');
      expect(updated.id, original.id);
      expect(original.name, 'Original');
    });
  });

  group('Sentence Entity', () {
    test('should create a sentence with required fields', () {
      final sentence = Sentence(
        id: 'sentence-1',
        projectId: 'project-1',
        index: 0,
        text: 'Dit is een zin.',
        startTime: 0.0,
        endTime: 2.5,
      );

      expect(sentence.id, 'sentence-1');
      expect(sentence.displayNumber, 1);
      expect(sentence.duration, 2.5);
      expect(sentence.hasTranslation, false);
      expect(sentence.hasKeywords, false);
    });

    test('should check if position is within sentence', () {
      final sentence = Sentence(
        id: 'sentence-1',
        projectId: 'project-1',
        index: 0,
        text: 'Test',
        startTime: 1.0,
        endTime: 3.0,
      );

      expect(sentence.containsPosition(0.5), false);
      expect(sentence.containsPosition(1.0), true);
      expect(sentence.containsPosition(2.0), true);
      expect(sentence.containsPosition(3.0), false);
    });

    test('should find keyword in sentence', () {
      final keyword = Keyword(
        id: 'kw-1',
        sentenceId: 'sentence-1',
        word: 'huis',
        meaningNl: 'woning',
        meaningEn: 'house',
      );

      final sentence = Sentence(
        id: 'sentence-1',
        projectId: 'project-1',
        index: 0,
        text: 'Dit is een huis.',
        startTime: 0.0,
        endTime: 2.0,
        keywords: [keyword],
      );

      expect(sentence.findKeyword('huis'), keyword);
      expect(sentence.findKeyword('auto'), null);
      expect(sentence.isKeyword('huis'), true);
      expect(sentence.isKeyword('auto'), false);
    });
  });

  group('Keyword Entity', () {
    test('should create a keyword with required fields', () {
      final keyword = Keyword(
        id: 'kw-1',
        sentenceId: 'sentence-1',
        word: 'huis',
        meaningNl: 'woning',
        meaningEn: 'house',
      );

      expect(keyword.word, 'huis');
      expect(keyword.meaningEn, 'house');
      expect(keyword.wordLower, 'huis');
    });

    test('should match word case insensitively', () {
      final keyword = Keyword(
        id: 'kw-1',
        sentenceId: 'sentence-1',
        word: 'Huis',
        meaningNl: 'woning',
        meaningEn: 'house',
      );

      expect(keyword.matches('huis'), true);
      expect(keyword.matches('HUIS'), true);
      expect(keyword.matches('Huis'), true);
      expect(keyword.matches('auto'), false);
    });
  });
}
