// mobile/test/presentation/providers/learning_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/presentation/providers/learning_provider.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';

void main() {
  late LearningNotifier notifier;

  setUp(() {
    notifier = LearningNotifier();
  });

  group('LearningNotifier', () {
    test('initial state', () {
      expect(notifier.state.selectedSentenceIndex, 0);
      expect(notifier.state.showTranslation, isTrue);
      // Source defaults showExplanationNl and showExplanationEn to true
      expect(notifier.state.showExplanationNl, isTrue);
      expect(notifier.state.showExplanationEn, isTrue);
      expect(notifier.state.selectedKeyword, isNull);
      expect(notifier.state.autoAdvance, isTrue);
    });

    test('selectSentence updates index', () {
      notifier.selectSentence(5);
      expect(notifier.state.selectedSentenceIndex, 5);
    });

    test('nextSentence increments within bounds', () {
      notifier.nextSentence(10);
      expect(notifier.state.selectedSentenceIndex, 1);
    });

    test('nextSentence does not exceed maxIndex', () {
      // maxIndex parameter is the upper bound (exclusive-like):
      // condition is selectedSentenceIndex < maxIndex
      // so at index 9 with maxIndex 9, 9 < 9 is false, stays at 9
      notifier.selectSentence(9);
      notifier.nextSentence(9);
      expect(notifier.state.selectedSentenceIndex, 9);
    });

    test('previousSentence decrements', () {
      notifier.selectSentence(3);
      notifier.previousSentence();
      expect(notifier.state.selectedSentenceIndex, 2);
    });

    test('previousSentence does not go below zero', () {
      notifier.previousSentence();
      expect(notifier.state.selectedSentenceIndex, 0);
    });

    test('toggleTranslation toggles visibility', () {
      expect(notifier.state.showTranslation, isTrue);
      notifier.toggleTranslation();
      expect(notifier.state.showTranslation, isFalse);
      notifier.toggleTranslation();
      expect(notifier.state.showTranslation, isTrue);
    });

    test('toggleExplanationNl toggles', () {
      // Starts as true, toggle makes it false
      expect(notifier.state.showExplanationNl, isTrue);
      notifier.toggleExplanationNl();
      expect(notifier.state.showExplanationNl, isFalse);
    });

    test('toggleExplanationEn toggles', () {
      // Starts as true, toggle makes it false
      expect(notifier.state.showExplanationEn, isTrue);
      notifier.toggleExplanationEn();
      expect(notifier.state.showExplanationEn, isFalse);
    });

    test('selectKeyword and clearKeyword', () {
      const kw = Keyword(
        id: 'k1',
        sentenceId: 's1',
        word: 'fiets',
        meaningNl: 'tweewieler',
        meaningEn: 'bicycle',
      );
      notifier.selectKeyword(kw);
      expect(notifier.state.selectedKeyword?.word, 'fiets');

      notifier.clearKeyword();
      expect(notifier.state.selectedKeyword, isNull);
    });

    test('toggleAutoAdvance toggles', () {
      notifier.toggleAutoAdvance();
      expect(notifier.state.autoAdvance, isFalse);
    });

    test('setAutoAdvance sets directly', () {
      notifier.setAutoAdvance(false);
      expect(notifier.state.autoAdvance, isFalse);
      notifier.setAutoAdvance(true);
      expect(notifier.state.autoAdvance, isTrue);
    });

    test('reset returns to initial state', () {
      notifier.selectSentence(5);
      notifier.toggleTranslation();
      notifier.toggleExplanationNl();
      notifier.reset();
      expect(notifier.state.selectedSentenceIndex, 0);
      expect(notifier.state.showTranslation, isTrue);
      expect(notifier.state.showExplanationNl, isTrue);
    });
  });
}
