import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dutch_learn_app/core/constants/app_constants.dart';
import 'package:dutch_learn_app/presentation/providers/project_provider.dart';
import 'package:dutch_learn_app/presentation/widgets/project_card.dart';

/// Home screen showing list of projects.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectListState = ref.watch(projectListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dutch Learn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(context, ref, projectListState, theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sync'),
        icon: const Icon(Icons.cloud_download),
        label: const Text('Import'),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ProjectListState state,
    ThemeData theme,
  ) {
    if (state.isLoading && state.projects.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading projects',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(projectListProvider.notifier).loadProjects(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: AppConstants.emptyStateIconSize,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'No projects yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import a project from Google Drive\nto get started',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/sync'),
              icon: const Icon(Icons.cloud_download),
              label: const Text('Import from Google Drive'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(projectListProvider.notifier).loadProjects(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: state.projects.length,
        itemBuilder: (context, index) {
          final project = state.projects[index];
          return ProjectCard(
            project: project,
            onTap: () {
              ref.read(currentProjectIdProvider.notifier).state = project.id;
              context.push('/learning/${project.id}');
            },
            onDelete: () async {
              final success = await ref
                  .read(projectListProvider.notifier)
                  .deleteProject(project.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${project.name}"'),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
