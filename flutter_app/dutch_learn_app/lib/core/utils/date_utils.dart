import 'package:intl/intl.dart';

/// Utility class for date and time operations.
///
/// Provides consistent date formatting and manipulation
/// across the application.
class AppDateUtils {
  AppDateUtils._();

  /// Standard date format for display (e.g., "Dec 31, 2024")
  static final DateFormat _displayFormat = DateFormat('MMM d, yyyy');

  /// Date and time format (e.g., "Dec 31, 2024, 2:30 PM")
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy, h:mm a');

  /// Short date format (e.g., "12/31/24")
  static final DateFormat _shortFormat = DateFormat('M/d/yy');

  /// Time only format (e.g., "2:30 PM")
  static final DateFormat _timeFormat = DateFormat('h:mm a');

  /// ISO 8601 format for storage
  static final DateFormat _isoFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  /// Formats a date for display.
  ///
  /// Returns "Never" if the date is null.
  static String formatForDisplay(DateTime? date) {
    if (date == null) return 'Never';
    return _displayFormat.format(date);
  }

  /// Formats a date and time for display.
  static String formatDateTime(DateTime? date) {
    if (date == null) return 'Never';
    return _dateTimeFormat.format(date);
  }

  /// Formats a date in short format.
  static String formatShort(DateTime? date) {
    if (date == null) return '-';
    return _shortFormat.format(date);
  }

  /// Formats just the time portion.
  static String formatTime(DateTime? date) {
    if (date == null) return '-';
    return _timeFormat.format(date);
  }

  /// Formats a date in ISO 8601 format for storage.
  static String toIsoString(DateTime date) {
    return _isoFormat.format(date);
  }

  /// Parses an ISO 8601 date string.
  ///
  /// Returns null if parsing fails.
  static DateTime? parseIsoString(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  /// Returns a human-readable relative time string.
  ///
  /// Examples: "Just now", "5 minutes ago", "2 hours ago", "Yesterday"
  static String getRelativeTime(DateTime? date) {
    if (date == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 2) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Checks if a date is today.
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Checks if a date is yesterday.
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Returns the start of the day for a given date.
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Returns the end of the day for a given date.
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }
}
