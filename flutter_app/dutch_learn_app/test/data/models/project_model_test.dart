import 'package:flutter_test/flutter_test.dart';

import 'package:dutch_learn_app/data/models/project_model.dart';
import 'package:dutch_learn_app/domain/entities/project.dart';

void main() {
  group('ProjectModel', () {
    final testMap = {
      'id': 'test-id',
      'source_id': 'source-123',
      'name': 'Test Project',
      'total_sentences': 100,
      'audio_path': '/path/to/audio.mp3',
      'imported_at': '2024-01-15T10:30:00.000',
      'last_played_at': '2024-01-16T14:00:00.000',
      'last_sentence_index': 25,
    };

    test('fromMap should create ProjectModel from database map', () {
      final model = ProjectModel.fromMap(testMap);

      expect(model.id, 'test-id');
      expect(model.sourceId, 'source-123');
      expect(model.name, 'Test Project');
      expect(model.totalSentences, 100);
      expect(model.audioPath, '/path/to/audio.mp3');
      expect(model.importedAt, DateTime(2024, 1, 15, 10, 30, 0));
      expect(model.lastPlayedAt, DateTime(2024, 1, 16, 14, 0, 0));
      expect(model.lastSentenceIndex, 25);
    });

    test('toMap should convert ProjectModel to database map', () {
      final model = ProjectModel(
        id: 'test-id',
        sourceId: 'source-123',
        name: 'Test Project',
        totalSentences: 100,
        audioPath: '/path/to/audio.mp3',
        importedAt: DateTime(2024, 1, 15, 10, 30, 0),
        lastPlayedAt: DateTime(2024, 1, 16, 14, 0, 0),
        lastSentenceIndex: 25,
      );

      final map = model.toMap();

      expect(map['id'], 'test-id');
      expect(map['source_id'], 'source-123');
      expect(map['name'], 'Test Project');
      expect(map['total_sentences'], 100);
      expect(map['audio_path'], '/path/to/audio.mp3');
      expect(map['imported_at'], '2024-01-15T10:30:00.000');
      expect(map['last_played_at'], '2024-01-16T14:00:00.000');
      expect(map['last_sentence_index'], 25);
    });

    test('fromJson should create ProjectModel from import JSON', () {
      final json = {
        'project': {
          'id': 'json-id',
          'name': 'JSON Project',
          'total_sentences': 50,
        },
      };

      final model = ProjectModel.fromJson(
        json,
        id: 'local-id',
        audioPath: '/audio.mp3',
      );

      expect(model.id, 'local-id');
      expect(model.sourceId, 'json-id');
      expect(model.name, 'JSON Project');
      expect(model.totalSentences, 50);
      expect(model.audioPath, '/audio.mp3');
    });

    test('fromEntity should create ProjectModel from domain entity', () {
      final entity = Project(
        id: 'entity-id',
        sourceId: 'source-id',
        name: 'Entity Project',
        totalSentences: 75,
        audioPath: '/audio.mp3',
        importedAt: DateTime(2024, 1, 1),
      );

      final model = ProjectModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.name, entity.name);
      expect(model.totalSentences, entity.totalSentences);
    });

    test('toEntity should convert ProjectModel to domain entity', () {
      final model = ProjectModel(
        id: 'model-id',
        name: 'Model Project',
        totalSentences: 30,
        importedAt: DateTime(2024, 1, 1),
      );

      final entity = model.toEntity();

      expect(entity.id, model.id);
      expect(entity.name, model.name);
      expect(entity, isA<Project>());
    });

    test('copyWith should create new instance with updated fields', () {
      final original = ProjectModel(
        id: 'original-id',
        name: 'Original',
        totalSentences: 10,
        importedAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        name: 'Updated',
        totalSentences: 20,
      );

      expect(updated.name, 'Updated');
      expect(updated.totalSentences, 20);
      expect(updated.id, original.id);
      expect(original.name, 'Original');
    });

    test('fromMap handles null optional fields', () {
      final minimalMap = {
        'id': 'minimal-id',
        'name': 'Minimal Project',
        'total_sentences': 5,
        'imported_at': '2024-01-01T00:00:00.000',
      };

      final model = ProjectModel.fromMap(minimalMap);

      expect(model.sourceId, null);
      expect(model.audioPath, null);
      expect(model.lastPlayedAt, null);
      expect(model.lastSentenceIndex, null);
    });
  });
}
