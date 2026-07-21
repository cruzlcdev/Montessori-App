import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:intl/intl.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/widgets/custom_drawer.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/features/directory/data/models/school_group_model.dart';
import 'package:prototipo_2/features/directory/data/models/student_model.dart';
import 'package:prototipo_2/features/directory/data/repositories/firestore_directory_repository.dart';
import 'package:prototipo_2/features/directory/presentation/controllers/directory_controller.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late final DirectoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DirectoryController(
      repository: FirestoreDirectoryRepository(),
    );
    _controller.addListener(_onControllerChanged);
    _controller.loadGroups();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudiantes'),
        backgroundColor: isDarkMode ? Colors.grey[900] : AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(AppIcons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
      ),
      drawer: const CustomDrawer(),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.directory,
        child: RefreshIndicator(
          onRefresh: _controller.loadGroups,
          child: _DirectoryBody(
            isLoading: _controller.isLoading,
            errorMessage: _controller.errorMessage,
            isEmpty: _controller.groups.isEmpty,
            emptyMessage: 'No hay grupos activos registrados',
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _controller.groups.length,
              itemBuilder: (context, index) {
                final group = _controller.groups[index];
                return _GroupCard(
                  group: group,
                  subtitle: 'Ver estudiantes',
                  onTap: () => _navigateToGroupStudents(context, group),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToGroupStudents(BuildContext context, SchoolGroupModel group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupStudentsScreen(group: group),
      ),
    );
  }
}

class GroupStudentsScreen extends StatefulWidget {
  const GroupStudentsScreen({super.key, required this.group});

  final SchoolGroupModel group;

  @override
  State<GroupStudentsScreen> createState() => _GroupStudentsScreenState();
}

class _GroupStudentsScreenState extends State<GroupStudentsScreen> {
  late final DirectoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DirectoryController(
      repository: FirestoreDirectoryRepository(),
    );
    _controller.addListener(_onControllerChanged);
    _controller.loadStudentsByGroup(widget.group.id);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupColor = _colorFromHex(widget.group.colorHex);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        backgroundColor: groupColor,
        foregroundColor: Colors.white,
      ),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.directory,
        child: RefreshIndicator(
          onRefresh: () => _controller.loadStudentsByGroup(widget.group.id),
          child: _DirectoryBody(
            isLoading: _controller.isLoading,
            errorMessage: _controller.errorMessage,
            isEmpty: _controller.students.isEmpty,
            emptyMessage: 'No hay estudiantes registrados en este grupo',
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _controller.students.length,
              itemBuilder: (context, index) {
                final student = _controller.students[index];
                return _StudentCard(
                  student: student,
                  group: widget.group,
                  onTap: () => _showStudentDetails(context, student),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentDetails(BuildContext context, StudentModel student) {
    final studentInfo = {
      'Fecha nacimiento': _formatDate(student.birthDate) ?? 'No registrada',
      'Tutor': _blankAsFallback(student.tutorName, 'No registrado'),
      'Contacto': _blankAsFallback(student.tutorPhone, 'No disponible'),
      'Alergias': _blankAsFallback(student.allergies, 'Ninguna registrada'),
      'Estado': student.displayStatus,
      'Fecha inscripción':
          _formatDate(student.enrollmentDate) ?? 'No registrada',
      'Observaciones': _blankAsFallback(student.notes, 'Sin observaciones'),
    };

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _colorFromHex(widget.group.colorHex),
                          child: Text(
                            _initials(student.fullName),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.group.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              studentInfo.entries
                                  .map(
                                    (entry) => _DetailRow(
                                      label: entry.key,
                                      value: entry.value,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: _colorFromHex(widget.group.colorHex),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.subtitle,
    required this.onTap,
  });

  final SchoolGroupModel group;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final groupColor = _colorFromHex(group.colorHex);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: groupColor,
          child: Text(
            group.initials,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(AppIcons.chevronRight),
        onTap: onTap,
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.group,
    required this.onTap,
  });

  final StudentModel student;
  final SchoolGroupModel group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final groupColor = _colorFromHex(group.colorHex);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: groupColor.withValues(alpha: 0.75),
          child: Text(
            _initials(student.fullName),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(student.displayStatus),
        trailing: const Icon(AppIcons.chevronRight),
        onTap: onTap,
      ),
    );
  }
}

class _DirectoryBody extends StatelessWidget {
  const _DirectoryBody({
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.emptyMessage,
    required this.child,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final String emptyMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const ModuleLoadingSkeleton(layout: AppSkeletonLayout.directory);
    }

    if (errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Text(errorMessage!, textAlign: TextAlign.center)),
        ],
      );
    }

    if (isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [Center(child: Text(emptyMessage))],
      );
    }

    return child;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

Color _colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? const Color(0xFF607D8B) : Color(parsed);
}

String _initials(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isNotEmpty && parts.first.isNotEmpty) {
    return parts.first[0].toUpperCase();
  }
  return '?';
}

String? _formatDate(DateTime? date) {
  if (date == null) return null;
  return DateFormat('dd/MM/yyyy').format(date);
}

String _blankAsFallback(String? value, String fallback) {
  if (value == null || value.trim().isEmpty) return fallback;
  return value;
}
