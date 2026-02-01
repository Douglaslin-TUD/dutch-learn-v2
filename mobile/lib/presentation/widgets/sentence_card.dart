import 'package:flutter/material.dart';

import 'package:dutch_learn_app/core/extensions/duration_extension.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';

/// Card widget for displaying a sentence in the list.
class SentenceCard extends StatelessWidget {
  final Sentence sentence;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  const SentenceCard({
    super.key,
    required this.sentence,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : isPlaying
              ? theme.colorScheme.secondaryContainer
              : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Sentence number
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${sentence.displayNumber}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sentence text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentence.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          sentence.startTimeAsDuration.formatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Text(
                          ' - ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Text(
                          sentence.endTimeAsDuration.formatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        if (sentence.hasKeywords) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.key,
                            size: 14,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${sentence.keywords.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Playing indicator
              if (isPlaying)
                const Icon(
                  Icons.play_arrow,
                  color: Colors.green,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact sentence list item for sidebar.
class SentenceListItem extends StatelessWidget {
  final Sentence sentence;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  const SentenceListItem({
    super.key,
    required this.sentence,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : isPlaying
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          '${sentence.displayNumber}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: (isSelected || isPlaying)
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        sentence.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(
        '${sentence.startTimeAsDuration.formatted} - ${sentence.endTimeAsDuration.formatted}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: isPlaying
          ? const Icon(Icons.volume_up, color: Colors.green, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
