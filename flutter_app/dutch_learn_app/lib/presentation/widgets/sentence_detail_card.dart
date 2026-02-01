import 'package:flutter/material.dart';

import 'package:dutch_learn_app/domain/entities/keyword.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/presentation/widgets/keyword_popup.dart';

/// Card showing detailed view of a sentence.
class SentenceDetailCard extends StatelessWidget {
  final Sentence sentence;
  final bool showTranslation;
  final bool showExplanationNl;
  final bool showExplanationEn;
  final bool showKeywords;
  final void Function(Keyword keyword)? onKeywordTap;
  final VoidCallback? onToggleTranslation;
  final VoidCallback? onToggleExplanationNl;
  final VoidCallback? onToggleExplanationEn;
  final VoidCallback? onToggleKeywords;

  const SentenceDetailCard({
    super.key,
    required this.sentence,
    this.showTranslation = true,
    this.showExplanationNl = true,
    this.showExplanationEn = true,
    this.showKeywords = true,
    this.onKeywordTap,
    this.onToggleTranslation,
    this.onToggleExplanationNl,
    this.onToggleExplanationEn,
    this.onToggleKeywords,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sentence number badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Sentence ${sentence.displayNumber}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dutch text with tappable keywords
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🇳🇱', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        'Dutch',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InteractiveText(
                    text: sentence.text,
                    keywords: sentence.keywords,
                    onKeywordTap: onKeywordTap,
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),

          // English translation
          if (sentence.hasTranslation) ...[
            const SizedBox(height: 12),
            _ExpandableSection(
              title: 'Translation',
              flag: '🇬🇧',
              isExpanded: showTranslation,
              onToggle: onToggleTranslation,
              child: Text(
                sentence.translationEn!,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],

          // Dutch explanation
          if (sentence.explanationNl != null &&
              sentence.explanationNl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ExpandableSection(
              title: 'Explanation (NL)',
              flag: '🇳🇱',
              isExpanded: showExplanationNl,
              onToggle: onToggleExplanationNl,
              child: Text(
                sentence.explanationNl!,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],

          // English explanation
          if (sentence.explanationEn != null &&
              sentence.explanationEn!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ExpandableSection(
              title: 'Explanation (EN)',
              flag: '🇬🇧',
              isExpanded: showExplanationEn,
              onToggle: onToggleExplanationEn,
              child: Text(
                sentence.explanationEn!,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],

          // Keywords/Vocabulary
          if (sentence.hasKeywords) ...[
            const SizedBox(height: 12),
            _ExpandableSection(
              title: 'Vocabulary (${sentence.keywords.length})',
              icon: Icons.key,
              isExpanded: showKeywords,
              onToggle: onToggleKeywords,
              child: Column(
                children: sentence.keywords.map((keyword) {
                  return _KeywordListItem(
                    keyword: keyword,
                    onTap: () => onKeywordTap?.call(keyword),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  final String title;
  final String? flag;
  final IconData? icon;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    this.flag,
    this.icon,
    required this.isExpanded,
    this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (flag != null) ...[
                    Text(flag!, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                  ],
                  if (icon != null) ...[
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

class _KeywordListItem extends StatelessWidget {
  final Keyword keyword;
  final VoidCallback onTap;

  const _KeywordListItem({
    required this.keyword,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                keyword.word,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keyword.meaningEn,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    keyword.meaningNl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
