import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/domain/entities/speaker.dart';
import 'package:dutch_learn_app/injection_container.dart';
import 'package:dutch_learn_app/presentation/providers/audio_provider.dart';
import 'package:dutch_learn_app/presentation/providers/learning_provider.dart';
import 'package:dutch_learn_app/presentation/providers/project_provider.dart';
import 'package:dutch_learn_app/presentation/screens/review_screen.dart';
import 'package:dutch_learn_app/presentation/widgets/audio_player_widget.dart';
import 'package:dutch_learn_app/presentation/widgets/keyword_popup.dart';
import 'package:dutch_learn_app/presentation/widgets/sentence_card.dart';
import 'package:dutch_learn_app/presentation/widgets/sentence_detail_card.dart';

/// Main learning screen with audio playback and sentence navigation.
class LearningScreen extends ConsumerStatefulWidget {
  final String projectId;

  const LearningScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen> {
  bool _audioLoaded = false;

  Speaker? _findSpeaker(List<Speaker> speakers, String? speakerId) {
    if (speakerId == null || speakers.isEmpty) return null;
    try {
      return speakers.firstWhere((s) => s.id == speakerId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleBookmark(Sentence sentence) async {
    final sentenceDao = ref.read(sentenceDaoProvider);
    await sentenceDao.toggleDifficult(sentence.id);
    ref.invalidate(projectDetailProvider(widget.projectId));
  }

  @override
  void initState() {
    super.initState();
    // Set current project ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentProjectIdProvider.notifier).state = widget.projectId;
    });
  }

  void _loadAudioIfNeeded(ProjectDetailState projectState) {
    if (!_audioLoaded &&
        !projectState.isLoading &&
        projectState.project?.audioPath != null) {
      _audioLoaded = true;
      // Schedule after build to avoid modifying provider during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioProvider.notifier).loadFile(
              projectState.project!.audioPath!,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectDetailProvider(widget.projectId));
    final learningState = ref.watch(learningProvider);
    final learningNotifier = ref.read(learningProvider.notifier);
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final theme = Theme.of(context);

    // Load audio when project is ready
    _loadAudioIfNeeded(projectState);

    // Handle loading state
    if (projectState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Handle error state
    if (projectState.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(projectState.error!),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.refresh(projectDetailProvider(widget.projectId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final project = projectState.project;
    final sentences = projectState.sentences;
    final speakers = projectState.speakers;

    if (project == null || sentences.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Data')),
        body: const Center(child: Text('No sentences found')),
      );
    }

    // Get current sentence
    final selectedIndex = learningState.selectedSentenceIndex.clamp(
      0,
      sentences.length - 1,
    );
    final selectedSentence = sentences[selectedIndex];

    // Find currently playing sentence
    Sentence? playingSentence;
    if (audioState.isPlaying) {
      for (final s in sentences) {
        if (s.containsPosition(audioState.positionSeconds)) {
          playingSentence = s;
          break;
        }
      }
    }

    // Auto-select playing sentence
    if (playingSentence != null &&
        learningState.autoAdvance &&
        playingSentence.index != selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        learningNotifier.selectSentence(playingSentence!.index);
      });
    }

    // Use LayoutBuilder for responsive layout
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(projectId: widget.projectId),
                ),
              );
            },
            tooltip: 'Review difficult sentences',
          ),
          IconButton(
            icon: Icon(
              learningState.autoAdvance
                  ? Icons.sync
                  : Icons.sync_disabled,
            ),
            onPressed: () => learningNotifier.toggleAutoAdvance(),
            tooltip: learningState.autoAdvance
                ? 'Auto-follow: ON'
                : 'Auto-follow: OFF',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Wide layout (tablet/desktop)
          if (constraints.maxWidth > 800) {
            return _buildWideLayout(
              context,
              ref,
              sentences,
              speakers,
              selectedSentence,
              selectedIndex,
              playingSentence,
              learningState,
              learningNotifier,
              audioNotifier,
              theme,
            );
          }
          // Narrow layout (phone)
          return _buildNarrowLayout(
            context,
            ref,
            sentences,
            speakers,
            selectedSentence,
            selectedIndex,
            playingSentence,
            learningState,
            learningNotifier,
            audioNotifier,
            theme,
          );
        },
      ),
      bottomNavigationBar: AudioPlayerWidget(
        onPrevious: selectedIndex > 0
            ? () {
                learningNotifier.previousSentence();
                final prevSentence = sentences[selectedIndex - 1];
                audioNotifier.playSentence(prevSentence);
              }
            : null,
        onNext: selectedIndex < sentences.length - 1
            ? () {
                learningNotifier.nextSentence(sentences.length - 1);
                final nextSentence = sentences[selectedIndex + 1];
                audioNotifier.playSentence(nextSentence);
              }
            : null,
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    WidgetRef ref,
    List<Sentence> sentences,
    List<Speaker> speakers,
    Sentence selectedSentence,
    int selectedIndex,
    Sentence? playingSentence,
    LearningState learningState,
    LearningNotifier learningNotifier,
    AudioNotifier audioNotifier,
    ThemeData theme,
  ) {
    return Row(
      children: [
        // Sentence list sidebar
        SizedBox(
          width: 320,
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (selectedIndex + 1) / sentences.length,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${selectedIndex + 1}/${sentences.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Sentence list
              Expanded(
                child: ListView.builder(
                  itemCount: sentences.length,
                  itemBuilder: (context, index) {
                    final sentence = sentences[index];
                    return SentenceListItem(
                      sentence: sentence,
                      isSelected: index == selectedIndex,
                      isPlaying: sentence == playingSentence,
                      speaker: _findSpeaker(speakers, sentence.speakerId),
                      onBookmarkTap: () => _toggleBookmark(sentence),
                      onTap: () {
                        learningNotifier.selectSentence(index);
                        audioNotifier.playSentence(sentence);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Sentence detail
        Expanded(
          child: SentenceDetailCard(
            sentence: selectedSentence,
            showTranslation: learningState.showTranslation,
            showExplanationNl: learningState.showExplanationNl,
            showExplanationEn: learningState.showExplanationEn,
            showKeywords: learningState.showKeywords,
            onKeywordTap: (keyword) {
              KeywordPopup.show(context, keyword);
            },
            onToggleTranslation: () => learningNotifier.toggleTranslation(),
            onToggleExplanationNl: () => learningNotifier.toggleExplanationNl(),
            onToggleExplanationEn: () => learningNotifier.toggleExplanationEn(),
            onToggleKeywords: () => learningNotifier.toggleKeywords(),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    WidgetRef ref,
    List<Sentence> sentences,
    List<Speaker> speakers,
    Sentence selectedSentence,
    int selectedIndex,
    Sentence? playingSentence,
    LearningState learningState,
    LearningNotifier learningNotifier,
    AudioNotifier audioNotifier,
    ThemeData theme,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (selectedIndex + 1) / sentences.length,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${selectedIndex + 1}/${sentences.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Tab bar
          TabBar(
            tabs: const [
              Tab(text: 'Sentence'),
              Tab(text: 'List'),
            ],
            labelColor: theme.colorScheme.primary,
          ),
          // Tab views
          Expanded(
            child: TabBarView(
              children: [
                // Sentence detail tab
                SentenceDetailCard(
                  sentence: selectedSentence,
                  showTranslation: learningState.showTranslation,
                  showExplanationNl: learningState.showExplanationNl,
                  showExplanationEn: learningState.showExplanationEn,
                  showKeywords: learningState.showKeywords,
                  onKeywordTap: (keyword) {
                    KeywordPopup.show(context, keyword);
                  },
                  onToggleTranslation: () => learningNotifier.toggleTranslation(),
                  onToggleExplanationNl: () => learningNotifier.toggleExplanationNl(),
                  onToggleExplanationEn: () => learningNotifier.toggleExplanationEn(),
                  onToggleKeywords: () => learningNotifier.toggleKeywords(),
                ),
                // Sentence list tab
                ListView.builder(
                  itemCount: sentences.length,
                  itemBuilder: (context, index) {
                    final sentence = sentences[index];
                    return SentenceCard(
                      sentence: sentence,
                      isSelected: index == selectedIndex,
                      isPlaying: sentence == playingSentence,
                      speaker: _findSpeaker(speakers, sentence.speakerId),
                      onBookmarkTap: () => _toggleBookmark(sentence),
                      onTap: () {
                        learningNotifier.selectSentence(index);
                        audioNotifier.playSentence(sentence);
                        DefaultTabController.of(context).animateTo(0);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
