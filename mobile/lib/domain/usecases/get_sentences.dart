import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/entities/sentence.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';

/// Use case for getting all sentences in a project.
class GetSentencesUseCase {
  final ProjectRepository _repository;

  GetSentencesUseCase(this._repository);

  /// Executes the use case.
  ///
  /// [projectId] is the ID of the project.
  Future<Result<List<Sentence>>> call(String projectId) {
    return _repository.getSentences(projectId);
  }
}
