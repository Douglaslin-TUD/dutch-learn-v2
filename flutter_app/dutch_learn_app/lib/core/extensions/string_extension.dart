/// Extensions on [String] for convenient text operations.
extension StringExtension on String {
  /// Capitalizes the first letter of the string.
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalizes the first letter of each word.
  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Truncates the string to a maximum length with ellipsis.
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Removes all whitespace from the string.
  String get removeWhitespace {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Normalizes whitespace (multiple spaces become single space).
  String get normalizeWhitespace {
    return replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Checks if the string contains only digits.
  bool get isNumeric {
    if (isEmpty) return false;
    return RegExp(r'^[0-9]+$').hasMatch(this);
  }

  /// Checks if the string is a valid email.
  bool get isEmail {
    if (isEmpty) return false;
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this);
  }

  /// Checks if the string is blank (empty or only whitespace).
  bool get isBlank {
    return trim().isEmpty;
  }

  /// Checks if the string is not blank.
  bool get isNotBlank {
    return !isBlank;
  }

  /// Returns null if blank, otherwise returns the string.
  String? get nullIfBlank {
    return isBlank ? null : this;
  }

  /// Converts a snake_case string to camelCase.
  String get snakeToCamel {
    final parts = split('_');
    if (parts.isEmpty) return this;
    return parts.first +
        parts.skip(1).map((p) => p.capitalize).join();
  }

  /// Converts a camelCase string to snake_case.
  String get camelToSnake {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }

  /// Extracts words from the string.
  List<String> get words {
    return split(RegExp(r'\s+'))
        .where((word) => word.isNotBlank)
        .toList();
  }

  /// Returns the first n characters.
  String first(int n) {
    if (n >= length) return this;
    return substring(0, n);
  }

  /// Returns the last n characters.
  String last(int n) {
    if (n >= length) return this;
    return substring(length - n);
  }

  /// Checks if the string contains another string (case insensitive).
  bool containsIgnoreCase(String other) {
    return toLowerCase().contains(other.toLowerCase());
  }

  /// Checks if the string equals another string (case insensitive).
  bool equalsIgnoreCase(String other) {
    return toLowerCase() == other.toLowerCase();
  }

  /// Removes diacritics/accents from the string.
  String get removeDiacritics {
    const diacritics =
        'AAAAAAAAAAAAAAAAEEEEEEIIIINNOOOOOOOOOOSUUUUUUYaaaaaaaaaaaaaaaeeeeeeiiiinnoooooooooossuuuuuuy';
    const withoutDiacritics =
        'AAAAAAAAAAAAAAAAEEEEEEIIIINNOOOOOOOOOOSUUUUUUYaaaaaaaaaaaaaaaeeeeeeiiiinnoooooooooossuuuuuuy';

    var result = this;
    for (var i = 0; i < diacritics.length; i++) {
      result = result.replaceAll(diacritics[i], withoutDiacritics[i]);
    }
    return result;
  }
}

/// Extension on nullable String.
extension NullableStringExtension on String? {
  /// Returns true if null or empty.
  bool get isNullOrEmpty {
    return this == null || this!.isEmpty;
  }

  /// Returns true if null or blank.
  bool get isNullOrBlank {
    return this == null || this!.isBlank;
  }

  /// Returns the string or a default if null.
  String orDefault(String defaultValue) {
    return this ?? defaultValue;
  }

  /// Returns the string or empty string if null.
  String get orEmpty {
    return this ?? '';
  }
}
