import 'package:flutter/material.dart';

import 'package:dutch_learn_app/core/constants/app_constants.dart';
import 'package:dutch_learn_app/domain/entities/keyword.dart';

/// Popup dialog for showing keyword details.
class KeywordPopup extends StatelessWidget {
  final Keyword keyword;
  final VoidCallback onClose;

  const KeywordPopup({
    super.key,
    required this.keyword,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: AppConstants.dialogMaxWidth),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.key,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keyword.word,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            // Dutch meaning
            _MeaningSection(
              flag: '🇳🇱',
              label: 'Nederlands',
              meaning: keyword.meaningNl,
            ),
            const SizedBox(height: 16),
            // English meaning
            _MeaningSection(
              flag: '🇬🇧',
              label: 'English',
              meaning: keyword.meaningEn,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onClose,
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the keyword popup as a dialog.
  static Future<void> show(BuildContext context, Keyword keyword) {
    return showDialog(
      context: context,
      builder: (context) => KeywordPopup(
        keyword: keyword,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _MeaningSection extends StatelessWidget {
  final String flag;
  final String label;
  final String meaning;

  const _MeaningSection({
    required this.flag,
    required this.label,
    required this.meaning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          meaning,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}

/// Widget for displaying a tappable word that may be a keyword.
class TappableWord extends StatelessWidget {
  final String word;
  final bool isKeyword;
  final VoidCallback? onTap;

  const TappableWord({
    super.key,
    required this.word,
    this.isKeyword = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isKeyword) {
      return Text(
        word,
        style: theme.textTheme.bodyLarge,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        child: Text(
          word,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Widget that displays sentence text with tappable keywords.
class InteractiveText extends StatelessWidget {
  final String text;
  final List<Keyword> keywords;
  final void Function(Keyword keyword)? onKeywordTap;
  final TextStyle? style;

  const InteractiveText({
    super.key,
    required this.text,
    required this.keywords,
    this.onKeywordTap,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.bodyLarge;

    // Split text into words while preserving punctuation
    final pattern = RegExp(r'(\S+)');
    final matches = pattern.allMatches(text);

    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in matches) {
      // Add any text before this match (spaces)
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final word = match.group(0)!;
      final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();

      // Check if this word is a keyword
      final keyword = keywords.where(
        (k) => k.word.toLowerCase() == cleanWord,
      ).firstOrNull;

      if (keyword != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => onKeywordTap?.call(keyword),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  word,
                  style: effectiveStyle?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: word));
      }

      lastEnd = match.end;
    }

    // Add any remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        style: effectiveStyle,
        children: spans,
      ),
    );
  }
}
