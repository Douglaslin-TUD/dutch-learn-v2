import 'package:sqflite_common/sqflite.dart';

import 'package:dutch_learn_app/data/local/database.dart';
import 'package:dutch_learn_app/data/models/speaker_model.dart';

/// Data Access Object for speaker database operations.
class SpeakerDao {
  final AppDatabase _database;

  SpeakerDao(this._database);

  /// Gets all speakers for a project ordered by label.
  Future<List<SpeakerModel>> getByProjectId(String projectId) async {
    final db = await _database.database;
    final results = await db.query(
      'speakers',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'label ASC',
    );
    return results.map((map) => SpeakerModel.fromMap(map)).toList();
  }

  /// Gets a speaker by ID.
  Future<SpeakerModel?> getById(String id) async {
    final db = await _database.database;
    final results = await db.query(
      'speakers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SpeakerModel.fromMap(results.first);
  }

  /// Inserts a new speaker.
  Future<void> insert(SpeakerModel speaker) async {
    final db = await _database.database;
    await db.insert(
      'speakers',
      speaker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts multiple speakers in a batch.
  Future<void> insertBatch(List<SpeakerModel> speakers) async {
    if (speakers.isEmpty) return;
    await _database.batch((batch) async {
      for (final speaker in speakers) {
        batch.insert(
          'speakers',
          speaker.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Updates a speaker's display name.
  Future<int> updateDisplayName(String id, String name) async {
    final db = await _database.database;
    return db.update(
      'speakers',
      {'display_name': name, 'is_manual': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes all speakers for a project.
  Future<int> deleteByProjectId(String projectId) async {
    final db = await _database.database;
    return db.delete(
      'speakers',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
  }
}
