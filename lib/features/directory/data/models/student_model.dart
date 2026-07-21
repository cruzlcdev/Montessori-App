import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  const StudentModel({
    required this.id,
    required this.schoolId,
    required this.groupId,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.birthDate,
    this.tutorName,
    this.tutorPhone,
    this.allergies,
    this.notes,
    this.enrollmentDate,
  });

  final String id;
  final String schoolId;
  final String groupId;
  final String fullName;
  final String firstName;
  final String lastName;
  final String status;
  final DateTime? birthDate;
  final String? tutorName;
  final String? tutorPhone;
  final String? allergies;
  final String? notes;
  final DateTime? enrollmentDate;

  String get displayStatus => status.isEmpty ? 'Activo' : status;

  factory StudentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final fullName = data['fullName']?.toString() ?? '';

    return StudentModel(
      id: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      groupId: data['groupId']?.toString() ?? '',
      fullName: fullName,
      firstName: data['firstName']?.toString() ?? _extractFirstName(fullName),
      lastName: data['lastName']?.toString() ?? _extractLastName(fullName),
      status: data['status']?.toString() ?? 'active',
      birthDate: _readDate(data['birthDate']),
      tutorName: data['tutorName']?.toString(),
      tutorPhone: data['tutorPhone']?.toString(),
      allergies: data['allergies']?.toString(),
      notes: data['notes']?.toString(),
      enrollmentDate: _readDate(data['enrollmentDate']),
    );
  }

  static String _extractLastName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return '';
    return parts.last;
  }

  static String _extractFirstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return fullName;
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
