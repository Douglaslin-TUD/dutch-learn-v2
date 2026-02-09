import 'package:flutter/foundation.dart';

/// Represents a speaker identified in a project's audio.
@immutable
class Speaker {
  /// Unique identifier for the speaker.
  final String id;

  /// ID of the project this speaker belongs to.
  final String projectId;

  /// Speaker label (A, B, C...).
  final String label;

  /// Display name (user-set or auto-detected).
  final String? displayName;

  /// Confidence score of speaker detection.
  final double confidence;

  /// Evidence text for speaker identification.
  final String? evidence;

  /// Whether the display name was manually set.
  final bool isManual;

  const Speaker({
    required this.id,
    required this.projectId,
    required this.label,
    this.displayName,
    this.confidence = 0.0,
    this.evidence,
    this.isManual = false,
  });

  /// Returns the display name or a default label.
  String get displayLabel => displayName ?? 'Speaker $label';

  Speaker copyWith({
    String? id,
    String? projectId,
    String? label,
    String? displayName,
    double? confidence,
    String? evidence,
    bool? isManual,
  }) {
    return Speaker(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      label: label ?? this.label,
      displayName: displayName ?? this.displayName,
      confidence: confidence ?? this.confidence,
      evidence: evidence ?? this.evidence,
      isManual: isManual ?? this.isManual,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Speaker &&
        other.id == id &&
        other.projectId == projectId &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(id, projectId, label);

  @override
  String toString() => 'Speaker(label: $label, name: $displayLabel)';
}
