// mobile/test/data/models/speaker_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/data/models/speaker_model.dart';
import 'package:dutch_learn_app/domain/entities/speaker.dart';

void main() {
  group('SpeakerModel', () {
    final testMap = {
      'id': 'spk-1',
      'project_id': 'proj-1',
      'label': 'A',
      'display_name': 'Jan',
      'confidence': 0.85,
      'evidence': 'Based on voice pitch',
      'is_manual': 1,
    };

    test('fromMap creates model with all fields', () {
      final model = SpeakerModel.fromMap(testMap);
      expect(model.id, 'spk-1');
      expect(model.projectId, 'proj-1');
      expect(model.label, 'A');
      expect(model.displayName, 'Jan');
      expect(model.confidence, 0.85);
      expect(model.evidence, 'Based on voice pitch');
      expect(model.isManual, true);
    });

    test('fromMap handles null optional fields', () {
      final minimalMap = {
        'id': 'spk-2',
        'project_id': 'proj-1',
        'label': 'B',
        'display_name': null,
        'confidence': null,
        'evidence': null,
        'is_manual': null,
      };
      final model = SpeakerModel.fromMap(minimalMap);
      expect(model.displayName, isNull);
      expect(model.confidence, 0.0);
      expect(model.evidence, isNull);
      expect(model.isManual, false);
    });

    test('toMap produces correct keys', () {
      final model = SpeakerModel.fromMap(testMap);
      final map = model.toMap();
      expect(map['id'], 'spk-1');
      expect(map['project_id'], 'proj-1');
      expect(map['label'], 'A');
      expect(map['display_name'], 'Jan');
      expect(map['confidence'], 0.85);
      expect(map['evidence'], 'Based on voice pitch');
      expect(map['is_manual'], 1);
    });

    test('toMap/fromMap roundtrip preserves data', () {
      final original = SpeakerModel.fromMap(testMap);
      final roundtripped = SpeakerModel.fromMap(original.toMap());
      expect(roundtripped.id, original.id);
      expect(roundtripped.projectId, original.projectId);
      expect(roundtripped.label, original.label);
      expect(roundtripped.displayName, original.displayName);
      expect(roundtripped.confidence, original.confidence);
      expect(roundtripped.evidence, original.evidence);
      expect(roundtripped.isManual, original.isManual);
    });

    test('fromJson with required id and projectId', () {
      final json = {
        'label': 'C',
        'display_name': 'Piet',
        'confidence': 0.72,
        'evidence': 'Frequency analysis',
        'is_manual': true,
      };
      final model = SpeakerModel.fromJson(json, id: 'new-id', projectId: 'proj-2');
      expect(model.id, 'new-id');
      expect(model.projectId, 'proj-2');
      expect(model.label, 'C');
      expect(model.displayName, 'Piet');
      expect(model.confidence, 0.72);
      expect(model.evidence, 'Frequency analysis');
      expect(model.isManual, true);
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{};
      final model = SpeakerModel.fromJson(json, id: 'id-1', projectId: 'proj-1');
      expect(model.id, 'id-1');
      expect(model.projectId, 'proj-1');
      expect(model.label, '');
      expect(model.displayName, isNull);
      expect(model.confidence, 0.0);
      expect(model.evidence, isNull);
      expect(model.isManual, false);
    });

    test('toJson produces correct format', () {
      final model = SpeakerModel.fromMap(testMap);
      final json = model.toJson();
      expect(json['id'], 'spk-1');
      expect(json['project_id'], 'proj-1');
      expect(json['label'], 'A');
      expect(json['display_name'], 'Jan');
      expect(json['confidence'], 0.85);
      expect(json['evidence'], 'Based on voice pitch');
      // toJson uses bool, not int
      expect(json['is_manual'], isA<bool>());
      expect(json['is_manual'], true);
    });

    test('toEntity and fromEntity roundtrip', () {
      final model = SpeakerModel.fromMap(testMap);
      final entity = model.toEntity();
      expect(entity, isA<Speaker>());
      final backToModel = SpeakerModel.fromEntity(entity);
      expect(backToModel.id, model.id);
      expect(backToModel.projectId, model.projectId);
      expect(backToModel.label, model.label);
      expect(backToModel.displayName, model.displayName);
      expect(backToModel.confidence, model.confidence);
      expect(backToModel.evidence, model.evidence);
      expect(backToModel.isManual, model.isManual);
    });

    test('displayLabel uses displayName when set', () {
      final model = SpeakerModel.fromMap(testMap);
      expect(model.displayLabel, 'Jan');
    });

    test('displayLabel falls back to Speaker label', () {
      final model = SpeakerModel.fromMap({
        'id': 'spk-3',
        'project_id': 'proj-1',
        'label': 'B',
        'display_name': null,
        'confidence': null,
        'evidence': null,
        'is_manual': 0,
      });
      expect(model.displayLabel, 'Speaker B');
    });

    test('copyWith creates modified copy', () {
      final original = SpeakerModel.fromMap(testMap);
      final modified = original.copyWith(
        displayName: 'Kees',
        confidence: 0.99,
        isManual: false,
      );
      // Changed fields
      expect(modified.displayName, 'Kees');
      expect(modified.confidence, 0.99);
      expect(modified.isManual, false);
      // Unchanged fields
      expect(modified.id, original.id);
      expect(modified.projectId, original.projectId);
      expect(modified.label, original.label);
      expect(modified.evidence, original.evidence);
    });
  });
}
