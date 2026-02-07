import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:dutch_learn_app/data/services/whisper_service.dart';
import 'package:dutch_learn_app/data/services/gpt_service.dart';

/// Service for processing audio files into Dutch learning projects.
///
/// Pipeline:
/// 1. Extract/convert audio to MP3 (using FFmpeg)
/// 2. Transcribe using Whisper API
/// 3. Generate explanations using GPT API
class AudioProcessor {
  final WhisperService _whisperService;
  final GptService _gptService;

  AudioProcessor({
    required WhisperService whisperService,
    required GptService gptService,
  })  : _whisperService = whisperService,
        _gptService = gptService;

  /// Processes an audio or video file into a learning project.
  Future<ProcessedProject> processFile(
    File inputFile, {
    String? projectName,
    void Function(ProcessingStatus status)? onProgress,
  }) async {
    final projectId = const Uuid().v4();
    final name = projectName ?? _extractFileName(inputFile.path);

    try {
      // Step 1: Convert to MP3
      onProgress?.call(ProcessingStatus(
        stage: ProcessingStage.extracting,
        progress: 0.0,
        message: 'Extracting audio...',
      ));

      final audioFile = await _convertToMp3(inputFile, projectId);

      onProgress?.call(ProcessingStatus(
        stage: ProcessingStage.extracting,
        progress: 1.0,
        message: 'Audio extracted',
      ));

      // Step 2: Transcribe
      onProgress?.call(ProcessingStatus(
        stage: ProcessingStage.transcribing,
        progress: 0.0,
        message: 'Transcribing audio...',
      ));

      final transcription = await _whisperService.transcribe(
        audioFile,
        onProgress: (status) {
          onProgress?.call(ProcessingStatus(
            stage: ProcessingStage.transcribing,
            progress: 0.5,
            message: status,
          ));
        },
      );

      onProgress?.call(ProcessingStatus(
        stage: ProcessingStage.transcribing,
        progress: 1.0,
        message: 'Transcription complete',
      ));

      // Step 3: Generate explanations
      onProgress?.call(ProcessingStatus(
        stage: ProcessingStage.explaining,
        progress: 0.0,
        message: 'Generating explanations...',
      ));

      final sentences = <ProcessedSentence>[];

      for (var i = 0; i < transcription.segments.length; i++) {
        final segment = transcription.segments[i];

        onProgress?.call(ProcessingStatus(
          stage: ProcessingStage.explaining,
          progress: i / transcription.segments.length,
          message: 'Explaining sentence ${i + 1}/${transcription.segments.length}',
        ));

        try {
          final explanation = await _gptService.explainSentence(segment.text);

          sentences.add(ProcessedSentence(
            id: const Uuid().v4(),
            order: i,
            text: segment.text,
            startTime: segment.startTime,
            endTime: segment.endTime,
            translationEn: explanation.translationEn,
            explanationNl: explanation.explanationNl,
            explanationEn: explanation.explanationEn,
            keywords: explanation.keywords.map((k) => ProcessedKeyword(
              id: const Uuid().v4(),
              word: k.word,
              meaningNl: k.meaningNl,
              meaningEn: k.meaningEn,
            )).toList(),
          ));
        } catch (e) {
          // If explanation fails, still include the sentence without explanation
          sentences.add(ProcessedSentence(
            id: const Uuid().v4(),
            order: i,
            text: segment.text,
            startTime: segment.startTime,
            endTime: segment.endTime,
            translationEn: null,
            explanationNl: null,
            explanationEn: null,
            keywords: [],
          ));
        }

        // Small delay to avoid rate limiting
        if (i < transcription.segments.length - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      onProgress?.call(ProcessingStatus(
        stage: ProcessingStage.explaining,
        progress: 1.0,
        message: 'Explanations complete',
      ));

      // Complete
      onProgress?.call(ProcessingStatus(
        stage: ProcessingStage.complete,
        progress: 1.0,
        message: 'Processing complete',
      ));

      return ProcessedProject(
        id: projectId,
        name: name,
        audioFile: audioFile,
        sentences: sentences,
        language: transcription.language,
        duration: transcription.duration,
      );
    } catch (e) {
      onProgress?.call(ProcessingStatus(
        stage: ProcessingStage.error,
        progress: 0.0,
        message: 'Error: $e',
      ));
      rethrow;
    }
  }

  /// Converts input file to MP3 format.
  Future<File> _convertToMp3(File inputFile, String projectId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }

    final outputPath = '${audioDir.path}/$projectId.mp3';

    // Check if already MP3
    if (inputFile.path.toLowerCase().endsWith('.mp3')) {
      await inputFile.copy(outputPath);
      return File(outputPath);
    }

    // Convert using FFmpeg
    final command =
        '-i "${inputFile.path}" -vn -ar 44100 -ac 2 -b:a 192k "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw AudioProcessingException('FFmpeg conversion failed: $logs');
    }

    return File(outputPath);
  }

  /// Extracts file name without extension.
  String _extractFileName(String path) {
    final fileName = path.split('/').last;
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot > 0) {
      return fileName.substring(0, lastDot);
    }
    return fileName;
  }
}

/// Processing status update.
class ProcessingStatus {
  final ProcessingStage stage;
  final double progress;
  final String message;

  ProcessingStatus({
    required this.stage,
    required this.progress,
    required this.message,
  });
}

/// Processing stages.
enum ProcessingStage {
  extracting,
  transcribing,
  explaining,
  complete,
  error,
}

/// A fully processed project.
class ProcessedProject {
  final String id;
  final String name;
  final File audioFile;
  final List<ProcessedSentence> sentences;
  final String language;
  final double? duration;

  ProcessedProject({
    required this.id,
    required this.name,
    required this.audioFile,
    required this.sentences,
    required this.language,
    this.duration,
  });

  /// Converts to JSON for export/storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': 'completed',
        'language': language,
        'duration': duration,
        'created_at': DateTime.now().toIso8601String(),
        'sentences': sentences.map((s) => s.toJson()).toList(),
        'keywords': sentences
            .expand((s) => s.keywords)
            .map((k) => k.toJson())
            .toList(),
      };
}

/// A processed sentence with explanation.
class ProcessedSentence {
  final String id;
  final int order;
  final String text;
  final double startTime;
  final double endTime;
  final String? translationEn;
  final String? explanationNl;
  final String? explanationEn;
  final List<ProcessedKeyword> keywords;

  ProcessedSentence({
    required this.id,
    required this.order,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.translationEn,
    this.explanationNl,
    this.explanationEn,
    required this.keywords,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'text': text,
        'start_time': startTime,
        'end_time': endTime,
        'translation_en': translationEn,
        'explanation_nl': explanationNl,
        'explanation_en': explanationEn,
        'keywords': keywords.map((k) => k.toJson()).toList(),
        'learned': false,
        'learn_count': 0,
      };
}

/// A processed keyword.
class ProcessedKeyword {
  final String id;
  final String word;
  final String meaningNl;
  final String meaningEn;

  ProcessedKeyword({
    required this.id,
    required this.word,
    required this.meaningNl,
    required this.meaningEn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'meaning_nl': meaningNl,
        'meaning_en': meaningEn,
      };
}

/// Exception for audio processing errors.
class AudioProcessingException implements Exception {
  final String message;

  AudioProcessingException(this.message);

  @override
  String toString() => 'AudioProcessingException: $message';
}
