import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/school_group_model.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';
import 'directory_repository.dart';

class FirestoreDirectoryRepository implements DirectoryRepository {
  FirestoreDirectoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(
    String schoolId,
    String collectionName,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection(collectionName);
  }

  @override
  Stream<List<SchoolGroupModel>> watchGroups({required String schoolId}) {
    return _collection(schoolId, 'groups')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snapshot) =>
              _sortGroups(snapshot.docs.map(SchoolGroupModel.fromFirestore)),
        );
  }

  @override
  Future<List<SchoolGroupModel>> getGroups({required String schoolId}) async {
    final snapshot =
        await _collection(
          schoolId,
          'groups',
        ).where('status', isEqualTo: 'active').get();

    return _sortGroups(snapshot.docs.map(SchoolGroupModel.fromFirestore));
  }

  @override
  Stream<List<SchoolGroupModel>> watchGroupsByIds({
    required String schoolId,
    required List<String> groupIds,
  }) {
    final ids = groupIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Stream.value(const []);

    return Stream.multi((controller) {
      final groups = <String, SchoolGroupModel>{};
      final subscriptions = <StreamSubscription>[];

      void emit() => controller.add(_sortGroups(groups.values));

      for (final groupId in ids) {
        final subscription = _collection(
          schoolId,
          'groups',
        ).doc(groupId).snapshots().listen((snapshot) {
          if (!snapshot.exists) {
            groups.remove(groupId);
          } else {
            final group = SchoolGroupModel.fromFirestore(snapshot);
            if (group.status == 'active') {
              groups[groupId] = group;
            } else {
              groups.remove(groupId);
            }
          }
          emit();
        }, onError: controller.addError);
        subscriptions.add(subscription);
      }

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  @override
  Future<List<SchoolGroupModel>> getGroupsByIds({
    required String schoolId,
    required List<String> groupIds,
  }) async {
    if (groupIds.isEmpty) return const [];

    final groups = <SchoolGroupModel>[];

    for (final groupId in groupIds.toSet()) {
      final snapshot = await _collection(schoolId, 'groups').doc(groupId).get();
      if (snapshot.exists) {
        final group = SchoolGroupModel.fromFirestore(snapshot);
        if (group.status == 'active') groups.add(group);
      }
    }

    return _sortGroups(groups);
  }

  @override
  Stream<List<StudentModel>> watchStudentsByGroup({
    required String schoolId,
    required String groupId,
  }) {
    return _collection(schoolId, 'students')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map(
          (snapshot) => _sortStudents(
            snapshot.docs
                .map(StudentModel.fromFirestore)
                .where((student) => student.status == 'active'),
          ),
        );
  }

  @override
  Future<List<StudentModel>> getStudentsByGroup({
    required String schoolId,
    required String groupId,
  }) async {
    final snapshot =
        await _collection(
          schoolId,
          'students',
        ).where('groupId', isEqualTo: groupId).get();

    return _sortStudents(
      snapshot.docs
          .map(StudentModel.fromFirestore)
          .where((student) => student.status == 'active'),
    );
  }

  @override
  Stream<List<StudentModel>> watchStudentsByIds({
    required String schoolId,
    required List<String> studentIds,
  }) {
    final ids = studentIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Stream.value(const []);

    return Stream.multi((controller) {
      final students = <String, StudentModel>{};
      final subscriptions = <StreamSubscription>[];

      void emit() => controller.add(_sortStudents(students.values));

      for (final studentId in ids) {
        final subscription = _collection(
          schoolId,
          'students',
        ).doc(studentId).snapshots().listen((snapshot) {
          if (!snapshot.exists) {
            students.remove(studentId);
          } else {
            final student = StudentModel.fromFirestore(snapshot);
            if (student.status == 'active') {
              students[studentId] = student;
            } else {
              students.remove(studentId);
            }
          }
          emit();
        }, onError: controller.addError);
        subscriptions.add(subscription);
      }

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  @override
  Future<List<StudentModel>> getStudentsByIds({
    required String schoolId,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) return const [];

    final students = <StudentModel>[];
    for (final studentId in studentIds.toSet()) {
      final snapshot =
          await _collection(schoolId, 'students').doc(studentId).get();
      if (snapshot.exists) {
        final student = StudentModel.fromFirestore(snapshot);
        if (student.status == 'active') students.add(student);
      }
    }

    return _sortStudents(students);
  }

  @override
  Stream<List<TeacherModel>> watchTeachersByGroup({
    required String schoolId,
    required String groupId,
  }) {
    return _collection(schoolId, 'teachers')
        .where('groupIds', arrayContains: groupId)
        .snapshots()
        .map(
          (snapshot) => _sortTeachers(
            snapshot.docs
                .map(TeacherModel.fromFirestore)
                .where((teacher) => teacher.status == 'active'),
          ),
        );
  }

  @override
  Future<List<TeacherModel>> getTeachersByGroup({
    required String schoolId,
    required String groupId,
  }) async {
    final snapshot =
        await _collection(
          schoolId,
          'teachers',
        ).where('groupIds', arrayContains: groupId).get();

    return _sortTeachers(
      snapshot.docs
          .map(TeacherModel.fromFirestore)
          .where((teacher) => teacher.status == 'active'),
    );
  }

  List<SchoolGroupModel> _sortGroups(Iterable<SchoolGroupModel> groups) {
    return groups.toList()..sort((a, b) {
      final orderComparison = a.sortOrder.compareTo(b.sortOrder);
      if (orderComparison != 0) return orderComparison;
      return a.name.compareTo(b.name);
    });
  }

  List<StudentModel> _sortStudents(Iterable<StudentModel> students) {
    return students.toList()..sort((a, b) {
      final lastNameComparison = a.lastName.compareTo(b.lastName);
      if (lastNameComparison != 0) return lastNameComparison;
      return a.firstName.compareTo(b.firstName);
    });
  }

  List<TeacherModel> _sortTeachers(Iterable<TeacherModel> teachers) {
    return teachers.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
  }
}
