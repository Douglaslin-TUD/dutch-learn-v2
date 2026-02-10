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

  group('SentenceDao', () {
    test('getByProjectId returns sentences ordered by idx', () async {
      await insertTestSentence(db, id: 'sent-3', idx: 2, text: 'Derde zin');
      await insertTestSentence(db, id: 'sent-1', idx: 0, text: 'Eerste zin');
      await insertTestSentence(db, id: 'sent-2', idx: 1, text: 'Tweede zin');

      final results = await db.query(
        'sentences',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
        orderBy: 'idx ASC',
      );

      expect(results.length, 3);
      expect(results[0]['idx'], 0);
      expect(results[0]['text'], 'Eerste zin');
      expect(results[1]['idx'], 1);
      expect(results[1]['text'], 'Tweede zin');
      expect(results[2]['idx'], 2);
      expect(results[2]['text'], 'Derde zin');
    });

    test('toggleDifficult flips the is_difficult flag', () async {
      await insertTestSentence(db, id: 'sent-1', isDifficult: 0);

      // Verify initial state
      var result = await db.query(
        'sentences',
        columns: ['is_difficult'],
        where: 'id = ?',
        whereArgs: ['sent-1'],
      );
      expect(result.first['is_difficult'], 0);

      // Toggle to difficult
      await db.rawUpdate(
        'UPDATE sentences SET is_difficult = 1 - is_difficult WHERE id = ?',
        ['sent-1'],
      );

      result = await db.query(
        'sentences',
        columns: ['is_difficult'],
        where: 'id = ?',
        whereArgs: ['sent-1'],
      );
      expect(result.first['is_difficult'], 1);

      // Toggle back to not difficult
      await db.rawUpdate(
        'UPDATE sentences SET is_difficult = 1 - is_difficult WHERE id = ?',
        ['sent-1'],
      );

      result = await db.query(
        'sentences',
        columns: ['is_difficult'],
        where: 'id = ?',
        whereArgs: ['sent-1'],
      );
      expect(result.first['is_difficult'], 0);
    });

    test('getDifficultByProjectId filters correctly', () async {
      await insertTestSentence(
        db,
        id: 'sent-1',
        idx: 0,
        isDifficult: 1,
        text: 'Moeilijke zin',
      );
      await insertTestSentence(
        db,
        id: 'sent-2',
        idx: 1,
        isDifficult: 0,
        text: 'Makkelijke zin',
      );
      await insertTestSentence(
        db,
        id: 'sent-3',
        idx: 2,
        isDifficult: 1,
        text: 'Nog een moeilijke',
      );

      final results = await db.query(
        'sentences',
        where: 'project_id = ? AND is_difficult = 1',
        whereArgs: ['proj-1'],
        orderBy: 'idx ASC',
      );

      expect(results.length, 2);
      expect(results[0]['text'], 'Moeilijke zin');
      expect(results[1]['text'], 'Nog een moeilijke');
    });

    test('recordReview increments count and sets timestamp', () async {
      await insertTestSentence(db, id: 'sent-1', reviewCount: 0);

      final timestamp = DateTime.now().toIso8601String();
      await db.rawUpdate(
        'UPDATE sentences SET review_count = review_count + 1, '
        'last_reviewed = ? WHERE id = ?',
        [timestamp, 'sent-1'],
      );

      final result = await db.query(
        'sentences',
        where: 'id = ?',
        whereArgs: ['sent-1'],
      );

      expect(result.first['review_count'], 1);
      expect(result.first['last_reviewed'], isNotNull);

      // Increment again
      final timestamp2 = DateTime.now().toIso8601String();
      await db.rawUpdate(
        'UPDATE sentences SET review_count = review_count + 1, '
        'last_reviewed = ? WHERE id = ?',
        [timestamp2, 'sent-1'],
      );

      final result2 = await db.query(
        'sentences',
        where: 'id = ?',
        whereArgs: ['sent-1'],
      );

      expect(result2.first['review_count'], 2);
    });

    test('updateLearningProgress sets learned and learn_count', () async {
      await insertTestSentence(
        db,
        id: 'sent-1',
        learned: 0,
        learnCount: 0,
      );

      await db.update(
        'sentences',
        {'learned': 1, 'learn_count': 5},
        where: 'id = ?',
        whereArgs: ['sent-1'],
      );

      final result = await db.query(
        'sentences',
        where: 'id = ?',
        whereArgs: ['sent-1'],
      );

      expect(result.first['learned'], 1);
      expect(result.first['learn_count'], 5);
    });

    test('search finds sentences by text LIKE', () async {
      await insertTestSentence(
        db,
        id: 'sent-1',
        idx: 0,
        text: 'De kat zit op de mat',
      );
      await insertTestSentence(
        db,
        id: 'sent-2',
        idx: 1,
        text: 'De hond loopt in het park',
      );
      await insertTestSentence(
        db,
        id: 'sent-3',
        idx: 2,
        text: 'Ik heb een kat en een hond',
      );

      // Search for "kat"
      final results = await db.query(
        'sentences',
        where: 'project_id = ? AND text LIKE ?',
        whereArgs: ['proj-1', '%kat%'],
        orderBy: 'idx ASC',
      );

      expect(results.length, 2);
      expect(results[0]['text'], 'De kat zit op de mat');
      expect(results[1]['text'], 'Ik heb een kat en een hond');

      // Search for "park" - should find 1
      final parkResults = await db.query(
        'sentences',
        where: 'project_id = ? AND text LIKE ?',
        whereArgs: ['proj-1', '%park%'],
        orderBy: 'idx ASC',
      );

      expect(parkResults.length, 1);
      expect(parkResults.first['text'], 'De hond loopt in het park');
    });

    test('cascade delete removes sentences when project deleted', () async {
      await insertTestSentence(db, id: 'sent-1', idx: 0);
      await insertTestSentence(db, id: 'sent-2', idx: 1);

      // Verify sentences exist
      var sentences = await db.query(
        'sentences',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
      );
      expect(sentences.length, 2);

      // Delete the project
      await db.delete('projects', where: 'id = ?', whereArgs: ['proj-1']);

      // Verify sentences are cascade-deleted
      sentences = await db.query(
        'sentences',
        where: 'project_id = ?',
        whereArgs: ['proj-1'],
      );
      expect(sentences.length, 0);
    });
  });
}
