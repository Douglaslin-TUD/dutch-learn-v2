// mobile/test/data/models/keyword_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/data/models/keyword_model.dart';

void main() {
  group('KeywordModel', () {
    final testMap = {
      'id': 'kw-1',
      'sentence_id': 'sent-1',
      'word': 'fiets',
      'meaning_nl': 'tweewieler',
      'meaning_en': 'bicycle',
    };

    test('fromMap creates model from DB row', () {
      final model = KeywordModel.fromMap(testMap);
      expect(model.id, 'kw-1');
      expect(model.word, 'fiets');
      expect(model.meaningNl, 'tweewieler');
      expect(model.meaningEn, 'bicycle');
    });

    test('toMap creates DB-compatible map', () {
      final model = KeywordModel.fromMap(testMap);
      final map = model.toMap();
      expect(map['word'], 'fiets');
      expect(map['sentence_id'], 'sent-1');
    });

    test('fromJson creates model from import JSON', () {
      final json = {
        'word': 'huis',
        'meaning_nl': 'gebouw om in te wonen',
        'meaning_en': 'house',
      };
      final model = KeywordModel.fromJson(json, id: 'new-id', sentenceId: 'sent-1');
      expect(model.id, 'new-id');
      expect(model.word, 'huis');
    });

    test('fromEntity round trips correctly', () {
      final model = KeywordModel.fromMap(testMap);
      final entity = model.toEntity();
      final backToModel = KeywordModel.fromEntity(entity);
      expect(backToModel.word, model.word);
      expect(backToModel.meaningEn, model.meaningEn);
    });
  });
}
