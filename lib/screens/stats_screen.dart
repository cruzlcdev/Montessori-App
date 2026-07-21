import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/core/layout/responsive_layout.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/utils/user_error_messages.dart';
import 'package:prototipo_2/core/widgets/custom_drawer.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/core/widgets/adaptive_single_line_text.dart';
import 'package:prototipo_2/features/academics/data/models/academic_period_model.dart';
import 'package:prototipo_2/features/academics/data/models/evaluation_model.dart';
import 'package:prototipo_2/features/academics/data/models/subject_model.dart';
import 'package:prototipo_2/features/academics/data/repositories/firestore_academic_repository.dart';
import 'package:prototipo_2/features/academics/data/repositories/firestore_evaluation_repository.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:prototipo_2/features/directory/data/models/school_group_model.dart';
import 'package:prototipo_2/features/directory/data/models/student_model.dart';
import 'package:prototipo_2/features/directory/data/repositories/firestore_directory_repository.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _directoryRepository = FirestoreDirectoryRepository();
  final _academicRepository = FirestoreAcademicRepository();
  final _evaluationRepository = FirestoreEvaluationRepository();

  String? _loadedProfileKey;
  bool _isInitialLoading = true;
  bool _isStatsLoading = false;
  bool _showStudentSelector = false;
  bool _isAdminView = false;
  String? _errorMessage;
  String _schoolId = AppConstants.defaultSchoolId;

  List<_StatsStudentOption> _studentOptions = [];
  List<AcademicPeriodModel> _periods = [];
  List<_StudentStatsSummary> _studentSummaries = [];
  _StatsStudentOption? _selectedStudent;
  int _selectedTerm = 1;
  int _overallPerformance = 0;
  List<_StatsSubjectResult> _subjectResults = [];
  StreamSubscription<List<SubjectModel>>? _subjectsSubscription;
  StreamSubscription<List<EvaluationModel>>? _evaluationsSubscription;
  Timer? _initialLoadTimer;
  Timer? _statsLoadTimer;
  List<SubjectModel> _watchedSubjects = [];
  List<EvaluationModel> _watchedEvaluations = [];
  bool _hasSubjectsSnapshot = false;
  bool _hasEvaluationsSnapshot = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentUser = context.watch<CurrentUserController>();
    if (currentUser.isLoading) return;

    final nextKey = _profileKey(currentUser);
    if (_loadedProfileKey == nextKey) return;
    _loadedProfileKey = nextKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData(currentUser);
    });
  }

  String _profileKey(CurrentUserController currentUser) {
    final user = currentUser.user;
    if (user == null) return 'none';

    final groupIds = user.groupIds.toSet().toList()..sort();
    final studentIds = user.studentIds.toSet().toList()..sort();
    return [
      user.uid,
      user.role,
      user.status,
      groupIds.join('|'),
      studentIds.join('|'),
    ].join('::');
  }

  Future<void> _loadInitialData(CurrentUserController currentUser) async {
    if (!mounted) return;

    setState(() {
      _isInitialLoading = true;
      _isStatsLoading = false;
      _errorMessage = null;
      _studentOptions = [];
      _studentSummaries = [];
      _subjectResults = [];
      _overallPerformance = 0;
    });
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || !_isInitialLoading) return;
      setState(() {
        _isInitialLoading = false;
        _errorMessage =
            'La conexión está tardando demasiado. Revisa tu internet e intenta nuevamente.';
      });
    });

    try {
      final user = currentUser.user;
      if (user == null || !user.isActive) {
        throw Exception(
          currentUser.errorMessage ?? 'No tienes un perfil activo.',
        );
      }

      _schoolId =
          user.schoolId.isEmpty ? AppConstants.defaultSchoolId : user.schoolId;

      final periodsFuture = _academicRepository.getActivePeriods(
        schoolId: _schoolId,
      );
      final studentsFuture = _loadVisibleStudents(currentUser);

      final periods = await periodsFuture;
      final students = await studentsFuture;

      if (!mounted) return;
      _initialLoadTimer?.cancel();
      setState(() {
        _isAdminView = currentUser.isAdmin;
        _periods = periods;
        _studentOptions = students;
        _selectedTerm =
            periods.isEmpty ? 1 : periods.first.termNumber.clamp(1, 6);
        _selectedStudent = students.isEmpty ? null : students.first;
        _isInitialLoading = false;
      });

      if (currentUser.isAdmin) {
        await _loadAdminStatsSummary();
      } else {
        await _loadStatsForSelection();
      }
    } catch (e) {
      if (!mounted) return;
      _initialLoadTimer?.cancel();
      setState(() {
        _isInitialLoading = false;
        _isStatsLoading = false;
        _errorMessage = userFriendlyErrorMessage(
          e,
          fallback:
              'No se pudieron cargar las estadisticas. Intenta nuevamente.',
        );
      });
    }
  }

  Future<List<_StatsStudentOption>> _loadVisibleStudents(
    CurrentUserController currentUser,
  ) async {
    final user = currentUser.user;
    if (user == null) return const [];

    if (currentUser.isAdmin) {
      final groups = await _directoryRepository.getGroups(schoolId: _schoolId);
      return _loadStudentsFromGroups(groups);
    }

    if (currentUser.isTeacher) {
      final groups = await _directoryRepository.getGroupsByIds(
        schoolId: _schoolId,
        groupIds: user.groupIds,
      );
      return _loadStudentsFromGroups(groups);
    }

    if (currentUser.isParent) {
      final students = await _directoryRepository.getStudentsByIds(
        schoolId: _schoolId,
        studentIds: user.studentIds,
      );
      final groupIds =
          user.groupIds.isEmpty
              ? students.map((student) => student.groupId).toSet().toList()
              : user.groupIds;
      final groups = await _directoryRepository.getGroupsByIds(
        schoolId: _schoolId,
        groupIds: groupIds,
      );
      final groupsById = {for (final group in groups) group.id: group};

      return students
          .map((student) {
            final group = groupsById[student.groupId];
            if (group == null) return null;
            return _StatsStudentOption(student: student, group: group);
          })
          .whereType<_StatsStudentOption>()
          .toList(growable: false);
    }

    return const [];
  }

  Future<List<_StatsStudentOption>> _loadStudentsFromGroups(
    List<SchoolGroupModel> groups,
  ) async {
    final options = <_StatsStudentOption>[];

    for (final group in groups) {
      final students = await _directoryRepository.getStudentsByGroup(
        schoolId: _schoolId,
        groupId: group.id,
      );
      options.addAll(
        students.map((student) {
          return _StatsStudentOption(student: student, group: group);
        }),
      );
    }

    options.sort((a, b) {
      final groupComparison = a.group.sortOrder.compareTo(b.group.sortOrder);
      if (groupComparison != 0) return groupComparison;
      final lastNameComparison = a.student.lastName.compareTo(
        b.student.lastName,
      );
      if (lastNameComparison != 0) return lastNameComparison;
      return a.student.firstName.compareTo(b.student.firstName);
    });

    return options;
  }

  Future<void> _loadStatsForSelection() async {
    final selectedStudent = _selectedStudent;
    if (selectedStudent == null) {
      if (!mounted) return;
      await _cancelRealtimeStats();
      setState(() {
        _subjectResults = [];
        _overallPerformance = 0;
      });
      return;
    }

    await _startRealtimeStatsForSelection(selectedStudent);
  }

  Future<void> _startRealtimeStatsForSelection(
    _StatsStudentOption selectedStudent,
  ) async {
    await _cancelRealtimeStats();

    _watchedSubjects = [];
    _watchedEvaluations = [];
    _hasSubjectsSnapshot = false;
    _hasEvaluationsSnapshot = false;

    setState(() {
      _isStatsLoading = true;
      _errorMessage = null;
    });
    _startStatsLoadTimeout();

    _subjectsSubscription = _academicRepository
        .watchSubjectsByGroup(
          schoolId: _schoolId,
          groupId: selectedStudent.group.id,
        )
        .listen(
          (subjects) {
            _watchedSubjects = subjects;
            _hasSubjectsSnapshot = true;
            _restartStatsEvaluationsStream(selectedStudent);
            _rebuildRealtimeStats();
          },
          onError: (Object error) {
            _handleStatsStreamError(error);
          },
        );
  }

  Future<void> _restartStatsEvaluationsStream(
    _StatsStudentOption selectedStudent,
  ) async {
    await _evaluationsSubscription?.cancel();
    _evaluationsSubscription = null;

    if (!_hasSubjectsSnapshot) return;

    final evaluationIds = _watchedSubjects
        .map((subject) {
          return EvaluationModel.documentId(
            groupId: selectedStudent.group.id,
            studentId: selectedStudent.student.id,
            subjectId: subject.id,
            termNumber: _selectedTerm,
          );
        })
        .toList(growable: false);

    if (evaluationIds.isEmpty) {
      _watchedEvaluations = [];
      _hasEvaluationsSnapshot = true;
      _rebuildRealtimeStats();
      return;
    }

    _hasEvaluationsSnapshot = false;
    _evaluationsSubscription = _evaluationRepository
        .watchEvaluationsByIds(
          schoolId: _schoolId,
          evaluationIds: evaluationIds,
        )
        .listen(
          (evaluations) {
            _watchedEvaluations = evaluations;
            _hasEvaluationsSnapshot = true;
            _rebuildRealtimeStats();
          },
          onError: (Object error) {
            _handleStatsStreamError(error);
          },
        );
  }

  Future<void> _cancelRealtimeStats() async {
    await Future.wait([
      _subjectsSubscription?.cancel() ?? Future.value(),
      _evaluationsSubscription?.cancel() ?? Future.value(),
    ]);
    _subjectsSubscription = null;
    _evaluationsSubscription = null;
  }

  void _rebuildRealtimeStats() {
    if (!mounted || !_hasSubjectsSnapshot || !_hasEvaluationsSnapshot) return;

    final selectedStudent = _selectedStudent;
    if (selectedStudent == null) return;

    final evaluationsBySubjectId = {
      for (final evaluation in _watchedEvaluations)
        evaluation.subjectId: evaluation,
    };
    final results = <_StatsSubjectResult>[];

    for (final subject in _watchedSubjects) {
      final evaluation = evaluationsBySubjectId[subject.id];
      final rawValue = evaluation?.value.trim() ?? '';
      if (rawValue.isEmpty) continue;

      final score = _scoreFromValue(rawValue, subject);
      results.add(
        _StatsSubjectResult(
          subject: subject,
          value: rawValue,
          score: score,
          displayValue: _displayValue(rawValue, subject),
        ),
      );
    }

    final total = results.fold<int>(0, (sum, result) => sum + result.score);
    final average = results.isEmpty ? 0 : (total / results.length).round();

    _statsLoadTimer?.cancel();
    setState(() {
      _subjectResults = results;
      _overallPerformance = average.clamp(0, 100);
      _isStatsLoading = false;
      _errorMessage = null;
    });
  }

  void _handleStatsStreamError(Object error) {
    if (!mounted) return;
    _statsLoadTimer?.cancel();
    setState(() {
      _subjectResults = [];
      _overallPerformance = 0;
      _isStatsLoading = false;
      _errorMessage = userFriendlyErrorMessage(
        error,
        fallback: 'No se pudieron cargar las estadisticas. Intenta nuevamente.',
      );
    });
  }

  Future<void> _loadAdminStatsSummary() async {
    setState(() {
      _isStatsLoading = true;
      _errorMessage = null;
    });
    _startStatsLoadTimeout();

    try {
      final summaries = <_StudentStatsSummary>[];
      final subjectsByGroup = <String, List<SubjectModel>>{};

      for (final option in _studentOptions) {
        final subjects =
            subjectsByGroup[option.group.id] ??
            await _academicRepository.getSubjectsByGroup(
              schoolId: _schoolId,
              groupId: option.group.id,
            );
        subjectsByGroup[option.group.id] = subjects;

        summaries.add(await _buildStudentSummary(option, subjects));
      }

      final evaluatedSummaries = summaries
          .where((summary) => summary.evaluatedSubjectCount > 0)
          .toList(growable: false);
      final total = evaluatedSummaries.fold<int>(
        0,
        (sum, summary) => sum + summary.performance,
      );
      final average =
          evaluatedSummaries.isEmpty
              ? 0
              : (total / evaluatedSummaries.length).round();

      if (!mounted) return;
      _statsLoadTimer?.cancel();
      setState(() {
        _studentSummaries = summaries;
        _subjectResults = [];
        _overallPerformance = average.clamp(0, 100);
        _isStatsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _statsLoadTimer?.cancel();
      setState(() {
        _studentSummaries = [];
        _overallPerformance = 0;
        _isStatsLoading = false;
        _errorMessage = userFriendlyErrorMessage(
          e,
          fallback:
              'No se pudieron cargar las estadisticas. Intenta nuevamente.',
        );
      });
    }
  }

  void _startStatsLoadTimeout() {
    _statsLoadTimer?.cancel();
    _statsLoadTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || !_isStatsLoading) return;
      setState(() {
        _isStatsLoading = false;
        _errorMessage =
            'La conexión está tardando demasiado. Revisa tu internet e intenta nuevamente.';
      });
    });
  }

  Future<_StudentStatsSummary> _buildStudentSummary(
    _StatsStudentOption option,
    List<SubjectModel> subjects,
  ) async {
    var total = 0;
    var evaluatedCount = 0;

    for (final subject in subjects) {
      final evaluationId = EvaluationModel.documentId(
        groupId: option.group.id,
        studentId: option.student.id,
        subjectId: subject.id,
        termNumber: _selectedTerm,
      );
      final evaluation = await _evaluationRepository.getEvaluation(
        schoolId: _schoolId,
        evaluationId: evaluationId,
      );

      final rawValue = evaluation?.value.trim() ?? '';
      if (rawValue.isEmpty) continue;

      total += _scoreFromValue(rawValue, subject);
      evaluatedCount++;
    }

    return _StudentStatsSummary(
      option: option,
      performance: evaluatedCount == 0 ? 0 : (total / evaluatedCount).round(),
      evaluatedSubjectCount: evaluatedCount,
      subjectCount: subjects.length,
    );
  }

  int _scoreFromValue(String value, SubjectModel subject) {
    if (subject.isQualitative) {
      return _mapDescriptorToPercentage(value);
    }

    final normalized = value.replaceAll(',', '.');
    final numericValue = double.tryParse(normalized) ?? 0;
    return (numericValue.clamp(0, 10) * 10).round();
  }

  int _mapDescriptorToPercentage(String descriptor) {
    switch (descriptor.trim().toLowerCase()) {
      case 'excelente':
        return 100;
      case 'bueno':
        return 75;
      case 'en desarrollo':
        return 50;
      default:
        return 0;
    }
  }

  String _displayValue(String value, SubjectModel subject) {
    if (subject.isQualitative) return value;

    final normalized = value.replaceAll(',', '.');
    final numericValue = double.tryParse(normalized);
    if (numericValue == null) return value;
    return numericValue.toStringAsFixed(1);
  }

  Color _performanceColor(int percentage) {
    if (percentage >= 90) return AppColors.primaryGreen;
    if (percentage >= 70) return AppColors.primaryYellow;
    return AppColors.primaryRed;
  }

  String _performanceText(int percentage) {
    if (percentage >= 90) return 'Excelente';
    if (percentage >= 70) return 'Bueno';
    if (percentage > 0) return 'En desarrollo';
    return 'Sin datos';
  }

  String _termLabel(int termNumber) {
    return '$termNumber° Trim.';
  }

  List<int> get _termOptions {
    if (_periods.isEmpty) return const [1, 2, 3];
    return _periods.map((period) => period.termNumber).toSet().toList()..sort();
  }

  Future<void> _refresh() async {
    final currentUser = context.read<CurrentUserController>();
    await _loadInitialData(currentUser);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<CurrentUserController>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Estadísticas'),
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
        layout: AppSkeletonLayout.statistics,
        child:
            currentUser.isLoading || _isInitialLoading
                ? const ModuleLoadingSkeleton(
                  layout: AppSkeletonLayout.statistics,
                )
                : RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildBody(currentUser, isDarkMode),
                ),
      ),
    );
  }

  Widget _buildBody(CurrentUserController currentUser, bool isDarkMode) {
    if (!currentUser.hasAppAccess) {
      return _buildCenteredMessage(
        currentUser.errorMessage ?? 'No tienes permisos para ver estadísticas.',
      );
    }

    if (_errorMessage != null && _studentOptions.isEmpty) {
      return _buildCenteredMessage(_errorMessage!);
    }

    if (_studentOptions.isEmpty) {
      final message =
          currentUser.isParent
              ? 'No hay alumnos vinculados a tu cuenta.'
              : 'No hay alumnos disponibles para calcular estadísticas.';
      return _buildCenteredMessage(message);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              isDarkMode
                  ? [AppColors.darkSurfaceAlt, AppColors.darkBackground]
                  : [const Color(0xFFF4F9FF), const Color(0xFFFDFEFF)],
        ),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveLayout.pagePadding(context, top: 18, bottom: 28),
        children: [
          _buildStatsHeader(currentUser, isDarkMode),
          const SizedBox(height: 16),
          if (!_isAdminView) ...[
            _buildStudentSelector(isDarkMode),
            const SizedBox(height: 14),
          ],
          _buildTermSelector(isDarkMode),
          const SizedBox(height: 18),
          _buildPerformanceCard(isDarkMode),
          const SizedBox(height: 24),
          _buildSectionTitle(
            _isAdminView ? 'Alumnos evaluados' : 'Desglose por materia',
            _isAdminView
                ? 'Promedio por alumno durante ${_termLabel(_selectedTerm).toLowerCase()}.'
                : 'Avance registrado por cada materia evaluada.',
            isDarkMode,
          ),
          if (_isStatsLoading)
            const ModuleLoadingSkeleton(
              layout: AppSkeletonLayout.statistics,
              itemCount: 2,
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            )
          else if (_isAdminView && _studentSummaries.isEmpty)
            _buildEmptyState(
              icon: AppIcons.insightsRounded,
              title: 'Sin estadísticas por ahora',
              message: 'No hay alumnos disponibles para este periodo.',
              isDarkMode: isDarkMode,
            )
          else if (!_isAdminView && _subjectResults.isEmpty)
            _buildEmptyState(
              icon: AppIcons.queryStatsRounded,
              title: 'Sin datos del trimestre',
              message:
                  'Todavía no hay evaluaciones disponibles para este periodo.',
              isDarkMode: isDarkMode,
            )
          else if (_isAdminView)
            ..._studentSummaries.map(
              (summary) => _buildStudentSummaryCard(summary, isDarkMode),
            )
          else
            ..._subjectResults.map(
              (result) => _buildSubjectCard(result, isDarkMode),
            ),
        ],
      ),
    );
  }

  Widget _buildCenteredMessage(String message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveLayout.pagePadding(context, top: 24, bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: _buildEmptyState(
            icon: AppIcons.infoOutlineRounded,
            title: 'No disponible',
            message: message,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(CurrentUserController currentUser, bool isDarkMode) {
    final evaluatedSubjects =
        _isAdminView
            ? _studentSummaries.fold<int>(
              0,
              (sum, summary) => sum + summary.evaluatedSubjectCount,
            )
            : _subjectResults.length;
    final studentCount =
        _isAdminView
            ? _studentOptions.length
            : (_selectedStudent == null ? 0 : 1);
    final showStudentCount = !currentUser.isParent;
    final title =
        currentUser.isParent
            ? 'Avance de tu hijo'
            : currentUser.isTeacher
            ? 'Seguimiento del grupo'
            : 'Panorama académico';
    final subtitle =
        currentUser.isParent
            ? 'Desempeño por trimestre y materia.'
            : currentUser.isTeacher
            ? 'Revisa el progreso de tus alumnos asignados.'
            : 'Visualiza el desempeño general del alumnado.';
    final compact = ResponsiveLayout.isNarrowPhone(context);
    final iconSize = compact ? 44.0 : 48.0;

    return Container(
      padding: EdgeInsets.all(ResponsiveLayout.cardPadding(context)),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2EAF3),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: AppColors.primaryTurquoise.withValues(
                    alpha: isDarkMode ? 0.20 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  AppIcons.queryStatsRounded,
                  color: AppColors.primaryTurquoise,
                  size: 26,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptiveSingleLineText(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: compact ? 20 : 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
          if (showStudentCount)
            Row(
              children: [
                Flexible(
                  child: _buildInfoChip(
                    icon: AppIcons.groups,
                    label: _countLabel(studentCount, 'alumno', 'alumnos'),
                    color: AppColors.primaryBlue,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: _buildInfoChip(
                    icon: AppIcons.factCheckRounded,
                    label: _countLabel(
                      evaluatedSubjects,
                      'registro evaluado',
                      'registros evaluados',
                    ),
                    color: AppColors.primaryGreen,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            )
          else
            _buildInfoChip(
              icon: AppIcons.factCheckRounded,
              label: _countLabel(
                evaluatedSubjects,
                'registro evaluado',
                'registros evaluados',
              ),
              color: AppColors.primaryGreen,
              isDarkMode: isDarkMode,
            ),
        ],
      ),
    );
  }

  Widget _buildStudentSelector(bool isDarkMode) {
    final selectedStudent = _selectedStudent;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2EAF3),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(
                  alpha: isDarkMode ? 0.20 : 0.12,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                AppIcons.personSearchRounded,
                color: AppColors.primaryBlue,
              ),
            ),
            title: Text(
              'Seleccionar alumno',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            subtitle: Text(
              selectedStudent == null
                  ? 'Sin alumno seleccionado'
                  : selectedStudent.student.fullName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            trailing: Icon(
              _showStudentSelector
                  ? AppIcons.keyboardArrowUp
                  : AppIcons.keyboardArrowDown,
              color: AppColors.textPrimary(context),
            ),
            onTap: () {
              setState(() => _showStudentSelector = !_showStudentSelector);
            },
          ),
          if (_showStudentSelector)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.38,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _studentOptions.length,
                itemBuilder: (context, index) {
                  final option = _studentOptions[index];
                  final isSelected =
                      option.student.id == selectedStudent?.student.id;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primaryTurquoise.withValues(
                                  alpha: isDarkMode ? 0.16 : 0.12,
                                )
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.primaryTurquoise.withValues(
                                    alpha: isDarkMode ? 0.42 : 0.30,
                                  )
                                  : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        selected: isSelected,
                        leading: Icon(
                          isSelected
                              ? AppIcons.checkCircleRounded
                              : AppIcons.personOutlineRounded,
                          color:
                              isSelected
                                  ? AppColors.primaryTurquoise
                                  : AppColors.primaryBlue,
                        ),
                        title: Text(
                          option.student.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight:
                                isSelected ? FontWeight.w900 : FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        subtitle: Text(
                          option.group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedStudent = option;
                            _showStudentSelector = false;
                          });
                          _loadStatsForSelection();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTermSelector(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Row(
        children:
            _termOptions.map((term) {
              final isSelected = _selectedTerm == term;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (isSelected) return;
                      setState(() => _selectedTerm = term);
                      if (_isAdminView) {
                        _loadAdminStatsSummary();
                      } else {
                        _loadStatsForSelection();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primaryRed
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _termLabel(term),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildPerformanceCard(bool isDarkMode) {
    final performanceColor = _performanceColor(_overallPerformance);
    final evaluatedLabel =
        _isAdminView
            ? _countLabel(
              _studentSummaries
                  .where((summary) => summary.evaluatedSubjectCount > 0)
                  .length,
              'alumno con avance',
              'alumnos con avance',
            )
            : _countLabel(
              _subjectResults.length,
              'materia evaluada',
              'materias evaluadas',
            );

    final compact = ResponsiveLayout.isNarrowPhone(context);

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2EAF3),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child:
          compact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildPerformanceRing(performanceColor, true)),
                  const SizedBox(height: 16),
                  _buildPerformanceDetails(
                    evaluatedLabel: evaluatedLabel,
                    performanceColor: performanceColor,
                    isDarkMode: isDarkMode,
                  ),
                ],
              )
              : Row(
                children: [
                  _buildPerformanceRing(performanceColor, false),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildPerformanceDetails(
                      evaluatedLabel: evaluatedLabel,
                      performanceColor: performanceColor,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildPerformanceRing(Color performanceColor, bool compact) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final targetPerformance = _overallPerformance.clamp(0, 100).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetPerformance),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final animatedPercentage = animatedValue.clamp(0, 100);
        final animatedScore = animatedPercentage.round();
        final progress =
            targetPerformance <= 0
                ? 1.0
                : (animatedPercentage / targetPerformance)
                    .clamp(0.0, 1.0)
                    .toDouble();
        final animatedColor =
            Color.lerp(AppColors.primaryRed, performanceColor, progress) ??
            performanceColor;

        return SizedBox(
          width: compact ? 118 : 138,
          height: compact ? 118 : 138,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: compact ? 112 : 132,
                height: compact ? 112 : 132,
                child: CircularProgressIndicator(
                  value: animatedPercentage / 100,
                  strokeWidth: compact ? 10 : 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor:
                      isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE8EEF5),
                  color: animatedColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$animatedScore%',
                    style: TextStyle(
                      fontSize: compact ? 26 : 30,
                      fontWeight: FontWeight.w900,
                      color: animatedColor,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: Text(
                      _performanceText(_overallPerformance),
                      key: ValueKey(_performanceText(_overallPerformance)),
                      style: TextStyle(
                        color: animatedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceDetails({
    required String evaluatedLabel,
    required Color performanceColor,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptiveSingleLineText(
          _isAdminView ? 'Desempeño general' : 'Promedio del periodo',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isAdminView
              ? 'Promedio del grupo en este periodo.'
              : 'Promedio del trimestre seleccionado.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        _buildInfoChip(
          icon: AppIcons.verifiedRounded,
          label: evaluatedLabel,
          color: performanceColor,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildSubjectCard(_StatsSubjectResult result, bool isDarkMode) {
    final color = _performanceColor(result.score);

    return TweenAnimationBuilder<double>(
      key: ValueKey('${result.subject.id}_${result.score}_$_selectedTerm'),
      tween: Tween<double>(
        begin: 0,
        end: result.score.clamp(0, 100).toDouble(),
      ),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, animatedScore, _) {
        final score = animatedScore.clamp(0, 100);
        final animatedColor =
            Color.lerp(AppColors.primaryRed, color, score / 100) ?? color;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2EAF3),
            ),
            boxShadow: _softShadows(isDarkMode),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: animatedColor.withValues(
                          alpha: isDarkMode ? 0.18 : 0.11,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _subjectIcon(result.subject),
                        color: animatedColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.subject.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary(context),
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            result.subject.isQualitative
                                ? result.displayValue
                                : 'Calificación: ${result.displayValue}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: animatedColor.withValues(
                          alpha: isDarkMode ? 0.18 : 0.11,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${score.round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: animatedColor,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildProgressBar(
                  value: score / 100,
                  color: animatedColor,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _subjectIcon(SubjectModel subject) {
    final name = subject.name.toLowerCase();
    final iconName = subject.iconName?.toLowerCase();

    if (iconName == 'language' || name.contains('lenguaje')) {
      return AppIcons.menuBookRounded;
    }
    if (iconName == 'calculate' || name.contains('matemática')) {
      return AppIcons.calculateRounded;
    }
    if (iconName == 'science' || name.contains('ciencia')) {
      return AppIcons.scienceRounded;
    }
    if (iconName == 'history' || name.contains('historia')) {
      return AppIcons.publicRounded;
    }
    if (iconName == 'sensorial' || name.contains('sensorial')) {
      return AppIcons.extensionRounded;
    }
    if (iconName == 'home' || name.contains('vida práctica')) {
      return AppIcons.homeRounded;
    }

    return AppIcons.schoolRounded;
  }

  Widget _buildStudentSummaryCard(
    _StudentStatsSummary summary,
    bool isDarkMode,
  ) {
    final hasEvaluations = summary.evaluatedSubjectCount > 0;
    final color =
        hasEvaluations
            ? _performanceColor(summary.performance)
            : AppColors.textSecondary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2EAF3),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDarkMode ? 0.18 : 0.11),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(AppIcons.personRounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.option.student.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary(context),
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        summary.option.group.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDarkMode ? 0.18 : 0.11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasEvaluations ? '${summary.performance}%' : 'Sin datos',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildProgressBar(
              value: hasEvaluations ? summary.performance / 100 : 0,
              color: hasEvaluations ? color : Colors.grey,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.evaluatedSubjectCount}/${summary.subjectCount} materias evaluadas',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveSingleLineText(
            title,
            style: TextStyle(
              fontSize: ResponsiveLayout.titleSize(context, 20),
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary(context),
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required double value,
    required Color color,
    required bool isDarkMode,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        backgroundColor:
            isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE8EEF5),
        color: color,
        minHeight: 9,
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required bool isDarkMode,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.softBlue.withValues(
                alpha: isDarkMode ? 0.12 : 1,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
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
        color: const Color(0xFFC9D8E8).withValues(alpha: 0.38),
        blurRadius: 20,
        offset: const Offset(7, 11),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.92),
        blurRadius: 16,
        offset: const Offset(-6, -8),
      ),
    ];
  }

  String _countLabel(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    _evaluationsSubscription?.cancel();
    _initialLoadTimer?.cancel();
    _statsLoadTimer?.cancel();
    super.dispose();
  }
}

class _StatsStudentOption {
  const _StatsStudentOption({required this.student, required this.group});

  final StudentModel student;
  final SchoolGroupModel group;
}

class _StatsSubjectResult {
  const _StatsSubjectResult({
    required this.subject,
    required this.value,
    required this.score,
    required this.displayValue,
  });

  final SubjectModel subject;
  final String value;
  final int score;
  final String displayValue;
}

class _StudentStatsSummary {
  const _StudentStatsSummary({
    required this.option,
    required this.performance,
    required this.evaluatedSubjectCount,
    required this.subjectCount,
  });

  final _StatsStudentOption option;
  final int performance;
  final int evaluatedSubjectCount;
  final int subjectCount;
}
