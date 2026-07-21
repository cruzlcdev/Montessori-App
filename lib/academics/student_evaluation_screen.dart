import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/features/academics/data/models/evaluation_model.dart';
import 'package:prototipo_2/features/academics/data/models/subject_model.dart';
import 'package:prototipo_2/features/academics/data/repositories/firestore_evaluation_repository.dart';
import 'package:prototipo_2/features/directory/data/models/student_model.dart';
import 'package:prototipo_2/features/directory/data/repositories/firestore_directory_repository.dart';
import '../core/theme/colors.dart';
import '../core/widgets/app_loading_skeleton.dart';
import '../core/widgets/network_aware_module.dart';
import '../features/auth/presentation/controllers/current_user_controller.dart';
import '../features/auth/presentation/screens/unauthorized_screen.dart';
import '../screens/teacher_group_screen.dart';

class StudentEvaluationScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final GroupInfo group;
  final SubjectModel subject;
  final int selectedTerm;

  const StudentEvaluationScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.group,
    required this.subject,
    required this.selectedTerm,
  });

  @override
  State<StudentEvaluationScreen> createState() =>
      _StudentEvaluationScreenState();
}

class _StudentEvaluationScreenState extends State<StudentEvaluationScreen> {
  final FirestoreEvaluationRepository _repository =
      FirestoreEvaluationRepository();
  final FirestoreDirectoryRepository _directoryRepository =
      FirestoreDirectoryRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _qualitativeValue;
  double? _quantitativeValue;
  EvaluationModel? _loadedEvaluation;
  StreamSubscription<EvaluationModel?>? _evaluationSubscription;
  StreamSubscription<List<StudentModel>>? _studentSubscription;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _didLoadEvaluation = false;
  bool _studentAvailabilityChecked = false;
  bool _studentUnavailable = false;
  String? _saveError;

  // Opciones para evaluación cualitativa (preescolar)
  final List<String> _qualitativeOptions = [
    'Excelente',
    'Bueno',
    'En desarrollo',
  ];

  bool get isQualitativeEvaluation => widget.subject.isQualitative;

  String get _evaluationId => EvaluationModel.documentId(
    groupId: widget.group.id,
    studentId: widget.studentId,
    subjectId: widget.subject.id,
    termNumber: widget.selectedTerm,
  );

  bool _canEditEvaluation(CurrentUserController currentUser) {
    final user = currentUser.user;
    if (user == null || !currentUser.isTeacher) return false;
    return user.groupIds.contains(widget.group.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadEvaluation) return;

    final currentUser = context.watch<CurrentUserController>();
    if (currentUser.isLoading) return;
    if (!_canEditEvaluation(currentUser)) return;

    _didLoadEvaluation = true;
    _startStudentListener();
    _startEvaluationListener();
  }

  void _startStudentListener() {
    _studentSubscription?.cancel();
    _studentSubscription = _directoryRepository
        .watchStudentsByIds(
          schoolId: AppConstants.defaultSchoolId,
          studentIds: [widget.studentId],
        )
        .listen(
          (students) {
            if (!mounted || _studentUnavailable) return;

            final isAvailable = students.any(
              (student) =>
                  student.id == widget.studentId &&
                  student.groupId == widget.group.id,
            );

            if (!isAvailable) {
              _handleStudentUnavailable();
              return;
            }

            if (!_studentAvailabilityChecked) {
              setState(() => _studentAvailabilityChecked = true);
            }
          },
          onError: (Object error) {
            debugPrint('Error checking student availability: $error');
            if (mounted && !_studentAvailabilityChecked) {
              setState(() => _studentAvailabilityChecked = true);
            }
          },
        );
  }

  void _handleStudentUnavailable() {
    if (!mounted || _studentUnavailable) return;

    _studentUnavailable = true;
    _studentAvailabilityChecked = true;
    _evaluationSubscription?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(AppIcons.personOffRounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'El alumno fue desactivado y ya no está disponible para evaluación.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        );
    });
  }

  // Carga la evaluación existente del estudiante
  void _startEvaluationListener() {
    setState(() => _isLoading = true);

    _evaluationSubscription?.cancel();
    _evaluationSubscription = _repository
        .watchEvaluation(
          schoolId: AppConstants.defaultSchoolId,
          evaluationId: _evaluationId,
        )
        .listen(
          (evaluation) {
            if (!mounted) return;
            setState(() {
              _loadedEvaluation = evaluation;
              if (evaluation != null && !_isSaving) {
                _feedbackController.text = evaluation.feedback;
                if (isQualitativeEvaluation) {
                  _qualitativeValue = evaluation.value;
                } else {
                  _quantitativeValue = double.tryParse(evaluation.value);
                }
              }
              _isLoading = false;
            });
          },
          onError: (Object error) {
            debugPrint('Error loading evaluation: $error');
            if (mounted) setState(() => _isLoading = false);
          },
        );
  }

  @override
  void dispose() {
    _evaluationSubscription?.cancel();
    _studentSubscription?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  // Guarda la evaluación en Firebase
  Future<void> _saveEvaluation() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    if (_studentUnavailable || _isSaving || !_isValidEvaluation()) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final String value =
        isQualitativeEvaluation
            ? (_qualitativeValue ?? '')
            : (_quantitativeValue?.toStringAsFixed(1) ?? '');
    var shouldResetSaving = true;

    try {
      final now = DateTime.now();
      await _repository.saveEvaluation(
        EvaluationModel(
          id: _evaluationId,
          schoolId: AppConstants.defaultSchoolId,
          groupId: widget.group.id,
          studentId: widget.studentId,
          studentName: widget.studentName,
          subjectId: widget.subject.id,
          subjectName: widget.subject.name,
          termNumber: widget.selectedTerm,
          value: value,
          feedback: _feedbackController.text.trim(),
          updatedBy: currentUserId,
          createdAt: _loadedEvaluation?.createdAt ?? now,
          updatedAt: now,
        ),
      );

      if (!mounted) return;

      // Muestra snackbar de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(AppIcons.checkCircle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('¡Evaluación guardada exitosamente!')),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          duration: const Duration(seconds: 3),
        ),
      );

      shouldResetSaving = false;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving evaluation: $e');
      if (!mounted) return;
      setState(() {
        _saveError = 'No se pudo guardar la evaluación. Intenta nuevamente.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(AppIcons.errorOutlineRounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('No se pudo guardar la evaluación')),
            ],
          ),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
    } finally {
      if (mounted && shouldResetSaving) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Valida si la evaluación es válida para guardar
  bool _isValidEvaluation() {
    if (isQualitativeEvaluation) {
      return _qualitativeValue != null && _qualitativeValue!.isNotEmpty;
    } else {
      return _quantitativeValue != null &&
          _quantitativeValue! >= 6.0 &&
          _quantitativeValue! <= 10.0;
    }
  }

  // Valida el texto de retroalimentación (solo letras y signos básicos)
  String? _validateFeedback(String? value) {
    if (value == null || value.isEmpty) {
      return null; // No mostrar error si está vacío
    }

    final validCharacters = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s.,;:¡!¿?()\-"]*$');

    if (!validCharacters.hasMatch(value)) {
      return 'Solo se permiten letras y signos de puntuación básicos';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.watch<CurrentUserController>();
    final canEditEvaluation = _canEditEvaluation(currentUser);

    if (currentUser.isLoading) {
      return const Scaffold(
        body: ModuleLoadingSkeleton(layout: AppSkeletonLayout.academic),
      );
    }

    if (!canEditEvaluation) {
      return const UnauthorizedScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Capturar evaluación'),
        backgroundColor:
            isDarkMode ? AppColors.brandBlueSurface : AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: NetworkAwareModule(
        layout: AppSkeletonLayout.academic,
        child:
            _isLoading || !_studentAvailabilityChecked
                ? const ModuleLoadingSkeleton(
                  layout: AppSkeletonLayout.academic,
                )
                : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEvaluationHeader(isDarkMode),
                        const SizedBox(height: 18),
                        _buildGuidanceCard(isDarkMode),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          isDarkMode: isDarkMode,
                          title: 'Calificación',
                          icon: AppIcons.gradeRounded,
                          child:
                              isQualitativeEvaluation
                                  ? _buildQualitativeSelector(canEditEvaluation)
                                  : _buildQuantitativeField(canEditEvaluation),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          isDarkMode: isDarkMode,
                          title: 'Observaciones',
                          icon: AppIcons.notesRounded,
                          child: TextField(
                            controller: _feedbackController,
                            readOnly: !canEditEvaluation,
                            maxLines: 4,
                            decoration: _fieldDecoration(
                              hintText: 'Escribe tu retroalimentación...',
                              errorText: _validateFeedback(
                                _feedbackController.text,
                              ),
                            ),
                            onChanged: (value) {
                              if (canEditEvaluation) {
                                setState(() {});
                              }
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(
                                  r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s.,;:¡!¿?()\-"]',
                                ),
                              ),
                              LengthLimitingTextInputFormatter(500),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (_saveError != null) ...[
                          _buildSaveErrorBanner(isDarkMode),
                          const SizedBox(height: 14),
                        ],

                        if (canEditEvaluation)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isValidEvaluation() && !_isSaving
                                      ? _saveEvaluation
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                disabledBackgroundColor:
                                    isDarkMode
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : const Color(0xFFE5EAF0),
                                foregroundColor: Colors.white,
                                disabledForegroundColor:
                                    isDarkMode
                                        ? Colors.white38
                                        : Colors.black38,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                              icon:
                                  _isSaving
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(AppIcons.saveRounded),
                              label: Text(
                                _isSaving
                                    ? 'Guardando...'
                                    : 'Guardar evaluación',
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Modo consulta. Solo el profesor asignado puede modificar esta evaluación.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildEvaluationHeader(bool isDarkMode) {
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: widget.group.color.withValues(
                      alpha: isDarkMode ? 0.20 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(
                    AppIcons.personRounded,
                    color: widget.group.color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.group.name,
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
                  icon: AppIcons.menuBookRounded,
                  label: widget.subject.name,
                  color: AppColors.primaryBlue,
                ),
                _InfoPill(
                  icon: AppIcons.eventNoteRounded,
                  label: '${widget.selectedTerm}° Trim.',
                  color: AppColors.primaryGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDarkMode,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(
                alpha: isDarkMode ? 0.24 : 0.12,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              AppIcons.lightbulbOutlineRounded,
              color: AppColors.primaryBlue,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Selecciona el avance del alumno y agrega una observación breve si aporta contexto.',
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

  Widget _buildSaveErrorBanner(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryRed.withValues(
            alpha: isDarkMode ? 0.36 : 0.20,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.errorOutlineRounded, color: AppColors.primaryRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _saveError!,
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

  // Selector de evaluación cualitativa (preescolar)
  Widget _buildQualitativeSelector(bool canEditEvaluation) {
    return Column(
      children:
          _qualitativeOptions.map((option) {
            final isSelected = _qualitativeValue == option;
            final optionColor = _qualitativeColor(option);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QualitativeOptionTile(
                label: option,
                color: optionColor,
                icon: _qualitativeIcon(option),
                description: _qualitativeDescription(option),
                isSelected: isSelected,
                isEnabled: canEditEvaluation,
                onTap:
                    canEditEvaluation
                        ? () => setState(() => _qualitativeValue = option)
                        : null,
              ),
            );
          }).toList(),
    );
  }

  Color _qualitativeColor(String option) {
    switch (option.toLowerCase()) {
      case 'excelente':
        return AppColors.primaryGreen;
      case 'bueno':
        return AppColors.primaryBlue;
      case 'en desarrollo':
        return AppColors.primaryOrange;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _qualitativeIcon(String option) {
    switch (option.toLowerCase()) {
      case 'excelente':
        return AppIcons.starRounded;
      case 'bueno':
        return AppIcons.thumbUpAltRounded;
      case 'en desarrollo':
        return AppIcons.trendingUpRounded;
      default:
        return AppIcons.checkCircleRounded;
    }
  }

  String _qualitativeDescription(String option) {
    switch (option.toLowerCase()) {
      case 'excelente':
        return 'Domina el aprendizaje esperado.';
      case 'bueno':
        return 'Avanza de forma adecuada.';
      case 'en desarrollo':
        return 'Requiere mayor acompañamiento.';
      default:
        return 'Selecciona esta opción.';
    }
  }

  // Campo de evaluación cuantitativa (otros grupos)
  Widget _buildQuantitativeField(bool canEditEvaluation) {
    return TextFormField(
      initialValue: _quantitativeValue?.toString(),
      readOnly: !canEditEvaluation,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _fieldDecoration(
        hintText: 'Ingresa una calificación (6.0 a 10)',
        suffixText: '/ 10',
        errorText:
            (_quantitativeValue != null &&
                    (_quantitativeValue! < 6.0 || _quantitativeValue! > 10.0))
                ? 'Debe estar entre 6.0 y 10'
                : null,
      ),
      onChanged: (val) {
        if (!canEditEvaluation) return;
        final parsed = double.tryParse(val);
        setState(() {
          _quantitativeValue = parsed;
        });
      },
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    String? suffixText,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixText: suffixText,
      errorText: errorText,
      filled: true,
      fillColor:
          Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBackground
              : AppColors.softBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5EAF0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
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
        maxWidth: MediaQuery.sizeOf(context).width - 48,
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

class _QualitativeOptionTile extends StatelessWidget {
  const _QualitativeOptionTile({
    required this.label,
    required this.color,
    required this.icon,
    required this.description,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final String description;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isEnabled
            ? AppColors.textPrimary(context)
            : AppColors.textSecondary(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            isSelected
                ? color.withValues(alpha: isDarkMode ? 0.22 : 0.12)
                : isDarkMode
                ? AppColors.darkBackground
                : AppColors.softBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isSelected
                  ? color
                  : isDarkMode
                  ? Colors.white10
                  : const Color(0xFFE5EAF0),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDarkMode ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected ? color : AppColors.borderColor(context),
                      width: 1.5,
                    ),
                  ),
                  child:
                      isSelected
                          ? const Icon(
                            AppIcons.checkRounded,
                            color: Colors.white,
                            size: 16,
                          )
                          : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
