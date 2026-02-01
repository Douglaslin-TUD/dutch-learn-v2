import 'package:dutch_learn_app/core/utils/result.dart';
import 'package:dutch_learn_app/domain/entities/project.dart';
import 'package:dutch_learn_app/domain/repositories/project_repository.dart';

/// Use case for importing a project from JSON data.
///
/// Parses the JSON data and creates a new project with
/// all sentences and keywords.
class ImportProjectUseCase {
  final ProjectRepository _repository;

  ImportProjectUseCase(this._repository);

  /// Executes the use case.
  ///
  /// [jsonData] is the parsed JSON content.
  /// [audioPath] is the optional local path to the audio file.
  Future<Result<Project>> call({
    required Map<String, dynamic> jsonData,
    String? audioPath,
  }) {
    return _repository.importProject(jsonData, audioPath);
  }
}
