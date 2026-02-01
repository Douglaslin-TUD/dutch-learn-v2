import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'package:dutch_learn_app/core/constants/app_constants.dart';

/// Service for Google Drive API operations.
///
/// Handles authentication and file operations with Google Drive.
class GoogleDriveService {
  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;

  /// Returns true if running on desktop platform where GoogleSignIn is not supported.
  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  GoogleSignIn get googleSignIn {
    if (_isDesktop) {
      throw Exception('Google Sign-In is not supported on desktop platforms');
    }
    _googleSignIn ??= GoogleSignIn(
      scopes: AppConstants.googleDriveScopes,
    );
    return _googleSignIn!;
  }

  /// Signs in to Google.
  Future<void> signIn() async {
    if (_isDesktop) {
      throw Exception('Google Sign-In is not supported on desktop. Use local file import.');
    }
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw Exception('Sign in cancelled');
    }
    await _initDriveApi(account);
  }

  /// Signs out of Google.
  Future<void> signOut() async {
    if (_isDesktop) return;
    await googleSignIn.signOut();
    _driveApi = null;
  }

  /// Checks if the user is signed in.
  Future<bool> isSignedIn() async {
    if (_isDesktop) return false;
    return googleSignIn.isSignedIn();
  }

  /// Gets the current user's email.
  Future<String?> getCurrentUserEmail() async {
    if (_isDesktop) return null;
    final account = googleSignIn.currentUser;
    return account?.email;
  }

  /// Gets or creates the Drive API instance.
  Future<drive.DriveApi> getDriveApi() async {
    if (_driveApi != null) return _driveApi!;

    final account = await googleSignIn.signInSilently();
    if (account == null) {
      throw Exception('Not signed in');
    }

    await _initDriveApi(account);
    return _driveApi!;
  }

  Future<void> _initDriveApi(GoogleSignInAccount account) async {
    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(client);
  }

  /// Lists files in a folder.
  Future<List<Map<String, dynamic>>> listFiles({
    String? folderId,
    String? mimeType,
    int pageSize = 100,
  }) async {
    final api = await getDriveApi();

    var query = "trashed = false";
    if (folderId != null) {
      query += " and '$folderId' in parents";
    }
    if (mimeType != null) {
      if (mimeType.endsWith('/')) {
        // Match prefix (e.g., 'audio/')
        query += " and mimeType contains '${mimeType.substring(0, mimeType.length - 1)}'";
      } else {
        query += " and mimeType = '$mimeType'";
      }
    }

    final files = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      final response = await api.files.list(
        q: query,
        pageSize: pageSize,
        pageToken: pageToken,
        $fields: 'nextPageToken, files(id, name, mimeType, size, createdTime, modifiedTime, parents)',
        orderBy: 'name',
      );

      if (response.files != null) {
        for (final file in response.files!) {
          files.add({
            'id': file.id,
            'name': file.name,
            'mimeType': file.mimeType,
            'size': file.size,
            'createdTime': file.createdTime?.toIso8601String(),
            'modifiedTime': file.modifiedTime?.toIso8601String(),
            'parents': file.parents,
          });
        }
      }

      pageToken = response.nextPageToken;
    } while (pageToken != null);

    return files;
  }

  /// Searches for files by name.
  Future<List<Map<String, dynamic>>> searchFiles(String query) async {
    final api = await getDriveApi();

    final searchQuery = "name contains '$query' and trashed = false";

    final response = await api.files.list(
      q: searchQuery,
      pageSize: 50,
      $fields: 'files(id, name, mimeType, size, createdTime, modifiedTime, parents)',
      orderBy: 'name',
    );

    final files = <Map<String, dynamic>>[];
    if (response.files != null) {
      for (final file in response.files!) {
        files.add({
          'id': file.id,
          'name': file.name,
          'mimeType': file.mimeType,
          'size': file.size,
          'createdTime': file.createdTime?.toIso8601String(),
          'modifiedTime': file.modifiedTime?.toIso8601String(),
          'parents': file.parents,
        });
      }
    }

    return files;
  }

  /// Downloads a file's content.
  Future<List<int>> downloadFile(String fileId) async {
    final api = await getDriveApi();

    final response = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }

    return bytes;
  }

  /// Downloads a file with progress callback.
  Future<List<int>> downloadFileWithProgress(
    String fileId,
    void Function(double progress) onProgress,
  ) async {
    final api = await getDriveApi();

    // First get file metadata to know the size
    final metadata = await api.files.get(
      fileId,
      $fields: 'size',
    ) as drive.File;

    final totalSize = int.tryParse(metadata.size ?? '0') ?? 0;

    final response = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    var downloaded = 0;

    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      downloaded += chunk.length;

      if (totalSize > 0) {
        onProgress(downloaded / totalSize);
      }
    }

    onProgress(1.0);
    return bytes;
  }

  /// Gets file metadata.
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async {
    final api = await getDriveApi();

    final file = await api.files.get(
      fileId,
      $fields: 'id, name, mimeType, size, createdTime, modifiedTime, parents',
    ) as drive.File;

    return {
      'id': file.id,
      'name': file.name,
      'mimeType': file.mimeType,
      'size': file.size,
      'createdTime': file.createdTime?.toIso8601String(),
      'modifiedTime': file.modifiedTime?.toIso8601String(),
      'parents': file.parents,
    };
  }

  /// Finds a folder by name, optionally within a parent folder.
  Future<String?> findFolder(String folderName, {String? parentId}) async {
    final api = await getDriveApi();

    var query = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    if (parentId != null) {
      query += " and '$parentId' in parents";
    }

    final response = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (response.files != null && response.files!.isNotEmpty) {
      return response.files!.first.id;
    }
    return null;
  }

  /// Creates a folder in Google Drive.
  Future<String> createFolder(String folderName, {String? parentId}) async {
    final api = await getDriveApi();

    final metadata = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    if (parentId != null) {
      metadata.parents = [parentId];
    }

    final folder = await api.files.create(
      metadata,
      $fields: 'id',
    );

    return folder.id!;
  }

  /// Gets or creates the Dutch Learn folder in Drive.
  Future<String> getOrCreateDutchLearnFolder() async {
    const folderName = 'Dutch Learn';

    var folderId = await findFolder(folderName);
    if (folderId == null) {
      folderId = await createFolder(folderName);
    }

    return folderId;
  }

  /// Uploads a file to Google Drive.
  /// If a file with the same name exists in the parent folder, it will be updated.
  Future<Map<String, dynamic>> uploadFile({
    required Uint8List content,
    required String fileName,
    required String mimeType,
    required String parentId,
  }) async {
    final api = await getDriveApi();

    // Check if file already exists
    final query = "name='$fileName' and '$parentId' in parents and trashed=false";
    final existingFiles = await api.files.list(
      q: query,
      $fields: 'files(id)',
    );

    final media = drive.Media(
      Stream.value(content),
      content.length,
    );

    drive.File result;

    if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
      // Update existing file
      result = await api.files.update(
        drive.File(),
        existingFiles.files!.first.id!,
        uploadMedia: media,
        $fields: 'id, name, modifiedTime',
      );
    } else {
      // Create new file
      final metadata = drive.File()
        ..name = fileName
        ..parents = [parentId];

      result = await api.files.create(
        metadata,
        uploadMedia: media,
        $fields: 'id, name, modifiedTime',
      );
    }

    return {
      'id': result.id,
      'name': result.name,
      'modifiedTime': result.modifiedTime?.toIso8601String(),
    };
  }

  /// Uploads a project folder with JSON and audio files.
  Future<void> uploadProject({
    required String projectId,
    required String jsonContent,
    File? audioFile,
    void Function(double progress)? onProgress,
  }) async {
    // Get or create Dutch Learn folder
    final dutchLearnFolderId = await getOrCreateDutchLearnFolder();

    // Get or create project folder
    var projectFolderId = await findFolder(projectId, parentId: dutchLearnFolderId);
    if (projectFolderId == null) {
      projectFolderId = await createFolder(projectId, parentId: dutchLearnFolderId);
    }

    onProgress?.call(0.2);

    // Upload project.json
    await uploadFile(
      content: Uint8List.fromList(jsonContent.codeUnits),
      fileName: 'project.json',
      mimeType: 'application/json',
      parentId: projectFolderId,
    );

    onProgress?.call(0.5);

    // Upload audio file if exists
    if (audioFile != null && await audioFile.exists()) {
      final audioBytes = await audioFile.readAsBytes();
      await uploadFile(
        content: audioBytes,
        fileName: 'audio.mp3',
        mimeType: 'audio/mpeg',
        parentId: projectFolderId,
      );
    }

    onProgress?.call(1.0);
  }
}

/// HTTP client that adds auth headers to requests.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
