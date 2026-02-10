import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Helper to query table column names via PRAGMA table_info.
Future<List<String>> _getColumnNames(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((r) => r['name'] as String).toList();
}

/// Helper to check if a table exists.
Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    [table],
  );
  return rows.isNotEmpty;
}

/// Replays the full v3 _onCreate logic from database.dart.
Future<void> _createV3Schema(Database db) async {
  await db.execute('''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      source_id TEXT,
      name TEXT NOT NULL,
      total_sentences INTEGER NOT NULL DEFAULT 0,
      audio_path TEXT,
      imported_at TEXT NOT NULL,
      last_played_at TEXT,
      last_sentence_index INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE sentences (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      idx INTEGER NOT NULL,
      text TEXT NOT NULL,
      start_time REAL NOT NULL,
      end_time REAL NOT NULL,
      translation_en TEXT,
      explanation_nl TEXT,
      explanation_en TEXT,
      learned INTEGER NOT NULL DEFAULT 0,
      learn_count INTEGER NOT NULL DEFAULT 0,
      speaker_id TEXT,
      is_difficult INTEGER NOT NULL DEFAULT 0,
      review_count INTEGER NOT NULL DEFAULT 0,
      last_reviewed TEXT,
      FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE TABLE keywords (
      id TEXT PRIMARY KEY,
      sentence_id TEXT NOT NULL,
      word TEXT NOT NULL,
      meaning_nl TEXT NOT NULL,
      meaning_en TEXT NOT NULL,
      FOREIGN KEY (sentence_id) REFERENCES sentences (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE TABLE speakers (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      label TEXT NOT NULL,
      display_name TEXT,
      confidence REAL NOT NULL DEFAULT 0.0,
      evidence TEXT,
      is_manual INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
    )
  ''');
}

/// Replays the v1 schema (original, before any migrations).
Future<void> _createV1Schema(Database db) async {
  await db.execute('''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      source_id TEXT,
      name TEXT NOT NULL,
      total_sentences INTEGER NOT NULL DEFAULT 0,
      audio_path TEXT,
      imported_at TEXT NOT NULL,
      last_played_at TEXT,
      last_sentence_index INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE sentences (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      idx INTEGER NOT NULL,
      text TEXT NOT NULL,
      start_time REAL NOT NULL,
      end_time REAL NOT NULL,
      translation_en TEXT,
      explanation_nl TEXT,
      explanation_en TEXT,
      FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE TABLE keywords (
      id TEXT PRIMARY KEY,
      sentence_id TEXT NOT NULL,
      word TEXT NOT NULL,
      meaning_nl TEXT NOT NULL,
      meaning_en TEXT NOT NULL,
      FOREIGN KEY (sentence_id) REFERENCES sentences (id) ON DELETE CASCADE
    )
  ''');
}

/// Replays the _onUpgrade logic from database.dart.
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      'ALTER TABLE sentences ADD COLUMN learned INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE sentences ADD COLUMN learn_count INTEGER NOT NULL DEFAULT 0',
    );
  }
  if (oldVersion < 3) {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS speakers (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        label TEXT NOT NULL,
        display_name TEXT,
        confidence REAL NOT NULL DEFAULT 0.0,
        evidence TEXT,
        is_manual INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_speakers_project ON speakers (project_id)',
    );
    await db.execute('ALTER TABLE sentences ADD COLUMN speaker_id TEXT');
    await db.execute(
      'ALTER TABLE sentences ADD COLUMN is_difficult INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE sentences ADD COLUMN review_count INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE sentences ADD COLUMN last_reviewed TEXT');
  }
}

void main() {
  // Initialize FFI for desktop test runner.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Database schema', () {
    test('fresh v3 creation has all tables and columns', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) => _createV3Schema(db),
        ),
      );

      try {
        // Verify all 4 tables exist.
        expect(await _tableExists(db, 'projects'), isTrue);
        expect(await _tableExists(db, 'sentences'), isTrue);
        expect(await _tableExists(db, 'keywords'), isTrue);
        expect(await _tableExists(db, 'speakers'), isTrue);

        // Verify sentences table has all expected columns.
        final sentenceCols = await _getColumnNames(db, 'sentences');
        for (final col in [
          'id',
          'project_id',
          'idx',
          'text',
          'start_time',
          'end_time',
          'translation_en',
          'explanation_nl',
          'explanation_en',
          'learned',
          'learn_count',
          'speaker_id',
          'is_difficult',
          'review_count',
          'last_reviewed',
        ]) {
          expect(sentenceCols, contains(col));
        }

        // Verify speakers table has all expected columns.
        final speakerCols = await _getColumnNames(db, 'speakers');
        for (final col in [
          'id',
          'project_id',
          'label',
          'display_name',
          'confidence',
          'evidence',
          'is_manual',
        ]) {
          expect(speakerCols, contains(col));
        }
      } finally {
        await db.close();
      }
    });

    test('v1 to v3 migration adds all new columns and tables', () async {
      // Use a temp file so we can close and reopen the same database.
      final tmpDir = await Directory.systemTemp.createTemp('db_test_');
      final dbPath = '${tmpDir.path}/test_migration.db';

      try {
        // Step 1: Create a v1 database with original schema.
        var db = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) => _createV1Schema(db),
          ),
        );

        // Confirm v1 state: no speakers table, no learned column.
        expect(await _tableExists(db, 'speakers'), isFalse);
        final v1Cols = await _getColumnNames(db, 'sentences');
        expect(v1Cols, isNot(contains('learned')));
        expect(v1Cols, isNot(contains('learn_count')));
        expect(v1Cols, isNot(contains('speaker_id')));

        await db.close();

        // Step 2: Reopen at v3 with migration logic.
        db = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 3,
            onUpgrade: _onUpgrade,
          ),
        );

        // Verify speakers table was created.
        expect(await _tableExists(db, 'speakers'), isTrue);

        final speakerCols = await _getColumnNames(db, 'speakers');
        for (final col in [
          'id',
          'project_id',
          'label',
          'display_name',
          'confidence',
          'evidence',
          'is_manual',
        ]) {
          expect(speakerCols, contains(col));
        }

        // Verify all new sentence columns were added.
        final sentenceCols = await _getColumnNames(db, 'sentences');
        for (final col in [
          'learned',
          'learn_count',
          'speaker_id',
          'is_difficult',
          'review_count',
          'last_reviewed',
        ]) {
          expect(sentenceCols, contains(col));
        }

        await db.close();
      } finally {
        // Clean up temp directory.
        await tmpDir.delete(recursive: true);
      }
    });
  });
}
