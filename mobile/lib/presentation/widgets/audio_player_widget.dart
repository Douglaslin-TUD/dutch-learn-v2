import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/core/constants/app_constants.dart';
import 'package:dutch_learn_app/core/extensions/duration_extension.dart';
import 'package:dutch_learn_app/presentation/providers/audio_provider.dart';

/// Widget for audio playback controls.
class AudioPlayerWidget extends ConsumerWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const AudioPlayerWidget({
    super.key,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress slider
          Row(
            children: [
              Text(
                audioState.position.formatted,
                style: theme.textTheme.bodySmall,
              ),
              Expanded(
                child: Slider(
                  value: audioState.progress.clamp(0.0, 1.0),
                  onChanged: audioState.isLoaded
                      ? (value) {
                          final position = Duration(
                            milliseconds:
                                (value * audioState.duration.inMilliseconds)
                                    .round(),
                          );
                          audioNotifier.seek(position);
                        }
                      : null,
                ),
              ),
              Text(
                audioState.duration.formatted,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed button
              _SpeedButton(
                speed: audioState.speed,
                onTap: () => audioNotifier.cycleSpeed(),
              ),
              // Skip backward
              IconButton(
                icon: const Icon(Icons.replay_5),
                onPressed: audioState.isLoaded
                    ? () => audioNotifier.skipBackward()
                    : null,
                tooltip: 'Skip back 5s',
              ),
              // Previous sentence
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: onPrevious,
                tooltip: 'Previous sentence',
              ),
              // Play/pause button
              _PlayPauseButton(
                isPlaying: audioState.isPlaying,
                isLoading: audioState.isLoading,
                isLoaded: audioState.isLoaded,
                onPressed: () => audioNotifier.togglePlayPause(),
              ),
              // Next sentence
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: onNext,
                tooltip: 'Next sentence',
              ),
              // Skip forward
              IconButton(
                icon: const Icon(Icons.forward_5),
                onPressed: audioState.isLoaded
                    ? () => audioNotifier.skipForward()
                    : null,
                tooltip: 'Skip forward 5s',
              ),
              // Loop button
              _LoopButton(
                isLooping: audioState.isLooping,
                loopCount: audioState.loopCount,
                currentLoop: audioState.currentLoop,
                onTap: () => audioNotifier.setLooping(!audioState.isLooping),
                onLongPress: () => _showLoopDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLoopDialog(BuildContext context, WidgetRef ref) {
    final audioState = ref.read(audioProvider);
    var loopCount = audioState.loopCount;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Loop Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Number of times to loop:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: loopCount > 1
                        ? () => setState(() => loopCount--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$loopCount',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: loopCount < AppConstants.maxLoopCount
                        ? () => setState(() => loopCount++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(audioProvider.notifier).setLoopCount(loopCount);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final bool isLoaded;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.isLoaded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Container(
        width: AppConstants.playPauseButtonSize,
        height: AppConstants.playPauseButtonSize,
        padding: const EdgeInsets.all(16),
        child: const CircularProgressIndicator(),
      );
    }

    return Container(
      width: AppConstants.playPauseButtonSize,
      height: AppConstants.playPauseButtonSize,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          size: 32,
        ),
        color: theme.colorScheme.onPrimary,
        onPressed: isLoaded ? onPressed : null,
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final double speed;
  final VoidCallback onTap;

  const _SpeedButton({
    required this.speed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${speed}x',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LoopButton extends StatelessWidget {
  final bool isLooping;
  final int loopCount;
  final int currentLoop;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LoopButton({
    required this.isLooping,
    required this.loopCount,
    required this.currentLoop,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(
              Icons.repeat,
              color: isLooping ? theme.colorScheme.primary : null,
            ),
            onPressed: onTap,
            tooltip: 'Loop (long press for settings)',
          ),
          if (isLooping)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${currentLoop + 1}/$loopCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact audio player for smaller spaces.
class CompactAudioPlayer extends ConsumerWidget {
  const CompactAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Play/pause
          IconButton(
            icon: Icon(
              audioState.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
            onPressed: audioState.isLoaded
                ? () => audioNotifier.togglePlayPause()
                : null,
          ),
          // Position
          Text(
            audioState.position.formatted,
            style: theme.textTheme.bodySmall,
          ),
          // Slider
          Expanded(
            child: Slider(
              value: audioState.progress.clamp(0.0, 1.0),
              onChanged: audioState.isLoaded
                  ? (value) {
                      final position = Duration(
                        milliseconds:
                            (value * audioState.duration.inMilliseconds).round(),
                      );
                      audioNotifier.seek(position);
                    }
                  : null,
            ),
          ),
          // Duration
          Text(
            audioState.duration.formatted,
            style: theme.textTheme.bodySmall,
          ),
          // Speed
          TextButton(
            onPressed: () => audioNotifier.cycleSpeed(),
            child: Text('${audioState.speed}x'),
          ),
        ],
      ),
    );
  }
}
