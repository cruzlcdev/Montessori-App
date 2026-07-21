import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
  const TeacherModel({
    required this.id,
    required this.schoolId,
    required this.fullName,
    required this.status,
    required this.groupIds,
    this.authUid,
    this.email,
    this.phone,
  });

  final String id;
  final String schoolId;
  final String fullName;
  final String status;
  final List<String> groupIds;
  final String? authUid;
  final String? email;
  final String? phone;

  factory TeacherModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return TeacherModel(
      id: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      fullName: data['fullName']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      groupIds: _readStringList(data['groupIds']),
      authUid: _readAuthUid(data),
      email: data['email']?.toString(),
      phone: data['phone']?.toString(),
    );
  }

  static String? _readAuthUid(Map<String, dynamic> data) {
    final value = data['authUid'] ?? data['uid'] ?? data['userId'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
