import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/directory/data/models/school_group_model.dart';
import '../../data/admin_groups_repository.dart';
import '../widgets/admin_form_controls.dart';
import '../widgets/admin_segmented_filter.dart';
import '../widgets/admin_feedback.dart';

void _showGroupsToast(
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

class AdminGroupsScreen extends StatefulWidget {
  const AdminGroupsScreen({super.key});

  @override
  State<AdminGroupsScreen> createState() => _AdminGroupsScreenState();
}

class _AdminGroupsScreenState extends State<AdminGroupsScreen> {
  final _repository = AdminGroupsRepository();
  String _statusFilter = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<SchoolGroupModel>>(
        stream: _repository.watchGroups(),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <SchoolGroupModel>[];
          final visibleGroups = _filterGroups(groups);
          final activeCount =
              groups.where((group) => group.status == 'active').length;
          final inactiveCount =
              groups.where((group) => group.status != 'active').length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(34, 30, 34, 20),
                  child: _GroupsHeader(
                    totalCount: groups.length,
                    activeCount: activeCount,
                    inactiveCount: inactiveCount,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
                  child: _GroupsToolbar(
                    selectedStatus: _statusFilter,
                    onStatusChanged:
                        (value) => setState(() => _statusFilter = value),
                    onQueryChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visibleGroups.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyGroupsState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(34, 0, 34, 34),
                  sliver: SliverGrid.builder(
                    itemCount: visibleGroups.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 430,
                          mainAxisExtent: 190,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemBuilder: (context, index) {
                      final group = visibleGroups[index];
                      return _GroupAdminCard(
                        group: group,
                        onEdit: () => _openForm(group: group),
                        onDelete: () => _confirmDelete(group),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<SchoolGroupModel> _filterGroups(List<SchoolGroupModel> groups) {
    final normalizedQuery = _query.trim().toLowerCase();
    return groups
        .where((group) {
          final matchesStatus =
              _statusFilter == 'all' ||
              (_statusFilter == 'active' && group.status == 'active') ||
              (_statusFilter == 'inactive' && group.status != 'active');
          final matchesQuery =
              normalizedQuery.isEmpty ||
              group.name.toLowerCase().contains(normalizedQuery) ||
              group.level.toLowerCase().contains(normalizedQuery) ||
              group.initials.toLowerCase().contains(normalizedQuery);

          return matchesStatus && matchesQuery;
        })
        .toList(growable: false);
  }

  Future<void> _openForm({SchoolGroupModel? group}) async {
    if (group == null) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupFormSheet(repository: _repository, group: group),
    );

    if (saved == true && mounted) {
      _showGroupsToast(
        context,
        'Grupo actualizado',
        message:
            'Los datos del grupo quedaron guardados y sincronizados con Firestore.',
      );
    }
  }

  Future<void> _confirmDelete(SchoolGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteGroupDialog(group: group),
    );

    if (confirmed != true) return;
    await _repository.deleteGroup(group);
    if (!mounted) return;
    _showGroupsToast(
      context,
      'Grupo eliminado',
      message:
          'El grupo se retiró del panel. Revisa alumnos, materias y contenidos que pudieran estar vinculados.',
      icon: AdminIcons.deleteOutlineRounded,
      color: AppColors.primaryRed,
    );
  }
}

class _GroupsHeader extends StatelessWidget {
  const _GroupsHeader({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
  });

  final int totalCount;
  final int activeCount;
  final int inactiveCount;

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
              color: AppColors.primaryGreen.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              AdminIcons.groupsRounded,
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
                  'Grupos',
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$activeCount activos · $inactiveCount inactivos · $totalCount totales',
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
    );
  }
}

class _GroupsToolbar extends StatelessWidget {
  const _GroupsToolbar({
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onQueryChanged,
  });

  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
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
            child: TextField(
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, nivel o iniciales',
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

class _GroupAdminCard extends StatelessWidget {
  const _GroupAdminCard({
    required this.group,
    required this.onEdit,
    required this.onDelete,
  });

  final SchoolGroupModel group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(group.colorHex);
    final isActive = group.status == 'active';

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
                  group.initials.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      group.name,
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
                      group.level.trim().isEmpty
                          ? 'Sin nivel configurado'
                          : group.level,
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
          const SizedBox(height: 16),
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
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _IconAction(
                tooltip: 'Editar',
                icon: AdminIcons.editRounded,
                onTap: onEdit,
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

class _GroupFormSheet extends StatefulWidget {
  const _GroupFormSheet({required this.repository, this.group});

  final AdminGroupsRepository repository;
  final SchoolGroupModel? group;

  @override
  State<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<_GroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _levelController;
  late String _colorHex;
  late String _status;
  bool _isSaving = false;

  static const _colorOptions = [
    '#0073DB',
    '#01B7CE',
    '#2DC121',
    '#FFD731',
    '#FAA619',
    '#FF5E52',
    '#8E44AD',
  ];

  @override
  void initState() {
    super.initState();
    final group = widget.group!;
    _nameController = TextEditingController(text: group.name);
    _levelController = TextEditingController(text: group.level);
    _colorHex =
        _colorOptions.contains(group.colorHex.toUpperCase())
            ? group.colorHex.toUpperCase()
            : _colorOptions.first;
    _status = group.status == 'inactive' ? 'inactive' : 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.repository.updateGroupProfile(
        group: widget.group!,
        name: _nameController.text,
        level: _levelController.text,
        colorHex: _colorHex,
        status: _status,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showGroupsToast(
        context,
        'No se pudo guardar el grupo',
        message:
            'No se aplicaron los cambios. Revisa los datos e inténtalo nuevamente. Detalle: $error',
        icon: AdminIcons.errorOutlineRounded,
        color: AppColors.primaryRed,
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final groupColor = _parseColor(_colorHex);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 620,
          height: MediaQuery.sizeOf(context).height,
          decoration: BoxDecoration(
            color: context.adminPalette.surface,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 22, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: groupColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            AdminIcons.groupsRounded,
                            color: groupColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Editar grupo',
                            style: TextStyle(
                              color: context.adminPalette.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: Icon(AdminIcons.closeRounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 26),
                      children: [
                        _FormBlock(
                          icon: AdminIcons.badgeRounded,
                          title: 'Datos del grupo',
                          subtitle:
                              'Actualiza el nombre y su nivel o comunidad. Las iniciales y el orden se calculan automáticamente.',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                maxLength: 80,
                                decoration: _inputDecoration(
                                  context,
                                  hint: 'Nombre del grupo',
                                  icon: AdminIcons.groupsRounded,
                                ),
                                validator: (value) {
                                  final name = value?.trim() ?? '';
                                  if (name.isEmpty) return 'Ingresa un nombre';
                                  if (name.length > 80) {
                                    return 'Máximo 80 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _levelController,
                                maxLength: 60,
                                decoration: _inputDecoration(
                                  context,
                                  hint: 'Nivel o comunidad',
                                  icon: AdminIcons.schoolRounded,
                                ),
                                validator: (value) {
                                  final level = value?.trim() ?? '';
                                  if (level.length > 60) {
                                    return 'Máximo 60 caracteres';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _FormBlock(
                          icon: AdminIcons.tuneRounded,
                          title: 'Apariencia y disponibilidad',
                          subtitle:
                              'El color identifica visualmente al grupo. El estado controla si estará disponible para asignaciones.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    _colorOptions.map((colorHex) {
                                      final color = _parseColor(colorHex);
                                      final selected = _colorHex == colorHex;

                                      return Tooltip(
                                        message: colorHex,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          onTap:
                                              () => setState(
                                                () => _colorHex = colorHex,
                                              ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color:
                                                    selected
                                                        ? context
                                                            .adminPalette
                                                            .textPrimary
                                                        : context
                                                            .adminPalette
                                                            .surface,
                                                width: selected ? 2.2 : 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: color.withValues(
                                                    alpha:
                                                        selected ? 0.28 : 0.12,
                                                  ),
                                                  blurRadius:
                                                      selected ? 18 : 10,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child:
                                                selected
                                                    ? Icon(
                                                      AdminIcons.checkRounded,
                                                      color: Colors.white,
                                                    )
                                                    : null,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              const SizedBox(height: 18),
                              AdminStatusSwitch(
                                value: _status == 'active',
                                title: 'Grupo activo',
                                activeSubtitle:
                                    'Disponible para alumnos, materias y audiencias.',
                                inactiveSubtitle:
                                    'No disponible para nuevas asignaciones.',
                                onChanged:
                                    (value) => setState(
                                      () =>
                                          _status =
                                              value ? 'active' : 'inactive',
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.adminPalette.border),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextButton(
                            onPressed:
                                _isSaving
                                    ? null
                                    : () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  context.adminPalette.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 190,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child:
                                _isSaving
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Text('Guardar cambios'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteGroupDialog extends StatefulWidget {
  const _DeleteGroupDialog({required this.group});

  final SchoolGroupModel group;

  @override
  State<_DeleteGroupDialog> createState() => _DeleteGroupDialogState();
}

class _DeleteGroupDialogState extends State<_DeleteGroupDialog> {
  final _controller = TextEditingController();

  bool get _canDelete => _controller.text.trim().toUpperCase() == 'ELIMINAR';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                        'Eliminar grupo',
                        style: TextStyle(
                          color: context.adminPalette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.group.name,
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
                      'Esta acción puede afectar alumnos, materias, comunicados y eventos vinculados. Úsala solo si el grupo fue creado por error.',
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
              decoration: _inputDecoration(
                context,
                hint: 'ELIMINAR',
                icon: AdminIcons.keyboardRounded,
              ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.adminPalette.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.adminPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue, size: 19),
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
                          fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    prefixIcon: Icon(icon, color: AppColors.primaryBlue),
    hintStyle: TextStyle(
      color: context.adminPalette.textSecondary,
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: context.adminPalette.inputFill,
    contentPadding: const EdgeInsets.fromLTRB(0, 18, 18, 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: context.adminPalette.borderStrong),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: context.adminPalette.borderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
    ),
  );
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
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: context.adminPalette.textPrimary,
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  const _EmptyGroupsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: context.adminPalette.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: context.adminPalette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                AdminIcons.groupsRounded,
                color: AppColors.primaryGreen,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin grupos registrados',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea el primer grupo para organizar alumnos, materias y comunicados por comunidad.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.adminPalette.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? AppColors.primaryBlue : Color(parsed);
}
