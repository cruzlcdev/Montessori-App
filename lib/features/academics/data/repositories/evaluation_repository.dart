import '../models/evaluation_model.dart';

abstract class EvaluationRepository {
  Stream<EvaluationModel?> watchEvaluation({
    required String schoolId,
    required String evaluationId,
  });

  Future<EvaluationModel?> getEvaluation({
    required String schoolId,
    required String evaluationId,
  });

  Stream<List<EvaluationModel>> watchEvaluationsByGroupTerm({
    required String schoolId,
    required String groupId,
    required int termNumber,
  });

  Stream<List<EvaluationModel>> watchEvaluationsByIds({
    required String schoolId,
    required List<String> evaluationIds,
  });

  Future<void> saveEvaluation(EvaluationModel evaluation);
}
