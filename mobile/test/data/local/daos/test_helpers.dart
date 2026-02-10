/// Test helpers for DAO tests.
///
/// Provides in-memory SQLite database creation using sqflite_common_ffi
/// for desktop test execution with the full v3 schema.
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Creates an in-memory SQLite database with the full v3 schema.
///
/// Uses sqflite_common_ffi for desktop test execution. The database
/// has foreign keys enabled and includes all 4 tables (projects,
/// sentences, keywords, speakers) plus indexes.
Future<Database> createTestDatabase() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
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
      },
    ),
  );

  return db;
}

/// Inserts a test project row into the database.
///
/// Returns the project id for convenience.
Future<String> insertTestProject(
  Database db, {
  String id = 'proj-1',
  String? sourceId,
  String name = 'Test Project',
  int totalSentences = 0,
  String? audioPath,
  String importedAt = '2026-01-15T10:00:00.000',
  String? lastPlayedAt,
  int? lastSentenceIndex,
}) async {
  await db.insert('projects', {
    'id': id,
    'source_id': sourceId,
    'name': name,
    'total_sentences': totalSentences,
    'audio_path': audioPath,
    'imported_at': importedAt,
    'last_played_at': lastPlayedAt,
    'last_sentence_index': lastSentenceIndex,
  });
  return id;
}

/// Inserts a test sentence row into the database.
///
/// Returns the sentence id for convenience.
Future<String> insertTestSentence(
  Database db, {
  String id = 'sent-1',
  String projectId = 'proj-1',
  int idx = 0,
  String text = 'Hallo, hoe gaat het?',
  double startTime = 0.0,
  double endTime = 2.5,
  String? translationEn = 'Hello, how are you?',
  String? explanationNl,
  String? explanationEn,
  int learned = 0,
  int learnCount = 0,
  String? speakerId,
  int isDifficult = 0,
  int reviewCount = 0,
  String? lastReviewed,
}) async {
  await db.insert('sentences', {
    'id': id,
    'project_id': projectId,
    'idx': idx,
    'text': text,
    'start_time': startTime,
    'end_time': endTime,
    'translation_en': translationEn,
    'explanation_nl': explanationNl,
    'explanation_en': explanationEn,
    'learned': learned,
    'learn_count': learnCount,
    'speaker_id': speakerId,
    'is_difficult': isDifficult,
    'review_count': reviewCount,
    'last_reviewed': lastReviewed,
  });
  return id;
}

/// Inserts a test keyword row into the database.
///
/// Returns the keyword id for convenience.
Future<String> insertTestKeyword(
  Database db, {
  String id = 'kw-1',
  String sentenceId = 'sent-1',
  String word = 'fiets',
  String meaningNl = 'tweewieler',
  String meaningEn = 'bicycle',
}) async {
  await db.insert('keywords', {
    'id': id,
    'sentence_id': sentenceId,
    'word': word,
    'meaning_nl': meaningNl,
    'meaning_en': meaningEn,
  });
  return id;
}

/// Inserts a test speaker row into the database.
///
/// Returns the speaker id for convenience.
Future<String> insertTestSpeaker(
  Database db, {
  String id = 'spk-1',
  String projectId = 'proj-1',
  String label = 'A',
  String? displayName,
  double confidence = 0.9,
  String? evidence,
  int isManual = 0,
}) async {
  await db.insert('speakers', {
    'id': id,
    'project_id': projectId,
    'label': label,
    'display_name': displayName,
    'confidence': confidence,
    'evidence': evidence,
    'is_manual': isManual,
  });
  return id;
}
