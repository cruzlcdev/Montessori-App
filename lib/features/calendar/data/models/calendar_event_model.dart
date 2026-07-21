import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEventModel {
  const CalendarEventModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.status,
    required this.visibility,
    required this.targetGroupIds,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.startTime,
    this.endTime,
  });

  final String id;
  final String schoolId;
  final String title;
  final String description;
  final DateTime eventDate;
  final String status;
  final String visibility;
  final List<String> targetGroupIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? startTime;
  final String? endTime;

  bool get isPublished => status == 'published';
  bool get hasTime => startTime != null && startTime!.isNotEmpty;

  factory CalendarEventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return CalendarEventModel(
      id: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      eventDate: _readDate(data['eventDate']) ?? DateTime.now(),
      status: data['status']?.toString() ?? 'published',
      visibility: data['visibility']?.toString() ?? 'school',
      targetGroupIds: _readStringList(data['targetGroupIds']),
      createdBy: data['createdBy']?.toString() ?? '',
      createdAt: _readDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(data['updatedAt']) ?? DateTime.now(),
      startTime: data['startTime']?.toString(),
      endTime: data['endTime']?.toString(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    final now = Timestamp.now();

    return {
      'schoolId': schoolId,
      'title': title.trim(),
      'description': description.trim(),
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'visibility': visibility,
      'targetGroupIds': targetGroupIds,
      'createdBy': createdBy,
      'createdAt': now,
      'updatedAt': now,
    };
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const ['all'];
    final items = value.map((item) => item.toString()).toList(growable: false);
    return items.isEmpty ? const ['all'] : items;
  }
}
