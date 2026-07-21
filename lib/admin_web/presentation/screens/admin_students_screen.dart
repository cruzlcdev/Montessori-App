import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/directory/data/models/school_group_model.dart';
import '../../../features/directory/data/models/student_model.dart';
import '../../data/admin_students_repository.dart';
import '../widgets/admin_form_controls.dart';
import '../widgets/admin_segmented_filter.dart';
import '../widgets/admin_feedback.dart';

void _showStudentsToast(
  BuildContext context,
  String title, {
  required String message,
  IconData icon = AdminIcons.checkCircleRounded,
  Color color = AppColors.primaryGreen,
}) {
  showAdminFeedback(
    context,
    title: title,
    message: message,
    icon: icon,
    color: color,
  );
}

class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  final _repository = AdminStudentsRepository();
  String _statusFilter = 'all';
  String _groupFilter = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<SchoolGroupModel>>(
        stream: _repository.watchGroups(),
        builder: (context, groupsSnapshot) {
          final groups = groupsSnapshot.data ?? const <SchoolGroupModel>[];
          final groupsById = {for (final group in groups) group.id: group};

          return StreamBuilder<List<StudentModel>>(
            stream: _repository.watchStudents(),
            builder: (context, studentsSnapshot) {
              final students = studentsSnapshot.data ?? const <StudentModel>[];
              final visibleStudents = _filterStudents(students);
              final activeCount =
                  students
                      .where((student) => student.status == 'active')
                      .length;
              final inactiveCount =
                  students
                      .where((student) => student.status != 'active')
                      .length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 30, 34, 20),
                      child: _StudentsHeader(
                        totalCount: students.length,
                        activeCount: activeCount,
                        inactiveCount: inactiveCount,
                        onCreate: () => _openForm(groups: groups),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
                      child: _StudentsToolbar(
                        groups: groups,
                        selectedStatus: _statusFilter,
                        selectedGroupId: _groupFilter,
                        onStatusChanged:
                            (value) => setState(() => _statusFilter = value),
                        onGroupChanged:
                            (value) => setState(() => _groupFilter = value),
                        onQueryChanged:
                            (value) => setState(() => _query = value),
                      ),
                    ),
                  ),
                  if (groupsSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      studentsSnapshot.connectionState ==
                          ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (groups.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoGroupsForStudentsState(),
                    )
                  else if (visibleStudents.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyStudentsState(
                        onCreate: () => _openForm(groups: groups),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 34),
                      sliver: SliverGrid.builder(
                        itemCount: visibleStudents.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 440,
                              mainAxisExtent: 238,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemBuilder: (context, index) {
                          final student = visibleStudents[index];
                          return _StudentAdminCard(
                            student: student,
                            group: groupsById[student.groupId],
                            onEdit:
                                () =>
                                    _openForm(groups: groups, student: student),
                            onToggleStatus: () => _toggleStatus(student),
                            onDelete: () => _confirmDelete(student),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<StudentModel> _filterStudents(List<StudentModel> students) {
    final normalizedQuery = _query.trim().toLowerCase();
    return students
        .where((student) {
          final matchesStatus =
              _statusFilter == 'all' ||
              (_statusFilter == 'active' && student.status == 'active') ||
              (_statusFilter == 'inactive' && student.status != 'active');
          final matchesGroup =
              _groupFilter == 'all' || student.groupId == _groupFilter;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              student.fullName.toLowerCase().contains(normalizedQuery) ||
              student.firstName.toLowerCase().contains(normalizedQuery) ||
              student.lastName.toLowerCase().contains(normalizedQuery) ||
              (student.tutorName ?? '').toLowerCase().contains(normalizedQuery);

          return matchesStatus && matchesGroup && matchesQuery;
        })
        .toList(growable: false);
  }

  Future<void> _openForm({
    required List<SchoolGroupModel> groups,
    StudentModel? student,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _StudentFormSheet(
            repository: _repository,
            groups: groups,
            student: student,
          ),
    );

    if (saved == true && mounted) {
      _showStudentsToast(
        context,
        student == null ? 'Alumno registrado' : 'Alumno actualizado',
        message:
            student == null
                ? 'El alumno quedó vinculado a su grupo y ya puede consultarse desde los módulos escolares.'
                : 'Sus datos, grupo y estado quedaron guardados y sincronizados con la app.',
      );
    }
  }

  Future<void> _toggleStatus(StudentModel student) async {
    final nextStatus = student.status == 'active' ? 'inactive' : 'active';
    await _repository.setStudentStatus(student, nextStatus);
    if (!mounted) return;
    _showStudentsToast(
      context,
      nextStatus == 'active' ? 'Alumno activado' : 'Alumno desactivado',
      message:
          nextStatus == 'active'
              ? '${student.fullName} volverá a aparecer en su grupo y módulos académicos.'
              : '${student.fullName} dejará de aparecer para nuevas evaluaciones; su historial se conserva.',
      icon:
          nextStatus == 'active'
              ? AdminIcons.checkCircleRounded
              : AdminIcons.pauseCircleRounded,
      color:
          nextStatus == 'active'
              ? AppColors.primaryGreen
              : AppColors.primaryOrange,
    );
  }

  Future<void> _confirmDelete(StudentModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AdminDeleteConfirmDialog(
            title: 'Eliminar alumno',
            itemName: student.fullName,
            message:
                'Esta acción puede afectar boletas, estadísticas y cuentas familiares vinculadas. Úsala solo si el alumno fue creado por error.',
            actionLabel: 'Eliminar',
          ),
    );

    if (confirmed != true) return;
    await _repository.deleteStudent(student);
    if (!mounted) return;
    _showStudentsToast(
      context,
      'Alumno eliminado',
      message:
          '${student.fullName} se retiró del directorio. Revisa boletas y cuentas familiares que pudieran estar vinculadas.',
      icon: AdminIcons.deleteOutlineRounded,
      color: AppColors.primaryRed,
    );
  }
}

class _StudentsHeader extends StatelessWidget {
  const _StudentsHeader({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.onCreate,
  });

  final int totalCount;
  final int activeCount;
  final int inactiveCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.adminPalette.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              AdminIcons.schoolRounded,
              color: AppColors.primaryOrange,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alumnos',
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$activeCount activos · $inactiveCount inactivos · $totalCount registrados',
                  style: TextStyle(
                    color: context.adminPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onCreate,
            icon: Icon(AdminIcons.personAddAlt1Rounded),
            label: Text('Nuevo alumno'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsToolbar extends StatelessWidget {
  const _StudentsToolbar({
    required this.groups,
    required this.selectedStatus,
    required this.selectedGroupId,
    required this.onStatusChanged,
    required this.onGroupChanged,
    required this.onQueryChanged,
  });

  final List<SchoolGroupModel> groups;
  final String selectedStatus;
  final String selectedGroupId;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.adminPalette.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o tutor',
                prefixIcon: Icon(AdminIcons.searchRounded),
                filled: true,
                fillColor: context.adminPalette.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 250,
            child: AdminGroupSelectField(
              groups: groups,
              selectedGroupId: selectedGroupId,
              includeAllOption: true,
              onChanged: onGroupChanged,
            ),
          ),
          const SizedBox(width: 14),
          AdminSegmentedFilter<String>(
            options: const [
              AdminSegmentedOption(value: 'all', label: 'Todos'),
              AdminSegmentedOption(value: 'active', label: 'Activos'),
              AdminSegmentedOption(value: 'inactive', label: 'Inactivos'),
            ],
            selected: selectedStatus,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _StudentAdminCard extends StatelessWidget {
  const _StudentAdminCard({
    required this.student,
    required this.group,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final StudentModel student;
  final SchoolGroupModel? group;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final groupColor = _parseColor(group?.colorHex ?? '#0073DB');
    final isActive = student.status == 'active';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: context.adminPalette.border),
        boxShadow: [
          BoxShadow(
            color: groupColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _initials(student.fullName),
                  style: TextStyle(
                    color: groupColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      group?.name ?? 'Grupo no asignado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adminPalette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallPill(
                icon:
                    isActive
                        ? AdminIcons.checkCircleRounded
                        : AdminIcons.pauseCircleRounded,
                label: isActive ? 'Activo' : 'Inactivo',
                color:
                    isActive ? AppColors.primaryGreen : AppColors.primaryOrange,
              ),
              _SmallPill(
                icon: AdminIcons.groupsRounded,
                label:
                    group?.level.trim().isEmpty ?? true
                        ? 'Sin nivel'
                        : group!.level,
                color: groupColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            student.tutorName?.trim().isEmpty ?? true
                ? 'Tutor pendiente de registrar'
                : 'Tutor: ${student.tutorName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.adminPalette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _IconAction(
                tooltip: 'Editar',
                icon: AdminIcons.editRounded,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _IconAction(
                tooltip: isActive ? 'Desactivar' : 'Activar',
                icon:
                    isActive
                        ? AdminIcons.pauseCircleOutlineRounded
                        : AdminIcons.playCircleOutlineRounded,
                color:
                    isActive ? AppColors.primaryOrange : AppColors.primaryGreen,
                onTap: onToggleStatus,
              ),
              const Spacer(),
              _IconAction(
                tooltip: 'Eliminar',
                icon: AdminIcons.deleteOutlineRounded,
                color: AppColors.primaryRed,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentFormSheet extends StatefulWidget {
  const _StudentFormSheet({
    required this.repository,
    required this.groups,
    this.student,
  });

  final AdminStudentsRepository repository;
  final List<SchoolGroupModel> groups;
  final StudentModel? student;

  @override
  State<_StudentFormSheet> createState() => _StudentFormSheetState();
}

class _StudentFormSheetState extends State<_StudentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _tutorNameController;
  late final TextEditingController _tutorPhoneController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _notesController;
  late String _groupId;
  late String _status;
  bool _isSaving = false;

  bool get _isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _firstNameController = TextEditingController(
      text: student?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: student?.lastName ?? '');
    _tutorNameController = TextEditingController(
      text: student?.tutorName ?? '',
    );
    _tutorPhoneController = TextEditingController(
      text: student?.tutorPhone ?? '',
    );
    _allergiesController = TextEditingController(
      text: student?.allergies ?? '',
    );
    _notesController = TextEditingController(text: student?.notes ?? '');
    _groupId =
        widget.groups.any((group) => group.id == student?.groupId)
            ? student!.groupId
            : widget.groups.first.id;
    _status = student?.status ?? 'active';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _tutorNameController.dispose();
    _tutorPhoneController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 620,
        height: MediaQuery.sizeOf(context).height,
        decoration: BoxDecoration(
          color: context.adminPalette.surface,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(
                            alpha: 0.13,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          AdminIcons.schoolRounded,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Editar alumno' : 'Nuevo alumno',
                              style: TextStyle(
                                color: context.adminPalette.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Registra los datos base que usa la app móvil.',
                              style: TextStyle(
                                color: context.adminPalette.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                        icon: Icon(AdminIcons.closeRounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _FormBlock(
                    icon: AdminIcons.badgeRounded,
                    title: 'Datos del alumno',
                    subtitle: 'Nombre, grupo y estado dentro de la escuela.',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                decoration: _fieldDecoration(
                                  context,
                                  'Nombre(s)',
                                ),
                                textInputAction: TextInputAction.next,
                                validator:
                                    (value) =>
                                        (value?.trim().isEmpty ?? true)
                                            ? 'Ingresa el nombre.'
                                            : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: _fieldDecoration(
                                  context,
                                  'Apellidos',
                                ),
                                textInputAction: TextInputAction.next,
                                validator:
                                    (value) =>
                                        (value?.trim().isEmpty ?? true)
                                            ? 'Ingresa los apellidos.'
                                            : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AdminGroupSelectField(
                          groups: widget.groups,
                          selectedGroupId: _groupId,
                          onChanged:
                              (value) => setState(() => _groupId = value),
                        ),
                        const SizedBox(height: 14),
                        AdminStatusSwitch(
                          value: _status == 'active',
                          title: 'Alumno activo',
                          activeSubtitle:
                              'Disponible para boletas, evaluaciones y seguimiento familiar.',
                          inactiveSubtitle:
                              'No aparecerá en consultas activas de la app.',
                          onChanged:
                              (value) => setState(
                                () => _status = value ? 'active' : 'inactive',
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormBlock(
                    icon: AdminIcons.familyRestroomRounded,
                    title: 'Contacto familiar',
                    subtitle:
                        'Datos de referencia visibles para control interno.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _tutorNameController,
                          decoration: _fieldDecoration(
                            context,
                            'Tutor o responsable',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tutorPhoneController,
                          decoration: _fieldDecoration(context, 'Teléfono'),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-()\s]'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormBlock(
                    icon: AdminIcons.noteAltRounded,
                    title: 'Notas internas',
                    subtitle: 'Observaciones útiles para seguimiento escolar.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _allergiesController,
                          decoration: _fieldDecoration(
                            context,
                            'Alergias o cuidados',
                          ),
                          minLines: 2,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          decoration: _fieldDecoration(context, 'Notas'),
                          minLines: 3,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child:
                              _isSaving
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(_isEditing ? 'Guardar' : 'Registrar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      final student = widget.student;
      if (student == null) {
        await widget.repository.createStudent(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          groupId: _groupId,
          status: _status,
          tutorName: _tutorNameController.text,
          tutorPhone: _tutorPhoneController.text,
          allergies: _allergiesController.text,
          notes: _notesController.text,
        );
      } else {
        await widget.repository.updateStudent(
          student: student,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          groupId: _groupId,
          status: _status,
          tutorName: _tutorNameController.text,
          tutorPhone: _tutorPhoneController.text,
          allergies: _allergiesController.text,
          notes: _notesController.text,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showStudentsToast(
        context,
        'No se pudo guardar al alumno',
        message: _studentSaveErrorMessage(error),
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _studentSaveErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('permission-denied')) {
      return 'No fue posible registrar al alumno porque Firebase rechazó los datos. Revisa las reglas publicadas e inténtalo nuevamente.';
    }
    if (message.contains('network-request-failed') ||
        message.contains('unavailable')) {
      return 'No se pudo conectar con Firebase. Revisa tu conexión e inténtalo nuevamente.';
    }
    return 'No fue posible guardar al alumno. Inténtalo nuevamente.';
  }
}

class _FormBlock extends StatelessWidget {
  const _FormBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.adminPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.adminPalette.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.adminPalette.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primaryBlue,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _EmptyStudentsState extends StatelessWidget {
  const _EmptyStudentsState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.adminPalette.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.adminPalette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                AdminIcons.schoolRounded,
                color: AppColors.primaryOrange,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sin alumnos registrados',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra el primer alumno y asígnalo a su grupo para que aparezca en la app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.adminPalette.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: Icon(AdminIcons.personAddAlt1Rounded),
              label: Text('Nuevo alumno'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoGroupsForStudentsState extends StatelessWidget {
  const _NoGroupsForStudentsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.adminPalette.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.adminPalette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AdminIcons.groups2Rounded,
              color: AppColors.primaryBlue,
              size: 42,
            ),
            SizedBox(height: 16),
            Text(
              'Primero crea un grupo',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Los alumnos necesitan un grupo asignado para mostrarse correctamente en boletas, evaluaciones y estadísticas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.adminPalette.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: context.adminPalette.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.adminPalette.borderStrong),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.adminPalette.borderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  );
}

String _initials(String name) {
  final parts =
      name
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

Color _parseColor(String value) {
  final cleanValue = value.replaceFirst('#', '').trim();
  if (cleanValue.length != 6) return AppColors.primaryBlue;
  return Color(int.parse('FF$cleanValue', radix: 16));
}
