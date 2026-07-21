import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'current_user_repository.dart';

class FirestoreCurrentUserRepository implements CurrentUserRepository {
  FirestoreCurrentUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDocument({
    required String schoolId,
    required String uid,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .doc(uid);
  }

  @override
  Stream<AppUser?> watchCurrentUserProfile({
    required String schoolId,
    required String uid,
  }) {
    return _userDocument(schoolId: schoolId, uid: uid).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) return null;
      return AppUser.fromMap(data, uid: snapshot.id);
    });
  }

  @override
  Future<AppUser?> getCurrentUserProfile({
    required String schoolId,
    required String uid,
  }) async {
    final snapshot = await _userDocument(schoolId: schoolId, uid: uid).get();

    final data = snapshot.data();
    if (data == null) return null;

    return AppUser.fromMap(data, uid: snapshot.id);
  }
}
