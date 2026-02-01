import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';

/// Use case for deleting a project.
///
/// Removes the project and all associated data including
/// sentences, keywords, and audio files.
class DeleteProjectUseCase {
  final ProjectRepository _repository;

  DeleteProjectUseCase(this._repository);

  /// Executes the use case.
  ///
  /// [projectId] is the ID of the project to delete.
  Future<Result<void>> call(String projectId) {
    return _repository.deleteProject(projectId);
  }
}
