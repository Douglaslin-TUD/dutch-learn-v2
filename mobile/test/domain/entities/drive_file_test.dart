// mobile/test/domain/entities/drive_file_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/domain/entities/drive_file.dart';
import '../../fixtures/test_data.dart';

void main() {
  group('DriveFile Entity', () {
    test('isJson detects JSON files', () {
      final file = TestData.driveFile(name: 'data.json', mimeType: 'application/json');
      expect(file.isJson, isTrue);
      expect(file.isMp3, isFalse);
    });

    test('isMp3 detects MP3 files', () {
      final file = TestData.driveFile(name: 'audio.mp3', mimeType: 'audio/mpeg');
      expect(file.isMp3, isTrue);
      expect(file.isJson, isFalse);
    });

    test('extension extracts correctly', () {
      expect(TestData.driveFile(name: 'file.json').extension, '.json');
      expect(TestData.driveFile(name: 'audio.mp3').extension, '.mp3');
      expect(TestData.driveFile(name: 'noext').extension, '');
    });

    test('nameWithoutExtension strips extension', () {
      expect(TestData.driveFile(name: 'project.json').nameWithoutExtension, 'project');
      expect(TestData.driveFile(name: 'noext').nameWithoutExtension, 'noext');
    });

    test('formattedSize formats bytes', () {
      expect(TestData.driveFile(size: 500).formattedSize, contains('B'));
      expect(TestData.driveFile(size: 1024).formattedSize, contains('KB'));
      expect(TestData.driveFile(size: 1048576).formattedSize, contains('MB'));
      expect(TestData.driveFile(size: null).formattedSize, 'Unknown');
    });

    test('isFolder returns folder state', () {
      expect(TestData.driveFile(isFolder: true).isFolder, isTrue);
      expect(TestData.driveFile(isFolder: false).isFolder, isFalse);
    });

    test('equality by id, name, and mimeType', () {
      final a = TestData.driveFile(id: 'same', name: 'file.json', mimeType: 'application/json');
      final b = TestData.driveFile(id: 'same', name: 'file.json', mimeType: 'application/json');
      expect(a, equals(b));
    });
  });
}
