import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Service for audio playback operations.
///
/// Wraps just_audio functionality for playing audio files
/// with support for seeking, speed control, and looping.
class AudioService {
  final AudioPlayer _player;

  /// Stream of current position.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of buffered position.
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// Stream of duration.
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of player state.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of playing state.
  Stream<bool> get playingStream => _player.playingStream;

  /// Current position.
  Duration get position => _player.position;

  /// Current duration.
  Duration? get duration => _player.duration;

  /// Whether audio is currently playing.
  bool get playing => _player.playing;

  /// Current playback speed.
  double get speed => _player.speed;

  /// Whether looping is enabled.
  bool get looping => _player.loopMode != LoopMode.off;

  AudioService() : _player = AudioPlayer();

  /// Loads an audio file from a local path.
  Future<Duration?> loadFile(String path) async {
    return _player.setFilePath(path);
  }

  /// Loads an audio file from a URL.
  Future<Duration?> loadUrl(String url) async {
    return _player.setUrl(url);
  }

  /// Plays the audio.
  Future<void> play() async {
    await _player.play();
  }

  /// Pauses the audio.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Stops the audio.
  Future<void> stop() async {
    await _player.stop();
  }

  /// Seeks to a specific position.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Seeks to a specific position in seconds.
  Future<void> seekToSeconds(double seconds) async {
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  /// Sets the playback speed.
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// Enables or disables looping.
  Future<void> setLooping(bool loop) async {
    await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
  }

  /// Sets the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  /// Disposes the audio player.
  Future<void> dispose() async {
    await _player.dispose();
  }

  /// Sets a clip to loop between start and end times.
  Future<Duration?> setClip({
    Duration? start,
    Duration? end,
  }) async {
    return _player.setClip(start: start, end: end);
  }

  /// Clears the clip and allows full playback.
  Future<Duration?> clearClip() async {
    return _player.setClip();
  }

  /// Gets the current position as seconds.
  double get positionSeconds => position.inMilliseconds / 1000.0;

  /// Gets the duration as seconds.
  double? get durationSeconds {
    final d = duration;
    if (d == null) return null;
    return d.inMilliseconds / 1000.0;
  }

  /// Skips forward by the given duration.
  Future<void> skipForward(Duration amount) async {
    final newPosition = position + amount;
    final maxPosition = duration ?? newPosition;
    await seek(newPosition > maxPosition ? maxPosition : newPosition);
  }

  /// Skips backward by the given duration.
  Future<void> skipBackward(Duration amount) async {
    final newPosition = position - amount;
    await seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  /// Creates a combined stream of position, duration, and playing state.
  Stream<AudioState> get stateStream {
    return _player.positionStream.map((position) => AudioState(
      position: position,
      duration: _player.duration ?? Duration.zero,
      playing: _player.playing,
      speed: _player.speed,
    ));
  }
}

/// Represents the current audio playback state.
class AudioState {
  final Duration position;
  final Duration duration;
  final bool playing;
  final double speed;

  const AudioState({
    required this.position,
    required this.duration,
    required this.playing,
    required this.speed,
  });

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
