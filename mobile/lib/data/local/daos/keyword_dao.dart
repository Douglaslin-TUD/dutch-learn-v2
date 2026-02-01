import 'package:sqflite_common/sqflite.dart';

import 'package:dutch_learn_app/data/local/database.dart';
import 'package:dutch_learn_app/data/models/keyword_model.dart';

/// Data Access Object for keyword database operations.
class KeywordDao {
  final AppDatabase _database;

  KeywordDao(this._database);

  /// Gets all keywords for a sentence.
  Future<List<KeywordModel>> getBySentenceId(String sentenceId) async {
    final db = await _database.database;
    final results = await db.query(
      'keywords',
      where: 'sentence_id = ?',
      whereArgs: [sentenceId],
    );
    return results.map((map) => KeywordModel.fromMap(map)).toList();
  }

  /// Gets keywords for multiple sentences.
  Future<Map<String, List<KeywordModel>>> getBySentenceIds(
    List<String> sentenceIds,
  ) async {
    if (sentenceIds.isEmpty) return {};

    final db = await _database.database;
    final placeholders = List.filled(sentenceIds.length, '?').join(',');
    final results = await db.rawQuery(
      'SELECT * FROM keywords WHERE sentence_id IN ($placeholders)',
      sentenceIds,
    );

    final keywordMap = <String, List<KeywordModel>>{};
    for (final row in results) {
      final keyword = KeywordModel.fromMap(row);
      keywordMap.putIfAbsent(keyword.sentenceId, () => []).add(keyword);
    }
    return keywordMap;
  }

  /// Gets a keyword by ID.
  Future<KeywordModel?> getById(String id) async {
    final db = await _database.database;
    final results = await db.query(
      'keywords',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return KeywordModel.fromMap(results.first);
  }

  /// Finds a keyword by word in a sentence.
  Future<KeywordModel?> findByWord(String sentenceId, String word) async {
    final db = await _database.database;
    final results = await db.query(
      'keywords',
      where: 'sentence_id = ? AND LOWER(word) = LOWER(?)',
      whereArgs: [sentenceId, word],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return KeywordModel.fromMap(results.first);
  }

  /// Inserts a new keyword.
  Future<void> insert(KeywordModel keyword) async {
    final db = await _database.database;
    await db.insert(
      'keywords',
      keyword.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts multiple keywords in a batch.
  Future<void> insertBatch(List<KeywordModel> keywords) async {
    if (keywords.isEmpty) return;

    await _database.batch((batch) async {
      for (final keyword in keywords) {
        batch.insert(
          'keywords',
          keyword.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Deletes all keywords for a sentence.
  Future<int> deleteBySentenceId(String sentenceId) async {
    final db = await _database.database;
    return db.delete(
      'keywords',
      where: 'sentence_id = ?',
      whereArgs: [sentenceId],
    );
  }

  /// Deletes all keywords for sentences in a project.
  Future<int> deleteByProjectId(String projectId) async {
    final db = await _database.database;
    return db.rawDelete('''
      DELETE FROM keywords
      WHERE sentence_id IN (
        SELECT id FROM sentences WHERE project_id = ?
      )
    ''', [projectId]);
  }

  /// Searches keywords by word.
  Future<List<KeywordModel>> searchByWord(String query) async {
    final db = await _database.database;
    final results = await db.query(
      'keywords',
      where: 'word LIKE ?',
      whereArgs: ['%$query%'],
    );
    return results.map((map) => KeywordModel.fromMap(map)).toList();
  }
}
