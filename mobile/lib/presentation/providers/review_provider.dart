import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/data/local/daos/keyword_dao.dart';
import 'package:dutch_learn_app/data/local/daos/sentence_dao.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/injection_container.dart';

/// State for the review mode.
class ReviewState {
  final List<Sentence> sentences;
  final int currentIndex;
  final bool isTextRevealed;
  final bool isLoading;
  final bool isComplete;
  final String? error;

  const ReviewState({
    this.sentences = const [],
    this.currentIndex = 0,
    this.isTextRevealed = false,
    this.isLoading = false,
    this.isComplete = false,
    this.error,
  });

  Sentence? get currentSentence =>
      currentIndex < sentences.length ? sentences[currentIndex] : null;

  int get totalCount => sentences.length;
  int get reviewedCount => currentIndex;

  ReviewState copyWith({
    List<Sentence>? sentences,
    int? currentIndex,
    bool? isTextRevealed,
    bool? isLoading,
    bool? isComplete,
    String? error,
  }) {
    return ReviewState(
      sentences: sentences ?? this.sentences,
      currentIndex: currentIndex ?? this.currentIndex,
      isTextRevealed: isTextRevealed ?? this.isTextRevealed,
      isLoading: isLoading ?? this.isLoading,
      isComplete: isComplete ?? this.isComplete,
      error: error,
    );
  }
}

/// Notifier for managing review mode state.
class ReviewNotifier extends StateNotifier<ReviewState> {
  final SentenceDao _sentenceDao;
  final KeywordDao _keywordDao;

  ReviewNotifier(this._sentenceDao, this._keywordDao)
      : super(const ReviewState());

  /// Loads all difficult sentences for a project.
  Future<void> loadDifficultSentences(String projectId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final models = await _sentenceDao.getDifficultByProjectId(projectId);
      // Load keywords for each sentence
      final sentenceIds = models.map((s) => s.id).toList();
      final keywordMap = await _keywordDao.getBySentenceIds(sentenceIds);
      final sentences = models.map((s) {
        final keywords =
            keywordMap[s.id]?.map((k) => k.toEntity()).toList() ?? [];
        return s.withKeywords(keywords).toEntity();
      }).toList();
      state = state.copyWith(
        sentences: sentences,
        currentIndex: 0,
        isTextRevealed: false,
        isLoading: false,
        isComplete: sentences.isEmpty,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Reveals the text for the current sentence.
  void revealText() {
    state = state.copyWith(isTextRevealed: true);
  }

  /// Advances to the next sentence, recording a review for the current one.
  Future<void> nextSentence() async {
    final current = state.currentSentence;
    if (current != null) {
      await _sentenceDao.recordReview(current.id);
    }

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.sentences.length) {
      state = state.copyWith(isComplete: true);
    } else {
      state = state.copyWith(
        currentIndex: nextIndex,
        isTextRevealed: false,
      );
    }
  }

  /// Resets the review state.
  void reset() {
    state = const ReviewState();
  }
}

/// Provider for review mode.
final reviewProvider =
    StateNotifierProvider.autoDispose<ReviewNotifier, ReviewState>((ref) {
  final sentenceDao = ref.watch(sentenceDaoProvider);
  final keywordDao = ref.watch(keywordDaoProvider);
  return ReviewNotifier(sentenceDao, keywordDao);
});
