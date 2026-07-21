import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/academic_period_model.dart';
import '../models/subject_model.dart';
import 'academic_repository.dart';

class FirestoreAcademicRepository implements AcademicRepository {
  FirestoreAcademicRepository({FirebaseFirestore? firestore})
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
  Stream<List<SubjectModel>> watchSubjectsByGroup({
    required String schoolId,
    required String groupId,
  }) {
    return _collection(schoolId, 'subjects')
        .where('status', isEqualTo: 'active')
        .where('groupIds', arrayContains: groupId)
        .snapshots()
        .map(
          (snapshot) =>
              _sortSubjects(snapshot.docs.map(SubjectModel.fromFirestore)),
        );
  }

  @override
  Future<List<SubjectModel>> getSubjectsByGroup({
    required String schoolId,
    required String groupId,
  }) async {
    final snapshot =
        await _collection(schoolId, 'subjects')
            .where('status', isEqualTo: 'active')
            .where('groupIds', arrayContains: groupId)
            .get();

    return _sortSubjects(snapshot.docs.map(SubjectModel.fromFirestore));
  }

  @override
  Stream<List<AcademicPeriodModel>> watchActivePeriods({
    required String schoolId,
  }) {
    return _collection(schoolId, 'academicPeriods')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snapshot) => _sortPeriods(
            snapshot.docs.map(AcademicPeriodModel.fromFirestore),
          ),
        );
  }

  @override
  Future<List<AcademicPeriodModel>> getActivePeriods({
    required String schoolId,
  }) async {
    final snapshot =
        await _collection(
          schoolId,
          'academicPeriods',
        ).where('status', isEqualTo: 'active').get();

    return _sortPeriods(snapshot.docs.map(AcademicPeriodModel.fromFirestore));
  }

  List<SubjectModel> _sortSubjects(Iterable<SubjectModel> subjects) {
    return subjects.toList()..sort((a, b) {
      final orderComparison = a.sortOrder.compareTo(b.sortOrder);
      if (orderComparison != 0) return orderComparison;
      return a.name.compareTo(b.name);
    });
  }

  List<AcademicPeriodModel> _sortPeriods(
    Iterable<AcademicPeriodModel> periods,
  ) {
    return periods.toList()
      ..sort((a, b) => a.termNumber.compareTo(b.termNumber));
  }
}
