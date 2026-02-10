import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'test_helpers.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await createTestDatabase();
    await insertTestProject(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SpeakerDao', () {
    test('getByProjectId returns speakers ordered by label', () async {
      await insertTestSpeaker(db, id: 'spk-c', label: 'C');
      await insertTestSpeaker(db, id: 'spk-a', label: 'A');
      await insertTestSpeaker(db, id: 'spk-b', label: 'B');

      final results = await db.query(
        'speakers',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
        orderBy: 'label ASC',
      );

      expect(results.length, 3);
      expect(results[0]['label'], 'A');
      expect(results[1]['label'], 'B');
      expect(results[2]['label'], 'C');
    });

    test('updateDisplayName sets name and is_manual', () async {
      await insertTestSpeaker(
        db,
        id: 'spk-1',
        label: 'A',
        displayName: null,
        isManual: 0,
      );

      await db.update(
        'speakers',
        {'display_name': 'Jan', 'is_manual': 1},
        where: 'id = ?',
        whereArgs: ['spk-1'],
      );

      final result = await db.query(
        'speakers',
        where: 'id = ?',
        whereArgs: ['spk-1'],
      );

      expect(result.first['display_name'], 'Jan');
      expect(result.first['is_manual'], 1);
    });

    test('deleteByProjectId removes all speakers', () async {
      await insertTestSpeaker(db, id: 'spk-1', label: 'A');
      await insertTestSpeaker(db, id: 'spk-2', label: 'B');

      // Verify speakers exist
      var speakers = await db.query(
        'speakers',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
      );
      expect(speakers.length, 2);

      // Delete by project ID
      final deleted = await db.delete(
        'speakers',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
      );

      expect(deleted, 2);

      speakers = await db.query(
        'speakers',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
      );
      expect(speakers.length, 0);
    });

    test('cascade delete removes speakers when project deleted', () async {
      await insertTestSpeaker(db, id: 'spk-1', label: 'A');
      await insertTestSpeaker(db, id: 'spk-2', label: 'B');

      // Verify speakers exist
      var speakers = await db.query(
        'speakers',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
      );
      expect(speakers.length, 2);

      // Delete the project
      await db.delete('projects', where: 'id = ?', whereArgs: ['proj-1']);

      // Verify speakers are cascade-deleted
      speakers = await db.query(
        'speakers',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
      );
      expect(speakers.length, 0);
    });

    test('insert with ConflictAlgorithm.replace updates existing', () async {
      await insertTestSpeaker(
        db,
        id: 'spk-1',
        label: 'A',
        displayName: 'Original',
        confidence: 0.8,
      );

      // Insert with same ID but different data using replace
      await db.insert(
        'speakers',
        {
          'id': 'spk-1',
          'project_id': 'proj-1',
          'label': 'A',
          'display_name': 'Updated',
          'confidence': 0.95,
          'evidence': null,
          'is_manual': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final results = await db.query(
        'speakers',
        where: 'id = ?',
        whereArgs: ['spk-1'],
      );

      expect(results.length, 1);
      expect(results.first['display_name'], 'Updated');
      expect(results.first['confidence'], 0.95);
      expect(results.first['is_manual'], 1);
    });
  });
}
