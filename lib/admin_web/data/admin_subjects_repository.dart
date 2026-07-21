import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../features/academics/data/models/subject_model.dart';
import '../../features/directory/data/models/school_group_model.dart';

class AdminSubjectsRepository {
  AdminSubjectsRepository({
    FirebaseFirestore? firestore,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String schoolId;

  CollectionReference<Map<String, dynamic>> get _subjectsCollection {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subjects');
  }

  CollectionReference<Map<String, dynamic>> get _groupsCollection {
    return _firestore.collection('schools').doc(schoolId).collection('groups');
  }

  Stream<List<SubjectModel>> watchSubjects() {
    return _subjectsCollection.snapshots().map((snapshot) {
      final subjects =
          snapshot.docs.map(SubjectModel.fromFirestore).toList()..sort((a, b) {
            final orderComparison = a.sortOrder.compareTo(b.sortOrder);
            if (orderComparison != 0) return orderComparison;
            return a.name.compareTo(b.name);
          });

      return subjects;
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

  Future<void> createSubject({
    required String name,
    required String type,
    required List<String> groupIds,
    required String status,
  }) async {
    final subjectId = await _availableSubjectId(name);
    final now = Timestamp.now();
    final normalizedName = name.trim();

    await _subjectsCollection.doc(subjectId).set({
      'schoolId': schoolId,
      'name': normalizedName,
      'type': type,
      'groupIds': groupIds.toSet().toList(),
      'sortOrder': await _nextSortOrder(),
      'status': status,
      'iconName': _englishKeyFromName(normalizedName),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateSubject({
    required SubjectModel subject,
    required String name,
    required String type,
    required List<String> groupIds,
    required String status,
  }) async {
    final normalizedName = name.trim();

    await _subjectsCollection.doc(subject.id).set({
      'schoolId': subject.schoolId.isEmpty ? schoolId : subject.schoolId,
      'name': normalizedName,
      'type': type,
      'groupIds': groupIds.toSet().toList(),
      'sortOrder':
          subject.sortOrder > 0 ? subject.sortOrder : await _nextSortOrder(),
      'status': status,
      'iconName': _englishKeyFromName(normalizedName),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> setSubjectStatus(SubjectModel subject, String status) async {
    await _subjectsCollection.doc(subject.id).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteSubject(SubjectModel subject) async {
    await _subjectsCollection.doc(subject.id).delete();
  }

  Future<String> _availableSubjectId(String name) async {
    final baseId = _slugFromName(name);
    var candidateId = baseId;
    var suffix = 2;

    while ((await _subjectsCollection.doc(candidateId).get()).exists) {
      candidateId = '$baseId-$suffix';
      suffix++;
    }

    return candidateId;
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

    return slug.isEmpty ? 'materia' : slug;
  }

  Future<int> _nextSortOrder() async {
    final snapshot = await _subjectsCollection.get();
    if (snapshot.docs.isEmpty) return 1;

    final maxOrder = snapshot.docs
        .map((doc) => SubjectModel.fromFirestore(doc).sortOrder)
        .fold<int>(0, (max, order) => order > max ? order : max);

    return maxOrder + 1;
  }

  String _englishKeyFromName(String value) {
    final normalized = _slugFromName(value);
    const dictionary = {
      'lenguaje': 'language',
      'lectura': 'reading',
      'escritura': 'writing',
      'matematicas': 'math',
      'matematica': 'math',
      'aritmetica': 'arithmetic',
      'geometria': 'geometry',
      'arte': 'art',
      'musica': 'music',
      'sensorial': 'sensorial',
      'vida_practica': 'practical_life',
      'cultura': 'culture',
      'ciencias': 'science',
      'historia': 'history',
      'geografia': 'geography',
      'ingles': 'english',
      'educacion_fisica': 'physical_education',
      'psicomotricidad': 'psychomotor_skills',
      'computacion': 'computer_science',
    };

    return dictionary[normalized] ?? normalized;
  }
}
