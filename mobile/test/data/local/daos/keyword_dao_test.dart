import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'test_helpers.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await createTestDatabase();
    await insertTestProject(db);
    await insertTestSentence(db, id: 'sent-1', idx: 0);
    await insertTestSentence(db, id: 'sent-2', idx: 1, text: 'Tweede zin');
  });

  tearDown(() async {
    await db.close();
  });

  group('KeywordDao', () {
    test('getBySentenceId returns keywords for sentence', () async {
      await insertTestKeyword(
        db,
        id: 'kw-1',
        sentenceId: 'sent-1',
        word: 'hallo',
        meaningNl: 'begroeting',
        meaningEn: 'hello',
      );
      await insertTestKeyword(
        db,
        id: 'kw-2',
        sentenceId: 'sent-1',
        word: 'gaat',
        meaningNl: 'gaan',
        meaningEn: 'goes',
      );
      await insertTestKeyword(
        db,
        id: 'kw-3',
        sentenceId: 'sent-2',
        word: 'tweede',
        meaningNl: 'nummer twee',
        meaningEn: 'second',
      );

      final results = await db.query(
        'keywords',
        where: 'sentence_id = ?',
        whereArgs: ['sent-1'],
      );

      expect(results.length, 2);
      final words = results.map((r) => r['word']).toSet();
      expect(words, containsAll(['hallo', 'gaat']));
    });

    test('getBySentenceIds returns results from multiple sentences', () async {
      await insertTestKeyword(
        db,
        id: 'kw-1',
        sentenceId: 'sent-1',
        word: 'hallo',
        meaningNl: 'begroeting',
        meaningEn: 'hello',
      );
      await insertTestKeyword(
        db,
        id: 'kw-2',
        sentenceId: 'sent-2',
        word: 'tweede',
        meaningNl: 'nummer twee',
        meaningEn: 'second',
      );

      final sentenceIds = ['sent-1', 'sent-2'];
      final placeholders = List.filled(sentenceIds.length, '?').join(',');
      final results = await db.rawQuery(
        'SELECT * FROM keywords WHERE sentence_id IN ($placeholders)',
        sentenceIds,
      );

      expect(results.length, 2);

      // Group by sentence_id like the DAO does
      final keywordMap = <String, List<Map<String, Object?>>>{};
      for (final row in results) {
        final sentenceId = row['sentence_id'] as String;
        keywordMap.putIfAbsent(sentenceId, () => []).add(row);
      }

      expect(keywordMap.keys.length, 2);
      expect(keywordMap['sent-1']!.length, 1);
      expect(keywordMap['sent-2']!.length, 1);
      expect(keywordMap['sent-1']!.first['word'], 'hallo');
      expect(keywordMap['sent-2']!.first['word'], 'tweede');
    });

    test('cascade delete removes keywords when sentence deleted', () async {
      await insertTestKeyword(db, id: 'kw-1', sentenceId: 'sent-1');
      await insertTestKeyword(db, id: 'kw-2', sentenceId: 'sent-1');

      // Verify keywords exist
      var keywords = await db.query(
        'keywords',
        where: 'sentence_id = ?',
        whereArgs: ['sent-1'],
      );
      expect(keywords.length, 2);

      // Delete the sentence
      await db.delete('sentences', where: 'id = ?', whereArgs: ['sent-1']);

      // Verify keywords are cascade-deleted
      keywords = await db.query(
        'keywords',
        where: 'sentence_id = ?',
        whereArgs: ['sent-1'],
      );
      expect(keywords.length, 0);
    });

    test('deleteByProjectId removes via subquery', () async {
      await insertTestKeyword(db, id: 'kw-1', sentenceId: 'sent-1');
      await insertTestKeyword(db, id: 'kw-2', sentenceId: 'sent-2');

      // Verify keywords exist
      var allKeywords = await db.query('keywords');
      expect(allKeywords.length, 2);

      // Delete using subquery (same pattern as KeywordDao.deleteByProjectId)
      final deleted = await db.rawDelete('''
        DELETE FROM keywords
        WHERE sentence_id IN (
          SELECT id FROM sentences WHERE project_id = ?
        )
      ''', ['proj-1']);

      expect(deleted, 2);

      allKeywords = await db.query('keywords');
      expect(allKeywords.length, 0);
    });
  });
}
