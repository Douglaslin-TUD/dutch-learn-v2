import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'test_helpers.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('ProjectDao', () {
    test('getAll returns projects', () async {
      await insertTestProject(db, id: 'proj-1', name: 'Project 1');
      await insertTestProject(db, id: 'proj-2', name: 'Project 2');

      final results = await db.query(
        'projects',
        orderBy: 'last_played_at DESC, imported_at DESC',
      );

      expect(results.length, 2);
      final names = results.map((r) => r['name']).toSet();
      expect(names, containsAll(['Project 1', 'Project 2']));
    });

    test('getById returns correct project', () async {
      await insertTestProject(db, id: 'proj-1', name: 'Target Project');
      await insertTestProject(db, id: 'proj-2', name: 'Other Project');

      final results = await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['proj-1'],
        limit: 1,
      );

      expect(results.length, 1);
      expect(results.first['name'], 'Target Project');
      expect(results.first['id'], 'proj-1');
    });

    test('getById returns empty for nonexistent', () async {
      await insertTestProject(db, id: 'proj-1');

      final results = await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['nonexistent-id'],
        limit: 1,
      );

      expect(results.isEmpty, true);
    });

    test('getBySourceId finds by source', () async {
      await insertTestProject(
        db,
        id: 'proj-1',
        sourceId: 'desktop-abc',
        name: 'Synced Project',
      );
      await insertTestProject(
        db,
        id: 'proj-2',
        sourceId: 'desktop-xyz',
        name: 'Other Synced',
      );

      final results = await db.query(
        'projects',
        where: 'source_id = ?',
        whereArgs: ['desktop-abc'],
        limit: 1,
      );

      expect(results.length, 1);
      expect(results.first['name'], 'Synced Project');
      expect(results.first['source_id'], 'desktop-abc');
    });

    test('delete removes project', () async {
      await insertTestProject(db, id: 'proj-1', name: 'To Delete');
      await insertTestProject(db, id: 'proj-2', name: 'To Keep');

      // Verify both exist
      var all = await db.query('projects');
      expect(all.length, 2);

      // Delete one
      final deleted = await db.delete(
        'projects',
        where: 'id = ?',
        whereArgs: ['proj-1'],
      );

      expect(deleted, 1);

      all = await db.query('projects');
      expect(all.length, 1);
      expect(all.first['name'], 'To Keep');
    });

    test('updateLastPlayed sets fields', () async {
      await insertTestProject(db, id: 'proj-1');

      final playedAt = DateTime(2026, 2, 10, 14, 30);
      await db.update(
        'projects',
        {
          'last_played_at': playedAt.toIso8601String(),
          'last_sentence_index': 42,
        },
        where: 'id = ?',
        whereArgs: ['proj-1'],
      );

      final result = await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['proj-1'],
      );

      expect(result.first['last_played_at'], playedAt.toIso8601String());
      expect(result.first['last_sentence_index'], 42);
    });
  });
}
