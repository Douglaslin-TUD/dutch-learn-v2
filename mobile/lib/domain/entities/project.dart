import 'package:flutter/foundation.dart';

/// Represents a Dutch learning project.
///
/// A project contains a collection of sentences with audio and
/// optional translations, explanations, and vocabulary.
@immutable
class Project {
  /// Unique identifier for the project.
  final String id;

  /// Source ID from the imported JSON (if available).
  final String? sourceId;

  /// Display name of the project.
  final String name;

  /// Total number of sentences in the project.
  final int totalSentences;

  /// Local path to the audio file (if downloaded).
  final String? audioPath;

  /// When the project was imported.
  final DateTime importedAt;

  /// When the project was last played.
  final DateTime? lastPlayedAt;

  /// Index of the last sentence that was played.
  final int? lastSentenceIndex;

  /// Creates a new Project instance.
  const Project({
    required this.id,
    this.sourceId,
    required this.name,
    required this.totalSentences,
    this.audioPath,
    required this.importedAt,
    this.lastPlayedAt,
    this.lastSentenceIndex,
  });

  /// Creates a copy of this project with the given fields replaced.
  Project copyWith({
    String? id,
    String? sourceId,
    String? name,
    int? totalSentences,
    String? audioPath,
    DateTime? importedAt,
    DateTime? lastPlayedAt,
    int? lastSentenceIndex,
  }) {
    return Project(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      totalSentences: totalSentences ?? this.totalSentences,
      audioPath: audioPath ?? this.audioPath,
      importedAt: importedAt ?? this.importedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastSentenceIndex: lastSentenceIndex ?? this.lastSentenceIndex,
    );
  }

  /// Returns true if the project has an audio file.
  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  /// Returns true if the project has been played before.
  bool get hasBeenPlayed => lastPlayedAt != null;

  /// Returns the progress percentage (0-100).
  double get progressPercent {
    if (lastSentenceIndex == null || totalSentences == 0) return 0;
    return ((lastSentenceIndex! + 1) / totalSentences) * 100;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Project &&
        other.id == id &&
        other.sourceId == sourceId &&
        other.name == name &&
        other.totalSentences == totalSentences &&
        other.audioPath == audioPath &&
        other.importedAt == importedAt &&
        other.lastPlayedAt == lastPlayedAt &&
        other.lastSentenceIndex == lastSentenceIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      sourceId,
      name,
      totalSentences,
      audioPath,
      importedAt,
      lastPlayedAt,
      lastSentenceIndex,
    );
  }

  @override
  String toString() {
    return 'Project(id: $id, name: $name, totalSentences: $totalSentences)';
  }
}
