/// Extensions on [Duration] for convenient formatting and operations.
extension DurationExtension on Duration {
  /// Formats the duration as MM:SS (e.g., "02:35").
  String get formatted {
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Formats the duration as H:MM:SS if hours > 0, otherwise MM:SS.
  String get formattedWithHours {
    if (inHours > 0) {
      final hours = inHours.toString();
      final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return formatted;
  }

  /// Formats the duration as compact string (e.g., "2m 35s").
  String get compact {
    if (inHours > 0) {
      final hours = inHours;
      final minutes = inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    } else if (inMinutes > 0) {
      final minutes = inMinutes;
      final seconds = inSeconds.remainder(60);
      return '${minutes}m ${seconds}s';
    } else {
      return '${inSeconds}s';
    }
  }

  /// Formats as total seconds with milliseconds (e.g., "125.5").
  String get asSecondsString {
    return (inMilliseconds / 1000).toStringAsFixed(1);
  }

  /// Returns the duration in seconds as a double.
  double get asSeconds {
    return inMilliseconds / 1000.0;
  }

  /// Creates a duration from seconds (as double).
  static Duration fromSeconds(double seconds) {
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Checks if this duration is within a range.
  bool isWithin(Duration start, Duration end) {
    return this >= start && this <= end;
  }

  /// Clamps the duration to a range.
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }

  /// Adds a percentage of this duration.
  Duration addPercent(double percent) {
    final addMs = (inMilliseconds * percent / 100).round();
    return this + Duration(milliseconds: addMs);
  }

  /// Returns the percentage of this duration relative to total.
  double percentOf(Duration total) {
    if (total.inMilliseconds == 0) return 0;
    return (inMilliseconds / total.inMilliseconds) * 100;
  }

  /// Multiplies the duration by a factor.
  Duration multiply(double factor) {
    return Duration(milliseconds: (inMilliseconds * factor).round());
  }

  /// Divides the duration by a factor.
  Duration divide(double factor) {
    if (factor == 0) return Duration.zero;
    return Duration(milliseconds: (inMilliseconds / factor).round());
  }
}

/// Extension on double to convert to Duration.
extension DoubleToDuration on double {
  /// Converts seconds to Duration.
  Duration get seconds {
    return Duration(milliseconds: (this * 1000).round());
  }

  /// Converts milliseconds to Duration.
  Duration get milliseconds {
    return Duration(milliseconds: round());
  }

  /// Converts minutes to Duration.
  Duration get minutes {
    return Duration(minutes: round());
  }

  /// Converts hours to Duration.
  Duration get hours {
    return Duration(hours: round());
  }
}

/// Extension on int to convert to Duration.
extension IntToDuration on int {
  /// Converts seconds to Duration.
  Duration get seconds {
    return Duration(seconds: this);
  }

  /// Converts milliseconds to Duration.
  Duration get milliseconds {
    return Duration(milliseconds: this);
  }

  /// Converts minutes to Duration.
  Duration get minutes {
    return Duration(minutes: this);
  }

  /// Converts hours to Duration.
  Duration get hours {
    return Duration(hours: this);
  }
}
