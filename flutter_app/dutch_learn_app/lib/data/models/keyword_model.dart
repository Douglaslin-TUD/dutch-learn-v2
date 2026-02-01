import 'package:dutch_learn_app/domain/entities/keyword.dart';

/// Data model for Keyword with database mapping.
class KeywordModel extends Keyword {
  const KeywordModel({
    required super.id,
    required super.sentenceId,
    required super.word,
    required super.meaningNl,
    required super.meaningEn,
  });

  /// Creates a KeywordModel from a database map.
  factory KeywordModel.fromMap(Map<String, dynamic> map) {
    return KeywordModel(
      id: map['id'] as String,
      sentenceId: map['sentence_id'] as String,
      word: map['word'] as String,
      meaningNl: map['meaning_nl'] as String,
      meaningEn: map['meaning_en'] as String,
    );
  }

  /// Creates a KeywordModel from a JSON map (import format).
  factory KeywordModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
    required String sentenceId,
  }) {
    return KeywordModel(
      id: id,
      sentenceId: sentenceId,
      word: json['word'] as String? ?? '',
      meaningNl: json['meaning_nl'] as String? ?? '',
      meaningEn: json['meaning_en'] as String? ?? '',
    );
  }

  /// Creates a KeywordModel from a domain entity.
  factory KeywordModel.fromEntity(Keyword keyword) {
    return KeywordModel(
      id: keyword.id,
      sentenceId: keyword.sentenceId,
      word: keyword.word,
      meaningNl: keyword.meaningNl,
      meaningEn: keyword.meaningEn,
    );
  }

  /// Converts to a database map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sentence_id': sentenceId,
      'word': word,
      'meaning_nl': meaningNl,
      'meaning_en': meaningEn,
    };
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sentence_id': sentenceId,
      'word': word,
      'meaning_nl': meaningNl,
      'meaning_en': meaningEn,
    };
  }

  /// Converts to a domain entity.
  Keyword toEntity() {
    return Keyword(
      id: id,
      sentenceId: sentenceId,
      word: word,
      meaningNl: meaningNl,
      meaningEn: meaningEn,
    );
  }

  @override
  KeywordModel copyWith({
    String? id,
    String? sentenceId,
    String? word,
    String? meaningNl,
    String? meaningEn,
  }) {
    return KeywordModel(
      id: id ?? this.id,
      sentenceId: sentenceId ?? this.sentenceId,
      word: word ?? this.word,
      meaningNl: meaningNl ?? this.meaningNl,
      meaningEn: meaningEn ?? this.meaningEn,
    );
  }
}
