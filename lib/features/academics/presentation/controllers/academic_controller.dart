import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/core/utils/user_error_messages.dart';

import '../../data/models/academic_period_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/repositories/academic_repository.dart';

class AcademicController extends ChangeNotifier {
  AcademicController({
    required AcademicRepository repository,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _repository = repository;

  final AcademicRepository _repository;
  final String schoolId;

  List<SubjectModel> _subjects = [];
  List<AcademicPeriodModel> _periods = [];
  bool _subjectsLoading = false;
  bool _periodsLoading = false;
  String? _errorMessage;
  StreamSubscription<List<SubjectModel>>? _subjectsSubscription;
  StreamSubscription<List<AcademicPeriodModel>>? _periodsSubscription;
  Timer? _initialLoadTimer;

  List<SubjectModel> get subjects => List.unmodifiable(_subjects);
  List<AcademicPeriodModel> get periods => List.unmodifiable(_periods);
  bool get isLoading => _subjectsLoading || _periodsLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadSubjectsByGroup(String groupId) async {
    _listenToSubjects(
      _repository.watchSubjectsByGroup(schoolId: schoolId, groupId: groupId),
      errorPrefix: 'Error al cargar materias',
    );
  }

  Future<void> loadActivePeriods() async {
    _listenToPeriods(
      _repository.watchActivePeriods(schoolId: schoolId),
      errorPrefix: 'Error al cargar periodos',
    );
  }

  Future<void> loadEvaluationContext(String groupId) async {
    loadSubjectsByGroup(groupId);
    loadActivePeriods();
  }

  void _listenToSubjects(
    Stream<List<SubjectModel>> stream, {
    required String errorPrefix,
  }) {
    _subjectsSubscription?.cancel();
    _subjectsLoading = true;
    _errorMessage = null;
    _startInitialLoadTimeout();
    notifyListeners();

    _subjectsSubscription = stream.listen((subjects) {
      _subjects = subjects;
      _subjectsLoading = false;
      _errorMessage = null;
      _cancelTimeoutIfReady();
      notifyListeners();
    }, onError: (Object error) => _handleStreamError(error, errorPrefix));
  }

  void _listenToPeriods(
    Stream<List<AcademicPeriodModel>> stream, {
    required String errorPrefix,
  }) {
    _periodsSubscription?.cancel();
    _periodsLoading = true;
    _errorMessage = null;
    _startInitialLoadTimeout();
    notifyListeners();

    _periodsSubscription = stream.listen((periods) {
      _periods = periods;
      _periodsLoading = false;
      _errorMessage = null;
      _cancelTimeoutIfReady();
      notifyListeners();
    }, onError: (Object error) => _handleStreamError(error, errorPrefix));
  }

  void _handleStreamError(Object error, String errorPrefix) {
    _initialLoadTimer?.cancel();
    _errorMessage = userFriendlyErrorMessage(
      error,
      fallback: '$errorPrefix. Intenta nuevamente.',
    );
    _subjectsLoading = false;
    _periodsLoading = false;
    notifyListeners();
  }

  void _startInitialLoadTimeout() {
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(const Duration(seconds: 12), () {
      if (!isLoading) return;
      _subjectsLoading = false;
      _periodsLoading = false;
      _errorMessage =
          'La conexión está tardando demasiado. Revisa tu internet e intenta nuevamente.';
      notifyListeners();
    });
  }

  void _cancelTimeoutIfReady() {
    if (!isLoading) _initialLoadTimer?.cancel();
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    _periodsSubscription?.cancel();
    _initialLoadTimer?.cancel();
    super.dispose();
  }
}
