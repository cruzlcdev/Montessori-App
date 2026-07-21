import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyAccountModel {
  const FamilyAccountModel({
    required this.uid,
    required this.schoolId,
    required this.fullName,
    required this.email,
    required this.status,
    required this.relationship,
    required this.studentIds,
    required this.groupIds,
    this.phone,
    this.invitationStatus,
    this.invitationSentAt,
  });

  final String uid;
  final String schoolId;
  final String fullName;
  final String email;
  final String status;
  final String relationship;
  final List<String> studentIds;
  final List<String> groupIds;
  final String? phone;
  final String? invitationStatus;
  final DateTime? invitationSentAt;

  bool get isActive => status == 'active';

  factory FamilyAccountModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return FamilyAccountModel(
      uid: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      fullName: _firstText([
        data['name'],
        data['fullName'],
        data['displayName'],
      ]),
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString(),
      status: data['status']?.toString().toLowerCase() ?? 'inactive',
      relationship:
          data['relationship']?.toString().toLowerCase() ?? 'guardian',
      studentIds: _stringList(data['studentIds']),
      groupIds: _stringList(data['groupIds']),
      invitationStatus: data['invitationStatus']?.toString(),
      invitationSentAt: _readDate(data['invitationSentAt']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
