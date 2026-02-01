import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';

/// Repository interface for project operations.
///
/// Defines the contract for data access operations related to
/// projects, sentences, and keywords.
abstract class ProjectRepository {
  /// Gets all projects ordered by last played date.
  Future<Result<List<Project>>> getProjects();

  /// Gets a project by its ID.
  Future<Result<Project>> getProjectById(String id);

  /// Creates a new project.
  Future<Result<Project>> createProject(Project project);

  /// Updates an existing project.
  Future<Result<Project>> updateProject(Project project);

  /// Deletes a project and all its data.
  Future<Result<void>> deleteProject(String id);

  /// Gets all sentences for a project.
  Future<Result<List<Sentence>>> getSentences(String projectId);

  /// Gets a sentence by its ID.
  Future<Result<Sentence>> getSentenceById(String id);

  /// Gets a sentence by project ID and index.
  Future<Result<Sentence>> getSentenceByIndex(String projectId, int index);

  /// Updates the last played information for a project.
  Future<Result<void>> updateLastPlayed(
    String projectId,
    DateTime lastPlayedAt,
    int lastSentenceIndex,
  );

  /// Imports a project from JSON data.
  ///
  /// The [jsonData] should contain the project and sentences data.
  /// The [audioPath] is the local path to the audio file.
  Future<Result<Project>> importProject(
    Map<String, dynamic> jsonData,
    String? audioPath,
  );

  /// Checks if a project with the given source ID exists.
  Future<Result<bool>> projectExists(String sourceId);

  /// Searches sentences by text.
  Future<Result<List<Sentence>>> searchSentences(
    String projectId,
    String query,
  );

  /// Gets the sentence count for a project.
  Future<Result<int>> getSentenceCount(String projectId);

  /// Finds the sentence at a given audio position.
  Future<Result<Sentence?>> findSentenceAtPosition(
    String projectId,
    double positionSeconds,
  );
}
