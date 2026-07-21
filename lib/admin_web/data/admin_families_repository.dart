import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_constants.dart';
import '../../features/directory/data/models/school_group_model.dart';
import '../../features/directory/data/models/student_model.dart';
import 'admin_auth_account_provisioner.dart';
import 'models/family_account_model.dart';

class AdminFamiliesRepository {
  AdminFamiliesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AdminAuthAccountProvisioner accountProvisioner =
        const AdminAuthAccountProvisioner(),
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _accountProvisioner = accountProvisioner;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AdminAuthAccountProvisioner _accountProvisioner;
  final String schoolId;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('schools').doc(schoolId).collection('users');

  CollectionReference<Map<String, dynamic>> get _studentsCollection =>
      _firestore.collection('schools').doc(schoolId).collection('students');

  CollectionReference<Map<String, dynamic>> get _groupsCollection =>
      _firestore.collection('schools').doc(schoolId).collection('groups');

  Stream<List<FamilyAccountModel>> watchFamilies() {
    return _usersCollection.where('role', isEqualTo: 'parent').snapshots().map((
      snapshot,
    ) {
      final families =
          snapshot.docs
              .map(FamilyAccountModel.fromFirestore)
              .where((family) => family.status != 'archived')
              .toList()
            ..sort((a, b) => a.fullName.compareTo(b.fullName));
      return families;
    });
  }

  Stream<List<StudentModel>> watchStudents() {
    return _studentsCollection.snapshots().map((snapshot) {
      final students =
          snapshot.docs.map(StudentModel.fromFirestore).toList()..sort((a, b) {
            final groupComparison = a.groupId.compareTo(b.groupId);
            if (groupComparison != 0) return groupComparison;
            return a.fullName.compareTo(b.fullName);
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

  Future<FamilyCreationResult> createFamily({
    required String fullName,
    required String email,
    required String phone,
    required String relationship,
    required List<String> studentIds,
    required String status,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedStudentIds = studentIds.toSet().toList(growable: false);
    if (normalizedStudentIds.isEmpty) {
      throw StateError('Selecciona al menos un alumno para esta familia.');
    }

    final existingUserId = await _findParentUserIdByEmail(normalizedEmail);
    ProvisionedAdminAccount? provisionedAccount;
    final uid =
        existingUserId ??
        (provisionedAccount = await _accountProvisioner.createAccount(
              email: normalizedEmail,
              accountLabel: 'familiar',
            ))
            .user
            .uid;
    final now = Timestamp.now();
    final groupIds = await _activeGroupIdsForStudents(normalizedStudentIds);
    final userRef = _usersCollection.doc(uid);

    final data = <String, dynamic>{
      'uid': uid,
      'schoolId': schoolId,
      'name': fullName.trim(),
      'fullName': fullName.trim(),
      'displayName': fullName.trim(),
      'email': normalizedEmail,
      'phone': _nullableText(phone),
      'role': 'parent',
      'relationship': relationship,
      'studentIds': normalizedStudentIds,
      'groupIds': groupIds,
      'status': status,
      'updatedAt': now,
    };
    if (existingUserId == null) data['createdAt'] = now;

    try {
      await userRef.set(data, SetOptions(merge: true));
    } catch (_) {
      await provisionedAccount?.dispose(deleteUser: true);
      rethrow;
    }

    if (provisionedAccount == null) {
      return const FamilyCreationResult.linkedExistingAccount();
    }

    final resetEmailSent = await provisionedAccount.sendPasswordSetupEmail(
      normalizedEmail,
    );
    await provisionedAccount.dispose();
    await userRef.set({
      'invitationStatus': resetEmailSent ? 'sent' : 'send_failed',
      if (resetEmailSent) 'invitationSentAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    return FamilyCreationResult.newAccount(resetEmailSent: resetEmailSent);
  }

  Future<void> updateFamily({
    required FamilyAccountModel family,
    required String fullName,
    required String phone,
    required String relationship,
    required List<String> studentIds,
    required String status,
  }) async {
    final normalizedStudentIds = studentIds.toSet().toList(growable: false);
    if (normalizedStudentIds.isEmpty) {
      throw StateError('Selecciona al menos un alumno para esta familia.');
    }
    final groupIds = await _activeGroupIdsForStudents(normalizedStudentIds);
    await _usersCollection.doc(family.uid).set({
      'name': fullName.trim(),
      'fullName': fullName.trim(),
      'displayName': fullName.trim(),
      'phone': _nullableText(phone),
      'relationship': relationship,
      'studentIds': normalizedStudentIds,
      'groupIds': groupIds,
      'status': status,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> setFamilyStatus(FamilyAccountModel family, String status) async {
    await _usersCollection.doc(family.uid).set({
      'status': status,
      'accessRevokedAt':
          status == 'active' ? FieldValue.delete() : Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> archiveFamily(FamilyAccountModel family) async {
    final now = Timestamp.now();
    await _usersCollection.doc(family.uid).set({
      'status': 'archived',
      'studentIds': <String>[],
      'groupIds': <String>[],
      'accessRevokedAt': now,
      'deletedAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> resendInvitation(FamilyAccountModel family) async {
    await _auth.sendPasswordResetEmail(email: family.email);
    await _usersCollection.doc(family.uid).set({
      'invitationStatus': 'sent',
      'invitationSentAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<List<String>> _activeGroupIdsForStudents(
    List<String> studentIds,
  ) async {
    final groupIds = <String>{};
    for (final studentId in studentIds) {
      final snapshot = await _studentsCollection.doc(studentId).get();
      if (!snapshot.exists) continue;
      final student = StudentModel.fromFirestore(snapshot);
      if (student.status == 'active' && student.groupId.isNotEmpty) {
        groupIds.add(student.groupId);
      }
    }
    return groupIds.toList(growable: false)..sort();
  }

  Future<String?> _findParentUserIdByEmail(String email) async {
    final snapshot =
        await _usersCollection.where('email', isEqualTo: email).limit(1).get();
    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final role = doc.data()['role']?.toString().toLowerCase().trim() ?? '';
    if (role != 'parent') {
      throw StateError(
        'Ese correo ya está vinculado a otro rol escolar y no puede reutilizarse como familiar.',
      );
    }
    return doc.id;
  }

  String? _nullableText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class FamilyCreationResult {
  const FamilyCreationResult.newAccount({required this.resetEmailSent})
    : linkedExistingAccount = false;

  const FamilyCreationResult.linkedExistingAccount()
    : linkedExistingAccount = true,
      resetEmailSent = false;

  final bool linkedExistingAccount;
  final bool resetEmailSent;
}
