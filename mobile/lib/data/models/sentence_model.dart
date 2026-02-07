import 'package:dutch_learn_app/data/models/keyword_model.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';

/// Data model for Sentence with database mapping.
class SentenceModel extends Sentence {
  const SentenceModel({
    required super.id,
    required super.projectId,
    required super.index,
    required super.text,
    required super.startTime,
    required super.endTime,
    super.translationEn,
    super.explanationNl,
    super.explanationEn,
    super.learned = false,
    super.learnCount = 0,
    super.keywords = const [],
  });

  /// Creates a SentenceModel from a database map.
  ///
  /// Keywords are not included and should be loaded separately.
  factory SentenceModel.fromMap(Map<String, dynamic> map) {
    return SentenceModel(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      index: map['idx'] as int,
      text: map['text'] as String,
      startTime: (map['start_time'] as num).toDouble(),
      endTime: (map['end_time'] as num).toDouble(),
      translationEn: map['translation_en'] as String?,
      explanationNl: map['explanation_nl'] as String?,
      explanationEn: map['explanation_en'] as String?,
      learned: (map['learned'] as int? ?? 0) == 1,
      learnCount: map['learn_count'] as int? ?? 0,
      keywords: const [],
    );
  }

  /// Creates a SentenceModel from a JSON map (import format).
  factory SentenceModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
    required String projectId,
  }) {
    return SentenceModel(
      id: id,
      projectId: projectId,
      index: json['index'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      startTime: (json['start_time'] as num?)?.toDouble() ?? 0.0,
      endTime: (json['end_time'] as num?)?.toDouble() ?? 0.0,
      translationEn: json['translation_en'] as String?,
      explanationNl: json['explanation_nl'] as String?,
      explanationEn: json['explanation_en'] as String?,
      learned: json['learned'] as bool? ?? false,
      learnCount: json['learn_count'] as int? ?? 0,
      keywords: const [],
    );
  }

  /// Creates a SentenceModel from a domain entity.
  factory SentenceModel.fromEntity(Sentence sentence) {
    return SentenceModel(
      id: sentence.id,
      projectId: sentence.projectId,
      index: sentence.index,
      text: sentence.text,
      startTime: sentence.startTime,
      endTime: sentence.endTime,
      translationEn: sentence.translationEn,
      explanationNl: sentence.explanationNl,
      explanationEn: sentence.explanationEn,
      learned: sentence.learned,
      learnCount: sentence.learnCount,
      keywords: sentence.keywords,
    );
  }

  /// Converts to a database map.
  ///
  /// Keywords are stored separately.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'idx': index,
      'text': text,
      'start_time': startTime,
      'end_time': endTime,
      'translation_en': translationEn,
      'explanation_nl': explanationNl,
      'explanation_en': explanationEn,
      'learned': learned ? 1 : 0,
      'learn_count': learnCount,
    };
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'index': index,
      'text': text,
      'start_time': startTime,
      'end_time': endTime,
      'translation_en': translationEn,
      'explanation_nl': explanationNl,
      'explanation_en': explanationEn,
      'learned': learned,
      'learn_count': learnCount,
      'keywords': keywords.map((k) => KeywordModel.fromEntity(k).toJson()).toList(),
    };
  }

  /// Converts to a domain entity.
  Sentence toEntity() {
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
      keywords: keywords,
    );
  }

  /// Creates a copy with the given keywords.
  SentenceModel withKeywords(List<Keyword> keywords) {
    return SentenceModel(
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
      keywords: keywords,
    );
  }

  @override
  SentenceModel copyWith({
    String? id,
    String? projectId,
    int? index,
    String? text,
    double? startTime,
    double? endTime,
    String? translationEn,
    String? explanationNl,
    String? explanationEn,
    bool? learned,
    int? learnCount,
    List<Keyword>? keywords,
  }) {
    return SentenceModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      index: index ?? this.index,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      translationEn: translationEn ?? this.translationEn,
      explanationNl: explanationNl ?? this.explanationNl,
      explanationEn: explanationEn ?? this.explanationEn,
      learned: learned ?? this.learned,
      learnCount: learnCount ?? this.learnCount,
      keywords: keywords ?? this.keywords,
    );
  }
}
