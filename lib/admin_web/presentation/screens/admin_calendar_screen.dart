import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../theme/admin_theme.dart';
import '../../../features/calendar/data/models/calendar_event_model.dart';
import '../../../features/directory/data/models/school_group_model.dart';
import '../../data/admin_calendar_repository.dart';
import '../widgets/admin_segmented_filter.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_time_selector.dart';

void _showCalendarToast(
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

class AdminCalendarScreen extends StatefulWidget {
  const AdminCalendarScreen({super.key});

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen> {
  final _repository = AdminCalendarRepository();
  String _statusFilter = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<SchoolGroupModel>>(
        stream: _repository.watchActiveGroups(),
        builder: (context, groupsSnapshot) {
          final groups = groupsSnapshot.data ?? const <SchoolGroupModel>[];

          return StreamBuilder<List<CalendarEventModel>>(
            stream: _repository.watchEvents(),
            builder: (context, eventsSnapshot) {
              final events =
                  eventsSnapshot.data ?? const <CalendarEventModel>[];
              final visibleEvents = _filterEvents(events);
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final publishedCount =
                  events.where((event) => event.status == 'published').length;
              final archivedCount =
                  events.where((event) => event.status == 'archived').length;
              final upcomingCount =
                  events
                      .where(
                        (event) =>
                            event.status == 'published' &&
                            !event.eventDate.isBefore(today),
                      )
                      .length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 30, 34, 20),
                      child: _CalendarHeader(
                        totalCount: events.length,
                        publishedCount: publishedCount,
                        archivedCount: archivedCount,
                        upcomingCount: upcomingCount,
                        onCreate: () => _openForm(groups: groups),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
                      child: _CalendarToolbar(
                        selectedStatus: _statusFilter,
                        onStatusChanged:
                            (value) => setState(() => _statusFilter = value),
                        onQueryChanged:
                            (value) => setState(() => _query = value),
                      ),
                    ),
                  ),
                  if (eventsSnapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visibleEvents.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyCalendarState(
                        onCreate: () => _openForm(groups: groups),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 34),
                      sliver: SliverList.separated(
                        itemCount: visibleEvents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final event = visibleEvents[index];
                          return _CalendarAdminCard(
                            event: event,
                            groups: groups,
                            onEdit:
                                () => _openForm(event: event, groups: groups),
                            onArchive: () => _confirmArchive(event),
                            onPublish: () => _publishEvent(event),
                            onDelete: () => _confirmDelete(event),
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

  List<CalendarEventModel> _filterEvents(List<CalendarEventModel> events) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered =
        events.where((event) {
          final statusMatches =
              _statusFilter == 'all' || event.status == _statusFilter;
          final queryMatches =
              normalizedQuery.isEmpty ||
              event.title.toLowerCase().contains(normalizedQuery) ||
              event.description.toLowerCase().contains(normalizedQuery);

          return statusMatches && queryMatches;
        }).toList();

    filtered.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return filtered;
  }

  Future<void> _openForm({
    CalendarEventModel? event,
    required List<SchoolGroupModel> groups,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _CalendarFormSheet(
          repository: _repository,
          event: event,
          groups: groups,
        );
      },
    );

    if (saved == true && mounted) {
      _showCalendarToast(
        context,
        event == null ? 'Evento publicado' : 'Evento actualizado',
        message:
            event == null
                ? 'El evento quedó visible para la audiencia seleccionada y se sincronizará con la app.'
                : 'La fecha, el horario, la audiencia y el contenido quedaron actualizados en tiempo real.',
      );
    }
  }

  Future<void> _confirmArchive(CalendarEventModel event) async {
    final confirmed = await _confirm(
      title: 'Archivar evento',
      message: 'El evento dejará de mostrarse para padres y profesores.',
      actionLabel: 'Archivar',
    );

    if (!confirmed) return;
    await _repository.archiveEvent(event);
    if (mounted) {
      _showCalendarToast(
        context,
        'Evento archivado',
        message:
            'El evento dejó de mostrarse para padres y profesores, pero permanece disponible en Archivados.',
        icon: AdminIcons.archiveRounded,
        color: AppColors.primaryOrange,
      );
    }
  }

  Future<void> _publishEvent(CalendarEventModel event) async {
    await _repository.publishEvent(event);
    if (mounted) {
      _showCalendarToast(
        context,
        'Evento publicado nuevamente',
        message:
            'El evento volvió a estar visible para su audiencia y se sincronizará con la app.',
      );
    }
  }

  Future<void> _confirmDelete(CalendarEventModel event) async {
    final confirmed = await _confirm(
      title: 'Eliminar evento',
      message:
          'Esta acción eliminará el evento y sus copias por grupo. Úsalo solo para pruebas o errores.',
      actionLabel: 'Eliminar',
      destructive: true,
    );

    if (!confirmed) return;
    await _repository.deleteEvent(event);
    if (mounted) {
      _showCalendarToast(
        context,
        'Evento eliminado',
        message:
            'El evento y sus copias por grupo se retiraron definitivamente del calendario y de la app.',
        icon: AdminIcons.deleteOutlineRounded,
        color: AppColors.primaryRed,
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      destructive
                          ? AppColors.primaryRed
                          : AppColors.primaryBlue,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
            ],
          ),
    );

    return result == true;
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.totalCount,
    required this.publishedCount,
    required this.archivedCount,
    required this.upcomingCount,
    required this.onCreate,
  });

  final int totalCount;
  final int publishedCount;
  final int archivedCount;
  final int upcomingCount;
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
              color: AppColors.primaryTurquoise.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              AdminIcons.calendarMonthRounded,
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
                  'Calendario',
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$upcomingCount próximos · $publishedCount publicados · $archivedCount archivados · $totalCount totales',
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
            label: Text('Nuevo evento'),
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

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
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
                hintText: 'Buscar por título o descripción',
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
              AdminSegmentedOption(value: 'published', label: 'Publicados'),
              AdminSegmentedOption(value: 'archived', label: 'Archivados'),
            ],
            selected: selectedStatus,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _CalendarAdminCard extends StatelessWidget {
  const _CalendarAdminCard({
    required this.event,
    required this.groups,
    required this.onEdit,
    required this.onArchive,
    required this.onPublish,
    required this.onDelete,
  });

  final CalendarEventModel event;
  final List<SchoolGroupModel> groups;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent =
        event.status == 'published'
            ? AppColors.primaryTurquoise
            : context.adminPalette.textMuted;
    final dateLabel = DateFormat(
      "EEEE d 'de' MMMM",
      'es_MX',
    ).format(event.eventDate);
    final timeLabel =
        event.startTime == null || event.startTime!.isEmpty
            ? 'Sin horario'
            : event.endTime == null || event.endTime!.isEmpty
            ? event.startTime!
            : '${event.startTime} - ${event.endTime}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.adminPalette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: context.adminPalette.border),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('d', 'es_MX').format(event.eventDate),
                  style: TextStyle(
                    color: accent,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  DateFormat(
                    'MMM',
                    'es_MX',
                  ).format(event.eventDate).toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(status: event.status),
                    _SmallPill(
                      icon: AdminIcons.groupsRounded,
                      label: _audienceLabel(event, groups),
                      color: AppColors.primaryBlue,
                    ),
                    _SmallPill(
                      icon: AdminIcons.scheduleRounded,
                      label: timeLabel,
                      color: AppColors.primaryOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.adminPalette.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: context.adminPalette.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (event.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.adminPalette.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.28,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Wrap(
            spacing: 8,
            children: [
              _IconAction(
                tooltip: 'Editar',
                icon: AdminIcons.editRounded,
                onTap: onEdit,
              ),
              if (event.status == 'published')
                _IconAction(
                  tooltip: 'Archivar',
                  icon: AdminIcons.archiveRounded,
                  onTap: onArchive,
                )
              else
                _IconAction(
                  tooltip: 'Publicar',
                  icon: AdminIcons.publishRounded,
                  onTap: onPublish,
                ),
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

  String _audienceLabel(
    CalendarEventModel event,
    List<SchoolGroupModel> groups,
  ) {
    if (event.targetGroupIds.contains('all')) return 'Toda la escuela';
    if (event.targetGroupIds.length == 1) {
      final group = groups.where(
        (group) => group.id == event.targetGroupIds.first,
      );
      return group.isEmpty ? '1 grupo' : group.first.name;
    }
    return '${event.targetGroupIds.length} grupos';
  }
}

class _CalendarFormSheet extends StatefulWidget {
  const _CalendarFormSheet({
    required this.repository,
    required this.groups,
    this.event,
  });

  final AdminCalendarRepository repository;
  final List<SchoolGroupModel> groups;
  final CalendarEventModel? event;

  @override
  State<_CalendarFormSheet> createState() => _CalendarFormSheetState();
}

class _CalendarFormSheetState extends State<_CalendarFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final FocusNode _titleFocusNode;
  late final FocusNode _descriptionFocusNode;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final Set<String> _selectedGroupIds;
  late bool _wholeSchool;
  late DateTime _eventDate;
  String? _startTime;
  String? _endTime;
  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleFocusNode = FocusNode()..addListener(_handleFocusChange);
    _descriptionFocusNode = FocusNode()..addListener(_handleFocusChange);
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    _eventDate = event?.eventDate ?? DateTime.now();
    _startTime = event?.startTime;
    _endTime = event?.endTime;
    _wholeSchool = event == null || event.targetGroupIds.contains('all');
    _selectedGroupIds =
        event == null
            ? <String>{}
            : event.targetGroupIds.where((id) => id != 'all').toSet();
  }

  @override
  void dispose() {
    _titleFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _descriptionFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final targetGroupIds =
        _wholeSchool
            ? const ['all']
            : _selectedGroupIds.toList(growable: false);

    if (targetGroupIds.isEmpty) {
      _showLocalError('Selecciona toda la escuela o al menos un grupo.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await widget.repository.updateEvent(
          event: widget.event!,
          title: _titleController.text,
          description: _descriptionController.text,
          eventDate: _eventDate,
          targetGroupIds: targetGroupIds,
          startTime: _startTime,
          endTime: _endTime,
        );
      } else {
        final user = FirebaseAuth.instance.currentUser;
        await widget.repository.createEvent(
          title: _titleController.text,
          description: _descriptionController.text,
          eventDate: _eventDate,
          targetGroupIds: targetGroupIds,
          createdBy: user?.uid ?? '',
          startTime: _startTime,
          endTime: _endTime,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showLocalError('No se pudo guardar el evento: $error');
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder:
          (context) => _EventDateDialog(
            initialDate: _eventDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime(DateTime.now().year + 2, 12, 31),
          ),
    );

    if (selectedDate == null || !mounted) return;
    setState(() => _eventDate = selectedDate);
  }

  Future<void> _pickEventTime({required bool isStart}) async {
    final currentValue = isStart ? _startTime : _endTime;
    final fallbackValue =
        isStart ? '08:00' : _suggestedEndTime(_startTime) ?? '09:00';
    final selectedTime = await showDialog<String>(
      context: context,
      builder:
          (context) => _EventTimePickerDialog(
            title: isStart ? 'Hora de inicio' : 'Hora de finalización',
            subtitle:
                isStart
                    ? 'Define a qué hora comienza el evento.'
                    : 'Define a qué hora termina el evento.',
            initialValue: currentValue ?? fallbackValue,
            allowClear: currentValue != null,
          ),
    );

    if (selectedTime == null || !mounted) return;
    setState(() {
      final value = selectedTime.isEmpty ? null : selectedTime;
      if (isStart) {
        _startTime = value;
      } else {
        _endTime = value;
      }
    });
  }

  String? _suggestedEndTime(String? startTime) {
    final minutes = _timeToMinutes(startTime);
    if (minutes == null) return null;
    final endMinutes = (minutes + 60).clamp(0, (23 * 60) + 59);
    return _minutesToTime(endMinutes);
  }

  void _showLocalError(String message) {
    _showCalendarToast(
      context,
      'No se pudo guardar el evento',
      message: message,
      icon: AdminIcons.errorOutlineRounded,
      color: AppColors.primaryRed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

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
                            color: AppColors.primaryTurquoise.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            AdminIcons.calendarMonthRounded,
                            color: AppColors.primaryTurquoise,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _isEditing ? 'Editar evento' : 'Nuevo evento',
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
                          icon: AdminIcons.editCalendarRounded,
                          title: 'Información del evento',
                          subtitle:
                              'Define el título, descripción y fecha en que aparecerá en la app.',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _titleController,
                                focusNode: _titleFocusNode,
                                maxLength: 120,
                                decoration: _inputDecoration(
                                  context,
                                  hint: 'Título',
                                  icon: AdminIcons.titleRounded,
                                  hideHint: _titleFocusNode.hasFocus,
                                ),
                                validator: (value) {
                                  final title = value?.trim() ?? '';
                                  if (title.isEmpty) return 'Ingresa un título';
                                  if (title.length > 120) {
                                    return 'Máximo 120 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _descriptionController,
                                focusNode: _descriptionFocusNode,
                                minLines: 5,
                                maxLines: 8,
                                maxLength: 1000,
                                decoration: _inputDecoration(
                                  context,
                                  hint: 'Descripción',
                                  hideHint: _descriptionFocusNode.hasFocus,
                                ),
                                validator: (value) {
                                  final description = value?.trim() ?? '';
                                  if (description.length > 1000) {
                                    return 'Máximo 1000 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              _DateSelectorCard(
                                eventDate: _eventDate,
                                startTime: _startTime,
                                endTime: _endTime,
                                onPickDate: _pickDate,
                                onPickStart:
                                    () => _pickEventTime(isStart: true),
                                onPickEnd: () => _pickEventTime(isStart: false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _FormBlock(
                          icon: AdminIcons.groupsRounded,
                          title: 'Audiencia',
                          subtitle:
                              'Define quién podrá ver este evento desde la app.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                value: _wholeSchool,
                                onChanged:
                                    (value) =>
                                        setState(() => _wholeSchool = value),
                                title: Text(
                                  'Toda la escuela',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  'Visible para todos los usuarios activos.',
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                tileColor: context.adminPalette.surfaceMuted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: context.adminPalette.border,
                                  ),
                                ),
                              ),
                              if (!_wholeSchool) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children:
                                      widget.groups.map((group) {
                                        final selected = _selectedGroupIds
                                            .contains(group.id);
                                        return FilterChip(
                                          selected: selected,
                                          label: Text(group.name),
                                          avatar: CircleAvatar(
                                            backgroundColor: _parseColor(
                                              group.colorHex,
                                            ),
                                            child: Text(
                                              group.initials,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          onSelected: (value) {
                                            setState(() {
                                              if (value) {
                                                _selectedGroupIds.add(group.id);
                                              } else {
                                                _selectedGroupIds.remove(
                                                  group.id,
                                                );
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                ),
                              ],
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
                                    : Text(
                                      _isEditing
                                          ? 'Guardar cambios'
                                          : 'Publicar',
                                    ),
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

class _DateSelectorCard extends StatelessWidget {
  const _DateSelectorCard({
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.onPickDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime eventDate;
  final String? startTime;
  final String? endTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.adminPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.adminPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.adminPalette.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      AdminIcons.todayRounded,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fecha del evento',
                          style: TextStyle(
                            color: context.adminPalette.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          DateFormat(
                            "EEEE d 'de' MMMM, y",
                            'es_MX',
                          ).format(eventDate),
                          style: TextStyle(
                            color: context.adminPalette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AdminIcons.editCalendarRounded,
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryTurquoise.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  AdminIcons.scheduleRounded,
                  color: AppColors.primaryTurquoise,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Horario del evento',
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Opcional. Configura el inicio y el final por separado.',
                      style: TextStyle(
                        color: context.adminPalette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _EventTimeCard(
                  label: 'Hora de inicio',
                  value: startTime,
                  helper:
                      startTime == null
                          ? 'El evento no tiene hora de inicio.'
                          : 'Comienza a las $startTime.',
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EventTimeCard(
                  label: 'Hora de finalización',
                  value: endTime,
                  helper:
                      endTime == null
                          ? 'El evento no tiene hora de cierre.'
                          : 'Finaliza a las $endTime.',
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventTimeCard extends StatelessWidget {
  const _EventTimeCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                selected
                    ? AppColors.primaryTurquoise.withValues(alpha: 0.08)
                    : context.adminPalette.inputFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected
                      ? AppColors.primaryTurquoise.withValues(alpha: 0.26)
                      : context.adminPalette.borderStrong,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? AppColors.primaryTurquoise.withValues(alpha: 0.12)
                          : context.adminPalette.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AdminIcons.scheduleRounded,
                  color: AppColors.primaryTurquoise,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: context.adminPalette.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value ?? 'Sin hora',
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      helper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adminPalette.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                AdminIcons.chevronRightRounded,
                color: AppColors.primaryTurquoise,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTimePickerDialog extends StatefulWidget {
  const _EventTimePickerDialog({
    required this.title,
    required this.subtitle,
    required this.initialValue,
    required this.allowClear,
  });

  final String title;
  final String subtitle;
  final String initialValue;
  final bool allowClear;

  @override
  State<_EventTimePickerDialog> createState() => _EventTimePickerDialogState();
}

class _EventTimePickerDialogState extends State<_EventTimePickerDialog> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    final minutes = _timeToMinutes(widget.initialValue) ?? 8 * 60;
    _hour = minutes ~/ 60;
    _minute = minutes % 60;
  }

  String get _selectedValue {
    return '${_hour.toString().padLeft(2, '0')}:'
        '${_minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.adminPalette.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: context.adminPalette.border),
            boxShadow: [
              BoxShadow(
                color: context.adminPalette.shadow.withValues(alpha: 0.28),
                blurRadius: 36,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTurquoise.withValues(
                          alpha: 0.11,
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        AdminIcons.scheduleRounded,
                        color: AppColors.primaryTurquoise,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: context.adminPalette.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: context.adminPalette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        AdminIcons.closeRounded,
                        color: context.adminPalette.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTurquoise.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.primaryTurquoise.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Horario seleccionado',
                        style: TextStyle(
                          color: context.adminPalette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedValue,
                        style: TextStyle(
                          color: AppColors.primaryTurquoise,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AdminTimeSelector(
                  hour: _hour,
                  minute: _minute,
                  accentColor: AppColors.primaryTurquoise,
                  onHourChanged: (value) => setState(() => _hour = value),
                  onMinuteChanged: (value) => setState(() => _minute = value),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (widget.allowClear)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, ''),
                        icon: Icon(AdminIcons.closeRounded, size: 17),
                        label: const Text('Sin hora'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.adminPalette.textSecondary,
                          side: BorderSide(color: context.adminPalette.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, _selectedValue),
                      icon: Icon(AdminIcons.checkRounded, size: 18),
                      label: const Text('Aplicar hora'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
    );
  }
}

int? _timeToMinutes(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return (hour * 60) + minute;
}

String _minutesToTime(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

class _EventDateDialog extends StatefulWidget {
  const _EventDateDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_EventDateDialog> createState() => _EventDateDialogState();
}

class _EventDateDialogState extends State<_EventDateDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SizedBox(
        width: 430,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    AdminIcons.calendarMonthRounded,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seleccionar fecha',
                      style: TextStyle(
                        color: context.adminPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(AdminIcons.closeRounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onDateChanged: (value) => setState(() => _selectedDate = value),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedDate),
                    child: Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
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
  IconData? icon,
  bool hideHint = false,
}) {
  return InputDecoration(
    hintText: hideHint ? null : hint,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    prefixIcon: icon == null ? null : Icon(icon, color: AppColors.primaryBlue),
    hintStyle: TextStyle(
      color: context.adminPalette.textSecondary,
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: context.adminPalette.inputFill,
    contentPadding: EdgeInsets.fromLTRB(icon == null ? 18 : 0, 18, 18, 18),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final published = status == 'published';
    final color =
        published ? AppColors.primaryGreen : context.adminPalette.textMuted;

    return _SmallPill(
      icon:
          published ? AdminIcons.checkCircleRounded : AdminIcons.archiveRounded,
      label: published ? 'Publicado' : 'Archivado',
      color: color,
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

class _EmptyCalendarState extends StatelessWidget {
  const _EmptyCalendarState({required this.onCreate});

  final VoidCallback onCreate;

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
                color: AppColors.primaryTurquoise.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                AdminIcons.eventBusyRounded,
                color: AppColors.primaryTurquoise,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin eventos registrados',
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando publiques actividades, reuniones o avisos con fecha, aparecerán aquí y en la app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.adminPalette.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: Icon(AdminIcons.addRounded),
              label: Text('Crear evento'),
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
