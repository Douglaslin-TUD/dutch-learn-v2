import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';

/// Use case for updating the last played information.
///
/// Updates when the project was last played and which
/// sentence was playing.
class UpdateLastPlayedUseCase {
  final ProjectRepository _repository;

  UpdateLastPlayedUseCase(this._repository);

  /// Executes the use case.
  ///
  /// [projectId] is the ID of the project.
  /// [lastSentenceIndex] is the index of the last played sentence.
  Future<Result<void>> call({
    required String projectId,
    required int lastSentenceIndex,
  }) {
    return _repository.updateLastPlayed(
      projectId,
      DateTime.now(),
      lastSentenceIndex,
    );
  }
}
