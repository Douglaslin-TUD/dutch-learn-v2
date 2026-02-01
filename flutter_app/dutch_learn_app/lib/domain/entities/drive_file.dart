import 'package:flutter/foundation.dart';

/// Represents a file from Google Drive.
///
/// Contains metadata about a file that can be downloaded
/// from Google Drive for import.
@immutable
class DriveFile {
  /// Google Drive file ID.
  final String id;

  /// File name.
  final String name;

  /// MIME type of the file.
  final String mimeType;

  /// File size in bytes.
  final int? size;

  /// When the file was created.
  final DateTime? createdTime;

  /// When the file was last modified.
  final DateTime? modifiedTime;

  /// ID of the parent folder.
  final String? parentId;

  /// Whether this is a folder.
  final bool isFolder;

  /// Creates a new DriveFile instance.
  const DriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.size,
    this.createdTime,
    this.modifiedTime,
    this.parentId,
    this.isFolder = false,
  });

  /// Returns true if this is a JSON file.
  bool get isJson => mimeType == 'application/json' ||
      name.toLowerCase().endsWith('.json');

  /// Returns true if this is an MP3 file.
  bool get isMp3 => mimeType == 'audio/mpeg' ||
      mimeType == 'audio/mp3' ||
      name.toLowerCase().endsWith('.mp3');

  /// Returns true if this is an audio file.
  bool get isAudio => isMp3;

  /// Returns the file extension.
  String get extension {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return name.substring(dotIndex);
  }

  /// Returns the file name without extension.
  String get nameWithoutExtension {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1) return name;
    return name.substring(0, dotIndex);
  }

  /// Returns the formatted file size.
  String get formattedSize {
    if (size == null) return 'Unknown';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) {
      return '${(size! / 1024).toStringAsFixed(1)} KB';
    }
    if (size! < 1024 * 1024 * 1024) {
      return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DriveFile &&
        other.id == id &&
        other.name == name &&
        other.mimeType == mimeType;
  }

  @override
  int get hashCode => Object.hash(id, name, mimeType);

  @override
  String toString() => 'DriveFile(id: $id, name: $name)';
}
