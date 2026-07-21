import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/core/layout/responsive_layout.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/utils/user_error_messages.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';
import 'package:prototipo_2/features/academics/data/models/evaluation_model.dart';
import 'package:prototipo_2/features/academics/data/models/subject_model.dart';
import 'package:prototipo_2/features/academics/data/repositories/firestore_academic_repository.dart';
import 'package:prototipo_2/features/academics/data/repositories/firestore_evaluation_repository.dart';
import 'package:prototipo_2/features/directory/data/models/student_model.dart';
import 'package:prototipo_2/features/directory/data/repositories/firestore_directory_repository.dart';
import 'package:prototipo_2/models/app_state.dart';

class GroupReportCardsScreen extends StatefulWidget {
  const GroupReportCardsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.visibleStudentIds,
  });

  final String groupId;
  final String groupName;
  final List<String>? visibleStudentIds;

  @override
  State<GroupReportCardsScreen> createState() => _GroupReportCardsScreenState();
}

class _GroupReportCardsScreenState extends State<GroupReportCardsScreen> {
  final _directoryRepository = FirestoreDirectoryRepository();
  final _academicRepository = FirestoreAcademicRepository();
  final _evaluationRepository = FirestoreEvaluationRepository();
  final Set<String> _expandedStudentIds = {};

  StreamSubscription<List<StudentModel>>? _studentsSubscription;
  StreamSubscription<List<SubjectModel>>? _subjectsSubscription;
  StreamSubscription<List<EvaluationModel>>? _evaluationsSubscription;
  Timer? _initialLoadTimer;
  List<StudentModel> _students = [];
  List<SubjectModel> _subjects = [];
  List<EvaluationModel> _evaluations = [];
  List<_StudentReportCard> _reportCards = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasStudentsSnapshot = false;
  bool _hasSubjectsSnapshot = false;
  bool _hasEvaluationsSnapshot = false;

  bool get _isFamilyView => widget.visibleStudentIds != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startReportStreams());
  }

  @override
  void dispose() {
    _studentsSubscription?.cancel();
    _subjectsSubscription?.cancel();
    _evaluationsSubscription?.cancel();
    _initialLoadTimer?.cancel();
    super.dispose();
  }

  Future<void> _startReportStreams() async {
    if (!mounted) return;

    final selectedTerm = context.read<AppState>().selectedTerm;

    await Future.wait([
      _studentsSubscription?.cancel() ?? Future.value(),
      _subjectsSubscription?.cancel() ?? Future.value(),
      _evaluationsSubscription?.cancel() ?? Future.value(),
    ]);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _students = [];
      _subjects = [];
      _evaluations = [];
      _reportCards = [];
      _hasStudentsSnapshot = false;
      _hasSubjectsSnapshot = false;
      _hasEvaluationsSnapshot = false;
    });
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || !_isLoading) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'La conexión está tardando demasiado. Revisa tu internet e intenta nuevamente.';
      });
    });

    _studentsSubscription = _watchStudents().listen((students) {
      _students = students;
      _hasStudentsSnapshot = true;
      _restartEvaluationsStream(selectedTerm);
      _rebuildReportCards();
    }, onError: _handleLoadError);

    _subjectsSubscription = _academicRepository
        .watchSubjectsByGroup(
          schoolId: AppConstants.defaultSchoolId,
          groupId: widget.groupId,
        )
        .listen((subjects) {
          _subjects = subjects;
          _hasSubjectsSnapshot = true;
          _restartEvaluationsStream(selectedTerm);
          _rebuildReportCards();
        }, onError: _handleLoadError);
  }

  Future<void> _restartEvaluationsStream(int selectedTerm) async {
    await _evaluationsSubscription?.cancel();
    _evaluationsSubscription = null;

    if (!_hasStudentsSnapshot || !_hasSubjectsSnapshot) return;

    final evaluationIds = <String>[
      for (final student in _students)
        for (final subject in _subjects)
          EvaluationModel.documentId(
            groupId: widget.groupId,
            studentId: student.id,
            subjectId: subject.id,
            termNumber: selectedTerm,
          ),
    ];

    if (evaluationIds.isEmpty) {
      _evaluations = [];
      _hasEvaluationsSnapshot = true;
      _rebuildReportCards();
      return;
    }

    _hasEvaluationsSnapshot = false;
    _evaluationsSubscription = _evaluationRepository
        .watchEvaluationsByIds(
          schoolId: AppConstants.defaultSchoolId,
          evaluationIds: evaluationIds,
        )
        .listen((evaluations) {
          _evaluations = evaluations;
          _hasEvaluationsSnapshot = true;
          _rebuildReportCards();
        }, onError: _handleLoadError);
  }

  Stream<List<StudentModel>> _watchStudents() {
    final visibleStudentIds = widget.visibleStudentIds;

    if (visibleStudentIds == null) {
      return _directoryRepository.watchStudentsByGroup(
        schoolId: AppConstants.defaultSchoolId,
        groupId: widget.groupId,
      );
    }

    return _directoryRepository
        .watchStudentsByIds(
          schoolId: AppConstants.defaultSchoolId,
          studentIds: visibleStudentIds,
        )
        .map((students) {
          return students
              .where((student) => student.groupId == widget.groupId)
              .toList(growable: false);
        });
  }

  void _rebuildReportCards() {
    if (!mounted) return;
    if (!_hasStudentsSnapshot ||
        !_hasSubjectsSnapshot ||
        !_hasEvaluationsSnapshot) {
      return;
    }

    final selectedTerm = context.read<AppState>().selectedTerm;
    final evaluationsById = {
      for (final evaluation in _evaluations) evaluation.id: evaluation,
    };
    final reportCards = <_StudentReportCard>[];

    for (final student in _students) {
      final rows = _subjects
          .map((subject) {
            final evaluationId = EvaluationModel.documentId(
              groupId: widget.groupId,
              studentId: student.id,
              subjectId: subject.id,
              termNumber: selectedTerm,
            );
            final evaluation = evaluationsById[evaluationId];

            return _SubjectReportRow(
              subject: subject,
              value: evaluation?.value.trim() ?? '',
              feedback: evaluation?.feedback.trim() ?? '',
            );
          })
          .toList(growable: false);

      reportCards.add(_StudentReportCard(student: student, rows: rows));
    }

    _initialLoadTimer?.cancel();
    setState(() {
      _reportCards = reportCards;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  void _handleLoadError(Object error) {
    if (!mounted) return;
    _initialLoadTimer?.cancel();
    setState(() {
      _reportCards = [];
      _isLoading = false;
      _errorMessage = userFriendlyErrorMessage(
        error,
        fallback: 'No se pudo cargar la boleta. Intenta nuevamente.',
      );
    });
  }

  Future<void> _loadReportCards() async {
    await _startReportStreams();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          _isFamilyView ? 'Boleta escolar' : 'Boletas ${widget.groupName}',
        ),
        backgroundColor:
            isDarkMode ? AppColors.brandBlueSurface : AppColors.primaryBlue,
      ),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.reportCards,
        child: RefreshIndicator(
          onRefresh: _loadReportCards,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: ResponsiveLayout.pagePadding(context, top: 20, bottom: 28),
            children: [
              _buildReportHeader(appState, isDarkMode),
              const SizedBox(height: 16),
              _buildTermSelector(appState, isDarkMode),
              const SizedBox(height: 14),
              _buildGuidanceCard(isDarkMode),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                child: _buildReportContent(isDarkMode, appState.selectedTerm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportHeader(AppState appState, bool isDarkMode) {
    final studentCount = _reportCards.length;
    final subjectCount =
        _reportCards.isEmpty ? 0 : _reportCards.first.rows.length;
    final compact = ResponsiveLayout.isCompactPhone(context);
    final iconSize = compact ? 48.0 : 54.0;
    final termLabel = '${appState.selectedTerm}° Trim.';

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
                    color: AppColors.primaryBlue.withValues(
                      alpha: isDarkMode ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: const Icon(
                    AppIcons.assignmentRounded,
                    color: AppColors.primaryBlue,
                    size: 30,
                  ),
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isFamilyView
                            ? 'Seguimiento académico'
                            : widget.groupName,
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
                        _isFamilyView
                            ? 'Avance de tu hijo - $termLabel'
                            : termLabel,
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildSummaryPill(
                  icon: AppIcons.peopleAltRounded,
                  label:
                      _isFamilyView
                          ? _countLabel(studentCount, 'hijo', 'hijos')
                          : _countLabel(studentCount, 'alumno', 'alumnos'),
                  color: AppColors.primaryGreen,
                  isDarkMode: isDarkMode,
                ),
                _buildSummaryPill(
                  icon: AppIcons.menuBookRounded,
                  label: _countLabel(subjectCount, 'materia', 'materias'),
                  color: AppColors.primaryOrange,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSelector(AppState appState, bool isDarkMode) {
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
              [1, 2, 3].map((term) {
                final isSelected = appState.selectedTerm == term;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: TextButton(
                      onPressed: () {
                        if (isSelected) return;
                        appState.changeTerm(term);
                        _loadReportCards();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor:
                            isSelected
                                ? AppColors.primaryRed
                                : isDarkMode
                                ? Colors.white.withValues(alpha: 0.06)
                                : AppColors.softBackground,
                        foregroundColor:
                            isSelected
                                ? Colors.white
                                : isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        '$term° Trim.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildReportContent(bool isDarkMode, int selectedTerm) {
    if (_isLoading) {
      return const ModuleLoadingSkeleton(
        key: ValueKey('report_loading'),
        layout: AppSkeletonLayout.reportCards,
      );
    }

    if (_errorMessage != null) {
      return Padding(
        key: ValueKey('report_error'),
        padding: const EdgeInsets.only(top: 80),
        child: _buildStateCard(
          icon: AppIcons.errorOutlineRounded,
          title: 'No se pudo cargar la boleta',
          message: _errorMessage!,
        ),
      );
    }

    if (_reportCards.isEmpty) {
      return Padding(
        key: ValueKey('report_empty_$selectedTerm'),
        padding: const EdgeInsets.only(top: 80),
        child: _buildStateCard(
          icon: AppIcons.personSearchRounded,
          title: 'Sin alumnos para mostrar',
          message:
              widget.visibleStudentIds == null
                  ? 'No hay alumnos registrados en este grupo.'
                  : 'No hay hijos vinculados a tu cuenta en este grupo.',
        ),
      );
    }

    return Column(
      key: ValueKey('report_cards_$selectedTerm'),
      children: _reportCards
          .map((reportCard) => _buildStudentCard(reportCard, isDarkMode))
          .toList(growable: false),
    );
  }

  Widget _buildGuidanceCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(
          alpha: isDarkMode ? 0.16 : 0.08,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(
            alpha: isDarkMode ? 0.28 : 0.14,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(
                alpha: isDarkMode ? 0.24 : 0.12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isFamilyView
                  ? AppIcons.familyRestroomRounded
                  : AppIcons.assignmentTurnedInRounded,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isFamilyView
                  ? 'Revisa las materias evaluadas, la calificación y las observaciones registradas por el docente.'
                  : 'Consulta el avance capturado por materia para cada alumno del grupo.',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(_StudentReportCard reportCard, bool isDarkMode) {
    final student = reportCard.student;
    final isExpanded = _expandedStudentIds.contains(student.id);
    final completedCount =
        reportCard.rows.where((row) => row.value.isNotEmpty).length;
    final subjectLabel = reportCard.rows.length == 1 ? 'materia' : 'materias';
    final progressLabel =
        '$completedCount/${reportCard.rows.length} $subjectLabel evaluadas';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('report_card_${student.id}'),
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedStudentIds.add(student.id);
              } else {
                _expandedStudentIds.remove(student.id);
              }
            });
          },
          collapsedIconColor: isDarkMode ? Colors.white70 : AppColors.ink,
          iconColor: AppColors.primaryBlue,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(
                alpha: isDarkMode ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              AppIcons.personRounded,
              color: AppColors.primaryBlue,
            ),
          ),
          title: Text(
            _isFamilyView ? 'Tu hijo' : student.fullName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isFamilyView) ...[
                  Text(
                    student.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  progressLabel,
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
          children: [
            if (reportCard.rows.isEmpty)
              _buildStateCard(
                icon: AppIcons.menuBookOutlined,
                title: 'Sin materias asignadas',
                message: 'No hay materias asignadas a este grupo.',
                compact: true,
              )
            else
              Column(
                children:
                    reportCard.rows
                        .map((row) => _buildSubjectRow(row, isDarkMode))
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectRow(_SubjectReportRow row, bool isDarkMode) {
    final hasValue = row.value.isNotEmpty;
    final valueColor = _valueColor(row, isDarkMode);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE5EAF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: valueColor.withValues(alpha: isDarkMode ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _subjectIcon(row.subject),
                  color: valueColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasValue ? 'Avance registrado' : 'Pendiente de registro',
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
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minHeight: 32),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: valueColor.withValues(alpha: hasValue ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: valueColor),
                ),
                child: Text(
                  hasValue ? row.value : 'Pendiente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          if (row.feedback.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isDarkMode
                        ? Colors.white.withValues(alpha: 0.04)
                        : AppColors.softBlue.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Observación: ${row.feedback}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _subjectIcon(SubjectModel subject) {
    final subjectName = subject.name.toLowerCase();
    final iconName = subject.iconName?.toLowerCase();

    if (iconName == 'language' || subjectName.contains('lenguaje')) {
      return AppIcons.menuBookRounded;
    }
    if (iconName == 'calculate' || subjectName.contains('matemática')) {
      return AppIcons.calculateRounded;
    }
    if (iconName == 'science' || subjectName.contains('ciencia')) {
      return AppIcons.scienceRounded;
    }
    if (iconName == 'history' || subjectName.contains('historia')) {
      return AppIcons.publicRounded;
    }
    if (iconName == 'sensorial' || subjectName.contains('sensorial')) {
      return AppIcons.extensionRounded;
    }
    if (iconName == 'home' || subjectName.contains('vida práctica')) {
      return AppIcons.homeRounded;
    }

    return AppIcons.schoolRounded;
  }

  Color _valueColor(_SubjectReportRow row, bool isDarkMode) {
    if (row.value.isEmpty) {
      return isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    }

    if (row.subject.isQualitative) {
      switch (row.value.toLowerCase()) {
        case 'excelente':
          return AppColors.primaryGreen;
        case 'bueno':
          return const Color(0xFF4A90E2);
        case 'en desarrollo':
          return const Color(0xFFE0B507);
        default:
          return AppColors.primaryBlue;
      }
    }

    final numericValue = double.tryParse(row.value);
    if (numericValue == null) return AppColors.primaryBlue;
    if (numericValue >= 9) return AppColors.primaryGreen;
    if (numericValue >= 7) return const Color(0xFF4A90E2);
    if (numericValue >= 6) return const Color(0xFFE0B507);
    return AppColors.primaryRed;
  }

  String _countLabel(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }

  Widget _buildSummaryPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
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
        ],
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    bool compact = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 22),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: compact ? 28 : 34),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: compact ? 16 : 19,
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
}

class _StudentReportCard {
  const _StudentReportCard({required this.student, required this.rows});

  final StudentModel student;
  final List<_SubjectReportRow> rows;
}

class _SubjectReportRow {
  const _SubjectReportRow({
    required this.subject,
    required this.value,
    required this.feedback,
  });

  final SubjectModel subject;
  final String value;
  final String feedback;
}
