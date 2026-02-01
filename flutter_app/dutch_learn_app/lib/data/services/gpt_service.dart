import 'dart:convert';

import 'package:dio/dio.dart';

/// Service for OpenAI GPT API for generating explanations.
class GptService {
  final Dio _dio;
  final String _apiKey;

  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4o-mini';

  GptService({required String apiKey})
      : _apiKey = apiKey,
        _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 2),
        ));

  /// Generates explanations for a Dutch sentence.
  Future<SentenceExplanation> explainSentence(
    String sentence, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Generating explanation...');

    final prompt = '''
Analyze this Dutch sentence and provide:
1. An English translation
2. A brief explanation in Dutch about grammar and context
3. A brief explanation in English about grammar and context
4. Key vocabulary words with their meanings

Sentence: "$sentence"

Respond in this exact JSON format:
{
  "translation_en": "English translation here",
  "explanation_nl": "Dutch explanation of grammar and context",
  "explanation_en": "English explanation of grammar and context",
  "keywords": [
    {
      "word": "Dutch word",
      "meaning_nl": "Meaning in Dutch",
      "meaning_en": "Meaning in English"
    }
  ]
}

Only respond with valid JSON, no additional text.
''';

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a Dutch language teacher helping students learn Dutch. Always respond with valid JSON only.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 1000,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final content =
          data['choices'][0]['message']['content'] as String;

      // Parse JSON response
      final parsed = jsonDecode(content) as Map<String, dynamic>;

      final keywords = <Keyword>[];
      final rawKeywords = parsed['keywords'] as List<dynamic>? ?? [];
      for (final kw in rawKeywords) {
        keywords.add(Keyword(
          word: kw['word'] as String,
          meaningNl: kw['meaning_nl'] as String,
          meaningEn: kw['meaning_en'] as String,
        ));
      }

      return SentenceExplanation(
        translationEn: parsed['translation_en'] as String,
        explanationNl: parsed['explanation_nl'] as String,
        explanationEn: parsed['explanation_en'] as String,
        keywords: keywords,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final error = e.response!.data;
        throw GptException(
          'Explanation failed: ${error['error']?['message'] ?? e.message}',
        );
      }
      throw GptException('Network error: ${e.message}');
    } catch (e) {
      throw GptException('Explanation failed: $e');
    }
  }

  /// Generates explanations for multiple sentences.
  Future<List<SentenceExplanation>> explainSentences(
    List<String> sentences, {
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <SentenceExplanation>[];

    for (var i = 0; i < sentences.length; i++) {
      onProgress?.call(i + 1, sentences.length);

      final explanation = await explainSentence(sentences[i]);
      results.add(explanation);

      // Small delay to avoid rate limiting
      if (i < sentences.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return results;
  }
}

/// Explanation for a sentence.
class SentenceExplanation {
  final String translationEn;
  final String explanationNl;
  final String explanationEn;
  final List<Keyword> keywords;

  SentenceExplanation({
    required this.translationEn,
    required this.explanationNl,
    required this.explanationEn,
    required this.keywords,
  });

  Map<String, dynamic> toJson() => {
        'translation_en': translationEn,
        'explanation_nl': explanationNl,
        'explanation_en': explanationEn,
        'keywords': keywords.map((k) => k.toJson()).toList(),
      };
}

/// A keyword with its meaning.
class Keyword {
  final String word;
  final String meaningNl;
  final String meaningEn;

  Keyword({
    required this.word,
    required this.meaningNl,
    required this.meaningEn,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'meaning_nl': meaningNl,
        'meaning_en': meaningEn,
      };
}

/// Exception for GPT API errors.
class GptException implements Exception {
  final String message;

  GptException(this.message);

  @override
  String toString() => 'GptException: $message';
}
