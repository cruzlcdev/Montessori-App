import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/directory/data/models/school_group_model.dart';
import '../../../features/directory/data/models/student_model.dart';
import '../../data/admin_families_repository.dart';
import '../../data/models/family_account_model.dart';
import '../widgets/admin_form_controls.dart';
import '../widgets/admin_segmented_filter.dart';
import '../widgets/admin_feedback.dart';

class AdminFamiliesScreen extends StatefulWidget {
  const AdminFamiliesScreen({super.key});

  @override
  State<AdminFamiliesScreen> createState() => _AdminFamiliesScreenState();
}

class _AdminFamiliesScreenState extends State<AdminFamiliesScreen> {
  final _repository = AdminFamiliesRepository();
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
              final studentsById = {
                for (final student in students) student.id: student,
              };

              return StreamBuilder<List<FamilyAccountModel>>(
                stream: _repository.watchFamilies(),
                builder: (context, familiesSnapshot) {
                  final families =
                      familiesSnapshot.data ?? const <FamilyAccountModel>[];
                  final visibleFamilies = _filterFamilies(families);
                  final activeCount =
                      families.where((family) => family.isActive).length;
                  final inactiveCount = families.length - activeCount;
                  final loading =
                      groupsSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      studentsSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      familiesSnapshot.connectionState ==
                          ConnectionState.waiting;

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(34, 30, 34, 20),
                          child: _FamiliesHeader(
                            totalCount: families.length,
                            activeCount: activeCount,
                            inactiveCount: inactiveCount,
                            onCreate:
                                () => _openForm(
                                  students: students,
                                  groupsById: groupsById,
                                ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
                          child: _FamiliesToolbar(
                            groups: groups,
                            selectedStatus: _statusFilter,
                            selectedGroupId: _groupFilter,
                            onStatusChanged:
                                (value) =>
                                    setState(() => _statusFilter = value),
                            onGroupChanged:
                                (value) => setState(() => _groupFilter = value),
                            onQueryChanged:
                                (value) => setState(() => _query = value),
                          ),
                        ),
                      ),
                      if (loading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (students.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _NoStudentsForFamiliesState(),
                        )
                      else if (visibleFamilies.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyFamiliesState(
                            onCreate:
                                () => _openForm(
                                  students: students,
                                  groupsById: groupsById,
                                ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(34, 0, 34, 34),
                          sliver: SliverGrid.builder(
                            itemCount: visibleFamilies.length,
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 470,
                                  mainAxisExtent: 286,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemBuilder: (context, index) {
                              final family = visibleFamilies[index];
                              final linkedStudents = family.studentIds
                                  .map((id) => studentsById[id])
                                  .whereType<StudentModel>()
                                  .toList(growable: false);
                              return _FamilyAdminCard(
                                family: family,
                                students: linkedStudents,
                                onEdit:
                                    () => _openForm(
                                      students: students,
                                      groupsById: groupsById,
                                      family: family,
                                    ),
                                onResend: () => _resendInvitation(family),
                                onToggleStatus: () => _toggleStatus(family),
                                onDelete: () => _confirmDelete(family),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<FamilyAccountModel> _filterFamilies(List<FamilyAccountModel> families) {
    final normalizedQuery = _query.trim().toLowerCase();
    return families
        .where((family) {
          final matchesStatus =
              _statusFilter == 'all' ||
              (_statusFilter == 'active' && family.isActive) ||
              (_statusFilter == 'inactive' && !family.isActive);
          final matchesGroup =
              _groupFilter == 'all' || family.groupIds.contains(_groupFilter);
          final matchesQuery =
              normalizedQuery.isEmpty ||
              family.fullName.toLowerCase().contains(normalizedQuery) ||
              family.email.toLowerCase().contains(normalizedQuery) ||
              (family.phone ?? '').toLowerCase().contains(normalizedQuery);
          return matchesStatus && matchesGroup && matchesQuery;
        })
        .toList(growable: false);
  }

  Future<void> _openForm({
    required List<StudentModel> students,
    required Map<String, SchoolGroupModel> groupsById,
    FamilyAccountModel? family,
  }) async {
    final resultMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _FamilyFormSheet(
            repository: _repository,
            students: students,
            groupsById: groupsById,
            family: family,
          ),
    );
    if (resultMessage != null && mounted) {
      _showFamiliesToast(
        context,
        family == null ? 'Acceso familiar registrado' : 'Familia actualizada',
        message: resultMessage,
      );
    }
  }

  Future<void> _resendInvitation(FamilyAccountModel family) async {
    try {
      await _repository.resendInvitation(family);
      if (!mounted) return;
      _showFamiliesToast(
        context,
        'Invitación enviada',
        message:
            'Se envió un nuevo correo a ${family.email} para que configure o recupere su contraseña.',
        icon: AdminIcons.markEmailReadRounded,
        color: AppColors.primaryBlue,
      );
    } catch (_) {
      if (!mounted) return;
      _showFamiliesToast(
        context,
        'No se envió la invitación',
        message:
            'El correo no pudo enviarse. Verifica la dirección registrada, la conexión y vuelve a intentarlo.',
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
    }
  }

  Future<void> _toggleStatus(FamilyAccountModel family) async {
    final nextStatus = family.isActive ? 'inactive' : 'active';
    try {
      await _repository.setFamilyStatus(family, nextStatus);
      if (!mounted) return;
      _showFamiliesToast(
        context,
        nextStatus == 'active' ? 'Acceso restaurado' : 'Acceso suspendido',
        message:
            nextStatus == 'active'
                ? '${family.fullName} podrá ingresar nuevamente y consultar a sus hijos vinculados.'
                : '${family.fullName} ya no podrá ingresar a la app; sus vínculos familiares se conservan.',
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
      _showFamiliesToast(
        context,
        'No se actualizó el acceso',
        message:
            'El estado de ${family.fullName} no cambió. Verifica la conexión e inténtalo nuevamente.',
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
    }
  }

  Future<void> _confirmDelete(FamilyAccountModel family) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AdminDeleteConfirmDialog(
            title: 'Eliminar acceso familiar',
            itemName: family.fullName,
            message:
                'Se quitarán sus alumnos vinculados y su acceso a la app quedará revocado. Los registros académicos de los alumnos no se eliminarán.',
            actionLabel: 'Eliminar acceso',
          ),
    );
    if (confirmed != true) return;

    try {
      await _repository.archiveFamily(family);
      if (!mounted) return;
      _showFamiliesToast(
        context,
        'Acceso familiar eliminado',
        message:
            '${family.fullName} perdió el acceso a la app y se retiraron sus alumnos vinculados.',
        icon: AdminIcons.deleteOutlineRounded,
        color: AppColors.primaryRed,
      );
    } catch (_) {
      if (!mounted) return;
      _showFamiliesToast(
        context,
        'No se eliminó el acceso',
        message:
            'No se aplicaron cambios a ${family.fullName} ni a sus alumnos vinculados.',
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
    }
  }
}

class _FamiliesHeader extends StatelessWidget {
  const _FamiliesHeader({
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
      decoration: _panelDecoration(context, AppColors.primaryGreen),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              AdminIcons.familyRestroomRounded,
              color: AppColors.primaryGreen,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Familias y accesos',
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
            label: Text('Invitar familiar'),
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

class _FamiliesToolbar extends StatelessWidget {
  const _FamiliesToolbar({
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

class _FamilyAdminCard extends StatelessWidget {
  const _FamilyAdminCard({
    required this.family,
    required this.students,
    required this.onEdit,
    required this.onResend,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final FamilyAccountModel family;
  final List<StudentModel> students;
  final VoidCallback onEdit;
  final VoidCallback onResend;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primaryGreen;
    final invitationDate = family.invitationSentAt;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context, color),
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
                  _initials(family.fullName),
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
                      family.fullName.isEmpty
                          ? 'Familiar sin nombre'
                          : family.fullName,
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
                      family.email,
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FamilyPill(
                icon:
                    family.isActive
                        ? AdminIcons.checkCircleRounded
                        : AdminIcons.pauseCircleRounded,
                label: family.isActive ? 'Activo' : 'Inactivo',
                color:
                    family.isActive
                        ? AppColors.primaryGreen
                        : AppColors.primaryOrange,
              ),
              _FamilyPill(
                icon: AdminIcons.schoolRounded,
                label: _studentCountLabel(students.length),
                color: AppColors.primaryBlue,
              ),
              _FamilyPill(
                icon: AdminIcons.familyRestroomRounded,
                label: _relationshipLabel(family.relationship),
                color: AppColors.primaryTurquoise,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            students.isEmpty
                ? 'Sin alumnos vinculados'
                : students.map((student) => student.fullName).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.adminPalette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (invitationDate != null) ...[
            const SizedBox(height: 6),
            Text(
              'Última invitación: ${DateFormat('d MMM y', 'es_MX').format(invitationDate)}',
              style: TextStyle(
                color: context.adminPalette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              _FamilyAction(
                tooltip: 'Editar vínculos',
                icon: AdminIcons.editRounded,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _FamilyAction(
                tooltip: 'Reenviar invitación',
                icon: AdminIcons.markEmailUnreadRounded,
                color: AppColors.primaryTurquoise,
                onTap: onResend,
              ),
              const SizedBox(width: 8),
              _FamilyAction(
                tooltip:
                    family.isActive ? 'Suspender acceso' : 'Activar acceso',
                icon:
                    family.isActive
                        ? AdminIcons.pauseCircleOutlineRounded
                        : AdminIcons.playCircleOutlineRounded,
                color:
                    family.isActive
                        ? AppColors.primaryOrange
                        : AppColors.primaryGreen,
                onTap: onToggleStatus,
              ),
              const Spacer(),
              _FamilyAction(
                tooltip: 'Eliminar acceso',
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

class _FamilyFormSheet extends StatefulWidget {
  const _FamilyFormSheet({
    required this.repository,
    required this.students,
    required this.groupsById,
    this.family,
  });

  final AdminFamiliesRepository repository;
  final List<StudentModel> students;
  final Map<String, SchoolGroupModel> groupsById;
  final FamilyAccountModel? family;

  @override
  State<_FamilyFormSheet> createState() => _FamilyFormSheetState();
}

class _FamilyFormSheetState extends State<_FamilyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _studentSearchController;
  late final Set<String> _selectedStudentIds;
  late String _relationship;
  late String _status;
  String _studentQuery = '';
  bool _isSaving = false;

  bool get _isEditing => widget.family != null;

  @override
  void initState() {
    super.initState();
    final family = widget.family;
    _nameController = TextEditingController(text: family?.fullName ?? '');
    _emailController = TextEditingController(text: family?.email ?? '');
    _phoneController = TextEditingController(text: family?.phone ?? '');
    _studentSearchController = TextEditingController();
    _selectedStudentIds = {...?family?.studentIds};
    _relationship = family?.relationship ?? 'guardian';
    _status = family?.status == 'inactive' ? 'inactive' : 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleStudents = _visibleStudents();
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 650,
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
                  _buildFormHeader(),
                  const SizedBox(height: 26),
                  _FamilyFormBlock(
                    icon: AdminIcons.contactMailRounded,
                    title: 'Datos del familiar',
                    subtitle:
                        'El correo será su acceso y la contraseña la creará desde la invitación.',
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
                                      ? 'Ingresa el nombre del familiar.'
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isEditing,
                          decoration: _fieldDecoration(
                            context,
                            'Correo electrónico',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Ingresa el correo.';
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)) {
                              return 'Ingresa un correo válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: _fieldDecoration(
                                  context,
                                  'Teléfono (opcional)',
                                ),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9+\-()\s]'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _RelationshipSelectField(
                                value: _relationship,
                                onChanged:
                                    (value) =>
                                        setState(() => _relationship = value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AdminStatusSwitch(
                          value: _status == 'active',
                          title: 'Acceso familiar activo',
                          activeSubtitle:
                              'Podrá consultar la información de sus hijos vinculados.',
                          inactiveSubtitle:
                              'La cuenta conservará sus vínculos, pero no podrá entrar a la app.',
                          onChanged:
                              (value) => setState(
                                () => _status = value ? 'active' : 'inactive',
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FamilyFormBlock(
                    icon: AdminIcons.schoolRounded,
                    title: 'Hijos vinculados',
                    subtitle:
                        'Selecciona únicamente los alumnos que este familiar puede consultar.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _studentSearchController,
                          decoration: _fieldDecoration(
                            context,
                            'Buscar alumno o grupo',
                            prefixIcon: AdminIcons.searchRounded,
                          ).copyWith(
                            suffixIcon:
                                _studentQuery.isEmpty
                                    ? null
                                    : IconButton(
                                      tooltip: 'Limpiar búsqueda',
                                      onPressed: _clearStudentSearch,
                                      icon: Icon(AdminIcons.closeRounded),
                                    ),
                          ),
                          onChanged:
                              (value) => setState(() => _studentQuery = value),
                        ),
                        if (_studentQuery.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _StudentSuggestions(
                            students: visibleStudents.take(5).toList(),
                            groupsById: widget.groupsById,
                            selectedStudentIds: _selectedStudentIds,
                            onSelected: _selectSuggestion,
                          ),
                        ],
                        if (_studentQuery.trim().isEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 270),
                            decoration: BoxDecoration(
                              color: context.adminPalette.surfaceElevated,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color:
                                    _selectedStudentIds.isEmpty
                                        ? AppColors.primaryOrange.withValues(
                                          alpha: 0.45,
                                        )
                                        : context.adminPalette.borderStrong,
                              ),
                            ),
                            child:
                                visibleStudents.isEmpty
                                    ? Padding(
                                      padding: EdgeInsets.all(22),
                                      child: Center(
                                        child: Text(
                                          'No hay alumnos disponibles.',
                                          style: TextStyle(
                                            color:
                                                context
                                                    .adminPalette
                                                    .textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                    : ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      shrinkWrap: true,
                                      itemCount: visibleStudents.length,
                                      separatorBuilder:
                                          (_, _) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final student = visibleStudents[index];
                                        return _StudentLinkTile(
                                          student: student,
                                          group:
                                              widget.groupsById[student
                                                  .groupId],
                                          selected: _selectedStudentIds
                                              .contains(student.id),
                                          onChanged:
                                              (selected) => setState(() {
                                                if (selected) {
                                                  _selectedStudentIds.add(
                                                    student.id,
                                                  );
                                                } else {
                                                  _selectedStudentIds.remove(
                                                    student.id,
                                                  );
                                                }
                                              }),
                                        );
                                      },
                                    ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _LinkedStudentsSummary(
                          count: _selectedStudentIds.length,
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
                                  : Text(
                                    _isEditing
                                        ? 'Guardar cambios'
                                        : 'Crear e invitar',
                                  ),
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

  Widget _buildFormHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            AdminIcons.familyRestroomRounded,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Editar familia' : 'Invitar familiar',
                style: TextStyle(
                  color: context.adminPalette.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Gestiona el acceso sin compartir contraseñas ni datos técnicos.',
                style: TextStyle(
                  color: context.adminPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          icon: Icon(AdminIcons.closeRounded),
        ),
      ],
    );
  }

  List<StudentModel> _visibleStudents() {
    final query = _studentQuery.trim().toLowerCase();
    return widget.students
        .where((student) {
          final isSelectable =
              student.status == 'active' ||
              _selectedStudentIds.contains(student.id);
          if (!isSelectable) return false;
          final groupName =
              widget.groupsById[student.groupId]?.name.toLowerCase() ?? '';
          return query.isEmpty ||
              student.fullName.toLowerCase().contains(query) ||
              groupName.contains(query);
        })
        .toList(growable: false);
  }

  void _clearStudentSearch() {
    _studentSearchController.clear();
    setState(() => _studentQuery = '');
  }

  void _selectSuggestion(StudentModel student) {
    _selectedStudentIds.add(student.id);
    _studentSearchController.clear();
    setState(() => _studentQuery = '');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedStudentIds.isEmpty) {
      _showFamiliesToast(
        context,
        'Falta vincular un alumno',
        message:
            'Selecciona al menos un alumno antes de guardar esta cuenta familiar.',
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryOrange,
      );
      return;
    }
    setState(() => _isSaving = true);

    try {
      final family = widget.family;
      late final String resultMessage;
      if (family == null) {
        final result = await widget.repository.createFamily(
          fullName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          relationship: _relationship,
          studentIds: _selectedStudentIds.toList(),
          status: _status,
        );
        if (result.linkedExistingAccount) {
          resultMessage =
              'Familia vinculada a su cuenta existente y alumnos actualizados.';
        } else if (result.resetEmailSent) {
          resultMessage =
              'Familia registrada. Se envió el correo para crear su contraseña.';
        } else {
          resultMessage =
              'Familia registrada, pero el correo no pudo enviarse. Usa Reenviar invitación.';
        }
      } else {
        await widget.repository.updateFamily(
          family: family,
          fullName: _nameController.text,
          phone: _phoneController.text,
          relationship: _relationship,
          studentIds: _selectedStudentIds.toList(),
          status: _status,
        );
        resultMessage = 'Familia y alumnos vinculados actualizados.';
      }

      if (!mounted) return;
      Navigator.pop(context, resultMessage);
    } catch (error) {
      if (!mounted) return;
      _showFamiliesToast(
        context,
        'No se pudo guardar la familia',
        message: error.toString().replaceFirst('Bad state: ', ''),
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _RelationshipSelectField extends StatelessWidget {
  const _RelationshipSelectField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _relationshipOption(value);
    return PopupMenuButton<String>(
      tooltip: 'Seleccionar parentesco',
      color: context.adminPalette.surfaceElevated,
      elevation: 18,
      offset: const Offset(0, 10),
      constraints: const BoxConstraints(minWidth: 285, maxWidth: 340),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      onSelected: onChanged,
      itemBuilder:
          (context) => [
            PopupMenuItem<String>(
              enabled: false,
              height: 42,
              child: Text(
                'Parentesco con el alumno',
                style: TextStyle(
                  color: context.adminPalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ..._relationshipOptions.map(
              (option) => PopupMenuItem<String>(
                value: option.value,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _RelationshipMenuOption(
                  option: option,
                  selected: option.value == value,
                ),
              ),
            ),
          ],
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected.color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected.color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(selected.icon, color: selected.color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parentesco',
                    style: TextStyle(
                      color: context.adminPalette.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    selected.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.adminPalette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AdminIcons.keyboardArrowDownRounded,
              color: context.adminPalette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipMenuOption extends StatelessWidget {
  const _RelationshipMenuOption({required this.option, required this.selected});

  final _RelationshipOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color:
            selected
                ? option.color.withValues(alpha: 0.10)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: option.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(option.icon, color: option.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              option.label,
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          if (selected)
            Icon(AdminIcons.checkCircleRounded, color: option.color, size: 20),
        ],
      ),
    );
  }
}

class _StudentSuggestions extends StatelessWidget {
  const _StudentSuggestions({
    required this.students,
    required this.groupsById,
    required this.selectedStudentIds,
    required this.onSelected,
  });

  final List<StudentModel> students;
  final Map<String, SchoolGroupModel> groupsById;
  final Set<String> selectedStudentIds;
  final ValueChanged<StudentModel> onSelected;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryOrange.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          'No encontramos alumnos con esa búsqueda.',
          style: TextStyle(
            color: context.adminPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.adminPalette.borderStrong),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Text(
              'Sugerencias',
              style: TextStyle(
                color: context.adminPalette.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...students.map((student) {
            final group = groupsById[student.groupId];
            final selected = selectedStudentIds.contains(student.id);
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: selected ? null : () => onSelected(student),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AdminIcons.personRounded,
                        color: AppColors.primaryBlue,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            group?.name ?? 'Grupo no disponible',
                            style: TextStyle(
                              color: context.adminPalette.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (selected
                                ? AppColors.primaryGreen
                                : AppColors.primaryBlue)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        selected ? 'Vinculado' : 'Agregar',
                        style: TextStyle(
                          color:
                              selected
                                  ? AppColors.primaryGreen
                                  : AppColors.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LinkedStudentsSummary extends StatelessWidget {
  const _LinkedStudentsSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final hasSelection = count > 0;
    final color =
        hasSelection ? AppColors.primaryGreen : AppColors.primaryOrange;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              hasSelection
                  ? AdminIcons.familyRestroomRounded
                  : AdminIcons.infoOutlineRounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasSelection
                  ? _studentCountLabel(count)
                  : 'Selecciona al menos un alumno.',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (hasSelection)
            Icon(AdminIcons.checkCircleRounded, color: color, size: 20),
        ],
      ),
    );
  }
}

class _StudentLinkTile extends StatelessWidget {
  const _StudentLinkTile({
    required this.student,
    required this.group,
    required this.selected,
    required this.onChanged,
  });

  final StudentModel student;
  final SchoolGroupModel? group;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(group?.colorHex ?? '');
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primaryBlue.withValues(alpha: 0.09)
                  : context.adminPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected
                    ? AppColors.primaryBlue.withValues(alpha: 0.34)
                    : context.adminPalette.border,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(
                alpha: selected ? 0.08 : 0.025,
              ),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    selected
                        ? AppColors.primaryBlue.withValues(alpha: 0.13)
                        : color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                AdminIcons.schoolRounded,
                color: selected ? AppColors.primaryBlue : color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    group?.name ?? 'Grupo no disponible',
                    style: TextStyle(
                      color: context.adminPalette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color:
                    selected
                        ? AppColors.primaryBlue
                        : context.adminPalette.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected
                          ? AppColors.primaryBlue
                          : context.adminPalette.borderStrong,
                  width: 1.5,
                ),
              ),
              child:
                  selected
                      ? Icon(
                        AdminIcons.checkRounded,
                        color: Colors.white,
                        size: 19,
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyFormBlock extends StatelessWidget {
  const _FamilyFormBlock({
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

class _FamilyPill extends StatelessWidget {
  const _FamilyPill({
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

class _FamilyAction extends StatelessWidget {
  const _FamilyAction({
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

class _EmptyFamiliesState extends StatelessWidget {
  const _EmptyFamiliesState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _CenteredStateCard(
      icon: AdminIcons.familyRestroomRounded,
      title: 'Sin familias registradas',
      message:
          'Invita a madres, padres o tutores y define qué alumnos podrán consultar.',
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: Icon(AdminIcons.personAddAlt1Rounded),
        label: Text('Invitar familiar'),
      ),
    );
  }
}

class _NoStudentsForFamiliesState extends StatelessWidget {
  const _NoStudentsForFamiliesState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredStateCard(
      icon: AdminIcons.schoolOutlined,
      title: 'Primero registra alumnos',
      message:
          'Cada acceso familiar debe estar vinculado por lo menos a un alumno de la escuela.',
    );
  }
}

class _CenteredStateCard extends StatelessWidget {
  const _CenteredStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 450,
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
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.adminPalette.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

void _showFamiliesToast(
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

BoxDecoration _panelDecoration(BuildContext context, Color color) {
  return BoxDecoration(
    color: context.adminPalette.surface,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: context.adminPalette.border),
    boxShadow: [
      BoxShadow(
        color: color.withValues(alpha: 0.07),
        blurRadius: 26,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

InputDecoration _fieldDecoration(
  BuildContext context,
  String hint, {
  IconData? prefixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
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

String _relationshipLabel(String value) {
  return _relationshipOption(value).label;
}

const _relationshipOptions = <_RelationshipOption>[
  _RelationshipOption(
    value: 'mother',
    label: 'Madre',
    icon: AdminIcons.womanRounded,
    color: AppColors.primaryRed,
  ),
  _RelationshipOption(
    value: 'father',
    label: 'Padre',
    icon: AdminIcons.manRounded,
    color: AppColors.primaryBlue,
  ),
  _RelationshipOption(
    value: 'guardian',
    label: 'Tutor o responsable',
    icon: AdminIcons.shieldOutlined,
    color: AppColors.primaryTurquoise,
  ),
];

_RelationshipOption _relationshipOption(String value) {
  return _relationshipOptions.firstWhere(
    (option) => option.value == value,
    orElse: () => _relationshipOptions.last,
  );
}

class _RelationshipOption {
  const _RelationshipOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

String _studentCountLabel(int count) {
  return count == 1 ? '1 hijo vinculado' : '$count hijos vinculados';
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
  final normalized = value.replaceFirst('#', '').trim();
  final parsed = int.tryParse('FF$normalized', radix: 16);
  if (parsed == null) return AppColors.primaryBlue;
  return Color(parsed);
}
