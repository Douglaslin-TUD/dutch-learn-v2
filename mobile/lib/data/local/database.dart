import 'package:path/path.dart';
import 'package:sqflite_common/sqflite.dart';

import 'package:dutch_learn_app/core/constants/app_constants.dart';

/// Database helper class for SQLite operations.
///
/// Manages database creation, migrations, and provides
/// access to the database instance.
class AppDatabase {
  static Database? _database;
  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase() => _instance;

  AppDatabase._internal();

  /// Gets the database instance, creating it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create projects table
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

    // Create sentences table
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

    // Create keywords table
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

    // Create speakers table
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

    // Create indexes for performance
    await db.execute(
      'CREATE INDEX idx_sentences_project ON sentences (project_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sentences_idx ON sentences (project_id, idx)',
    );
    await db.execute(
      'CREATE INDEX idx_keywords_sentence ON keywords (sentence_id)',
    );
    await db.execute(
      'CREATE INDEX idx_projects_source ON projects (source_id)',
    );
    await db.execute(
      'CREATE INDEX idx_speakers_project ON speakers (project_id)',
    );
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sentences ADD COLUMN learned INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE sentences ADD COLUMN learn_count INTEGER NOT NULL DEFAULT 0');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_speakers_project ON speakers (project_id)');
      await db.execute('ALTER TABLE sentences ADD COLUMN speaker_id TEXT');
      await db.execute('ALTER TABLE sentences ADD COLUMN is_difficult INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE sentences ADD COLUMN review_count INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE sentences ADD COLUMN last_reviewed TEXT');
    }
  }

  /// Closes the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Deletes the database file.
  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// Runs a batch of operations in a transaction.
  Future<void> batch(Future<void> Function(Batch batch) action) async {
    final db = await database;
    final batch = db.batch();
    await action(batch);
    await batch.commit(noResult: true);
  }

  /// Runs operations in a transaction.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }
}
