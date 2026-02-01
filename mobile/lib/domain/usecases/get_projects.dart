import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';

/// Use case for getting all projects.
///
/// Returns a list of all projects ordered by last played date.
class GetProjectsUseCase {
  final ProjectRepository _repository;

  GetProjectsUseCase(this._repository);

  /// Executes the use case.
  Future<Result<List<Project>>> call() {
    return _repository.getProjects();
  }
}
