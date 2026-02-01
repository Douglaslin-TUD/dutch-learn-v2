import 'package:dutch_learn_app/domain/entities/project.dart';

/// Data model for Project with database mapping.
class ProjectModel extends Project {
  const ProjectModel({
    required super.id,
    super.sourceId,
    required super.name,
    required super.totalSentences,
    super.audioPath,
    required super.importedAt,
    super.lastPlayedAt,
    super.lastSentenceIndex,
  });

  /// Creates a ProjectModel from a database map.
  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as String,
      sourceId: map['source_id'] as String?,
      name: map['name'] as String,
      totalSentences: map['total_sentences'] as int? ?? 0,
      audioPath: map['audio_path'] as String?,
      importedAt: DateTime.parse(map['imported_at'] as String),
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.parse(map['last_played_at'] as String)
          : null,
      lastSentenceIndex: map['last_sentence_index'] as int?,
    );
  }

  /// Creates a ProjectModel from a JSON map (import format).
  factory ProjectModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
    String? audioPath,
  }) {
    final projectJson = json['project'] as Map<String, dynamic>? ?? json;
    return ProjectModel(
      id: id,
      sourceId: projectJson['id'] as String?,
      name: projectJson['name'] as String? ?? 'Unnamed Project',
      totalSentences: projectJson['total_sentences'] as int? ?? 0,
      audioPath: audioPath,
      importedAt: DateTime.now(),
      lastPlayedAt: null,
      lastSentenceIndex: null,
    );
  }

  /// Creates a ProjectModel from a domain entity.
  factory ProjectModel.fromEntity(Project project) {
    return ProjectModel(
      id: project.id,
      sourceId: project.sourceId,
      name: project.name,
      totalSentences: project.totalSentences,
      audioPath: project.audioPath,
      importedAt: project.importedAt,
      lastPlayedAt: project.lastPlayedAt,
      lastSentenceIndex: project.lastSentenceIndex,
    );
  }

  /// Converts to a database map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_id': sourceId,
      'name': name,
      'total_sentences': totalSentences,
      'audio_path': audioPath,
      'imported_at': importedAt.toIso8601String(),
      'last_played_at': lastPlayedAt?.toIso8601String(),
      'last_sentence_index': lastSentenceIndex,
    };
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'name': name,
      'total_sentences': totalSentences,
      'audio_path': audioPath,
      'imported_at': importedAt.toIso8601String(),
      'last_played_at': lastPlayedAt?.toIso8601String(),
      'last_sentence_index': lastSentenceIndex,
    };
  }

  /// Converts to a domain entity.
  Project toEntity() {
    return Project(
      id: id,
      sourceId: sourceId,
      name: name,
      totalSentences: totalSentences,
      audioPath: audioPath,
      importedAt: importedAt,
      lastPlayedAt: lastPlayedAt,
      lastSentenceIndex: lastSentenceIndex,
    );
  }

  @override
  ProjectModel copyWith({
    String? id,
    String? sourceId,
    String? name,
    int? totalSentences,
    String? audioPath,
    DateTime? importedAt,
    DateTime? lastPlayedAt,
    int? lastSentenceIndex,
  }) {
    return ProjectModel(
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
}
