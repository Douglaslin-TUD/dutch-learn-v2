import 'package:sqflite_common/sqflite.dart';

import 'package:dutch_learn_app/data/local/database.dart';
import 'package:dutch_learn_app/data/models/project_model.dart';

/// Data Access Object for project database operations.
class ProjectDao {
  final AppDatabase _database;

  ProjectDao(this._database);

  /// Gets all projects ordered by last played date.
  Future<List<ProjectModel>> getAll() async {
    final db = await _database.database;
    final results = await db.query(
      'projects',
      orderBy: 'last_played_at DESC, imported_at DESC',
    );
    return results.map((map) => ProjectModel.fromMap(map)).toList();
  }

  /// Gets a project by ID.
  Future<ProjectModel?> getById(String id) async {
    final db = await _database.database;
    final results = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ProjectModel.fromMap(results.first);
  }

  /// Gets a project by source ID.
  Future<ProjectModel?> getBySourceId(String sourceId) async {
    final db = await _database.database;
    final results = await db.query(
      'projects',
      where: 'source_id = ?',
      whereArgs: [sourceId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ProjectModel.fromMap(results.first);
  }

  /// Inserts a new project.
  Future<void> insert(ProjectModel project) async {
    final db = await _database.database;
    await db.insert(
      'projects',
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing project.
  Future<int> update(ProjectModel project) async {
    final db = await _database.database;
    return db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  /// Updates the last played information.
  Future<int> updateLastPlayed(
    String id,
    DateTime lastPlayedAt,
    int lastSentenceIndex,
  ) async {
    final db = await _database.database;
    return db.update(
      'projects',
      {
        'last_played_at': lastPlayedAt.toIso8601String(),
        'last_sentence_index': lastSentenceIndex,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a project by ID.
  Future<int> delete(String id) async {
    final db = await _database.database;
    return db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Checks if a project with the given source ID exists.
  Future<bool> existsBySourceId(String sourceId) async {
    final db = await _database.database;
    final results = await db.query(
      'projects',
      columns: ['id'],
      where: 'source_id = ?',
      whereArgs: [sourceId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Gets the count of all projects.
  Future<int> count() async {
    final db = await _database.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM projects');
    return result.isNotEmpty ? (result.first.values.first as int? ?? 0) : 0;
  }
}
