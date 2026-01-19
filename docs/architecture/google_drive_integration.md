# Google Drive Integration Design
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31

---

## 1. Integration Overview

### 1.1 Purpose

Google Drive integration enables users to:
1. **Connect** their Google account via OAuth 2.0
2. **Browse** their Drive folders to find exported project files
3. **Download** JSON and MP3 files for offline learning
4. **Disconnect** when needed (clear tokens, maintain local data)

### 1.2 Architecture

```
+------------------+     +-------------------+     +------------------+
|    Flutter UI    |     |   Drive Service   |     |  Google Drive    |
|    (Screens)     |     |   (Data Layer)    |     |      API         |
+------------------+     +-------------------+     +------------------+
        |                        |                        |
        |  1. Connect request    |                        |
        +----------------------->|                        |
        |                        |  2. OAuth flow         |
        |                        +----------------------->|
        |                        |                        |
        |                        |<-----------------------+
        |                        |  3. Access token       |
        |                        |                        |
        |<-----------------------+                        |
        |  4. Connection status  |                        |
        |                        |                        |
        |  5. List files         |                        |
        +----------------------->|                        |
        |                        |  6. files.list         |
        |                        +----------------------->|
        |                        |                        |
        |                        |<-----------------------+
        |                        |  7. File list          |
        |<-----------------------+                        |
        |  8. Display files      |                        |
        |                        |                        |
        |  9. Download file      |                        |
        +----------------------->|                        |
        |                        |  10. files.get         |
        |                        |      (media download)  |
        |                        +----------------------->|
        |                        |                        |
        |                        |<-----------------------+
        |                        |  11. File bytes        |
        |<-----------------------+                        |
        |  12. Progress updates  |                        |
```

---

## 2. OAuth 2.0 Flow

### 2.1 Flow Diagram

```
+-------------+     +----------------+     +----------------+     +--------------+
|   User      |     |   Flutter App  |     |  Google OAuth  |     | Google Drive |
+-------------+     +----------------+     +----------------+     +--------------+
      |                    |                      |                      |
      | 1. Tap "Connect"   |                      |                      |
      +------------------->|                      |                      |
      |                    |                      |                      |
      |                    | 2. Open browser/     |                      |
      |                    |    WebView           |                      |
      |                    +--------------------->|                      |
      |                    |                      |                      |
      | 3. Enter credentials                      |                      |
      +------------------------------------------>|                      |
      |                    |                      |                      |
      | 4. Grant permissions (scope: drive.readonly)                     |
      +------------------------------------------>|                      |
      |                    |                      |                      |
      |                    | 5. Redirect with     |                      |
      |                    |    auth code         |                      |
      |                    |<---------------------+                      |
      |                    |                      |                      |
      |                    | 6. Exchange code     |                      |
      |                    |    for tokens        |                      |
      |                    +--------------------->|                      |
      |                    |                      |                      |
      |                    | 7. Access token +    |                      |
      |                    |    Refresh token     |                      |
      |                    |<---------------------+                      |
      |                    |                      |                      |
      |                    | 8. Store tokens      |                      |
      |                    |    securely          |                      |
      |                    |                      |                      |
      | 9. Show "Connected"                       |                      |
      |<-------------------+                      |                      |
      |                    |                      |                      |
      |                    | 10. API calls with   |                      |
      |                    |     access token     |                      |
      |                    +--------------------------------------------->|
      |                    |                      |                      |
```

### 2.2 OAuth Configuration

**Scopes Required:**
```dart
const driveScopes = [
  'https://www.googleapis.com/auth/drive.readonly',
];
```

**OAuth Credentials (Android):**
```
- Client ID: [obtained from Google Cloud Console]
- Client Type: Android
- Package Name: com.example.dutch_learn
- SHA-1 Certificate: [from keystore]
```

### 2.3 Token Management

```dart
// lib/data/services/google_auth_service.dart

class GoogleAuthService {
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;

  static const _accessTokenKey = 'google_access_token';
  static const _refreshTokenKey = 'google_refresh_token';
  static const _expiryKey = 'google_token_expiry';

  GoogleAuthService(this._secureStorage)
      : _googleSignIn = GoogleSignIn(
          scopes: ['https://www.googleapis.com/auth/drive.readonly'],
        );

  /// Check if user is signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Sign in and get OAuth credentials
  Future<Result<AuthCredentials>> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return Failure(AppException.auth('Sign in cancelled'));
      }

      final auth = await account.authentication;

      // Store tokens securely
      await _secureStorage.write(
        key: _accessTokenKey,
        value: auth.accessToken,
      );
      if (auth.idToken != null) {
        await _secureStorage.write(
          key: _refreshTokenKey,
          value: auth.idToken,
        );
      }

      return Success(AuthCredentials(
        accessToken: auth.accessToken!,
        email: account.email,
      ));
    } catch (e) {
      return Failure(AppException.auth('Sign in failed: $e'));
    }
  }

  /// Get valid access token (refresh if needed)
  Future<String?> getAccessToken() async {
    final account = _googleSignIn.currentUser;
    if (account == null) return null;

    // Get fresh authentication
    final auth = await account.authentication;
    return auth.accessToken;
  }

  /// Sign out and clear tokens
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _expiryKey);
  }

  /// Get authenticated HTTP client
  Future<AuthClient?> getAuthClient() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return null;

    return AuthClient(accessToken);
  }
}

class AuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  AuthClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
}
```

---

## 3. Google Drive API Endpoints

### 3.1 API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `files.list` | GET | Browse folders and list files |
| `files.get` | GET | Get file metadata |
| `files.get` (media) | GET | Download file content |

### 3.2 File List Request

```dart
// List files in a folder
GET https://www.googleapis.com/drive/v3/files
  ?q='<folderId>' in parents and trashed=false
  &fields=files(id,name,mimeType,size,modifiedTime,parents)
  &orderBy=folder,name
  &pageSize=100

// For root folder
GET https://www.googleapis.com/drive/v3/files
  ?q='root' in parents and trashed=false
  &fields=files(id,name,mimeType,size,modifiedTime,parents)
  &orderBy=folder,name
  &pageSize=100

// Filter for JSON and MP3 only
&q='<folderId>' in parents and trashed=false and (mimeType='application/json' or mimeType='audio/mpeg' or mimeType='application/vnd.google-apps.folder')
```

### 3.3 File Download Request

```dart
// Download file content
GET https://www.googleapis.com/drive/v3/files/<fileId>?alt=media

// Headers
Authorization: Bearer <access_token>
```

### 3.4 API Implementation

```dart
// lib/data/datasources/remote/google_drive_datasource.dart

class GoogleDriveDataSource {
  final GoogleAuthService _authService;

  static const _baseUrl = 'https://www.googleapis.com/drive/v3';
  static const _filesEndpoint = '$_baseUrl/files';

  // MIME types we care about
  static const _folderMimeType = 'application/vnd.google-apps.folder';
  static const _jsonMimeType = 'application/json';
  static const _mp3MimeType = 'audio/mpeg';

  GoogleDriveDataSource(this._authService);

  /// List files in a folder
  Future<Result<List<DriveFile>>> listFiles({String? folderId}) async {
    try {
      final client = await _authService.getAuthClient();
      if (client == null) {
        return Failure(AppException.auth('Not authenticated'));
      }

      final parentId = folderId ?? 'root';
      final query = Uri.encodeComponent(
        "'$parentId' in parents and trashed=false and "
        "(mimeType='$_folderMimeType' or mimeType='$_jsonMimeType' or mimeType='$_mp3MimeType')"
      );

      final url = Uri.parse(
        '$_filesEndpoint'
        '?q=$query'
        '&fields=files(id,name,mimeType,size,modifiedTime,parents)'
        '&orderBy=folder,name'
        '&pageSize=100'
      );

      final response = await client.get(url);

      if (response.statusCode != 200) {
        return Failure(AppException.network('Failed to list files: ${response.statusCode}'));
      }

      final data = jsonDecode(response.body);
      final files = (data['files'] as List)
          .map((f) => DriveFile.fromJson(f))
          .toList();

      return Success(files);
    } catch (e) {
      return Failure(AppException.network('Failed to list files: $e'));
    }
  }

  /// Download file with progress
  Stream<DownloadProgress> downloadFile(
    String fileId,
    String fileName,
    String destinationPath,
  ) async* {
    final client = await _authService.getAuthClient();
    if (client == null) {
      throw AppException.auth('Not authenticated');
    }

    final url = Uri.parse('$_filesEndpoint/$fileId?alt=media');
    final request = http.Request('GET', url);
    request.headers['Authorization'] = 'Bearer ${await _authService.getAccessToken()}';

    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw AppException.network('Download failed: ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    var bytesReceived = 0;

    final file = File(destinationPath);
    final sink = file.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        yield DownloadProgress(
          fileName: fileName,
          bytesDownloaded: bytesReceived,
          totalBytes: totalBytes,
        );
      }
    } finally {
      await sink.close();
    }
  }

  /// Get file metadata
  Future<Result<DriveFile>> getFileMetadata(String fileId) async {
    try {
      final client = await _authService.getAuthClient();
      if (client == null) {
        return Failure(AppException.auth('Not authenticated'));
      }

      final url = Uri.parse(
        '$_filesEndpoint/$fileId'
        '?fields=id,name,mimeType,size,modifiedTime,parents'
      );

      final response = await client.get(url);

      if (response.statusCode != 200) {
        return Failure(AppException.network('Failed to get file: ${response.statusCode}'));
      }

      final data = jsonDecode(response.body);
      return Success(DriveFile.fromJson(data));
    } catch (e) {
      return Failure(AppException.network('Failed to get file: $e'));
    }
  }
}

/// Drive file model
class DriveFile {
  final String id;
  final String name;
  final String mimeType;
  final int? size;
  final DateTime? modifiedTime;
  final List<String>? parents;

  DriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.size,
    this.modifiedTime,
    this.parents,
  });

  bool get isFolder => mimeType == 'application/vnd.google-apps.folder';
  bool get isJson => mimeType == 'application/json';
  bool get isMp3 => mimeType == 'audio/mpeg';

  String get sizeFormatted {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory DriveFile.fromJson(Map<String, dynamic> json) {
    return DriveFile(
      id: json['id'],
      name: json['name'],
      mimeType: json['mimeType'],
      size: json['size'] != null ? int.parse(json['size'].toString()) : null,
      modifiedTime: json['modifiedTime'] != null
          ? DateTime.parse(json['modifiedTime'])
          : null,
      parents: json['parents'] != null
          ? List<String>.from(json['parents'])
          : null,
    );
  }
}
```

---

## 4. File Picker UI Flow

### 4.1 UI Flow Diagram

```
+-------------------+
| Not Connected     |
|                   |
| [Connect to       |
|  Google Drive]    |
+--------+----------+
         |
         | Tap connect
         v
+-------------------+
| OAuth WebView     |
| (Google login)    |
+--------+----------+
         |
         | Auth success
         v
+-------------------+
| Root Folder       |
|                   |
| > Folder 1        |
| > Folder 2        |
|   file1.json      |
|   audio1.mp3      |
+--------+----------+
         |
         | Tap folder
         v
+-------------------+
| Subfolder         |
| < Back            |
|                   |
|   project.json    |<-- Tap to select
|   project.mp3     |
+--------+----------+
         |
         | Tap JSON file
         v
+-------------------+
| File Selected     |
|                   |
| project.json      |
| 245 KB            |
|                   |
| [Download]        |
| [Cancel]          |
+--------+----------+
         |
         | Tap download
         v
+-------------------+
| Downloading...    |
|                   |
| [=======    ] 67% |
| 164 KB / 245 KB   |
+--------+----------+
         |
         | Complete
         v
+-------------------+
| Download Complete |
|                   |
| [Import Project]  |
+-------------------+
```

### 4.2 Screen Implementation

```dart
// lib/presentation/screens/drive/drive_picker_screen.dart

class DrivePickerScreen extends ConsumerWidget {
  const DrivePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driveBrowserProvider);
    final isOnline = ref.watch(isOnlineProvider);

    if (!isOnline) {
      return Scaffold(
        appBar: AppBar(title: const Text('Google Drive')),
        body: const OfflineBanner(
          message: 'Connect to internet to access Google Drive',
        ),
      );
    }

    if (!state.isConnected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Google Drive')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('Connect to access your files'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(driveBrowserProvider.notifier).connect(),
                icon: const Icon(Icons.login),
                label: const Text('Connect to Google Drive'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select File'),
        leading: state.isRoot
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref.read(driveBrowserProvider.notifier).goBack(),
              ),
      ),
      body: Column(
        children: [
          // Breadcrumbs
          if (!state.isRoot)
            FolderBreadcrumbs(
              pathNames: state.pathNames,
              onTap: (index) => ref.read(driveBrowserProvider.notifier).goToPath(index),
            ),

          // File list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.files.isEmpty
                    ? const Center(child: Text('No JSON or MP3 files found'))
                    : ListView.builder(
                        itemCount: state.files.length,
                        itemBuilder: (context, index) {
                          final file = state.files[index];
                          return DriveFileItem(
                            file: file,
                            isSelected: state.selectedFile?.id == file.id,
                            onTap: () => _handleFileTap(context, ref, file),
                          );
                        },
                      ),
          ),

          // Download progress
          if (state.isDownloading)
            DownloadProgressWidget(progress: state.downloadProgress!),

          // Download button
          if (state.hasSelection && !state.isDownloading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _startDownload(ref),
                child: Text('Download ${state.selectedFile!.name}'),
              ),
            ),
        ],
      ),
    );
  }

  void _handleFileTap(BuildContext context, WidgetRef ref, DriveFile file) {
    if (file.isFolder) {
      ref.read(driveBrowserProvider.notifier).openFolder(file.id, file.name);
    } else {
      ref.read(driveBrowserProvider.notifier).selectFile(file);
    }
  }

  void _startDownload(WidgetRef ref) {
    ref.read(driveBrowserProvider.notifier).downloadSelectedFile();
  }
}
```

---

## 5. Download Manager Design

### 5.1 Download Manager

```dart
// lib/data/services/download_manager.dart

class DownloadManager {
  final GoogleDriveDataSource _driveDataSource;
  final FileService _fileService;

  DownloadManager(this._driveDataSource, this._fileService);

  /// Download file from Google Drive
  Stream<DownloadResult> downloadFile(DriveFile file) async* {
    // Determine destination path
    final directory = await _fileService.getDownloadsDirectory();
    final destinationPath = '${directory.path}/${file.name}';

    // Check if file already exists
    if (await File(destinationPath).exists()) {
      await File(destinationPath).delete();
    }

    // Start download
    yield DownloadResult.started(file.name);

    try {
      await for (final progress in _driveDataSource.downloadFile(
        file.id,
        file.name,
        destinationPath,
      )) {
        yield DownloadResult.progress(
          fileName: file.name,
          bytesDownloaded: progress.bytesDownloaded,
          totalBytes: progress.totalBytes,
        );
      }

      // Verify file
      final downloadedFile = File(destinationPath);
      if (!await downloadedFile.exists()) {
        yield DownloadResult.failed(file.name, 'File not saved');
        return;
      }

      yield DownloadResult.completed(
        fileName: file.name,
        filePath: destinationPath,
        fileSize: await downloadedFile.length(),
      );
    } catch (e) {
      // Cleanup partial download
      final partialFile = File(destinationPath);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }

      yield DownloadResult.failed(file.name, e.toString());
    }
  }

  /// Download multiple files (JSON + MP3)
  Stream<MultiDownloadResult> downloadProjectFiles({
    required DriveFile jsonFile,
    DriveFile? mp3File,
  }) async* {
    yield MultiDownloadResult.started();

    // Download JSON
    String? jsonPath;
    await for (final result in downloadFile(jsonFile)) {
      if (result is DownloadCompleted) {
        jsonPath = result.filePath;
        yield MultiDownloadResult.jsonComplete(result.filePath);
      } else if (result is DownloadProgress) {
        yield MultiDownloadResult.progress(
          phase: DownloadPhase.json,
          progress: result.progress,
        );
      } else if (result is DownloadFailed) {
        yield MultiDownloadResult.failed(result.error);
        return;
      }
    }

    // Download MP3 if provided
    String? mp3Path;
    if (mp3File != null) {
      await for (final result in downloadFile(mp3File)) {
        if (result is DownloadCompleted) {
          mp3Path = result.filePath;
          yield MultiDownloadResult.mp3Complete(result.filePath);
        } else if (result is DownloadProgress) {
          yield MultiDownloadResult.progress(
            phase: DownloadPhase.mp3,
            progress: result.progress,
          );
        } else if (result is DownloadFailed) {
          // MP3 failure is non-critical, continue
          yield MultiDownloadResult.mp3Skipped(result.error);
        }
      }
    }

    yield MultiDownloadResult.allComplete(
      jsonPath: jsonPath!,
      mp3Path: mp3Path,
    );
  }
}

// Download result types
sealed class DownloadResult {}

class DownloadStarted extends DownloadResult {
  final String fileName;
  DownloadStarted(this.fileName);
}

class DownloadProgress extends DownloadResult {
  final String fileName;
  final int bytesDownloaded;
  final int totalBytes;

  DownloadProgress({
    required this.fileName,
    required this.bytesDownloaded,
    required this.totalBytes,
  });

  double get progress => totalBytes > 0 ? bytesDownloaded / totalBytes : 0;
}

class DownloadCompleted extends DownloadResult {
  final String fileName;
  final String filePath;
  final int fileSize;

  DownloadCompleted({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
  });
}

class DownloadFailed extends DownloadResult {
  final String fileName;
  final String error;

  DownloadFailed(this.fileName, this.error);
}
```

### 5.2 Download to Import Flow

```dart
// lib/presentation/notifiers/drive_browser_notifier.dart

class DriveBrowserNotifier extends StateNotifier<DriveBrowserState> {
  final GoogleAuthService _authService;
  final GoogleDriveDataSource _driveDataSource;
  final DownloadManager _downloadManager;
  final ImportNotifier _importNotifier;

  DriveBrowserNotifier(
    this._authService,
    this._driveDataSource,
    this._downloadManager,
    this._importNotifier,
  ) : super(const DriveBrowserState()) {
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final isConnected = await _authService.isSignedIn();
    state = state.copyWith(isConnected: isConnected);

    if (isConnected) {
      await loadFiles();
    }
  }

  Future<void> connect() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.signIn();

    result.when(
      success: (_) {
        state = state.copyWith(isConnected: true, isLoading: false);
        loadFiles();
      },
      failure: (e) {
        state = state.copyWith(isLoading: false, error: e.message);
      },
    );
  }

  Future<void> disconnect() async {
    await _authService.signOut();
    state = const DriveBrowserState();
  }

  Future<void> loadFiles() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _driveDataSource.listFiles(
      folderId: state.currentFolderId,
    );

    result.when(
      success: (files) {
        state = state.copyWith(isLoading: false, files: files);
      },
      failure: (e) {
        state = state.copyWith(isLoading: false, error: e.message);
      },
    );
  }

  void openFolder(String folderId, String folderName) {
    state = state.copyWith(
      currentFolderId: folderId,
      pathStack: [...state.pathStack, folderId],
      pathNames: [...state.pathNames, folderName],
    );
    loadFiles();
  }

  void goBack() {
    if (state.pathStack.isEmpty) return;

    final newPathStack = [...state.pathStack]..removeLast();
    final newPathNames = [...state.pathNames]..removeLast();

    state = state.copyWith(
      currentFolderId: newPathStack.isEmpty ? null : newPathStack.last,
      pathStack: newPathStack,
      pathNames: newPathNames,
      selectedFile: null,
    );
    loadFiles();
  }

  void goToPath(int index) {
    if (index >= state.pathStack.length) return;

    final newPathStack = state.pathStack.sublist(0, index + 1);
    final newPathNames = state.pathNames.sublist(0, index + 1);

    state = state.copyWith(
      currentFolderId: newPathStack.last,
      pathStack: newPathStack,
      pathNames: newPathNames,
      selectedFile: null,
    );
    loadFiles();
  }

  void selectFile(DriveFile file) {
    state = state.copyWith(
      selectedFile: state.selectedFile?.id == file.id ? null : file,
    );
  }

  Future<void> downloadSelectedFile() async {
    final file = state.selectedFile;
    if (file == null) return;

    state = state.copyWith(
      downloadProgress: DownloadProgress(
        fileName: file.name,
        bytesDownloaded: 0,
        totalBytes: file.size ?? 0,
      ),
    );

    try {
      await for (final result in _downloadManager.downloadFile(file)) {
        switch (result) {
          case DownloadProgress progress:
            state = state.copyWith(
              downloadProgress: DownloadProgress(
                fileName: progress.fileName,
                bytesDownloaded: progress.bytesDownloaded,
                totalBytes: progress.totalBytes,
              ),
            );

          case DownloadCompleted completed:
            state = state.copyWith(downloadProgress: null);

            // If JSON file, trigger import
            if (file.isJson) {
              _importNotifier.startImport(completed.filePath);
            }

          case DownloadFailed failed:
            state = state.copyWith(
              downloadProgress: null,
              error: 'Download failed: ${failed.error}',
            );
        }
      }
    } catch (e) {
      state = state.copyWith(
        downloadProgress: null,
        error: 'Download failed: $e',
      );
    }
  }
}
```

---

## 6. Error Handling

### 6.1 Error Types

| Error Type | Cause | User Message | Action |
|------------|-------|--------------|--------|
| `NetworkError` | No internet | "Check your connection" | Retry button |
| `AuthError` | OAuth failed/expired | "Please sign in again" | Re-authenticate |
| `QuotaError` | API quota exceeded | "Please try again later" | Wait and retry |
| `NotFoundError` | File deleted | "File not found" | Refresh list |
| `PermissionError` | Access denied | "Cannot access file" | Check permissions |
| `StorageError` | Device full | "Not enough space" | Free space |

### 6.2 Error Handling Strategy

```dart
// lib/data/datasources/remote/google_drive_datasource.dart

Future<Result<List<DriveFile>>> listFiles({String? folderId}) async {
  try {
    final client = await _authService.getAuthClient();
    if (client == null) {
      return Failure(AppException.auth('Please sign in to Google Drive'));
    }

    final response = await client.get(url);

    switch (response.statusCode) {
      case 200:
        // Success
        final data = jsonDecode(response.body);
        return Success(_parseFiles(data));

      case 401:
        // Token expired - try to refresh
        await _authService.refreshToken();
        return listFiles(folderId: folderId); // Retry once

      case 403:
        // Permission denied or quota exceeded
        final error = jsonDecode(response.body);
        if (error['error']['message']?.contains('quota') ?? false) {
          return Failure(AppException.quota('API quota exceeded'));
        }
        return Failure(AppException.permission('Access denied'));

      case 404:
        return Failure(AppException.notFound('Folder not found'));

      case 500:
      case 502:
      case 503:
        return Failure(AppException.server('Google Drive is temporarily unavailable'));

      default:
        return Failure(AppException.network('Request failed: ${response.statusCode}'));
    }
  } on SocketException {
    return Failure(AppException.network('No internet connection'));
  } on TimeoutException {
    return Failure(AppException.network('Connection timed out'));
  } catch (e) {
    return Failure(AppException.unknown('An error occurred: $e'));
  }
}
```

### 6.3 Retry Logic

```dart
// lib/core/utils/retry.dart

class RetryHelper {
  static const maxRetries = 3;
  static const retryDelays = [Duration(seconds: 1), Duration(seconds: 3), Duration(seconds: 5)];

  static Future<Result<T>> withRetry<T>(
    Future<Result<T>> Function() operation, {
    bool Function(AppException)? shouldRetry,
  }) async {
    AppException? lastError;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      final result = await operation();

      if (result is Success<T>) {
        return result;
      }

      final failure = result as Failure<T>;
      lastError = failure.exception;

      // Check if we should retry
      if (shouldRetry != null && !shouldRetry(lastError)) {
        return result;
      }

      // Don't retry auth errors
      if (lastError is AuthException) {
        return result;
      }

      // Wait before retry
      if (attempt < maxRetries - 1) {
        await Future.delayed(retryDelays[attempt]);
      }
    }

    return Failure(lastError!);
  }
}
```

---

## 7. Security Considerations

### 7.1 Token Storage

```dart
// Tokens stored in encrypted shared preferences (Android Keystore)
final secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  ),
);
```

### 7.2 Minimal Permissions

Only request `drive.readonly` scope - no write access needed.

### 7.3 File Validation

```dart
Future<Result<ExportData>> validateDownloadedJson(String filePath) async {
  try {
    final file = File(filePath);
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    // Validate schema version
    if (json['version'] != '1.0') {
      return Failure(AppException.validation('Unsupported file version'));
    }

    // Validate required fields
    if (json['project'] == null) {
      return Failure(AppException.validation('Missing project data'));
    }

    if (json['sentences'] == null || (json['sentences'] as List).isEmpty) {
      return Failure(AppException.validation('No sentences in file'));
    }

    return Success(ExportData.fromJson(json));
  } on FormatException {
    return Failure(AppException.validation('Invalid JSON format'));
  } catch (e) {
    return Failure(AppException.validation('Failed to read file: $e'));
  }
}
```

---

## 8. Offline Handling

### 8.1 Connection State UI

```dart
// Show offline banner when not connected
class DrivePickerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityProvider);

    return connectivityAsync.when(
      data: (isOnline) {
        if (!isOnline) {
          return _buildOfflineScreen();
        }
        return _buildDriveBrowser(ref);
      },
      loading: () => const LoadingIndicator(),
      error: (_, __) => _buildDriveBrowser(ref), // Assume online on error
    );
  }

  Widget _buildOfflineScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No internet connection'),
            const SizedBox(height: 8),
            const Text('Connect to access Google Drive'),
          ],
        ),
      ),
    );
  }
}
```

### 8.2 Resume Download

For large files, support resuming interrupted downloads:

```dart
// Check for partial download
Future<int> getPartialDownloadSize(String destinationPath) async {
  final partialFile = File('$destinationPath.partial');
  if (await partialFile.exists()) {
    return await partialFile.length();
  }
  return 0;
}

// Resume download with Range header
Future<void> resumeDownload(String fileId, String destinationPath, int startByte) async {
  final request = http.Request('GET', Uri.parse('$_filesEndpoint/$fileId?alt=media'));
  request.headers['Range'] = 'bytes=$startByte-';
  // ... continue download and append to file
}
```

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Solution Architect | Initial Google Drive integration design |
