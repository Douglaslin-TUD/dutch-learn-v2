// mobile/test/data/models/sentence_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/data/models/sentence_model.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';

void main() {
  group('SentenceModel', () {
    final testMap = {
      'id': 'sent-1',
      'project_id': 'proj-1',
      'idx': 0,
      'text': 'Hallo wereld',
      'start_time': 0.0,
      'end_time': 2.5,
      'translation_en': 'Hello world',
      'explanation_nl': null,
      'explanation_en': null,
    };

    test('fromMap creates model from DB row', () {
      final model = SentenceModel.fromMap(testMap);
      expect(model.id, 'sent-1');
      expect(model.projectId, 'proj-1');
      expect(model.index, 0);
      expect(model.text, 'Hallo wereld');
      expect(model.startTime, 0.0);
      expect(model.endTime, 2.5);
      expect(model.translationEn, 'Hello world');
    });

    test('toMap creates DB-compatible map', () {
      final model = SentenceModel.fromMap(testMap);
      final map = model.toMap();
      expect(map['id'], 'sent-1');
      expect(map['project_id'], 'proj-1');
      expect(map['idx'], 0);
    });

    test('fromJson creates model from import JSON', () {
      final json = {
        'index': 0,
        'text': 'Test zin',
        'start_time': 1.0,
        'end_time': 3.0,
        'translation_en': 'Test sentence',
        'explanation_nl': null,
        'explanation_en': null,
        'keywords': [],
      };
      final model = SentenceModel.fromJson(json, id: 'new-id', projectId: 'proj-1');
      expect(model.id, 'new-id');
      expect(model.projectId, 'proj-1');
      expect(model.text, 'Test zin');
    });

    test('fromEntity round trips correctly', () {
      final model = SentenceModel.fromMap(testMap);
      final entity = model.toEntity();
      final backToModel = SentenceModel.fromEntity(entity);
      expect(backToModel.id, model.id);
      expect(backToModel.text, model.text);
    });

    test('withKeywords attaches keywords', () {
      final model = SentenceModel.fromMap(testMap);
      expect(model.keywords, isEmpty);
      final withKw = model.withKeywords([
        const Keyword(id: 'k1', sentenceId: 'sent-1', word: 'hallo', meaningNl: 'begroeting', meaningEn: 'hello'),
      ]);
      expect(withKw.keywords.length, 1);
      expect(withKw.keywords[0].word, 'hallo');
    });

    test('handles null optional fields', () {
      final minMap = {
        'id': 'sent-2',
        'project_id': 'proj-1',
        'idx': 1,
        'text': 'Tekst',
        'start_time': 0.0,
        'end_time': 1.0,
        'translation_en': null,
        'explanation_nl': null,
        'explanation_en': null,
      };
      final model = SentenceModel.fromMap(minMap);
      expect(model.translationEn, isNull);
      expect(model.hasTranslation, isFalse);
    });
  });
}
