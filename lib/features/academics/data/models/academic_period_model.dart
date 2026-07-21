import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicPeriodModel {
  const AcademicPeriodModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.termNumber,
    required this.cycle,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String schoolId;
  final String name;
  final int termNumber;
  final String cycle;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  factory AcademicPeriodModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return AcademicPeriodModel(
      id: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      name: data['name']?.toString() ?? snapshot.id,
      termNumber: _readInt(data['termNumber']),
      cycle: data['cycle']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      startDate: _readDate(data['startDate']),
      endDate: _readDate(data['endDate']),
    );
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
