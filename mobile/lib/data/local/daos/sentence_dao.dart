import 'package:sqflite_common/sqflite.dart';

import 'package:dutch_learn_app/data/local/database.dart';
import 'package:dutch_learn_app/data/models/sentence_model.dart';

/// Data Access Object for sentence database operations.
class SentenceDao {
  final AppDatabase _database;

  SentenceDao(this._database);

  /// Gets all sentences for a project ordered by index.
  Future<List<SentenceModel>> getByProjectId(String projectId) async {
    final db = await _database.database;
    final results = await db.query(
      'sentences',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'idx ASC',
    );
    return results.map((map) => SentenceModel.fromMap(map)).toList();
  }

  /// Gets a sentence by ID.
  Future<SentenceModel?> getById(String id) async {
    final db = await _database.database;
    final results = await db.query(
      'sentences',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SentenceModel.fromMap(results.first);
  }

  /// Gets a sentence by project ID and index.
  Future<SentenceModel?> getByIndex(String projectId, int index) async {
    final db = await _database.database;
    final results = await db.query(
      'sentences',
      where: 'project_id = ? AND idx = ?',
      whereArgs: [projectId, index],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SentenceModel.fromMap(results.first);
  }

  /// Finds the sentence at a given audio position.
  Future<SentenceModel?> findAtPosition(
    String projectId,
    double positionSeconds,
  ) async {
    final db = await _database.database;
    final results = await db.query(
      'sentences',
      where: 'project_id = ? AND start_time <= ? AND end_time > ?',
      whereArgs: [projectId, positionSeconds, positionSeconds],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SentenceModel.fromMap(results.first);
  }

  /// Inserts a new sentence.
  Future<void> insert(SentenceModel sentence) async {
    final db = await _database.database;
    await db.insert(
      'sentences',
      sentence.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts multiple sentences in a batch.
  Future<void> insertBatch(List<SentenceModel> sentences) async {
    if (sentences.isEmpty) return;

    await _database.batch((batch) async {
      for (final sentence in sentences) {
        batch.insert(
          'sentences',
          sentence.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Deletes all sentences for a project.
  Future<int> deleteByProjectId(String projectId) async {
    final db = await _database.database;
    return db.delete(
      'sentences',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
  }

  /// Searches sentences by text.
  Future<List<SentenceModel>> search(String projectId, String query) async {
    final db = await _database.database;
    final results = await db.query(
      'sentences',
      where: 'project_id = ? AND text LIKE ?',
      whereArgs: [projectId, '%$query%'],
      orderBy: 'idx ASC',
    );
    return results.map((map) => SentenceModel.fromMap(map)).toList();
  }

  /// Gets the sentence count for a project.
  Future<int> countByProjectId(String projectId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sentences WHERE project_id = ?',
      [projectId],
    );
    return result.isNotEmpty ? (result.first.values.first as int? ?? 0) : 0;
  }

  /// Updates learning progress for a sentence.
  Future<int> updateLearningProgress(
    String id, {
    required bool learned,
    required int learnCount,
  }) async {
    final db = await _database.database;
    return db.update(
      'sentences',
      {
        'learned': learned ? 1 : 0,
        'learn_count': learnCount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggles is_difficult flag on a sentence atomically.
  ///
  /// Returns the new value of is_difficult (true if now difficult).
  Future<bool> toggleDifficult(String id) async {
    final db = await _database.database;
    await db.rawUpdate(
      'UPDATE sentences SET is_difficult = 1 - is_difficult WHERE id = ?',
      [id],
    );
    // Read back the new value
    final result = await db.query(
      'sentences',
      columns: ['is_difficult'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return false;
    return (result.first['is_difficult'] as int? ?? 0) == 1;
  }

  /// Gets all difficult sentences for a project.
  Future<List<SentenceModel>> getDifficultByProjectId(String projectId) async {
    final db = await _database.database;
    final results = await db.query(
      'sentences',
      where: 'project_id = ? AND is_difficult = 1',
      whereArgs: [projectId],
      orderBy: 'idx ASC',
    );
    return results.map((map) => SentenceModel.fromMap(map)).toList();
  }

  /// Records a review, incrementing review_count and updating last_reviewed.
  Future<int> recordReview(String id) async {
    final db = await _database.database;
    return db.rawUpdate(
      'UPDATE sentences SET review_count = review_count + 1, last_reviewed = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// Updates review-related fields for a sentence.
  Future<int> updateReviewProgress(
    String id, {
    required bool isDifficult,
    required int reviewCount,
    DateTime? lastReviewed,
  }) async {
    final db = await _database.database;
    return db.update(
      'sentences',
      {
        'is_difficult': isDifficult ? 1 : 0,
        'review_count': reviewCount,
        'last_reviewed': lastReviewed?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
