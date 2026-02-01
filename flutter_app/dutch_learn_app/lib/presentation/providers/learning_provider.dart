import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/domain/entities/keyword.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/presentation/providers/audio_provider.dart';
import 'package:dutch_learn_app/presentation/providers/project_provider.dart';

/// State for learning screen.
class LearningState {
  final int selectedSentenceIndex;
  final bool showTranslation;
  final bool showExplanationNl;
  final bool showExplanationEn;
  final bool showKeywords;
  final Keyword? selectedKeyword;
  final bool autoAdvance;

  const LearningState({
    this.selectedSentenceIndex = 0,
    this.showTranslation = true,
    this.showExplanationNl = true,
    this.showExplanationEn = true,
    this.showKeywords = true,
    this.selectedKeyword,
    this.autoAdvance = true,
  });

  LearningState copyWith({
    int? selectedSentenceIndex,
    bool? showTranslation,
    bool? showExplanationNl,
    bool? showExplanationEn,
    bool? showKeywords,
    Keyword? selectedKeyword,
    bool? autoAdvance,
    bool clearKeyword = false,
  }) {
    return LearningState(
      selectedSentenceIndex: selectedSentenceIndex ?? this.selectedSentenceIndex,
      showTranslation: showTranslation ?? this.showTranslation,
      showExplanationNl: showExplanationNl ?? this.showExplanationNl,
      showExplanationEn: showExplanationEn ?? this.showExplanationEn,
      showKeywords: showKeywords ?? this.showKeywords,
      selectedKeyword: clearKeyword ? null : (selectedKeyword ?? this.selectedKeyword),
      autoAdvance: autoAdvance ?? this.autoAdvance,
    );
  }
}

/// Notifier for managing learning state.
class LearningNotifier extends StateNotifier<LearningState> {
  LearningNotifier() : super(const LearningState());

  /// Selects a sentence by index.
  void selectSentence(int index) {
    state = state.copyWith(selectedSentenceIndex: index, clearKeyword: true);
  }

  /// Selects the next sentence.
  void nextSentence(int maxIndex) {
    if (state.selectedSentenceIndex < maxIndex) {
      selectSentence(state.selectedSentenceIndex + 1);
    }
  }

  /// Selects the previous sentence.
  void previousSentence() {
    if (state.selectedSentenceIndex > 0) {
      selectSentence(state.selectedSentenceIndex - 1);
    }
  }

  /// Toggles translation visibility.
  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }

  /// Toggles Dutch explanation visibility.
  void toggleExplanationNl() {
    state = state.copyWith(showExplanationNl: !state.showExplanationNl);
  }

  /// Toggles English explanation visibility.
  void toggleExplanationEn() {
    state = state.copyWith(showExplanationEn: !state.showExplanationEn);
  }

  /// Toggles keywords visibility.
  void toggleKeywords() {
    state = state.copyWith(showKeywords: !state.showKeywords);
  }

  /// Selects a keyword to show popup.
  void selectKeyword(Keyword keyword) {
    state = state.copyWith(selectedKeyword: keyword);
  }

  /// Clears the selected keyword.
  void clearKeyword() {
    state = state.copyWith(clearKeyword: true);
  }

  /// Toggles auto-advance mode.
  void toggleAutoAdvance() {
    state = state.copyWith(autoAdvance: !state.autoAdvance);
  }

  /// Sets auto-advance mode.
  void setAutoAdvance(bool enabled) {
    state = state.copyWith(autoAdvance: enabled);
  }

  /// Resets to initial state.
  void reset() {
    state = const LearningState();
  }
}

/// Provider for learning state.
final learningProvider =
    StateNotifierProvider<LearningNotifier, LearningState>((ref) {
  return LearningNotifier();
});

/// Provider for the currently selected sentence.
final selectedSentenceProvider = Provider<Sentence?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;

  final projectState = ref.watch(projectDetailProvider(projectId));
  final learningState = ref.watch(learningProvider);

  if (projectState.sentences.isEmpty) return null;

  final index = learningState.selectedSentenceIndex;
  if (index < 0 || index >= projectState.sentences.length) return null;

  return projectState.sentences[index];
});

/// Provider for finding which sentence is currently playing.
final currentPlayingSentenceProvider = Provider<Sentence?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;

  final projectState = ref.watch(projectDetailProvider(projectId));
  final audioState = ref.watch(audioProvider);

  if (projectState.sentences.isEmpty) return null;

  final positionSeconds = audioState.positionSeconds;

  // Find the sentence that contains the current position
  for (final sentence in projectState.sentences) {
    if (sentence.containsPosition(positionSeconds)) {
      return sentence;
    }
  }

  return null;
});

/// Provider for sentence progress (current index / total).
final sentenceProgressProvider = Provider<double>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return 0;

  final projectState = ref.watch(projectDetailProvider(projectId));
  final learningState = ref.watch(learningProvider);

  if (projectState.sentences.isEmpty) return 0;

  return (learningState.selectedSentenceIndex + 1) /
      projectState.sentences.length;
});
