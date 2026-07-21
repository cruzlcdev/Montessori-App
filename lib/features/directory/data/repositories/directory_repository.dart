import '../models/school_group_model.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';

abstract class DirectoryRepository {
  Stream<List<SchoolGroupModel>> watchGroups({required String schoolId});

  Future<List<SchoolGroupModel>> getGroups({required String schoolId});

  Stream<List<SchoolGroupModel>> watchGroupsByIds({
    required String schoolId,
    required List<String> groupIds,
  });

  Future<List<SchoolGroupModel>> getGroupsByIds({
    required String schoolId,
    required List<String> groupIds,
  });

  Stream<List<StudentModel>> watchStudentsByGroup({
    required String schoolId,
    required String groupId,
  });

  Future<List<StudentModel>> getStudentsByGroup({
    required String schoolId,
    required String groupId,
  });

  Stream<List<StudentModel>> watchStudentsByIds({
    required String schoolId,
    required List<String> studentIds,
  });

  Future<List<StudentModel>> getStudentsByIds({
    required String schoolId,
    required List<String> studentIds,
  });

  Stream<List<TeacherModel>> watchTeachersByGroup({
    required String schoolId,
    required String groupId,
  });

  Future<List<TeacherModel>> getTeachersByGroup({
    required String schoolId,
    required String groupId,
  });
}
