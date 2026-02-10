import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/presentation/providers/review_provider.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';

/// Helper to create a minimal Sentence for testing.
Sentence _makeSentence({required String id, int index = 0}) {
  return Sentence(
    id: id,
    projectId: 'proj-1',
    index: index,
    text: 'Hallo wereld',
    startTime: 0.0,
    endTime: 1.0,
  );
}

void main() {
  group('ReviewState', () {
    test('initial state has correct defaults', () {
      const state = ReviewState();

      expect(state.sentences, isEmpty);
      expect(state.currentIndex, 0);
      expect(state.isTextRevealed, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isComplete, isFalse);
      expect(state.error, isNull);
    });

    test('currentSentence returns null when empty', () {
      const state = ReviewState();

      expect(state.currentSentence, isNull);
    });

    test('totalCount and reviewedCount reflect state', () {
      final sentences = [
        _makeSentence(id: 's1', index: 0),
        _makeSentence(id: 's2', index: 1),
        _makeSentence(id: 's3', index: 2),
      ];
      final state = ReviewState(sentences: sentences, currentIndex: 2);

      expect(state.totalCount, 3);
      expect(state.reviewedCount, 2);
      expect(state.currentSentence, sentences[2]);
    });

    test('copyWith preserves unset fields', () {
      final sentences = [
        _makeSentence(id: 's1'),
        _makeSentence(id: 's2', index: 1),
      ];
      final original = ReviewState(
        sentences: sentences,
        currentIndex: 1,
        isTextRevealed: true,
        isLoading: true,
        isComplete: false,
        error: 'some error',
      );

      // Only change isLoading; everything else should be preserved.
      final updated = original.copyWith(isLoading: false);

      expect(updated.sentences, sentences);
      expect(updated.currentIndex, 1);
      expect(updated.isTextRevealed, isTrue);
      expect(updated.isLoading, isFalse);
      expect(updated.isComplete, isFalse);
      // Note: copyWith always passes error directly (not ?? this.error),
      // so omitting error sets it to null.
      // This is the documented behavior tested in the next test.
    });

    test('copyWith sets error to null when provided', () {
      final stateWithError = const ReviewState().copyWith(error: 'failure');
      expect(stateWithError.error, 'failure');

      // Calling copyWith without error clears it (error is passed directly,
      // not preserved via ?? this.error).
      final cleared = stateWithError.copyWith();
      expect(cleared.error, isNull);

      // Explicitly passing null also clears it.
      final explicitNull = stateWithError.copyWith(error: null);
      expect(explicitNull.error, isNull);
    });
  });
}
