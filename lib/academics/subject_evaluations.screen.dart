import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/academics/student_evaluation_screen.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/core/layout/responsive_layout.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/utils/user_error_messages.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:prototipo_2/features/auth/presentation/screens/unauthorized_screen.dart';
import 'package:prototipo_2/features/academics/data/models/academic_period_model.dart';
import 'package:prototipo_2/features/academics/data/models/subject_model.dart';
import 'package:prototipo_2/features/academics/data/repositories/firestore_academic_repository.dart';
import 'package:prototipo_2/features/academics/presentation/controllers/academic_controller.dart';
import 'package:prototipo_2/features/directory/data/models/student_model.dart';
import 'package:prototipo_2/features/directory/data/repositories/firestore_directory_repository.dart';
import 'package:prototipo_2/screens/teacher_group_screen.dart';

class SubjectEvaluationsScreen extends StatefulWidget {
  const SubjectEvaluationsScreen({
    super.key,
    required this.group,
    required this.subject,
  });

  final GroupInfo group;
  final SubjectModel subject;

  @override
  State<SubjectEvaluationsScreen> createState() =>
      _SubjectEvaluationsScreenState();
}

class _SubjectEvaluationsScreenState extends State<SubjectEvaluationsScreen> {
  final _directoryRepository = FirestoreDirectoryRepository();
  late final AcademicController _academicController;
  StreamSubscription<List<StudentModel>>? _studentsSubscription;
  Timer? _studentsLoadTimer;
  List<StudentModel> _students = [];
  bool _studentsLoading = true;
  String? _studentsError;

  int? _selectedTerm;
  bool _didLoadContext = false;

  @override
  void initState() {
    super.initState();
    _academicController = AcademicController(
      repository: FirestoreAcademicRepository(),
    );

    _academicController.addListener(_onAcademicChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadContext) return;

    final currentUser = context.watch<CurrentUserController>();
    if (currentUser.isLoading) return;
    if (!_canAccessEvaluations(currentUser)) return;

    _didLoadContext = true;
    unawaited(_startStudentsListener());
    _academicController.loadActivePeriods();
  }

  Future<void> _startStudentsListener() async {
    await _studentsSubscription?.cancel();
    if (!mounted) return;

    setState(() {
      _studentsLoading = true;
      _studentsError = null;
    });
    _studentsLoadTimer?.cancel();
    _studentsLoadTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || !_studentsLoading) return;
      setState(() {
        _studentsLoading = false;
        _studentsError =
            'La conexión está tardando demasiado. Revisa tu internet e intenta nuevamente.';
      });
    });

    _studentsSubscription = _directoryRepository
        .watchStudentsByGroup(
          schoolId: AppConstants.defaultSchoolId,
          groupId: widget.group.id,
        )
        .listen(
          (students) {
            if (!mounted) return;
            _studentsLoadTimer?.cancel();
            setState(() {
              _students = students;
              _studentsLoading = false;
              _studentsError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            _studentsLoadTimer?.cancel();
            setState(() {
              _students = [];
              _studentsLoading = false;
              _studentsError = userFriendlyErrorMessage(
                error,
                fallback:
                    'No se pudo actualizar la lista de alumnos. Intenta nuevamente.',
              );
            });
          },
        );
  }

  void _onAcademicChanged() {
    if (!mounted) return;

    if (_selectedTerm == null && _academicController.periods.isNotEmpty) {
      _selectedTerm = _academicController.periods.first.termNumber;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _academicController.removeListener(_onAcademicChanged);
    _studentsSubscription?.cancel();
    _studentsLoadTimer?.cancel();
    _academicController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final currentUser = context.read<CurrentUserController>();
    if (!_canAccessEvaluations(currentUser)) return;

    await Future.wait([
      _startStudentsListener(),
      _academicController.loadActivePeriods(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.watch<CurrentUserController>();

    if (currentUser.isLoading) {
      return const Scaffold(
        body: ModuleLoadingSkeleton(layout: AppSkeletonLayout.academic),
      );
    }

    if (!_canAccessEvaluations(currentUser)) {
      return const UnauthorizedScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Evaluar alumnos'),
        backgroundColor:
            isDarkMode ? AppColors.brandBlueSurface : AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.academic,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: _buildBody(isDarkMode),
        ),
      ),
    );
  }

  bool _canAccessEvaluations(CurrentUserController currentUser) {
    final user = currentUser.user;
    return currentUser.isTeacher == true &&
        user != null &&
        user.groupIds.contains(widget.group.id);
  }

  Widget _buildBody(bool isDarkMode) {
    final isLoading = _studentsLoading || _academicController.isLoading;

    if (isLoading) {
      return const ModuleLoadingSkeleton(layout: AppSkeletonLayout.academic);
    }

    final errorMessage = _studentsError ?? _academicController.errorMessage;

    if (errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveLayout.pagePadding(context, top: 24, bottom: 28),
        children: [
          _StateCard(
            icon: AppIcons.errorOutlineRounded,
            title: 'No se pudo cargar la lista',
            message: errorMessage,
            isDarkMode: isDarkMode,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveLayout.pagePadding(context, top: 20, bottom: 28),
      children: [
        _buildHeader(isDarkMode),
        const SizedBox(height: 16),
        _buildTermSelector(isDarkMode),
        const SizedBox(height: 18),
        if (_students.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 24),
            child: _StateCard(
              icon: AppIcons.personSearchRounded,
              title: 'Sin alumnos disponibles',
              message: 'No hay alumnos registrados para evaluar esta materia.',
              isDarkMode: isDarkMode,
            ),
          )
        else
          ..._students.map(_buildStudentCard),
      ],
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    final studentCount = _students.length;
    final studentLabel = studentCount == 1 ? 'alumno' : 'alumnos';
    final compact = ResponsiveLayout.isCompactPhone(context);
    final iconSize = compact ? 48.0 : 54.0;

    return DecoratedBox(
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
        padding: EdgeInsets.all(ResponsiveLayout.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: widget.group.color.withValues(
                      alpha: isDarkMode ? 0.20 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(
                    AppIcons.editNoteRounded,
                    color: widget.group.color,
                    size: compact ? 27 : 30,
                  ),
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lista de alumnos',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: ResponsiveLayout.titleSize(context, 21),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.group.name} - ${widget.subject.name}',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  icon: AppIcons.peopleAltRounded,
                  label: '$studentCount $studentLabel',
                  color: AppColors.primaryGreen,
                ),
                _InfoPill(
                  icon: AppIcons.menuBookRounded,
                  label: widget.subject.name,
                  color: AppColors.primaryBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSelector(bool isDarkMode) {
    if (_academicController.periods.isEmpty) {
      return _StateCard(
        icon: AppIcons.eventBusyRounded,
        title: 'Sin periodos activos',
        message: 'No hay periodos académicos activos.',
        isDarkMode: isDarkMode,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children:
              _academicController.periods.map((period) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _TermButton(
                      period: period,
                      isSelected: _selectedTerm == period.termNumber,
                      isDarkMode: isDarkMode,
                      onTap: () {
                        setState(() => _selectedTerm = period.termNumber);
                      },
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentModel student) {
    final selectedTerm = _selectedTerm;
    final canOpenEvaluation = selectedTerm != null;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final compact = ResponsiveLayout.isCompactPhone(context);
    final radius = ResponsiveLayout.cardRadius(context) - 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap:
              canOpenEvaluation
                  ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => StudentEvaluationScreen(
                              studentId: student.id,
                              studentName: student.fullName,
                              group: widget.group,
                              subject: widget.subject,
                              selectedTerm: selectedTerm,
                            ),
                      ),
                    );
                  }
                  : null,
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: Row(
              children: [
                Container(
                  width: compact ? 46 : 52,
                  height: compact ? 46 : 52,
                  decoration: BoxDecoration(
                    color: widget.group.color.withValues(
                      alpha: isDarkMode ? 0.20 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    AppIcons.personRounded,
                    color: widget.group.color,
                    size: compact ? 25 : 28,
                  ),
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _InfoPill(
                        icon: AppIcons.editRounded,
                        label: 'Capturar avance',
                        color: AppColors.primaryRed,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Container(
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  decoration: BoxDecoration(
                    color: widget.group.color.withValues(
                      alpha: isDarkMode ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    AppIcons.arrowForwardRounded,
                    color: widget.group.color,
                    size: 20,
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

class _TermButton extends StatelessWidget {
  const _TermButton({
    required this.period,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  final AcademicPeriodModel period;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor:
            isSelected
                ? AppColors.primaryRed
                : isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.softBackground,
        foregroundColor:
            isSelected ? Colors.white : AppColors.textSecondary(context),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Text(
        '${period.termNumber}° Trim.',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
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
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.sizeOf(context).width -
            (ResponsiveLayout.horizontalPadding(context) * 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
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

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.isDarkMode,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 34),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
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
