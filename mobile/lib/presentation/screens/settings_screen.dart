import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/core/constants/app_constants.dart';
import 'package:dutch_learn_app/presentation/providers/settings_provider.dart';

/// Settings screen for app configuration.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Playback Section
          _SectionHeader(title: 'Playback', icon: Icons.play_circle_outline),

          // Playback Speed
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Default Playback Speed'),
            subtitle: Text('${settings.playbackSpeed}x'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: settings.playbackSpeed,
                min: AppConstants.minPlaybackSpeed,
                max: AppConstants.maxPlaybackSpeed,
                divisions: ((AppConstants.maxPlaybackSpeed -
                            AppConstants.minPlaybackSpeed) /
                        AppConstants.playbackSpeedStep)
                    .round(),
                label: '${settings.playbackSpeed}x',
                onChanged: (value) => settingsNotifier.setPlaybackSpeed(value),
              ),
            ),
          ),

          // Loop Settings
          SwitchListTile(
            secondary: const Icon(Icons.repeat),
            title: const Text('Loop Sentences'),
            subtitle: const Text('Repeat sentence playback'),
            value: settings.loopEnabled,
            onChanged: (value) => settingsNotifier.setLoopEnabled(value),
          ),

          if (settings.loopEnabled)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Loop Count'),
              subtitle: Text('${settings.loopCount} times'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: settings.loopCount > 1
                        ? () => settingsNotifier.setLoopCount(
                              settings.loopCount - 1,
                            )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${settings.loopCount}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: settings.loopCount < AppConstants.maxLoopCount
                        ? () => settingsNotifier.setLoopCount(
                              settings.loopCount + 1,
                            )
                        : null,
                  ),
                ],
              ),
            ),

          // Auto-advance
          SwitchListTile(
            secondary: const Icon(Icons.skip_next),
            title: const Text('Auto-advance'),
            subtitle: const Text('Automatically move to next sentence'),
            value: settings.autoAdvance,
            onChanged: (value) => settingsNotifier.setAutoAdvance(value),
          ),

          const Divider(),

          // Display Section
          _SectionHeader(title: 'Display', icon: Icons.visibility),

          // Show Translation
          SwitchListTile(
            secondary: const Icon(Icons.translate),
            title: const Text('Show Translation'),
            subtitle: const Text('Display English translation'),
            value: settings.showTranslation,
            onChanged: (value) => settingsNotifier.setShowTranslation(value),
          ),

          // Show Explanation
          SwitchListTile(
            secondary: const Icon(Icons.info_outline),
            title: const Text('Show Explanation'),
            subtitle: const Text('Display sentence explanations'),
            value: settings.showExplanation,
            onChanged: (value) => settingsNotifier.setShowExplanation(value),
          ),

          // Font Size
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Font Size'),
            subtitle: Text('${settings.fontSize.round()}'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: settings.fontSize,
                min: 12,
                max: 24,
                divisions: 6,
                label: '${settings.fontSize.round()}',
                onChanged: (value) => settingsNotifier.setFontSize(value),
              ),
            ),
          ),

          const Divider(),

          // Appearance Section
          _SectionHeader(title: 'Appearance', icon: Icons.palette),

          // Theme Mode
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_suggest),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) {
                settingsNotifier.setThemeMode(selection.first);
              },
            ),
          ),

          const Divider(),

          // About Section
          _SectionHeader(title: 'About', icon: Icons.info),

          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('Version'),
            subtitle: Text(AppConstants.appVersion),
          ),

          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Reset Settings'),
            subtitle: const Text('Restore default settings'),
            onTap: () => _showResetConfirmation(context, settingsNotifier),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showResetConfirmation(
    BuildContext context,
    SettingsNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.resetToDefaults();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings have been reset'),
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
