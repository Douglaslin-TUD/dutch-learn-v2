import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';
import 'package:dutch_learn_app/injection_container.dart';

/// State for project list.
class ProjectListState {
  final List<Project> projects;
  final bool isLoading;
  final String? error;

  const ProjectListState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectListState copyWith({
    List<Project>? projects,
    bool? isLoading,
    String? error,
  }) {
    return ProjectListState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing project list state.
class ProjectListNotifier extends StateNotifier<ProjectListState> {
  final ProjectRepository _repository;

  ProjectListNotifier(this._repository) : super(const ProjectListState()) {
    loadProjects();
  }

  /// Loads all projects from the repository.
  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getProjects();

    result.fold(
      onSuccess: (projects) {
        state = state.copyWith(projects: projects, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(error: failure.message, isLoading: false);
      },
    );
  }

  /// Deletes a project.
  Future<bool> deleteProject(String projectId) async {
    final result = await _repository.deleteProject(projectId);

    return result.fold(
      onSuccess: (_) {
        state = state.copyWith(
          projects: state.projects.where((p) => p.id != projectId).toList(),
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
    );
  }

  /// Imports a project from JSON data.
  Future<Project?> importProject(
    Map<String, dynamic> jsonData,
    String? audioPath,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.importProject(jsonData, audioPath);

    return result.fold(
      onSuccess: (project) {
        state = state.copyWith(
          projects: [project, ...state.projects],
          isLoading: false,
        );
        return project;
      },
      onFailure: (failure) {
        state = state.copyWith(error: failure.message, isLoading: false);
        return null;
      },
    );
  }

  /// Clears any error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for project list.
final projectListProvider =
    StateNotifierProvider<ProjectListNotifier, ProjectListState>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  return ProjectListNotifier(repository);
});

/// State for a single project with sentences.
class ProjectDetailState {
  final Project? project;
  final List<Sentence> sentences;
  final bool isLoading;
  final String? error;

  const ProjectDetailState({
    this.project,
    this.sentences = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectDetailState copyWith({
    Project? project,
    List<Sentence>? sentences,
    bool? isLoading,
    String? error,
  }) {
    return ProjectDetailState(
      project: project ?? this.project,
      sentences: sentences ?? this.sentences,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing project detail state.
class ProjectDetailNotifier extends StateNotifier<ProjectDetailState> {
  final ProjectRepository _repository;
  final String _projectId;

  ProjectDetailNotifier(this._repository, this._projectId)
      : super(const ProjectDetailState()) {
    loadProject();
  }

  /// Loads the project and its sentences.
  Future<void> loadProject() async {
    state = state.copyWith(isLoading: true, error: null);

    // Load project
    final projectResult = await _repository.getProjectById(_projectId);

    await projectResult.fold(
      onSuccess: (project) async {
        state = state.copyWith(project: project);

        // Load sentences
        final sentencesResult = await _repository.getSentences(_projectId);

        sentencesResult.fold(
          onSuccess: (sentences) {
            state = state.copyWith(sentences: sentences, isLoading: false);
          },
          onFailure: (failure) {
            state = state.copyWith(error: failure.message, isLoading: false);
          },
        );
      },
      onFailure: (failure) {
        state = state.copyWith(error: failure.message, isLoading: false);
      },
    );
  }

  /// Updates the last played information.
  Future<void> updateLastPlayed(int sentenceIndex) async {
    await _repository.updateLastPlayed(
      _projectId,
      DateTime.now(),
      sentenceIndex,
    );
  }
}

/// Provider family for project details.
final projectDetailProvider = StateNotifierProvider.family<
    ProjectDetailNotifier, ProjectDetailState, String>((ref, projectId) {
  final repository = ref.watch(projectRepositoryProvider);
  return ProjectDetailNotifier(repository, projectId);
});

/// Provider for current project ID.
final currentProjectIdProvider = StateProvider<String?>((ref) => null);

/// Provider for current project (convenience wrapper).
final currentProjectProvider = Provider<ProjectDetailState?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;
  return ref.watch(projectDetailProvider(projectId));
});
