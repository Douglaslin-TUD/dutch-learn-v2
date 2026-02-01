import 'dart:convert';
import 'dart:io';

import 'package:dutch_learn_app/core/errors/failures.dart';
import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/data/models/drive_file_model.dart';
import 'package:dutch_learn_app/data/services/google_drive_service.dart';
import 'package:dutch_learn_app/domain/entities/drive_file.dart';
import 'package:dutch_learn_app/domain/repositories/google_drive_repository.dart';

/// Implementation of GoogleDriveRepository.
class GoogleDriveRepositoryImpl implements GoogleDriveRepository {
  final GoogleDriveService _driveService;

  GoogleDriveRepositoryImpl({
    required GoogleDriveService driveService,
  }) : _driveService = driveService;

  @override
  Future<Result<void>> signIn() async {
    try {
      await _driveService.signIn();
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(AuthenticationFailure(
        message: 'Failed to sign in: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _driveService.signOut();
      return const Result.success(null);
    } on Exception catch (e) {
      return Result.failure(AuthenticationFailure(
        message: 'Failed to sign out: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<bool>> isSignedIn() async {
    try {
      final signedIn = await _driveService.isSignedIn();
      return Result.success(signedIn);
    } on Exception catch (e) {
      return Result.failure(AuthenticationFailure(
        message: 'Failed to check sign in status: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<String?>> getCurrentUserEmail() async {
    try {
      final email = await _driveService.getCurrentUserEmail();
      return Result.success(email);
    } on Exception catch (e) {
      return Result.failure(AuthenticationFailure(
        message: 'Failed to get user email: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<List<DriveFile>>> listFiles({String? folderId}) async {
    try {
      final files = await _driveService.listFiles(folderId: folderId);
      final driveFiles = files
          .map((f) => DriveFileModel.fromGoogleDrive(f).toEntity())
          .toList();
      return Result.success(driveFiles);
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to list files: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<List<DriveFile>>> listJsonFiles({String? folderId}) async {
    try {
      final files = await _driveService.listFiles(
        folderId: folderId,
        mimeType: 'application/json',
      );
      final driveFiles = files
          .map((f) => DriveFileModel.fromGoogleDrive(f).toEntity())
          .where((f) => f.isJson)
          .toList();
      return Result.success(driveFiles);
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to list JSON files: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<List<DriveFile>>> listAudioFiles({String? folderId}) async {
    try {
      final files = await _driveService.listFiles(
        folderId: folderId,
        mimeType: 'audio/',
      );
      final driveFiles = files
          .map((f) => DriveFileModel.fromGoogleDrive(f).toEntity())
          .where((f) => f.isAudio)
          .toList();
      return Result.success(driveFiles);
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to list audio files: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<List<DriveFile>>> searchFiles(String query) async {
    try {
      final files = await _driveService.searchFiles(query);
      final driveFiles = files
          .map((f) => DriveFileModel.fromGoogleDrive(f).toEntity())
          .toList();
      return Result.success(driveFiles);
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to search files: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<List<int>>> downloadFile(String fileId) async {
    try {
      final bytes = await _driveService.downloadFile(fileId);
      return Result.success(bytes);
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to download file: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<String>> downloadFileToPath(
    String fileId,
    String localPath,
  ) async {
    try {
      final bytes = await _driveService.downloadFile(fileId);
      final file = File(localPath);
      await file.writeAsBytes(bytes);
      return Result.success(localPath);
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to download file: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> downloadJson(String fileId) async {
    try {
      final bytes = await _driveService.downloadFile(fileId);
      final content = utf8.decode(bytes);
      final json = jsonDecode(content) as Map<String, dynamic>;
      return Result.success(json);
    } on FormatException catch (e) {
      return Result.failure(ImportFailure(
        message: 'Invalid JSON format: ${e.toString()}',
      ));
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to download JSON: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<DriveFile>> getFileMetadata(String fileId) async {
    try {
      final file = await _driveService.getFileMetadata(fileId);
      final driveFile = DriveFileModel.fromGoogleDrive(file).toEntity();
      return Result.success(driveFile);
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to get file metadata: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Result<String>> downloadFileWithProgress(
    String fileId,
    String localPath,
    void Function(double progress) onProgress,
  ) async {
    try {
      final bytes = await _driveService.downloadFileWithProgress(
        fileId,
        onProgress,
      );
      final file = File(localPath);
      await file.writeAsBytes(bytes);
      return Result.success(localPath);
    } on Exception catch (e) {
      return Result.failure(GoogleDriveFailure(
        message: 'Failed to download file: ${e.toString()}',
      ));
    }
  }
}
