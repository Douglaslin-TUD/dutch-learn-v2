import 'package:flutter/foundation.dart';

import 'package:dutch_learn_app/domain/entities/keyword.dart';

/// Represents a sentence in a Dutch learning project.
///
/// Each sentence has timing information for audio playback,
/// optional translations, explanations, and associated keywords.
@immutable
class Sentence {
  /// Unique identifier for the sentence.
  final String id;

  /// ID of the project this sentence belongs to.
  final String projectId;

  /// Zero-based index of the sentence within the project.
  final int index;

  /// The Dutch text of the sentence.
  final String text;

  /// Start time in seconds for audio playback.
  final double startTime;

  /// End time in seconds for audio playback.
  final double endTime;

  /// English translation of the sentence.
  final String? translationEn;

  /// Explanation in Dutch.
  final String? explanationNl;

  /// Explanation in English.
  final String? explanationEn;

  /// List of keywords/vocabulary in this sentence.
  final List<Keyword> keywords;

  /// Creates a new Sentence instance.
  const Sentence({
    required this.id,
    required this.projectId,
    required this.index,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.translationEn,
    this.explanationNl,
    this.explanationEn,
    this.keywords = const [],
  });

  /// Creates a copy of this sentence with the given fields replaced.
  Sentence copyWith({
    String? id,
    String? projectId,
    int? index,
    String? text,
    double? startTime,
    double? endTime,
    String? translationEn,
    String? explanationNl,
    String? explanationEn,
    List<Keyword>? keywords,
  }) {
    return Sentence(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      index: index ?? this.index,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      translationEn: translationEn ?? this.translationEn,
      explanationNl: explanationNl ?? this.explanationNl,
      explanationEn: explanationEn ?? this.explanationEn,
      keywords: keywords ?? this.keywords,
    );
  }

  /// Returns the duration of this sentence in seconds.
  double get duration => endTime - startTime;

  /// Returns the duration as a [Duration] object.
  Duration get durationAsDuration {
    return Duration(milliseconds: (duration * 1000).round());
  }

  /// Returns the start time as a [Duration] object.
  Duration get startTimeAsDuration {
    return Duration(milliseconds: (startTime * 1000).round());
  }

  /// Returns the end time as a [Duration] object.
  Duration get endTimeAsDuration {
    return Duration(milliseconds: (endTime * 1000).round());
  }

  /// Returns true if this sentence has a translation.
  bool get hasTranslation =>
      translationEn != null && translationEn!.isNotEmpty;

  /// Returns true if this sentence has explanations.
  bool get hasExplanation =>
      (explanationNl != null && explanationNl!.isNotEmpty) ||
      (explanationEn != null && explanationEn!.isNotEmpty);

  /// Returns true if this sentence has keywords.
  bool get hasKeywords => keywords.isNotEmpty;

  /// Returns the display number (1-based index).
  int get displayNumber => index + 1;

  /// Returns the words in this sentence.
  List<String> get words {
    // Split by whitespace and common punctuation
    return text.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Finds a keyword that matches the given word.
  ///
  /// Returns null if no match is found.
  Keyword? findKeyword(String word) {
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
    for (final keyword in keywords) {
      if (keyword.word.toLowerCase() == cleanWord) {
        return keyword;
      }
    }
    return null;
  }

  /// Checks if a word is a keyword in this sentence.
  bool isKeyword(String word) {
    return findKeyword(word) != null;
  }

  /// Checks if a given position (in seconds) is within this sentence.
  bool containsPosition(double position) {
    return position >= startTime && position < endTime;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Sentence &&
        other.id == id &&
        other.projectId == projectId &&
        other.index == index &&
        other.text == text &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.translationEn == translationEn &&
        other.explanationNl == explanationNl &&
        other.explanationEn == explanationEn &&
        listEquals(other.keywords, keywords);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      projectId,
      index,
      text,
      startTime,
      endTime,
      translationEn,
      explanationNl,
      explanationEn,
      Object.hashAll(keywords),
    );
  }

  @override
  String toString() {
    return 'Sentence(index: $index, text: ${text.length > 50 ? '${text.substring(0, 50)}...' : text})';
  }
}
