import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/presentation/providers/audio_provider.dart';
import 'package:dutch_learn_app/presentation/providers/project_provider.dart';
import 'package:dutch_learn_app/presentation/providers/review_provider.dart';

/// Review screen for difficult sentences with audio-first flashcard mode.
class ReviewScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ReviewScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  Timer? _autoRevealTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reviewProvider.notifier).loadDifficultSentences(widget.projectId);
    });
  }

  @override
  void dispose() {
    _autoRevealTimer?.cancel();
    super.dispose();
  }

  void _startAutoRevealTimer() {
    _autoRevealTimer?.cancel();
    _autoRevealTimer = Timer(const Duration(seconds: 5), () {
      final reviewState = ref.read(reviewProvider);
      if (!reviewState.isTextRevealed && !reviewState.isComplete) {
        ref.read(reviewProvider.notifier).revealText();
      }
    });
  }

  void _playCurrent() {
    final reviewState = ref.read(reviewProvider);
    final sentence = reviewState.currentSentence;
    if (sentence != null) {
      ref.read(audioProvider.notifier).playSentence(sentence);
      _startAutoRevealTimer();
    }
  }

  void _revealAndAdvance() {
    final reviewState = ref.read(reviewProvider);
    if (!reviewState.isTextRevealed) {
      ref.read(reviewProvider.notifier).revealText();
      _autoRevealTimer?.cancel();
    } else {
      _advance();
    }
  }

  Future<void> _advance() async {
    _autoRevealTimer?.cancel();
    await ref.read(reviewProvider.notifier).nextSentence();
    final reviewState = ref.read(reviewProvider);
    if (!reviewState.isComplete) {
      _playCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewProvider);
    final projectState = ref.watch(projectDetailProvider(widget.projectId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review${projectState.project != null ? ' - ${projectState.project!.name}' : ''}',
        ),
      ),
      body: _buildBody(reviewState, theme),
    );
  }

  Widget _buildBody(ReviewState reviewState, ThemeData theme) {
    if (reviewState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reviewState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(reviewState.error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref
                  .read(reviewProvider.notifier)
                  .loadDifficultSentences(widget.projectId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (reviewState.isComplete && reviewState.sentences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No difficult sentences bookmarked',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on sentences to add them for review.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (reviewState.isComplete) {
      return _buildCompletionView(reviewState, theme);
    }

    return _buildReviewCard(reviewState, theme);
  }

  Widget _buildCompletionView(ReviewState reviewState, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Review Complete!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Reviewed ${reviewState.totalCount} sentence${reviewState.totalCount == 1 ? '' : 's'}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () {
                ref.read(reviewProvider.notifier).loadDifficultSentences(widget.projectId);
              },
              child: const Text('Review Again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Learning'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewState reviewState, ThemeData theme) {
    final sentence = reviewState.currentSentence!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: reviewState.totalCount > 0
                      ? (reviewState.reviewedCount + 1) / reviewState.totalCount
                      : 0,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${reviewState.reviewedCount + 1} / ${reviewState.totalCount}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Flashcard
          Expanded(
            child: GestureDetector(
              onTap: _revealAndAdvance,
              child: Card(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!reviewState.isTextRevealed) ...[
                          Icon(
                            Icons.hearing,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Listen carefully...',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to reveal text',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ] else ...[
                          // Revealed text
                          Text(
                            sentence.text,
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          if (sentence.translationEn != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              sentence.translationEn!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (sentence.explanationEn != null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              sentence.explanationEn!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const Spacer(),
                          Text(
                            'Tap to continue',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Audio controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: _playCurrent,
                icon: const Icon(Icons.replay),
                tooltip: 'Replay',
              ),
              const SizedBox(width: 16),
              if (!reviewState.isTextRevealed)
                FilledButton.icon(
                  onPressed: () {
                    ref.read(reviewProvider.notifier).revealText();
                    _autoRevealTimer?.cancel();
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Reveal'),
                )
              else
                FilledButton.icon(
                  onPressed: _advance,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
