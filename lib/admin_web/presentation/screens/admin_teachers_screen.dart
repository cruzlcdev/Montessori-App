import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/directory/data/models/school_group_model.dart';
import '../../../features/directory/data/models/teacher_model.dart';
import '../../data/admin_teachers_repository.dart';
import '../widgets/admin_form_controls.dart';
import '../widgets/admin_segmented_filter.dart';
import '../widgets/admin_feedback.dart';

void _showTeachersToast(
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

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  final _repository = AdminTeachersRepository();
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

          return StreamBuilder<List<TeacherModel>>(
            stream: _repository.watchTeachers(),
            builder: (context, teachersSnapshot) {
              final teachers = teachersSnapshot.data ?? const <TeacherModel>[];
              final visibleTeachers = _filterTeachers(teachers);
              final activeCount =
                  teachers
                      .where((teacher) => teacher.status == 'active')
                      .length;
              final inactiveCount =
                  teachers
                      .where((teacher) => teacher.status != 'active')
                      .length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 30, 34, 20),
                      child: _TeachersHeader(
                        totalCount: teachers.length,
                        activeCount: activeCount,
                        inactiveCount: inactiveCount,
                        onCreate: () => _openForm(groups: groups),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
                      child: _TeachersToolbar(
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
                      teachersSnapshot.connectionState ==
                          ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (groups.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoGroupsForTeachersState(),
                    )
                  else if (visibleTeachers.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyTeachersState(
                        onCreate: () => _openForm(groups: groups),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 34),
                      sliver: SliverGrid.builder(
                        itemCount: visibleTeachers.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 450,
                              mainAxisExtent: 236,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemBuilder: (context, index) {
                          final teacher = visibleTeachers[index];
                          final assignedGroups = teacher.groupIds
                              .map((id) => groupsById[id])
                              .whereType<SchoolGroupModel>()
                              .toList(growable: false);
                          return _TeacherAdminCard(
                            teacher: teacher,
                            groups: assignedGroups,
                            onEdit:
                                () =>
                                    _openForm(groups: groups, teacher: teacher),
                            onToggleStatus: () => _toggleStatus(teacher),
                            onDelete: () => _confirmDelete(teacher),
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

  List<TeacherModel> _filterTeachers(List<TeacherModel> teachers) {
    final normalizedQuery = _query.trim().toLowerCase();
    return teachers
        .where((teacher) {
          final matchesStatus =
              _statusFilter == 'all' ||
              (_statusFilter == 'active' && teacher.status == 'active') ||
              (_statusFilter == 'inactive' && teacher.status != 'active');
          final matchesGroup =
              _groupFilter == 'all' || teacher.groupIds.contains(_groupFilter);
          final matchesQuery =
              normalizedQuery.isEmpty ||
              teacher.fullName.toLowerCase().contains(normalizedQuery) ||
              (teacher.email ?? '').toLowerCase().contains(normalizedQuery) ||
              (teacher.phone ?? '').toLowerCase().contains(normalizedQuery);

          return matchesStatus && matchesGroup && matchesQuery;
        })
        .toList(growable: false);
  }

  Future<void> _openForm({
    required List<SchoolGroupModel> groups,
    TeacherModel? teacher,
  }) async {
    final resultMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _TeacherFormSheet(
            repository: _repository,
            groups: groups,
            teacher: teacher,
          ),
    );

    if (resultMessage != null && mounted) {
      _showTeachersToast(
        context,
        teacher == null ? 'Profesor registrado' : 'Profesor actualizado',
        message: resultMessage,
      );
    }
  }

  Future<void> _toggleStatus(TeacherModel teacher) async {
    final nextStatus = teacher.status == 'active' ? 'inactive' : 'active';
    try {
      await _repository.setTeacherStatus(teacher, nextStatus);
      if (!mounted) return;
      _showTeachersToast(
        context,
        nextStatus == 'active' ? 'Profesor activado' : 'Profesor desactivado',
        message:
            nextStatus == 'active'
                ? '${teacher.fullName} recuperó el acceso móvil y volverá a ver sus grupos asignados.'
                : '${teacher.fullName} ya no podrá ingresar a la app; sus asignaciones y registros se conservan.',
        icon:
            nextStatus == 'active'
                ? AdminIcons.checkCircleRounded
                : AdminIcons.pauseCircleRounded,
        color:
            nextStatus == 'active'
                ? AppColors.primaryGreen
                : AppColors.primaryOrange,
      );
    } catch (_) {
      if (!mounted) return;
      _showTeachersToast(
        context,
        'No se actualizó el acceso',
        message:
            'El estado de ${teacher.fullName} no cambió. Verifica la conexión e inténtalo nuevamente.',
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
    }
  }

  Future<void> _confirmDelete(TeacherModel teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AdminDeleteConfirmDialog(
            title: 'Eliminar profesor',
            itemName: teacher.fullName,
            message:
                'Se eliminará del directorio docente, se quitarán sus grupos y su acceso a la app quedará revocado. Úsala solo si fue creado por error.',
            actionLabel: 'Eliminar',
          ),
    );

    if (confirmed != true) return;
    try {
      await _repository.deleteTeacher(teacher);
      if (!mounted) return;
      _showTeachersToast(
        context,
        'Profesor eliminado',
        message:
            '${teacher.fullName} se retiró del directorio, perdió sus grupos asignados y su acceso escolar quedó revocado.',
        icon: AdminIcons.deleteOutlineRounded,
        color: AppColors.primaryRed,
      );
    } catch (_) {
      if (!mounted) return;
      _showTeachersToast(
        context,
        'No se eliminó al profesor',
        message:
            'No se aplicaron cambios a ${teacher.fullName} ni a su acceso. Inténtalo nuevamente.',
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
    }
  }
}

class _TeachersHeader extends StatelessWidget {
  const _TeachersHeader({
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
              color: AppColors.primaryTurquoise.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              AdminIcons.coPresentRounded,
              color: AppColors.primaryTurquoise,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profesores',
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
            label: Text('Nuevo profesor'),
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

class _TeachersToolbar extends StatelessWidget {
  const _TeachersToolbar({
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
                hintText: 'Buscar por nombre, correo o teléfono',
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

class _TeacherAdminCard extends StatelessWidget {
  const _TeacherAdminCard({
    required this.teacher,
    required this.groups,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final TeacherModel teacher;
  final List<SchoolGroupModel> groups;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color =
        groups.isEmpty
            ? AppColors.primaryTurquoise
            : _parseColor(groups.first.colorHex);
    final isActive = teacher.status == 'active';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: context.adminPalette.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _initials(teacher.fullName),
                  style: TextStyle(
                    color: color,
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
                      teacher.fullName,
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
                      teacher.email?.trim().isEmpty ?? true
                          ? 'Correo pendiente'
                          : teacher.email!,
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
                label: _groupLabel(groups.length),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            groups.isEmpty
                ? 'Sin grupos asignados'
                : groups.map((group) => group.name).join(' · '),
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

class _TeacherFormSheet extends StatefulWidget {
  const _TeacherFormSheet({
    required this.repository,
    required this.groups,
    this.teacher,
  });

  final AdminTeachersRepository repository;
  final List<SchoolGroupModel> groups;
  final TeacherModel? teacher;

  @override
  State<_TeacherFormSheet> createState() => _TeacherFormSheetState();
}

class _TeacherFormSheetState extends State<_TeacherFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final Set<String> _selectedGroupIds;
  late String _status;
  bool _isSaving = false;

  bool get _isEditing => widget.teacher != null;

  @override
  void initState() {
    super.initState();
    final teacher = widget.teacher;
    _nameController = TextEditingController(text: teacher?.fullName ?? '');
    _emailController = TextEditingController(text: teacher?.email ?? '');
    _phoneController = TextEditingController(text: teacher?.phone ?? '');
    _selectedGroupIds = {...?teacher?.groupIds};
    _status = teacher?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
                          color: AppColors.primaryTurquoise.withValues(
                            alpha: 0.13,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          AdminIcons.coPresentRounded,
                          color: AppColors.primaryTurquoise,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Editar profesor' : 'Nuevo profesor',
                              style: TextStyle(
                                color: context.adminPalette.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Asigna grupos y datos de contacto del docente.',
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
                    title: 'Datos del profesor',
                    subtitle:
                        'Usa el correo del usuario móvil para mantener la app sincronizada.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: _fieldDecoration(
                            context,
                            'Nombre completo',
                          ),
                          textInputAction: TextInputAction.next,
                          validator:
                              (value) =>
                                  (value?.trim().isEmpty ?? true)
                                      ? 'Ingresa el nombre.'
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration: _fieldDecoration(context, 'Correo'),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_isEditing,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Ingresa el correo del profesor.';
                            }
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)) {
                              return 'Ingresa un correo válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: _fieldDecoration(context, 'Teléfono'),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-()\s]'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AdminStatusSwitch(
                          value: _status == 'active',
                          title: 'Profesor activo',
                          activeSubtitle:
                              'Disponible para asignaciones, grupos y evaluaciones.',
                          inactiveSubtitle:
                              'No aparecerá como docente activo en los módulos.',
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
                    icon: AdminIcons.groupsRounded,
                    title: 'Grupos asignados',
                    subtitle:
                        'Selecciona los grupos donde participa el docente.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          widget.groups.map((group) {
                            final selected = _selectedGroupIds.contains(
                              group.id,
                            );
                            final color = _parseColor(group.colorHex);

                            return FilterChip(
                              selected: selected,
                              label: Text(group.name),
                              avatar: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.16),
                                child: Text(
                                  group.initials,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              selectedColor: color.withValues(alpha: 0.14),
                              checkmarkColor: color,
                              side: BorderSide(
                                color:
                                    selected
                                        ? color.withValues(alpha: 0.35)
                                        : context.adminPalette.borderStrong,
                              ),
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedGroupIds.add(group.id);
                                  } else {
                                    _selectedGroupIds.remove(group.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
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
      final teacher = widget.teacher;
      late final String resultMessage;
      if (teacher == null) {
        final result = await widget.repository.createTeacher(
          fullName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          groupIds: _selectedGroupIds.toList(),
          status: _status,
        );
        if (result.linkedExistingAccount) {
          resultMessage =
              'Profesor registrado y vinculado a su cuenta existente.';
        } else if (result.resetEmailSent) {
          resultMessage =
              'Profesor registrado. Se envió un correo para crear su contraseña.';
        } else {
          resultMessage =
              'Profesor registrado, pero no se pudo enviar el correo. Puede solicitarlo desde “¿Olvidaste tu contraseña?”.';
        }
      } else {
        await widget.repository.updateTeacher(
          teacher: teacher,
          fullName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          groupIds: _selectedGroupIds.toList(),
          status: _status,
        );
        resultMessage = 'Profesor actualizado.';
      }

      if (!mounted) return;
      Navigator.pop(context, resultMessage);
    } catch (error) {
      if (!mounted) return;
      _showTeachersToast(
        context,
        'No se pudo guardar al profesor',
        message: error.toString().replaceFirst('Bad state: ', ''),
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

class _EmptyTeachersState extends StatelessWidget {
  const _EmptyTeachersState({required this.onCreate});

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
                color: AppColors.primaryTurquoise.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                AdminIcons.coPresentRounded,
                color: AppColors.primaryTurquoise,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sin profesores registrados',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra docentes para mantener el directorio y sus grupos asignados.',
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
              label: Text('Nuevo profesor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoGroupsForTeachersState extends StatelessWidget {
  const _NoGroupsForTeachersState();

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
              'Los profesores necesitan grupos disponibles para que sus asignaciones tengan sentido en la app.',
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

String _groupLabel(int count) {
  if (count == 1) return '1 grupo';
  return '$count grupos';
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
