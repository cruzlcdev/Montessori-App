import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectModel {
  const SubjectModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.type,
    required this.status,
    required this.groupIds,
    required this.sortOrder,
    this.iconName,
  });

  final String id;
  final String schoolId;
  final String name;
  final String type;
  final String status;
  final List<String> groupIds;
  final int sortOrder;
  final String? iconName;

  bool get isQualitative => type == 'qualitative';

  factory SubjectModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return SubjectModel(
      id: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      name: data['name']?.toString() ?? snapshot.id,
      type: data['type']?.toString() ?? 'quantitative',
      status: data['status']?.toString() ?? 'active',
      groupIds: _readStringList(data['groupIds']),
      sortOrder: _readInt(data['sortOrder']),
      iconName: data['iconName']?.toString(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
