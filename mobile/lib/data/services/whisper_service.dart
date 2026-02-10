import 'dart:io';

import 'package:dio/dio.dart';

/// Service for OpenAI Whisper API transcription.
class WhisperService {
  final Dio _dio;

  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'whisper-1';

  WhisperService({required String apiKey})
      : _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ));

  /// Transcribes an audio file using Whisper API.
  ///
  /// Returns a list of segments with timestamps.
  Future<TranscriptionResult> transcribe(
    File audioFile, {
    String language = 'nl',
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Preparing audio for transcription...');

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFile.path,
          filename: audioFile.uri.pathSegments.last,
        ),
        'model': _model,
        'language': language,
        'response_format': 'verbose_json',
        'timestamp_granularities[]': 'segment',
      });

      onProgress?.call('Uploading to Whisper API...');

      final response = await _dio.post(
        '/audio/transcriptions',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      onProgress?.call('Processing response...');

      final data = response.data as Map<String, dynamic>;

      // Parse segments
      final segments = <TranscriptionSegment>[];
      final rawSegments = data['segments'] as List<dynamic>? ?? [];

      for (final seg in rawSegments) {
        segments.add(TranscriptionSegment(
          id: seg['id'] as int,
          text: (seg['text'] as String).trim(),
          startTime: (seg['start'] as num).toDouble(),
          endTime: (seg['end'] as num).toDouble(),
        ));
      }

      return TranscriptionResult(
        text: data['text'] as String,
        language: data['language'] as String? ?? language,
        duration: data['duration'] as double?,
        segments: segments,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final error = e.response!.data;
        throw WhisperException(
          'Transcription failed: ${error['error']?['message'] ?? e.message}',
        );
      }
      throw WhisperException('Network error: ${e.message}');
    } catch (e) {
      throw WhisperException('Transcription failed: $e');
    }
  }
}

/// Result of a transcription.
class TranscriptionResult {
  final String text;
  final String language;
  final double? duration;
  final List<TranscriptionSegment> segments;

  TranscriptionResult({
    required this.text,
    required this.language,
    this.duration,
    required this.segments,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'language': language,
        'duration': duration,
        'segments': segments.map((s) => s.toJson()).toList(),
      };
}

/// A segment of transcribed audio.
class TranscriptionSegment {
  final int id;
  final String text;
  final double startTime;
  final double endTime;

  TranscriptionSegment({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'start_time': startTime,
        'end_time': endTime,
      };
}

/// Exception for Whisper API errors.
class WhisperException implements Exception {
  final String message;

  WhisperException(this.message);

  @override
  String toString() => 'WhisperException: $message';
}
