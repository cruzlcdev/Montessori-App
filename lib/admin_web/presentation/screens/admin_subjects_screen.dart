import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/academics/data/models/subject_model.dart';
import '../../../features/directory/data/models/school_group_model.dart';
import '../../data/admin_subjects_repository.dart';
import '../widgets/admin_form_controls.dart';
import '../widgets/admin_segmented_filter.dart';
import '../widgets/admin_feedback.dart';

void _showSubjectsToast(
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

class AdminSubjectsScreen extends StatefulWidget {
  const AdminSubjectsScreen({super.key});

  @override
  State<AdminSubjectsScreen> createState() => _AdminSubjectsScreenState();
}

class _AdminSubjectsScreenState extends State<AdminSubjectsScreen> {
  final _repository = AdminSubjectsRepository();
  String _statusFilter = 'all';
  String _groupFilter = 'all';
  String _typeFilter = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<SchoolGroupModel>>(
        stream: _repository.watchGroups(),
        builder: (context, groupsSnapshot) {
          final groups = groupsSnapshot.data ?? const <SchoolGroupModel>[];
          final groupsById = {for (final group in groups) group.id: group};

          return StreamBuilder<List<SubjectModel>>(
            stream: _repository.watchSubjects(),
            builder: (context, subjectsSnapshot) {
              final subjects = subjectsSnapshot.data ?? const <SubjectModel>[];
              final visibleSubjects = _filterSubjects(subjects);
              final activeCount =
                  subjects
                      .where((subject) => subject.status == 'active')
                      .length;
              final qualitativeCount =
                  subjects.where((subject) => subject.isQualitative).length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 30, 34, 20),
                      child: _SubjectsHeader(
                        totalCount: subjects.length,
                        activeCount: activeCount,
                        qualitativeCount: qualitativeCount,
                        onCreate: () => _openForm(groups: groups),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
                      child: _SubjectsToolbar(
                        groups: groups,
                        selectedStatus: _statusFilter,
                        selectedGroupId: _groupFilter,
                        selectedType: _typeFilter,
                        onStatusChanged:
                            (value) => setState(() => _statusFilter = value),
                        onGroupChanged:
                            (value) => setState(() => _groupFilter = value),
                        onTypeChanged:
                            (value) => setState(() => _typeFilter = value),
                        onQueryChanged:
                            (value) => setState(() => _query = value),
                      ),
                    ),
                  ),
                  if (groupsSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      subjectsSnapshot.connectionState ==
                          ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (groups.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoGroupsForSubjectsState(),
                    )
                  else if (visibleSubjects.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptySubjectsState(
                        onCreate: () => _openForm(groups: groups),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 34),
                      sliver: SliverGrid.builder(
                        itemCount: visibleSubjects.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 450,
                              mainAxisExtent: 236,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemBuilder: (context, index) {
                          final subject = visibleSubjects[index];
                          final assignedGroups = subject.groupIds
                              .map((id) => groupsById[id])
                              .whereType<SchoolGroupModel>()
                              .toList(growable: false);
                          return _SubjectAdminCard(
                            subject: subject,
                            groups: assignedGroups,
                            onEdit:
                                () =>
                                    _openForm(groups: groups, subject: subject),
                            onToggleStatus: () => _toggleStatus(subject),
                            onDelete: () => _confirmDelete(subject),
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

  List<SubjectModel> _filterSubjects(List<SubjectModel> subjects) {
    final normalizedQuery = _query.trim().toLowerCase();
    return subjects
        .where((subject) {
          final matchesStatus =
              _statusFilter == 'all' ||
              (_statusFilter == 'active' && subject.status == 'active') ||
              (_statusFilter == 'inactive' && subject.status != 'active');
          final matchesGroup =
              _groupFilter == 'all' || subject.groupIds.contains(_groupFilter);
          final matchesType =
              _typeFilter == 'all' || subject.type == _typeFilter;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              subject.name.toLowerCase().contains(normalizedQuery);

          return matchesStatus && matchesGroup && matchesType && matchesQuery;
        })
        .toList(growable: false);
  }

  Future<void> _openForm({
    required List<SchoolGroupModel> groups,
    SubjectModel? subject,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _SubjectFormSheet(
            repository: _repository,
            groups: groups,
            subject: subject,
          ),
    );

    if (saved == true && mounted) {
      _showSubjectsToast(
        context,
        subject == null ? 'Materia registrada' : 'Materia actualizada',
        message:
            subject == null
                ? 'La materia quedó disponible para los grupos seleccionados y se sincronizará con la app.'
                : 'Los cambios de la materia y sus grupos asignados quedaron sincronizados.',
      );
    }
  }

  Future<void> _toggleStatus(SubjectModel subject) async {
    final nextStatus = subject.status == 'active' ? 'inactive' : 'active';
    await _repository.setSubjectStatus(subject, nextStatus);
    if (!mounted) return;
    _showSubjectsToast(
      context,
      nextStatus == 'active' ? 'Materia activada' : 'Materia desactivada',
      message:
          nextStatus == 'active'
              ? '${subject.name} volverá a estar disponible en los grupos asignados.'
              : '${subject.name} dejará de aparecer para nuevas evaluaciones; los registros existentes se conservan.',
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

  Future<void> _confirmDelete(SubjectModel subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteSubjectDialog(subject: subject),
    );

    if (confirmed != true) return;
    await _repository.deleteSubject(subject);
    if (!mounted) return;
    _showSubjectsToast(
      context,
      'Materia eliminada',
      message:
          '${subject.name} se retiró del catálogo. Las evaluaciones históricas pueden conservar su referencia.',
      icon: AdminIcons.deleteOutlineRounded,
      color: AppColors.primaryRed,
    );
  }
}

class _DeleteSubjectDialog extends StatefulWidget {
  const _DeleteSubjectDialog({required this.subject});

  final SubjectModel subject;

  @override
  State<_DeleteSubjectDialog> createState() => _DeleteSubjectDialogState();
}

class _DeleteSubjectDialogState extends State<_DeleteSubjectDialog> {
  final _controller = TextEditingController();

  bool get _canDelete => _controller.text.trim().toUpperCase() == 'ELIMINAR';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  InputDecoration _deleteInputDecoration() {
    return InputDecoration(
      hintText: 'ELIMINAR',
      hintStyle: TextStyle(
        color: context.adminPalette.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      prefixIcon: Icon(
        AdminIcons.keyboardRounded,
        color: AppColors.primaryBlue,
      ),
      filled: true,
      fillColor: context.adminPalette.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: context.adminPalette.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.adminPalette.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.adminPalette.border),
          boxShadow: [
            BoxShadow(
              color: context.adminPalette.textPrimary.withValues(alpha: 0.16),
              blurRadius: 34,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    AdminIcons.deleteOutlineRounded,
                    color: AppColors.primaryRed,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eliminar materia',
                        style: TextStyle(
                          color: context.adminPalette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subject.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.adminPalette.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(AdminIcons.closeRounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AdminIcons.warningAmberRounded,
                    color: AppColors.primaryRed,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esta acción puede afectar evaluaciones, boletas y estadísticas. Úsala solo si la materia fue creada por error.',
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Para confirmar escribe ELIMINAR',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: _deleteInputDecoration(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 130,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: context.adminPalette.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primaryRed.withValues(
                        alpha: 0.28,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.70,
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        _canDelete ? () => Navigator.pop(context, true) : null,
                    icon: Icon(AdminIcons.deleteOutlineRounded),
                    label: Text('Eliminar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectsHeader extends StatelessWidget {
  const _SubjectsHeader({
    required this.totalCount,
    required this.activeCount,
    required this.qualitativeCount,
    required this.onCreate,
  });

  final int totalCount;
  final int activeCount;
  final int qualitativeCount;
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
              color: AppColors.primaryYellow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              AdminIcons.menuBookRounded,
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
                  'Materias',
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$activeCount activas · $qualitativeCount cualitativas · $totalCount registradas',
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
            icon: Icon(AdminIcons.addRounded),
            label: Text('Nueva materia'),
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

class _SubjectsToolbar extends StatelessWidget {
  const _SubjectsToolbar({
    required this.groups,
    required this.selectedStatus,
    required this.selectedGroupId,
    required this.selectedType,
    required this.onStatusChanged,
    required this.onGroupChanged,
    required this.onTypeChanged,
    required this.onQueryChanged,
  });

  final List<SchoolGroupModel> groups;
  final String selectedStatus;
  final String selectedGroupId;
  final String selectedType;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onTypeChanged;
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
                hintText: 'Buscar materia',
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
              AdminSegmentedOption(value: 'all', label: 'Todas'),
              AdminSegmentedOption(value: 'quantitative', label: 'Numéricas'),
              AdminSegmentedOption(value: 'qualitative', label: 'Cualitativas'),
            ],
            selected: selectedType,
            onChanged: onTypeChanged,
          ),
          const SizedBox(width: 14),
          AdminSegmentedFilter<String>(
            options: const [
              AdminSegmentedOption(value: 'all', label: 'Todos'),
              AdminSegmentedOption(value: 'active', label: 'Activas'),
              AdminSegmentedOption(value: 'inactive', label: 'Inactivas'),
            ],
            selected: selectedStatus,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _SubjectAdminCard extends StatelessWidget {
  const _SubjectAdminCard({
    required this.subject,
    required this.groups,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final SubjectModel subject;
  final List<SchoolGroupModel> groups;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color =
        subject.isQualitative ? AppColors.primaryOrange : AppColors.primaryBlue;
    final isActive = subject.status == 'active';

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
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(_subjectIcon(subject), color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
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
                      subject.isQualitative
                          ? 'Evaluación cualitativa'
                          : 'Evaluación numérica',
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
                label: isActive ? 'Activa' : 'Inactiva',
                color:
                    isActive ? AppColors.primaryGreen : AppColors.primaryOrange,
              ),
              _SmallPill(
                icon: AdminIcons.groupsRounded,
                label: _groupLabel(groups.length),
                color: AppColors.primaryTurquoise,
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

class _SubjectFormSheet extends StatefulWidget {
  const _SubjectFormSheet({
    required this.repository,
    required this.groups,
    this.subject,
  });

  final AdminSubjectsRepository repository;
  final List<SchoolGroupModel> groups;
  final SubjectModel? subject;

  @override
  State<_SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends State<_SubjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final Set<String> _selectedGroupIds;
  late String _type;
  late String _status;
  bool _isSaving = false;

  bool get _isEditing => widget.subject != null;

  @override
  void initState() {
    super.initState();
    final subject = widget.subject;
    _nameController = TextEditingController(text: subject?.name ?? '');
    _selectedGroupIds = {...?subject?.groupIds};
    _type = subject?.type ?? 'quantitative';
    _status = subject?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                          color: AppColors.primaryYellow.withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          AdminIcons.menuBookRounded,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Editar materia' : 'Nueva materia',
                              style: TextStyle(
                                color: context.adminPalette.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Configura cómo aparecerá en evaluaciones y boletas.',
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
                    icon: AdminIcons.editNoteRounded,
                    title: 'Contenido académico',
                    subtitle:
                        'Nombre y tipo de evaluación. El orden y la clave interna se generan automáticamente.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: _fieldDecoration(
                            context,
                            'Nombre de la materia',
                          ),
                          textInputAction: TextInputAction.next,
                          validator:
                              (value) =>
                                  (value?.trim().isEmpty ?? true)
                                      ? 'Ingresa el nombre.'
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: AdminSegmentedFilter<String>(
                            options: const [
                              AdminSegmentedOption(
                                value: 'quantitative',
                                label: 'Numérica',
                              ),
                              AdminSegmentedOption(
                                value: 'qualitative',
                                label: 'Cualitativa',
                              ),
                            ],
                            selected: _type,
                            onChanged: (value) => setState(() => _type = value),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AdminStatusSwitch(
                          value: _status == 'active',
                          title: 'Materia activa',
                          activeSubtitle:
                              'Disponible para evaluaciones, boletas y estadísticas.',
                          inactiveSubtitle:
                              'No aparecerá como materia activa en la app.',
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
                    subtitle: 'Selecciona dónde se impartirá esta materia.',
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
      final subject = widget.subject;
      if (subject == null) {
        await widget.repository.createSubject(
          name: _nameController.text,
          type: _type,
          groupIds: _selectedGroupIds.toList(),
          status: _status,
        );
      } else {
        await widget.repository.updateSubject(
          subject: subject,
          name: _nameController.text,
          type: _type,
          groupIds: _selectedGroupIds.toList(),
          status: _status,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
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

class _EmptySubjectsState extends StatelessWidget {
  const _EmptySubjectsState({required this.onCreate});

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
                color: AppColors.primaryYellow.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                AdminIcons.menuBookRounded,
                color: AppColors.primaryOrange,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sin materias registradas',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea las materias y asígnalas a sus grupos para activar evaluaciones y boletas.',
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
              icon: Icon(AdminIcons.addRounded),
              label: Text('Nueva materia'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoGroupsForSubjectsState extends StatelessWidget {
  const _NoGroupsForSubjectsState();

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
              'Las materias necesitan grupos asignados para aparecer en la app móvil.',
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

IconData _subjectIcon(SubjectModel subject) {
  final iconName = subject.iconName?.toLowerCase() ?? '';
  if (iconName.contains('lenguaje')) return AdminIcons.editNoteRounded;
  if (iconName.contains('math') || iconName.contains('mate')) {
    return AdminIcons.calculateRounded;
  }
  if (iconName.contains('arte')) return AdminIcons.paletteRounded;
  if (iconName.contains('sensorial')) return AdminIcons.psychologyAltRounded;
  if (subject.isQualitative) return AdminIcons.rateReviewRounded;
  return AdminIcons.menuBookRounded;
}

Color _parseColor(String value) {
  final cleanValue = value.replaceFirst('#', '').trim();
  if (cleanValue.length != 6) return AppColors.primaryBlue;
  return Color(int.parse('FF$cleanValue', radix: 16));
}
