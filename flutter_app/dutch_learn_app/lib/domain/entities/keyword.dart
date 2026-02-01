import 'package:flutter/foundation.dart';

/// Represents a vocabulary word (keyword) in a sentence.
///
/// Keywords are important words within a sentence that have
/// additional meaning explanations in Dutch and English.
@immutable
class Keyword {
  /// Unique identifier for the keyword.
  final String id;

  /// ID of the sentence this keyword belongs to.
  final String sentenceId;

  /// The Dutch word.
  final String word;

  /// Meaning/explanation in Dutch.
  final String meaningNl;

  /// Meaning/explanation in English.
  final String meaningEn;

  /// Creates a new Keyword instance.
  const Keyword({
    required this.id,
    required this.sentenceId,
    required this.word,
    required this.meaningNl,
    required this.meaningEn,
  });

  /// Creates a copy of this keyword with the given fields replaced.
  Keyword copyWith({
    String? id,
    String? sentenceId,
    String? word,
    String? meaningNl,
    String? meaningEn,
  }) {
    return Keyword(
      id: id ?? this.id,
      sentenceId: sentenceId ?? this.sentenceId,
      word: word ?? this.word,
      meaningNl: meaningNl ?? this.meaningNl,
      meaningEn: meaningEn ?? this.meaningEn,
    );
  }

  /// Returns the word in lowercase for comparison.
  String get wordLower => word.toLowerCase();

  /// Returns true if this keyword matches the given word (case insensitive).
  bool matches(String searchWord) {
    return word.toLowerCase() == searchWord.toLowerCase();
  }

  /// Returns true if this keyword contains the given substring.
  bool contains(String substring) {
    return word.toLowerCase().contains(substring.toLowerCase());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Keyword &&
        other.id == id &&
        other.sentenceId == sentenceId &&
        other.word == word &&
        other.meaningNl == meaningNl &&
        other.meaningEn == meaningEn;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      sentenceId,
      word,
      meaningNl,
      meaningEn,
    );
  }

  @override
  String toString() {
    return 'Keyword(word: $word, meaningEn: $meaningEn)';
  }
}
