import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../features/directory/data/models/school_group_model.dart';

class AdminGroupsRepository {
  AdminGroupsRepository({
    FirebaseFirestore? firestore,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String schoolId;

  CollectionReference<Map<String, dynamic>> get _groupsCollection {
    return _firestore.collection('schools').doc(schoolId).collection('groups');
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

  Future<void> createGroup({
    required String name,
    required String level,
    String colorHex = '#0073DB',
    String status = 'active',
  }) async {
    final groupId = await _availableGroupId(name);
    final now = Timestamp.now();
    final normalizedName = name.trim();

    await _groupsCollection.doc(groupId).set({
      'schoolId': schoolId,
      'name': normalizedName,
      'level': level.trim(),
      'initials': _initialsFromName(normalizedName),
      'colorHex': _normalizeColorHex(colorHex),
      'sortOrder': await _nextSortOrder(),
      'status': status,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateGroupProfile({
    required SchoolGroupModel group,
    required String name,
    required String level,
    required String colorHex,
    required String status,
  }) async {
    final normalizedName = name.trim();

    await _groupsCollection.doc(group.id).set({
      'schoolId': group.schoolId.isEmpty ? schoolId : group.schoolId,
      'name': normalizedName,
      'level': level.trim(),
      'initials': _initialsFromName(normalizedName),
      'colorHex': _normalizeColorHex(colorHex),
      'sortOrder':
          group.sortOrder > 0 ? group.sortOrder : await _nextSortOrder(),
      'status': status,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> setGroupStatus(SchoolGroupModel group, String status) async {
    await _groupsCollection.doc(group.id).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteGroup(SchoolGroupModel group) async {
    await _groupsCollection.doc(group.id).delete();
  }

  Future<String> _availableGroupId(String name) async {
    final baseId = _slugFromName(name);
    var candidateId = baseId;
    var suffix = 2;

    while ((await _groupsCollection.doc(candidateId).get()).exists) {
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

    return slug.isEmpty ? 'grupo' : slug;
  }

  Future<int> _nextSortOrder() async {
    final snapshot = await _groupsCollection.get();
    if (snapshot.docs.isEmpty) return 1;

    final maxOrder = snapshot.docs
        .map((doc) => SchoolGroupModel.fromFirestore(doc).sortOrder)
        .fold<int>(0, (max, order) => order > max ? order : max);

    return maxOrder + 1;
  }

  String _initialsFromName(String value) {
    final words =
        value
            .trim()
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();

    if (words.isEmpty) return '?';

    final meaningfulWords =
        words
            .where(
              (word) =>
                  !{
                    'de',
                    'del',
                    'la',
                    'las',
                    'el',
                    'los',
                    'y',
                  }.contains(word.toLowerCase()),
            )
            .toList();
    final sourceWords = meaningfulWords.isEmpty ? words : meaningfulWords;

    if (sourceWords.length == 1) {
      final word = sourceWords.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }

    return '${sourceWords.first[0]}${sourceWords.last[0]}'.toUpperCase();
  }

  String _normalizeColorHex(String value) {
    final cleanValue = value.trim().replaceFirst('#', '').toUpperCase();
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(cleanValue)) {
      return '#$cleanValue';
    }
    return '#0073DB';
  }
}
