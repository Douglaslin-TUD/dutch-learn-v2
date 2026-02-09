import 'package:dutch_learn_app/domain/entities/speaker.dart';

/// Data model for Speaker with database mapping.
class SpeakerModel extends Speaker {
  const SpeakerModel({
    required super.id,
    required super.projectId,
    required super.label,
    super.displayName,
    super.confidence = 0.0,
    super.evidence,
    super.isManual = false,
  });

  /// Creates a SpeakerModel from a database map.
  factory SpeakerModel.fromMap(Map<String, dynamic> map) {
    return SpeakerModel(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      label: map['label'] as String,
      displayName: map['display_name'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      evidence: map['evidence'] as String?,
      isManual: (map['is_manual'] as int? ?? 0) == 1,
    );
  }

  /// Creates a SpeakerModel from a JSON map (import format).
  factory SpeakerModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
    required String projectId,
  }) {
    return SpeakerModel(
      id: id,
      projectId: projectId,
      label: json['label'] as String? ?? '',
      displayName: json['display_name'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      evidence: json['evidence'] as String?,
      isManual: json['is_manual'] as bool? ?? false,
    );
  }

  /// Creates a SpeakerModel from a domain entity.
  factory SpeakerModel.fromEntity(Speaker speaker) {
    return SpeakerModel(
      id: speaker.id,
      projectId: speaker.projectId,
      label: speaker.label,
      displayName: speaker.displayName,
      confidence: speaker.confidence,
      evidence: speaker.evidence,
      isManual: speaker.isManual,
    );
  }

  /// Converts to a database map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'label': label,
      'display_name': displayName,
      'confidence': confidence,
      'evidence': evidence,
      'is_manual': isManual ? 1 : 0,
    };
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'label': label,
      'display_name': displayName,
      'confidence': confidence,
      'evidence': evidence,
      'is_manual': isManual,
    };
  }

  /// Converts to a domain entity.
  Speaker toEntity() {
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

  @override
  SpeakerModel copyWith({
    String? id,
    String? projectId,
    String? label,
    String? displayName,
    double? confidence,
    String? evidence,
    bool? isManual,
  }) {
    return SpeakerModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      label: label ?? this.label,
      displayName: displayName ?? this.displayName,
      confidence: confidence ?? this.confidence,
      evidence: evidence ?? this.evidence,
      isManual: isManual ?? this.isManual,
    );
  }
}
