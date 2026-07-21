import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:intl/intl.dart';
import 'package:prototipo_2/core/layout/responsive_layout.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/widgets/custom_drawer.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/features/calendar/data/models/calendar_event_model.dart';
import 'package:prototipo_2/features/calendar/data/repositories/firestore_calendar_repository.dart';
import 'package:prototipo_2/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarController _controller;
  late final DateTime _firstDay;
  late final DateTime _lastDay;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDay = DateTime(now.year - 1, 1, 1);
    _lastDay = DateTime(now.year + 2, 12, 31);
    _selectedDay = DateUtils.dateOnly(now);

    _controller = CalendarController(repository: FirestoreCalendarRepository());
    _controller.addListener(_onControllerChanged);
    _controller.initialize(startDate: _firstDay, endDate: _lastDay);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reloadEvents() async {
    _controller.watchEvents(startDate: _firstDay, endDate: _lastDay);
    await Future<void>.delayed(const Duration(milliseconds: 350));
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
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Calendario'),
        backgroundColor:
            isDarkMode ? AppColors.brandBlueSurface : AppColors.primaryBlue,
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
        layout: AppSkeletonLayout.calendar,
        child: _buildBody(isDarkMode),
      ),
      floatingActionButton:
          _controller.isAdmin
              ? FloatingActionButton(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                onPressed: _openCreateEventSheet,
                child: const Icon(AppIcons.addRounded),
              )
              : null,
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_controller.isLoading && _controller.events.isEmpty) {
      return const ModuleLoadingSkeleton(layout: AppSkeletonLayout.calendar);
    }

    return RefreshIndicator(
      onRefresh: _reloadEvents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveLayout.pagePadding(context, top: 18, bottom: 28),
        children: [
          if (_controller.errorMessage != null)
            _ErrorBanner(message: _controller.errorMessage!),
          _CalendarHero(
            eventCount: _controller.events.length,
            selectedDay: _selectedDay ?? _focusedDay,
          ),
          const SizedBox(height: 16),
          _CalendarCard(
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            calendarFormat: _calendarFormat,
            controller: _controller,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = DateUtils.dateOnly(selectedDay);
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            title:
                _selectedDay == null
                    ? 'Eventos del día'
                    : 'Eventos del ${_formatDate(_selectedDay!)}',
            icon: AppIcons.todayRounded,
          ),
          const SizedBox(height: 10),
          ..._buildSelectedDayEvents(),
          const SizedBox(height: 22),
          _SectionTitle(
            title:
                'Próximos eventos después del ${_formatDate(_selectedDay ?? _focusedDay)}',
            icon: AppIcons.upcomingRounded,
          ),
          const SizedBox(height: 10),
          ..._buildUpcomingEvents(),
        ],
      ),
    );
  }

  List<Widget> _buildSelectedDayEvents() {
    final selectedDay = _selectedDay ?? DateTime.now();
    final events = _controller.eventsForDay(selectedDay);

    if (events.isEmpty) {
      return const [_EmptyState(message: 'No hay eventos para este día')];
    }

    return events.map(_EventTile.new).toList(growable: false);
  }

  List<Widget> _buildUpcomingEvents() {
    final selectedDay = _selectedDay ?? _focusedDay;
    final events = _controller.upcomingEvents(afterDay: selectedDay);

    if (events.isEmpty) {
      return const [
        _EmptyState(message: 'No hay próximos eventos después de este día'),
      ];
    }

    return events.map(_EventTile.new).toList(growable: false);
  }

  Future<void> _openCreateEventSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (context) => _CreateEventSheet(
            initialDate: _selectedDay ?? _focusedDay,
            onCreate: _createEvent,
          ),
    );
  }

  Future<void> _createEvent({
    required String title,
    required String description,
    required DateTime eventDate,
    required List<String> targetGroupIds,
    String? startTime,
    String? endTime,
  }) {
    return _controller.createEvent(
      title: title,
      description: description,
      eventDate: eventDate,
      targetGroupIds: targetGroupIds,
      startTime: startTime,
      endTime: endTime,
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

class _CalendarHero extends StatelessWidget {
  const _CalendarHero({required this.eventCount, required this.selectedDay});

  final int eventCount;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final countLabel = eventCount == 1 ? 'evento activo' : 'eventos activos';
    final compact = ResponsiveLayout.isCompactPhone(context);
    final iconSize = compact ? 50.0 : 58.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveLayout.cardPadding(context)),
        child: Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(
                  alpha: isDarkMode ? 0.20 : 0.13,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                AppIcons.calendarMonthRounded,
                color: AppColors.primaryOrange,
                size: compact ? 28 : 32,
              ),
            ),
            SizedBox(width: compact ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agenda escolar',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: ResponsiveLayout.titleSize(context, 22),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: AppIcons.eventAvailableRounded,
                        label: '$eventCount $countLabel',
                        color: AppColors.primaryGreen,
                      ),
                      _InfoPill(
                        icon: AppIcons.todayRounded,
                        label: DateFormat('d MMM').format(selectedDay),
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.firstDay,
    required this.lastDay,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.controller,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final CalendarFormat calendarFormat;
  final CalendarController controller;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(CalendarFormat format) onFormatChanged;
  final void Function(DateTime focusedDay) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final compact = ResponsiveLayout.isCompactPhone(context);
    final shortScreen = ResponsiveLayout.isShortScreen(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 12,
          14,
          compact ? 8 : 12,
          16,
        ),
        child: TableCalendar<CalendarEventModel>(
          firstDay: firstDay,
          lastDay: lastDay,
          focusedDay: focusedDay,
          calendarFormat: calendarFormat,
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          onDaySelected: onDaySelected,
          onFormatChanged: onFormatChanged,
          onPageChanged: onPageChanged,
          eventLoader: controller.eventsForDay,
          daysOfWeekHeight: compact ? 30 : 34,
          rowHeight: compact || shortScreen ? 44 : 48,
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            weekendStyle: TextStyle(
              color: AppColors.primaryRed.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          calendarStyle: CalendarStyle(
            cellMargin: EdgeInsets.all(compact ? 3.5 : 5),
            defaultTextStyle: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            weekendTextStyle: TextStyle(
              color: AppColors.primaryRed.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            outsideTextStyle: TextStyle(
              color: AppColors.textSecondary(context).withValues(alpha: 0.36),
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            todayTextStyle: TextStyle(
              color: isDarkMode ? Colors.white : AppColors.primaryBlue,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.primaryTurquoise.withValues(
                alpha: isDarkMode ? 0.28 : 0.16,
              ),
              border: Border.all(color: AppColors.primaryTurquoise, width: 1.4),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            markersAlignment: Alignment.bottomCenter,
            markersMaxCount: 2,
            markerSize: 7,
            markerMargin: const EdgeInsets.symmetric(horizontal: 1.4),
            markerDecoration: const BoxDecoration(
              color: AppColors.primaryOrange,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            formatButtonShowsNext: false,
            titleCentered: true,
            headerMargin: const EdgeInsets.only(bottom: 10),
            headerPadding: const EdgeInsets.symmetric(horizontal: 4),
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            leftChevronIcon: Icon(
              AppIcons.chevronLeftRounded,
              color: AppColors.adaptiveBlue(context),
              size: 30,
            ),
            rightChevronIcon: Icon(
              AppIcons.chevronRightRounded,
              color: AppColors.adaptiveBlue(context),
              size: 30,
            ),
            formatButtonDecoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(
                alpha: isDarkMode ? 0.22 : 0.10,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.20),
              ),
            ),
            formatButtonTextStyle: TextStyle(
              color: AppColors.adaptiveBlue(context),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateEventSheet extends StatefulWidget {
  const _CreateEventSheet({required this.initialDate, required this.onCreate});

  final DateTime initialDate;
  final Future<void> Function({
    required String title,
    required String description,
    required DateTime eventDate,
    required List<String> targetGroupIds,
    String? startTime,
    String? endTime,
  })
  onCreate;

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _eventDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;
  bool _sendToWholeSchool = true;

  final Map<String, bool> _selectedGroups = {
    'comunidad_infantil': false,
    'casa_ninos': false,
    'taller_1': false,
    'taller_2': false,
    'comunidad_adolescente': false,
  };

  @override
  void initState() {
    super.initState();
    _eventDate = DateUtils.dateOnly(widget.initialDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final targetGroupIds =
        _sendToWholeSchool
            ? const ['all']
            : _selectedGroups.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(growable: false);

    if (targetGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona toda la escuela o al menos un grupo'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.onCreate(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        eventDate: _eventDate,
        targetGroupIds: targetGroupIds,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo crear el evento. Intenta nuevamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked != null && mounted) {
      setState(() => _eventDate = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _selectTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isStart
              ? (_startTime ?? TimeOfDay.now())
              : (_endTime ?? _startTime ?? TimeOfDay.now()),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset + 18),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? Colors.white24 : const Color(0xFFD8E0EA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(
                          alpha: isDarkMode ? 0.20 : 0.13,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        AppIcons.eventAvailableRounded,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Crear evento',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(AppIcons.close),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    prefixIcon: const Icon(AppIcons.titleRounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Ingresa un título';
                    if (text.length > 120) return 'Máximo 120 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: const Icon(AppIcons.notesRounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length > 1000) return 'Máximo 1000 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _PickerTile(
                  icon: AppIcons.calendarTodayRounded,
                  label: 'Fecha',
                  value: DateFormat('dd/MM/yyyy').format(_eventDate),
                  onTap: _selectDate,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: AppIcons.schedule,
                        label: 'Inicio',
                        value: _formatTime(_startTime) ?? 'Opcional',
                        onTap: () => _selectTime(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PickerTile(
                        icon: AppIcons.schedule,
                        label: 'Fin',
                        value: _formatTime(_endTime) ?? 'Opcional',
                        onTap: () => _selectTime(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Dirigido a:',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primaryGreen,
                  activeTrackColor: AppColors.primaryGreen.withValues(
                    alpha: 0.24,
                  ),
                  title: const Text('Toda la escuela'),
                  subtitle: const Text(
                    'Visible para administradores, profesores y padres.',
                  ),
                  value: _sendToWholeSchool,
                  onChanged: (value) {
                    setState(() => _sendToWholeSchool = value);
                  },
                ),
                if (!_sendToWholeSchool)
                  ..._selectedGroups.keys.map((group) {
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primaryBlue,
                      title: Text(_getGroupName(group)),
                      value: _selectedGroups[group],
                      onChanged: (value) {
                        setState(() {
                          _selectedGroups[group] = value ?? false;
                        });
                      },
                    );
                  }),
                if (!_sendToWholeSchool)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Solo lo verán usuarios vinculados a los grupos seleccionados.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _isSaving ? null : _submit,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(AppIcons.saveRounded),
                    label: const Text(
                      'Guardar evento',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGroupName(String groupId) {
    const groupNames = {
      'comunidad_infantil': 'Comunidad Infantil',
      'casa_ninos': 'Casa de Niños',
      'taller_1': 'Taller 1',
      'taller_2': 'Taller 2',
      'comunidad_adolescente': 'Comunidad Adolescente',
    };
    return groupNames[groupId] ?? groupId;
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : AppColors.softBlue.withValues(alpha: 0.42),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color:
                  isDarkMode
                      ? Colors.white12
                      : AppColors.primaryBlue.withValues(alpha: 0.12),
            ),
          ),
          prefixIcon: Icon(icon),
        ),
        child: Text(value, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.event);

  final CalendarEventModel event;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final date = DateFormat('d MMM').format(event.eventDate);
    final time =
        event.hasTime
            ? '${event.startTime}${event.endTime == null ? '' : ' - ${event.endTime}'}'
            : 'Todo el día';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(
                  alpha: isDarkMode ? 0.22 : 0.10,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    AppIcons.eventRounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    date,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _InfoPill(
                    icon: AppIcons.scheduleRounded,
                    label: time,
                    color: AppColors.primaryTurquoise,
                  ),
                  if (event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      event.description.trim(),
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(
              alpha: isDarkMode ? 0.20 : 0.10,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.adaptiveBlue(context), size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary(context),
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : AppColors.primaryBlue.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withValues(
                alpha: isDarkMode ? 0.18 : 0.24,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              AppIcons.eventBusyRounded,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<BoxShadow> _softShadows(bool isDarkMode) {
  if (isDarkMode) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.24),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ];
  }

  return [
    BoxShadow(
      color: const Color(0xFFC9D8E8).withValues(alpha: 0.46),
      blurRadius: 22,
      offset: const Offset(8, 12),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.95),
      blurRadius: 18,
      offset: const Offset(-8, -10),
    ),
  ];
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryRed.withValues(
            alpha: isDarkMode ? 0.40 : 0.24,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              AppIcons.errorOutlineRounded,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
