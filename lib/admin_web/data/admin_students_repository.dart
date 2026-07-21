import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../features/directory/data/models/school_group_model.dart';
import '../../features/directory/data/models/student_model.dart';

class AdminStudentsRepository {
  AdminStudentsRepository({
    FirebaseFirestore? firestore,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String schoolId;

  CollectionReference<Map<String, dynamic>> get _studentsCollection {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students');
  }

  CollectionReference<Map<String, dynamic>> get _groupsCollection {
    return _firestore.collection('schools').doc(schoolId).collection('groups');
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('schools').doc(schoolId).collection('users');
  }

  Stream<List<StudentModel>> watchStudents() {
    return _studentsCollection.snapshots().map((snapshot) {
      final students =
          snapshot.docs.map(StudentModel.fromFirestore).toList()..sort((a, b) {
            final groupComparison = a.groupId.compareTo(b.groupId);
            if (groupComparison != 0) return groupComparison;
            final lastNameComparison = a.lastName.compareTo(b.lastName);
            if (lastNameComparison != 0) return lastNameComparison;
            return a.firstName.compareTo(b.firstName);
          });

      return students;
    });
  }

  Stream<List<SchoolGroupModel>> watchGroups() {
    return _groupsCollection.snapshots().map((snapshot) {
      final groups =
          snapshot.docs.map(SchoolGroupModel.fromFirestore).toList()
            ..sort((a, b) {
              final orderComparison = a.sortOrder.compareTo(b.sortOrder);
              if (orderComparison != 0) return orderComparison;
              return a.name.compareTo(b.name);
            });

      return groups;
    });
  }

  Future<void> createStudent({
    required String firstName,
    required String lastName,
    required String groupId,
    required String status,
    String? tutorName,
    String? tutorPhone,
    String? allergies,
    String? notes,
  }) async {
    final fullName = _buildFullName(firstName, lastName);
    final studentId = await _availableStudentId(fullName);
    final now = Timestamp.now();

    await _studentsCollection.doc(studentId).set({
      'schoolId': schoolId,
      'groupId': groupId,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'fullName': fullName,
      'status': status,
      'birthDate': null,
      'tutorName': _nullableText(tutorName),
      'tutorPhone': _nullableText(tutorPhone),
      'allergies': _nullableText(allergies),
      'notes': _nullableText(notes),
      'enrollmentDate': now,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateStudent({
    required StudentModel student,
    required String firstName,
    required String lastName,
    required String groupId,
    required String status,
    String? tutorName,
    String? tutorPhone,
    String? allergies,
    String? notes,
  }) async {
    await _studentsCollection.doc(student.id).set({
      'schoolId': student.schoolId.isEmpty ? schoolId : student.schoolId,
      'groupId': groupId,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'fullName': _buildFullName(firstName, lastName),
      'status': status,
      'birthDate':
          student.birthDate == null
              ? null
              : Timestamp.fromDate(student.birthDate!),
      'enrollmentDate':
          student.enrollmentDate == null
              ? null
              : Timestamp.fromDate(student.enrollmentDate!),
      'tutorName': _nullableText(tutorName),
      'tutorPhone': _nullableText(tutorPhone),
      'allergies': _nullableText(allergies),
      'notes': _nullableText(notes),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    await _syncLinkedFamilyAccess(student.id);
  }

  Future<void> setStudentStatus(StudentModel student, String status) async {
    await _studentsCollection.doc(student.id).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
    await _syncLinkedFamilyAccess(student.id);
  }

  Future<void> deleteStudent(StudentModel student) async {
    await _studentsCollection.doc(student.id).delete();
    await _syncLinkedFamilyAccess(student.id, removeStudent: true);
  }

  Future<void> _syncLinkedFamilyAccess(
    String changedStudentId, {
    bool removeStudent = false,
  }) async {
    final familySnapshot =
        await _usersCollection
            .where('studentIds', arrayContains: changedStudentId)
            .get();
    if (familySnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final familyDoc in familySnapshot.docs) {
      final familyData = familyDoc.data();
      if (familyData['role']?.toString().toLowerCase() != 'parent') continue;

      final linkedStudentIds = (familyData['studentIds'] as List<dynamic>? ??
              const [])
          .map((item) => item.toString())
          .where((id) => !removeStudent || id != changedStudentId)
          .toSet()
          .toList(growable: false);
      final groupIds = <String>{};

      for (final studentId in linkedStudentIds) {
        final studentSnapshot = await _studentsCollection.doc(studentId).get();
        if (!studentSnapshot.exists) continue;
        final linkedStudent = StudentModel.fromFirestore(studentSnapshot);
        if (linkedStudent.status == 'active' &&
            linkedStudent.groupId.isNotEmpty) {
          groupIds.add(linkedStudent.groupId);
        }
      }

      batch.set(familyDoc.reference, {
        'studentIds': linkedStudentIds,
        'groupIds': groupIds.toList(growable: false)..sort(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<String> _availableStudentId(String fullName) async {
    final baseId = _slugFromName(fullName);
    var candidateId = baseId;
    var suffix = 2;

    while ((await _studentsCollection.doc(candidateId).get()).exists) {
      candidateId = '$baseId-$suffix';
      suffix++;
    }

    return candidateId;
  }

  String _buildFullName(String firstName, String lastName) {
    return [
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ').trim();
  }

  String? _nullableText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _slugFromName(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
    final slug = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return slug.isEmpty ? 'alumno' : slug;
  }
}
