import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Utility class for file system operations.
///
/// Provides consistent file handling across the application
/// including path management and file operations.
class FileUtils {
  FileUtils._();

  /// Gets the application documents directory path.
  static Future<String> getDocumentsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Gets the application cache directory path.
  static Future<String> getCachePath() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  /// Gets the audio files directory path.
  ///
  /// Creates the directory if it doesn't exist.
  static Future<String> getAudioDirectoryPath() async {
    final documentsPath = await getDocumentsPath();
    final audioDir = Directory(path.join(documentsPath, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  /// Gets the projects directory path.
  ///
  /// Creates the directory if it doesn't exist.
  static Future<String> getProjectsDirectoryPath() async {
    final documentsPath = await getDocumentsPath();
    final projectsDir = Directory(path.join(documentsPath, 'projects'));
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }
    return projectsDir.path;
  }

  /// Gets the full path for an audio file.
  static Future<String> getAudioFilePath(String filename) async {
    final audioDir = await getAudioDirectoryPath();
    return path.join(audioDir, filename);
  }

  /// Gets the full path for a project file.
  static Future<String> getProjectFilePath(
    String projectId,
    String filename,
  ) async {
    final projectsDir = await getProjectsDirectoryPath();
    final projectDir = Directory(path.join(projectsDir, projectId));
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    return path.join(projectDir.path, filename);
  }

  /// Checks if a file exists at the given path.
  static Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }

  /// Reads a file as a string.
  static Future<String> readFileAsString(String filePath) async {
    final file = File(filePath);
    return file.readAsString();
  }

  /// Reads a file as bytes.
  static Future<List<int>> readFileAsBytes(String filePath) async {
    final file = File(filePath);
    return file.readAsBytes();
  }

  /// Writes a string to a file.
  static Future<File> writeStringToFile(
    String filePath,
    String content,
  ) async {
    final file = File(filePath);
    return file.writeAsString(content);
  }

  /// Writes bytes to a file.
  static Future<File> writeBytesToFile(
    String filePath,
    List<int> bytes,
  ) async {
    final file = File(filePath);
    return file.writeAsBytes(bytes);
  }

  /// Deletes a file if it exists.
  static Future<bool> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Deletes a directory and its contents.
  static Future<bool> deleteDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      return true;
    }
    return false;
  }

  /// Copies a file to a new location.
  static Future<File> copyFile(String sourcePath, String destPath) async {
    final file = File(sourcePath);
    return file.copy(destPath);
  }

  /// Moves a file to a new location.
  static Future<File> moveFile(String sourcePath, String destPath) async {
    final file = File(sourcePath);
    return file.rename(destPath);
  }

  /// Gets the file extension from a path.
  static String getExtension(String filePath) {
    return path.extension(filePath);
  }

  /// Gets the filename without extension.
  static String getBasename(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  /// Gets the filename with extension.
  static String getFilename(String filePath) {
    return path.basename(filePath);
  }

  /// Gets the directory containing a file.
  static String getDirectory(String filePath) {
    return path.dirname(filePath);
  }

  /// Joins path segments.
  static String joinPath(String part1, String part2, [String? part3]) {
    if (part3 != null) {
      return path.join(part1, part2, part3);
    }
    return path.join(part1, part2);
  }

  /// Gets the file size in bytes.
  static Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    return file.length();
  }

  /// Formats a file size for display.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Lists files in a directory.
  static Future<List<File>> listFiles(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      return [];
    }

    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        files.add(entity);
      }
    }
    return files;
  }

  /// Lists files with a specific extension.
  static Future<List<File>> listFilesWithExtension(
    String dirPath,
    String extension,
  ) async {
    final files = await listFiles(dirPath);
    return files
        .where((f) => path.extension(f.path).toLowerCase() == extension)
        .toList();
  }
}
