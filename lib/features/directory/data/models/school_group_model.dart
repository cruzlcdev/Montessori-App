import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolGroupModel {
  const SchoolGroupModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.level,
    required this.status,
    required this.sortOrder,
    required this.initials,
    required this.colorHex,
  });

  final String id;
  final String schoolId;
  final String name;
  final String level;
  final String status;
  final int sortOrder;
  final String initials;
  final String colorHex;

  factory SchoolGroupModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return SchoolGroupModel(
      id: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      name: data['name']?.toString() ?? snapshot.id,
      level: data['level']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      sortOrder: _readInt(data['sortOrder']),
      initials: data['initials']?.toString() ?? _fallbackInitials(snapshot.id),
      colorHex: data['colorHex']?.toString() ?? '#607D8B',
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _fallbackInitials(String value) {
    final parts = value.split('_').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
