class AppUser {
  const AppUser({
    required this.uid,
    required this.schoolId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.groupIds = const [],
    this.studentIds = const [],
  });

  final String uid;
  final String schoolId;
  final String name;
  final String email;
  final String role;
  final String status;
  final List<String> groupIds;
  final List<String> studentIds;

  bool get isActive => status == 'active';
  bool get isOwner => role == 'owner';
  bool get isAdmin => isOwner || role == 'admin';
  bool get isTeacher => role == 'teacher';
  bool get isParent => role == 'parent';
  bool get isStaff => role == 'staff';

  factory AppUser.fromMap(Map<String, dynamic> data, {String? uid}) {
    return AppUser(
      uid: uid ?? data['uid']?.toString() ?? '',
      schoolId: data['schoolId']?.toString() ?? '',
      name: _readName(data),
      email: data['email']?.toString() ?? '',
      role: data['role']?.toString().toLowerCase() ?? '',
      status: data['status']?.toString().toLowerCase() ?? 'inactive',
      groupIds: _readStringList(data['groupIds']),
      studentIds: _readStringList(data['studentIds']),
    );
  }

  static String _readName(Map<String, dynamic> data) {
    final directName = _firstNonEmpty([
      data['name'],
      data['fullName'],
      data['displayName'],
      data['parentName'],
      data['tutorName'],
      data['nombre'],
      data['nombreCompleto'],
    ]);

    if (directName.isNotEmpty) return directName;

    final firstName = _firstNonEmpty([
      data['firstName'],
      data['first_name'],
      data['nombrePila'],
      data['nombres'],
    ]);
    final lastName = _firstNonEmpty([
      data['lastName'],
      data['last_name'],
      data['apellido'],
      data['apellidos'],
    ]);

    return [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ').trim();
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }

    return '';
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
