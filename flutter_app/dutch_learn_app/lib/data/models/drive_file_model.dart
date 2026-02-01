import 'package:dutch_learn_app/domain/entities/drive_file.dart';

/// Data model for DriveFile with API mapping.
class DriveFileModel extends DriveFile {
  const DriveFileModel({
    required super.id,
    required super.name,
    required super.mimeType,
    super.size,
    super.createdTime,
    super.modifiedTime,
    super.parentId,
    super.isFolder = false,
  });

  /// Creates a DriveFileModel from Google Drive API response.
  factory DriveFileModel.fromGoogleDrive(Map<String, dynamic> file) {
    final mimeType = file['mimeType'] as String? ?? '';
    final isFolder = mimeType == 'application/vnd.google-apps.folder';

    return DriveFileModel(
      id: file['id'] as String,
      name: file['name'] as String? ?? 'Unnamed',
      mimeType: mimeType,
      size: file['size'] != null ? int.tryParse(file['size'].toString()) : null,
      createdTime: file['createdTime'] != null
          ? DateTime.tryParse(file['createdTime'] as String)
          : null,
      modifiedTime: file['modifiedTime'] != null
          ? DateTime.tryParse(file['modifiedTime'] as String)
          : null,
      parentId: (file['parents'] as List<dynamic>?)?.firstOrNull as String?,
      isFolder: isFolder,
    );
  }

  /// Creates a DriveFileModel from a domain entity.
  factory DriveFileModel.fromEntity(DriveFile file) {
    return DriveFileModel(
      id: file.id,
      name: file.name,
      mimeType: file.mimeType,
      size: file.size,
      createdTime: file.createdTime,
      modifiedTime: file.modifiedTime,
      parentId: file.parentId,
      isFolder: file.isFolder,
    );
  }

  /// Converts to a domain entity.
  DriveFile toEntity() {
    return DriveFile(
      id: id,
      name: name,
      mimeType: mimeType,
      size: size,
      createdTime: createdTime,
      modifiedTime: modifiedTime,
      parentId: parentId,
      isFolder: isFolder,
    );
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mimeType': mimeType,
      'size': size,
      'createdTime': createdTime?.toIso8601String(),
      'modifiedTime': modifiedTime?.toIso8601String(),
      'parentId': parentId,
      'isFolder': isFolder,
    };
  }
}
