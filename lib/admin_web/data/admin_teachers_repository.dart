import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../features/directory/data/models/school_group_model.dart';
import '../../features/directory/data/models/teacher_model.dart';
import 'admin_auth_account_provisioner.dart';

class AdminTeachersRepository {
  AdminTeachersRepository({
    FirebaseFirestore? firestore,
    AdminAuthAccountProvisioner accountProvisioner =
        const AdminAuthAccountProvisioner(),
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _accountProvisioner = accountProvisioner;

  final FirebaseFirestore _firestore;
  final AdminAuthAccountProvisioner _accountProvisioner;
  final String schoolId;

  CollectionReference<Map<String, dynamic>> get _teachersCollection {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teachers');
  }

  CollectionReference<Map<String, dynamic>> get _groupsCollection {
    return _firestore.collection('schools').doc(schoolId).collection('groups');
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('schools').doc(schoolId).collection('users');
  }

  Stream<List<TeacherModel>> watchTeachers() {
    return _teachersCollection.snapshots().asyncMap((snapshot) async {
      final teachers = <TeacherModel>[];

      for (final doc in snapshot.docs) {
        final teacher = TeacherModel.fromFirestore(doc);
        if (await _hasLinkedTeacherUser(teacher)) {
          teachers.add(teacher);
        }
      }

      teachers.sort((a, b) => a.fullName.compareTo(b.fullName));

      return teachers;
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

  Future<TeacherCreationResult> createTeacher({
    required String fullName,
    required String email,
    required String phone,
    required List<String> groupIds,
    required String status,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw StateError('Ingresa el correo institucional del profesor.');
    }

    final existingUserId = await _findTeacherUserIdByEmail(normalizedEmail);
    ProvisionedAdminAccount? provisionedAccount;
    final teacherId =
        existingUserId ??
        (provisionedAccount = await _accountProvisioner.createAccount(
              email: normalizedEmail,
              accountLabel: 'profesor',
            ))
            .user
            .uid;

    if ((await _teachersCollection.doc(teacherId).get()).exists) {
      await provisionedAccount?.dispose(deleteUser: true);
      throw StateError('Ya existe un profesor registrado con ese correo.');
    }

    final now = Timestamp.now();
    final teacherRef = _teachersCollection.doc(teacherId);
    final linkedUserRef = _usersCollection.doc(teacherId);
    final normalizedGroupIds = groupIds.toSet().toList();
    final batch = _firestore.batch();

    batch.set(teacherRef, {
      'schoolId': schoolId,
      'fullName': fullName.trim(),
      'email': normalizedEmail,
      'phone': _nullableText(phone),
      'groupIds': normalizedGroupIds,
      'authUid': linkedUserRef.id,
      'uid': linkedUserRef.id,
      'status': status,
      'createdAt': now,
      'updatedAt': now,
    });

    batch.set(
      linkedUserRef,
      _linkedUserUpdateMap(
        uid: linkedUserRef.id,
        fullName: fullName,
        email: normalizedEmail,
        groupIds: normalizedGroupIds,
        status: status,
        updatedAt: now,
      ),
      SetOptions(merge: true),
    );

    try {
      await batch.commit();
    } catch (_) {
      await provisionedAccount?.dispose(deleteUser: true);
      rethrow;
    }

    if (provisionedAccount == null) {
      return const TeacherCreationResult.linkedExistingAccount();
    }

    var resetEmailSent = false;
    try {
      resetEmailSent = await provisionedAccount.sendPasswordSetupEmail(
        normalizedEmail,
      );
    } finally {
      await provisionedAccount.dispose();
    }

    return TeacherCreationResult.newAccount(resetEmailSent: resetEmailSent);
  }

  Future<void> updateTeacher({
    required TeacherModel teacher,
    required String fullName,
    required String email,
    required String phone,
    required List<String> groupIds,
    required String status,
  }) async {
    final now = Timestamp.now();
    final teacherRef = _teachersCollection.doc(teacher.id);
    final linkedUserRef = await _requiredLinkedUserDocument(
      teacherId: teacher.id,
      teacherAuthUid: teacher.authUid,
      email: email,
      fullName: fullName,
    );
    final normalizedGroupIds = groupIds.toSet().toList();
    final batch = _firestore.batch();

    batch.set(teacherRef, {
      'schoolId': teacher.schoolId.isEmpty ? schoolId : teacher.schoolId,
      'fullName': fullName.trim(),
      'email': _nullableText(email),
      'phone': _nullableText(phone),
      'groupIds': normalizedGroupIds,
      'authUid': linkedUserRef.id,
      'uid': linkedUserRef.id,
      'status': status,
      'updatedAt': now,
    }, SetOptions(merge: true));

    batch.set(
      linkedUserRef,
      _linkedUserUpdateMap(
        uid: linkedUserRef.id,
        fullName: fullName,
        email: email,
        groupIds: normalizedGroupIds,
        status: status,
        updatedAt: now,
      ),
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> setTeacherStatus(TeacherModel teacher, String status) async {
    final now = Timestamp.now();
    final accessRevokedAt = status == 'active' ? FieldValue.delete() : now;
    final linkedUserRef = await _requiredLinkedUserDocument(
      teacherId: teacher.id,
      teacherAuthUid: teacher.authUid,
      email: teacher.email ?? '',
      fullName: teacher.fullName,
    );
    final batch = _firestore.batch();

    batch.update(_teachersCollection.doc(teacher.id), {
      'status': status,
      'accessRevokedAt': accessRevokedAt,
      'updatedAt': now,
    });

    batch.set(linkedUserRef, {
      'status': status,
      'accessRevokedAt': accessRevokedAt,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> deleteTeacher(TeacherModel teacher) async {
    final now = Timestamp.now();
    final linkedUserRef = await _requiredLinkedUserDocument(
      teacherId: teacher.id,
      teacherAuthUid: teacher.authUid,
      email: teacher.email ?? '',
      fullName: teacher.fullName,
    );
    final batch = _firestore.batch();

    batch.delete(_teachersCollection.doc(teacher.id));
    batch.set(linkedUserRef, {
      'status': 'archived',
      'groupIds': <String>[],
      'accessRevokedAt': now,
      'deletedAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<bool> _hasLinkedTeacherUser(TeacherModel teacher) async {
    final linkedUserRef = await _linkedUserDocument(
      teacherId: teacher.id,
      teacherAuthUid: teacher.authUid,
      email: teacher.email ?? '',
      fullName: teacher.fullName,
      throwOnWrongRole: false,
    );

    if (linkedUserRef == null) return false;
    final snapshot = await linkedUserRef.get();
    return _isTeacherUser(snapshot.data());
  }

  Future<String?> _findUserIdByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    final normalizedSnapshot =
        await _usersCollection
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
    if (normalizedSnapshot.docs.isNotEmpty) {
      return normalizedSnapshot.docs.first.id;
    }

    final rawEmail = email.trim();
    if (rawEmail == normalizedEmail) return null;

    final rawSnapshot =
        await _usersCollection
            .where('email', isEqualTo: rawEmail)
            .limit(1)
            .get();
    if (rawSnapshot.docs.isNotEmpty) return rawSnapshot.docs.first.id;

    return null;
  }

  Future<DocumentReference<Map<String, dynamic>>> _requiredLinkedUserDocument({
    required String teacherId,
    String? teacherAuthUid,
    required String email,
    required String fullName,
  }) async {
    final linkedUserRef = await _linkedUserDocument(
      teacherId: teacherId,
      teacherAuthUid: teacherAuthUid,
      email: email,
      fullName: fullName,
      throwOnWrongRole: true,
    );
    if (linkedUserRef != null) return linkedUserRef;

    throw StateError(
      'No se encontró un usuario móvil vinculado para este profesor. Verifica que exista en la colección users con el mismo correo o vincúlalo antes de guardar.',
    );
  }

  Future<DocumentReference<Map<String, dynamic>>?> _linkedUserDocument({
    required String teacherId,
    String? teacherAuthUid,
    required String email,
    required String fullName,
    required bool throwOnWrongRole,
  }) async {
    final authUid = teacherAuthUid?.trim() ?? '';
    if (authUid.isNotEmpty) {
      final userByAuthUid = _usersCollection.doc(authUid);
      final userByAuthUidSnapshot = await userByAuthUid.get();
      if (userByAuthUidSnapshot.exists) {
        if (!_isTeacherUser(userByAuthUidSnapshot.data())) {
          if (throwOnWrongRole) _throwWrongRole(authUid);
          return null;
        }
        return userByAuthUid;
      }
    }

    final userByTeacherId = _usersCollection.doc(teacherId);
    final userByTeacherIdSnapshot = await userByTeacherId.get();
    if (userByTeacherIdSnapshot.exists) {
      if (!_isTeacherUser(userByTeacherIdSnapshot.data())) {
        if (throwOnWrongRole) _throwWrongRole(teacherId);
        return null;
      }
      return userByTeacherId;
    }

    final userIdByEmail = await _findTeacherUserIdByEmail(email);
    if (userIdByEmail != null) return _usersCollection.doc(userIdByEmail);

    final userIdByName = await _findUniqueTeacherUserIdByName(fullName);
    if (userIdByName == null) return null;
    return _usersCollection.doc(userIdByName);
  }

  Future<String?> _findTeacherUserIdByEmail(String email) async {
    final userId = await _findUserIdByEmail(email);
    if (userId == null) return null;

    final snapshot = await _usersCollection.doc(userId).get();
    if (!_isTeacherUser(snapshot.data())) _throwWrongRole(userId);
    return userId;
  }

  bool _isTeacherUser(Map<String, dynamic>? data) {
    final role = data?['role']?.toString().toLowerCase().trim() ?? '';
    return role == 'teacher';
  }

  Never _throwWrongRole(String userId) {
    throw StateError(
      'El usuario vinculado ($userId) no es profesor. Revisa que el correo corresponda a un usuario con rol teacher.',
    );
  }

  Future<String?> _findUniqueTeacherUserIdByName(String fullName) async {
    final normalizedName = _normalizeText(fullName);
    if (normalizedName.isEmpty) return null;

    final snapshot =
        await _usersCollection.where('role', isEqualTo: 'teacher').get();
    final matches = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final candidates = [
            data['name'],
            data['fullName'],
            data['displayName'],
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
          ];

          return candidates.any(
            (value) => _normalizeText(value) == normalizedName,
          );
        })
        .toList(growable: false);

    return matches.length == 1 ? matches.first.id : null;
  }

  Map<String, dynamic> _linkedUserUpdateMap({
    required String uid,
    required String fullName,
    required String email,
    required List<String> groupIds,
    required String status,
    required Timestamp updatedAt,
  }) {
    final trimmedName = fullName.trim();

    return {
      'uid': uid,
      'schoolId': schoolId,
      'name': trimmedName,
      'fullName': trimmedName,
      'displayName': trimmedName,
      'email': _nullableText(email),
      'role': 'teacher',
      'groupIds': groupIds,
      'status': status,
      'updatedAt': updatedAt,
    };
  }

  String? _nullableText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _normalizeText(Object? value) {
    return value
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll('á', 'a')
            .replaceAll('é', 'e')
            .replaceAll('í', 'i')
            .replaceAll('ó', 'o')
            .replaceAll('ú', 'u')
            .replaceAll('ü', 'u')
            .replaceAll('ñ', 'n') ??
        '';
  }
}

class TeacherCreationResult {
  const TeacherCreationResult.newAccount({required this.resetEmailSent})
    : linkedExistingAccount = false;

  const TeacherCreationResult.linkedExistingAccount()
    : linkedExistingAccount = true,
      resetEmailSent = false;

  final bool linkedExistingAccount;
  final bool resetEmailSent;
}
