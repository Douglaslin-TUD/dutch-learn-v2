import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dutch_learn_app/domain/entities/drive_file.dart';
import 'package:dutch_learn_app/presentation/providers/sync_provider.dart';

/// Screen for syncing with Google Drive.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  DriveFile? _selectedJsonFile;
  DriveFile? _selectedAudioFile;

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final syncNotifier = ref.read(syncProvider.notifier);
    final theme = Theme.of(context);

    // Show success message
    if (syncState.successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncState.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        syncNotifier.clearSuccess();
      });
    }

    // Show error message
    if (syncState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncState.error!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        syncNotifier.clearError();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync & Import'),
        actions: [
          if (syncState.isSignedIn) ...[
            // Sync button
            IconButton(
              icon: syncState.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: syncState.isSyncing
                  ? null
                  : () => syncNotifier.performSync(),
              tooltip: 'Sync with Drive',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => syncNotifier.signOut(),
              tooltip: 'Sign Out',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Sync progress indicator
          if (syncState.isSyncing)
            _buildSyncProgress(syncState, theme),

          // Main content
          Expanded(
            child: syncState.isSignedIn
                ? _buildFileBrowser(context, ref, syncState, theme)
                : _buildSignIn(context, ref, syncState, theme),
          ),
        ],
      ),
      bottomNavigationBar: syncState.isSignedIn && _selectedJsonFile != null
          ? _buildImportBar(context, ref, syncState, theme)
          : null,
    );
  }

  Widget _buildSyncProgress(SyncState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.syncStatus ?? 'Syncing...',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${(state.syncProgress * 100).toInt()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: state.syncProgress),
        ],
      ),
    );
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  Widget _buildSignIn(
    BuildContext context,
    WidgetRef ref,
    SyncState state,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Import Project',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import projects from Google Drive\nor local files',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (state.isLoading)
              const CircularProgressIndicator()
            else ...[
              // Google Sign-In button
              ElevatedButton.icon(
                onPressed: () {
                  if (_isDesktop) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Google Sign-In is not available on Linux desktop. Please use "Import from Local Folder".'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  } else {
                    ref.read(syncProvider.notifier).signIn();
                  }
                },
                icon: const Icon(Icons.cloud_download),
                label: const Text('Sign in with Google Drive'),
              ),
              const SizedBox(height: 16),
              // Local import button
              OutlinedButton.icon(
                onPressed: () => _importLocalProject(context, ref),
                icon: const Icon(Icons.folder_open),
                label: const Text('Import from Local Folder'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _importLocalProject(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);

    // Pick a directory containing project.json and audio.mp3
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select project.json file',
    );

    if (result == null || result.files.isEmpty) return;

    final jsonPath = result.files.first.path;
    if (jsonPath == null) return;

    final jsonFile = File(jsonPath);
    final parentDir = jsonFile.parent;

    // Look for audio file in the same directory
    File? audioFile;
    final mp3File = File('${parentDir.path}/audio.mp3');
    if (await mp3File.exists()) {
      audioFile = mp3File;
    }

    if (!context.mounted) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('JSON: ${jsonFile.path}'),
            const SizedBox(height: 8),
            Text(audioFile != null
                ? 'Audio: ${audioFile.path}'
                : 'No audio.mp3 found in folder'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Import the project
    try {
      final success = await ref.read(syncProvider.notifier).importLocalProject(
        jsonFile,
        audioFile: audioFile,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildFileBrowser(
    BuildContext context,
    WidgetRef ref,
    SyncState state,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // User info and breadcrumb
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.userEmail != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.account_circle,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.userEmail!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Breadcrumb
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => ref.read(syncProvider.notifier).goToFolder(-1),
                      child: Row(
                        children: [
                          Icon(
                            Icons.home,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'My Drive',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < state.folderStack.length; i++) ...[
                      const Icon(Icons.chevron_right, size: 16),
                      InkWell(
                        onTap: () => ref.read(syncProvider.notifier).goToFolder(i),
                        child: Text(
                          state.folderStack[i].name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Loading indicator
        if (state.isLoading)
          const LinearProgressIndicator()
        else
          const SizedBox(height: 4),

        // Download progress
        if (state.isDownloading)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(value: state.downloadProgress),
                const SizedBox(height: 8),
                Text(
                  'Downloading... ${(state.downloadProgress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

        // File list
        Expanded(
          child: state.files.isEmpty && !state.isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This folder is empty',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(syncProvider.notifier).loadFiles(),
                  child: ListView.builder(
                    itemCount: state.files.length,
                    itemBuilder: (context, index) {
                      final file = state.files[index];
                      return _buildFileItem(context, ref, file, theme);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFileItem(
    BuildContext context,
    WidgetRef ref,
    DriveFile file,
    ThemeData theme,
  ) {
    final isSelected = file == _selectedJsonFile || file == _selectedAudioFile;

    IconData icon;
    Color iconColor;

    if (file.isFolder) {
      icon = Icons.folder;
      iconColor = Colors.amber;
    } else if (file.isJson) {
      icon = Icons.description;
      iconColor = Colors.blue;
    } else if (file.isAudio) {
      icon = Icons.audiotrack;
      iconColor = Colors.purple;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = theme.colorScheme.outline;
    }

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: file.isFolder
          ? null
          : Text(
              file.formattedSize,
              style: theme.textTheme.bodySmall,
            ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
            )
          : null,
      selected: isSelected,
      onTap: () {
        if (file.isFolder) {
          ref.read(syncProvider.notifier).openFolder(file);
        } else if (file.isJson) {
          setState(() {
            _selectedJsonFile = file == _selectedJsonFile ? null : file;
          });
        } else if (file.isAudio) {
          setState(() {
            _selectedAudioFile = file == _selectedAudioFile ? null : file;
          });
        }
      },
    );
  }

  Widget _buildImportBar(
    BuildContext context,
    WidgetRef ref,
    SyncState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected files:',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (_selectedJsonFile != null)
              Chip(
                avatar: const Icon(Icons.description, size: 16),
                label: Text(_selectedJsonFile!.name),
                onDeleted: () => setState(() => _selectedJsonFile = null),
              ),
            if (_selectedAudioFile != null)
              Chip(
                avatar: const Icon(Icons.audiotrack, size: 16),
                label: Text(_selectedAudioFile!.name),
                onDeleted: () => setState(() => _selectedAudioFile = null),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isDownloading
                    ? null
                    : () async {
                        final success = await ref
                            .read(syncProvider.notifier)
                            .importProject(
                              _selectedJsonFile!,
                              audioFile: _selectedAudioFile,
                            );
                        if (success && context.mounted) {
                          setState(() {
                            _selectedJsonFile = null;
                            _selectedAudioFile = null;
                          });
                          context.pop();
                        }
                      },
                icon: state.isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(state.isDownloading ? 'Importing...' : 'Import Project'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
