import 'package:cloud_firestore/cloud_firestore.dart';

class EvaluationModel {
  const EvaluationModel({
    required this.id,
    required this.schoolId,
    required this.groupId,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.subjectName,
    required this.termNumber,
    required this.value,
    required this.feedback,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String schoolId;
  final String groupId;
  final String studentId;
  final String studentName;
  final String subjectId;
  final String subjectName;
  final int termNumber;
  final String value;
  final String feedback;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String documentId({
    required String groupId,
    required String studentId,
    required String subjectId,
    required int termNumber,
  }) {
    return '${groupId}_${studentId}_${subjectId}_t$termNumber';
  }

  factory EvaluationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return EvaluationModel(
      id: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      groupId: data['groupId']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      subjectId: data['subjectId']?.toString() ?? '',
      subjectName: data['subjectName']?.toString() ?? '',
      termNumber: _readInt(data['termNumber']),
      value: data['value']?.toString() ?? '',
      feedback: data['feedback']?.toString() ?? '',
      updatedBy: data['updatedBy']?.toString() ?? '',
      createdAt: _readDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSaveMap() {
    final now = Timestamp.now();

    return {
      'schoolId': schoolId,
      'groupId': groupId,
      'studentId': studentId,
      'studentName': studentName,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'termNumber': termNumber,
      'value': value,
      'feedback': feedback.trim(),
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': now,
    };
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
