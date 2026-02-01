import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/core/constants/app_constants.dart';
import 'package:dutch_learn_app/data/services/audio_service.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/injection_container.dart';

/// State for audio playback.
class AudioState {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final bool isLoaded;
  final double speed;
  final bool isLooping;
  final int loopCount;
  final int currentLoop;
  final String? error;

  const AudioState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.isLoaded = false,
    this.speed = 1.0,
    this.isLooping = false,
    this.loopCount = 1,
    this.currentLoop = 0,
    this.error,
  });

  AudioState copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    bool? isLoaded,
    double? speed,
    bool? isLooping,
    int? loopCount,
    int? currentLoop,
    String? error,
  }) {
    return AudioState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isLoaded: isLoaded ?? this.isLoaded,
      speed: speed ?? this.speed,
      isLooping: isLooping ?? this.isLooping,
      loopCount: loopCount ?? this.loopCount,
      currentLoop: currentLoop ?? this.currentLoop,
      error: error,
    );
  }

  /// Progress as a value between 0 and 1.
  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  /// Position in seconds.
  double get positionSeconds => position.inMilliseconds / 1000.0;

  /// Duration in seconds.
  double get durationSeconds => duration.inMilliseconds / 1000.0;
}

/// Notifier for managing audio playback state.
class AudioNotifier extends StateNotifier<AudioState> {
  final AudioService _audioService;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;

  // Sentence looping state
  Sentence? _currentSentence;
  Timer? _loopTimer;

  AudioNotifier(this._audioService) : super(const AudioState()) {
    _setupListeners();
  }

  void _setupListeners() {
    _positionSubscription = _audioService.positionStream.listen((position) {
      state = state.copyWith(position: position);

      // Check if we need to loop the sentence
      if (_currentSentence != null && state.isLooping) {
        _checkSentenceLoop(position);
      }
    });

    _durationSubscription = _audioService.durationStream.listen((duration) {
      state = state.copyWith(duration: duration ?? Duration.zero);
    });

    _playingSubscription = _audioService.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
  }

  void _checkSentenceLoop(Duration position) {
    if (_currentSentence == null) return;

    final endTime = _currentSentence!.endTimeAsDuration;
    if (position >= endTime) {
      final newLoop = state.currentLoop + 1;

      if (newLoop < state.loopCount) {
        // Continue looping
        state = state.copyWith(currentLoop: newLoop);
        seekToSentence(_currentSentence!);
      } else {
        // Stop looping
        state = state.copyWith(currentLoop: 0, isLooping: false);
        _currentSentence = null;
      }
    }
  }

  /// Loads an audio file from a local path.
  Future<void> loadFile(String path) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final duration = await _audioService.loadFile(path);
      state = state.copyWith(
        duration: duration ?? Duration.zero,
        isLoading: false,
        isLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoaded: false,
        error: 'Failed to load audio: $e',
      );
    }
  }

  /// Plays the audio.
  Future<void> play() async {
    try {
      await _audioService.play();
    } catch (e) {
      state = state.copyWith(error: 'Failed to play: $e');
    }
  }

  /// Pauses the audio.
  Future<void> pause() async {
    try {
      await _audioService.pause();
    } catch (e) {
      state = state.copyWith(error: 'Failed to pause: $e');
    }
  }

  /// Toggles play/pause.
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Stops the audio.
  Future<void> stop() async {
    try {
      await _audioService.stop();
      _currentSentence = null;
      state = state.copyWith(isLooping: false, currentLoop: 0);
    } catch (e) {
      state = state.copyWith(error: 'Failed to stop: $e');
    }
  }

  /// Seeks to a specific position.
  Future<void> seek(Duration position) async {
    try {
      await _audioService.seek(position);
    } catch (e) {
      state = state.copyWith(error: 'Failed to seek: $e');
    }
  }

  /// Seeks to a specific position in seconds.
  Future<void> seekToSeconds(double seconds) async {
    await seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  /// Seeks to the start of a sentence.
  Future<void> seekToSentence(Sentence sentence) async {
    await seek(sentence.startTimeAsDuration);
  }

  /// Plays a specific sentence.
  Future<void> playSentence(Sentence sentence, {bool loop = false}) async {
    _currentSentence = sentence;

    if (loop) {
      state = state.copyWith(
        isLooping: true,
        currentLoop: 0,
      );
    }

    await seekToSentence(sentence);
    await play();
  }

  /// Sets the playback speed.
  Future<void> setSpeed(double speed) async {
    try {
      await _audioService.setSpeed(speed);
      state = state.copyWith(speed: speed);
    } catch (e) {
      state = state.copyWith(error: 'Failed to set speed: $e');
    }
  }

  /// Cycles through playback speed options.
  Future<void> cycleSpeed() async {
    final currentIndex = AppConstants.playbackSpeedOptions.indexOf(state.speed);
    final nextIndex =
        (currentIndex + 1) % AppConstants.playbackSpeedOptions.length;
    await setSpeed(AppConstants.playbackSpeedOptions[nextIndex]);
  }

  /// Enables or disables sentence looping.
  void setLooping(bool enabled, {int count = 1}) {
    state = state.copyWith(
      isLooping: enabled,
      loopCount: count,
      currentLoop: 0,
    );
  }

  /// Sets the loop count.
  void setLoopCount(int count) {
    state = state.copyWith(loopCount: count);
  }

  /// Skips forward by 5 seconds.
  Future<void> skipForward() async {
    await _audioService.skipForward(const Duration(seconds: 5));
  }

  /// Skips backward by 5 seconds.
  Future<void> skipBackward() async {
    await _audioService.skipBackward(const Duration(seconds: 5));
  }

  /// Clears any error.
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _loopTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}

/// Provider for audio state.
final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  return AudioNotifier(audioService);
});

/// Provider for formatted position string.
final positionStringProvider = Provider<String>((ref) {
  final state = ref.watch(audioProvider);
  return _formatDuration(state.position);
});

/// Provider for formatted duration string.
final durationStringProvider = Provider<String>((ref) {
  final state = ref.watch(audioProvider);
  return _formatDuration(state.duration);
});

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
