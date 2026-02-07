import 'dart:io';

import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/entities/drive_file.dart';

/// Repository interface for Google Drive operations.
///
/// Defines the contract for Google Drive authentication
/// and file operations.
abstract class GoogleDriveRepository {
  /// Signs in to Google.
  Future<Result<void>> signIn();

  /// Signs out of Google.
  Future<Result<void>> signOut();

  /// Checks if the user is signed in.
  Future<Result<bool>> isSignedIn();

  /// Gets the current user's email.
  Future<Result<String?>> getCurrentUserEmail();

  /// Lists files in a folder.
  ///
  /// If [folderId] is null, lists files in the root folder.
  Future<Result<List<DriveFile>>> listFiles({String? folderId});

  /// Lists only JSON files.
  Future<Result<List<DriveFile>>> listJsonFiles({String? folderId});

  /// Lists only audio files (MP3).
  Future<Result<List<DriveFile>>> listAudioFiles({String? folderId});

  /// Searches for files by name.
  Future<Result<List<DriveFile>>> searchFiles(String query);

  /// Downloads a file's content as bytes.
  Future<Result<List<int>>> downloadFile(String fileId);

  /// Downloads a file to a local path.
  Future<Result<String>> downloadFileToPath(
    String fileId,
    String localPath,
  );

  /// Downloads a JSON file and parses it.
  Future<Result<Map<String, dynamic>>> downloadJson(String fileId);

  /// Gets file metadata.
  Future<Result<DriveFile>> getFileMetadata(String fileId);

  /// Downloads a file with progress callback.
  Future<Result<String>> downloadFileWithProgress(
    String fileId,
    String localPath,
    void Function(double progress) onProgress,
  );

  /// Gets or creates the Dutch Learn folder in Drive.
  Future<Result<String>> getOrCreateDutchLearnFolder();

  /// Uploads a project to Google Drive.
  Future<Result<void>> uploadProject({
    required String projectId,
    required String jsonContent,
    File? audioFile,
  });
}
