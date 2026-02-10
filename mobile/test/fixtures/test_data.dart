// Shared test data factories for unit tests.

import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';
import 'package:dutch_learn_app/domain/entities/drive_file.dart';
import 'package:dutch_learn_app/domain/entities/speaker.dart';

class TestData {
  static Project project({
    String id = 'test-project-id',
    String? sourceId,
    String name = 'Test Project',
    int totalSentences = 10,
    String? audioPath,
    DateTime? importedAt,
    DateTime? lastPlayedAt,
    int lastSentenceIndex = 0,
  }) {
    return Project(
      id: id,
      sourceId: sourceId,
      name: name,
      totalSentences: totalSentences,
      audioPath: audioPath,
      importedAt: importedAt ?? DateTime(2026, 1, 15),
      lastPlayedAt: lastPlayedAt,
      lastSentenceIndex: lastSentenceIndex,
    );
  }

  static Keyword keyword({
    String id = 'kw-1',
    String sentenceId = 'sent-1',
    String word = 'fiets',
    String meaningNl = 'tweewieler',
    String meaningEn = 'bicycle',
  }) {
    return Keyword(
      id: id,
      sentenceId: sentenceId,
      word: word,
      meaningNl: meaningNl,
      meaningEn: meaningEn,
    );
  }

  static Sentence sentence({
    String id = 'sent-1',
    String projectId = 'test-project-id',
    int index = 0,
    String text = 'Hallo, hoe gaat het?',
    double startTime = 0.0,
    double endTime = 2.5,
    String? translationEn = 'Hello, how are you?',
    String? explanationNl,
    String? explanationEn,
    bool learned = false,
    int learnCount = 0,
    String? speakerId,
    bool isDifficult = false,
    int reviewCount = 0,
    DateTime? lastReviewed,
    List<Keyword>? keywords,
  }) {
    return Sentence(
      id: id,
      projectId: projectId,
      index: index,
      text: text,
      startTime: startTime,
      endTime: endTime,
      translationEn: translationEn,
      explanationNl: explanationNl,
      explanationEn: explanationEn,
      learned: learned,
      learnCount: learnCount,
      speakerId: speakerId,
      isDifficult: isDifficult,
      reviewCount: reviewCount,
      lastReviewed: lastReviewed,
      keywords: keywords ?? [],
    );
  }

  static DriveFile driveFile({
    String id = 'drive-file-1',
    String name = 'project.json',
    String mimeType = 'application/json',
    int? size = 1024,
    bool isFolder = false,
  }) {
    return DriveFile(
      id: id,
      name: name,
      mimeType: mimeType,
      size: size,
      isFolder: isFolder,
    );
  }

  static Speaker speaker({
    String id = 'speaker-1',
    String projectId = 'test-project-id',
    String label = 'A',
    String? displayName,
    double confidence = 0.0,
    String? evidence,
    bool isManual = false,
  }) {
    return Speaker(
      id: id,
      projectId: projectId,
      label: label,
      displayName: displayName,
      confidence: confidence,
      evidence: evidence,
      isManual: isManual,
    );
  }

  /// Standard import JSON matching v1.0 schema.
  static Map<String, dynamic> importJson({
    String projectId = 'source-project-id',
    String projectName = 'Import Test',
    int sentenceCount = 2,
    bool includeSpeakers = false,
  }) {
    final json = <String, dynamic>{
      'version': '1.0',
      'exported_at': '2026-01-15T10:00:00',
      'project': {
        'id': projectId,
        'name': projectName,
        'status': 'ready',
        'total_sentences': sentenceCount,
        'created_at': '2026-01-15T10:00:00',
      },
      'sentences': List.generate(sentenceCount, (i) {
        return {
          'index': i,
          'text': 'Zin ${i + 1}',
          'start_time': i * 2.0,
          'end_time': (i + 1) * 2.0,
          'translation_en': 'Sentence ${i + 1}',
          'explanation_nl': null,
          'explanation_en': null,
          'speaker_id': includeSpeakers ? 'speaker-${i % 2 + 1}' : null,
          'is_difficult': false,
          'review_count': 0,
          'last_reviewed': null,
          'keywords': [
            {
              'word': 'woord$i',
              'meaning_nl': 'betekenis $i',
              'meaning_en': 'meaning $i',
            }
          ],
        };
      }),
    };
    if (includeSpeakers) {
      json['speakers'] = [
        {
          'id': 'speaker-1',
          'label': 'A',
          'display_name': null,
          'confidence': 0.95,
          'evidence': null,
          'is_manual': false,
        },
        {
          'id': 'speaker-2',
          'label': 'B',
          'display_name': null,
          'confidence': 0.87,
          'evidence': null,
          'is_manual': false,
        },
      ];
    }
    return json;
  }
}
