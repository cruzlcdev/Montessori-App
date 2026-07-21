import '../models/academic_period_model.dart';
import '../models/subject_model.dart';

abstract class AcademicRepository {
  Stream<List<SubjectModel>> watchSubjectsByGroup({
    required String schoolId,
    required String groupId,
  });

  Future<List<SubjectModel>> getSubjectsByGroup({
    required String schoolId,
    required String groupId,
  });

  Stream<List<AcademicPeriodModel>> watchActivePeriods({
    required String schoolId,
  });

  Future<List<AcademicPeriodModel>> getActivePeriods({
    required String schoolId,
  });
}
