import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/core/utils/user_error_messages.dart';

import '../../data/models/school_group_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/teacher_model.dart';
import '../../data/repositories/directory_repository.dart';

class DirectoryController extends ChangeNotifier {
  DirectoryController({
    required DirectoryRepository repository,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _repository = repository;

  final DirectoryRepository _repository;
  final String schoolId;

  List<SchoolGroupModel> _groups = [];
  List<StudentModel> _students = [];
  List<TeacherModel> _teachers = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<SchoolGroupModel>>? _groupsSubscription;
  StreamSubscription<List<StudentModel>>? _studentsSubscription;
  StreamSubscription<List<TeacherModel>>? _teachersSubscription;
  Timer? _initialLoadTimer;

  List<SchoolGroupModel> get groups => List.unmodifiable(_groups);
  List<StudentModel> get students => List.unmodifiable(_students);
  List<TeacherModel> get teachers => List.unmodifiable(_teachers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadGroups() async {
    _listenToGroups(
      _repository.watchGroups(schoolId: schoolId),
      errorPrefix: 'Error al cargar grupos',
    );
  }

  Future<void> loadGroupsByIds(List<String> groupIds) async {
    _listenToGroups(
      _repository.watchGroupsByIds(schoolId: schoolId, groupIds: groupIds),
      errorPrefix: 'Error al cargar grupos',
    );
  }

  Future<void> loadStudentsByGroup(String groupId) async {
    _listenToStudents(
      _repository.watchStudentsByGroup(schoolId: schoolId, groupId: groupId),
      errorPrefix: 'Error al cargar estudiantes',
    );
  }

  Future<void> loadTeachersByGroup(String groupId) async {
    _listenToTeachers(
      _repository.watchTeachersByGroup(schoolId: schoolId, groupId: groupId),
      errorPrefix: 'Error al cargar profesores',
    );
  }

  Future<void> loadStudentsByIds(List<String> studentIds) async {
    _listenToStudents(
      _repository.watchStudentsByIds(
        schoolId: schoolId,
        studentIds: studentIds,
      ),
      errorPrefix: 'Error al cargar estudiantes',
    );
  }

  void _listenToGroups(
    Stream<List<SchoolGroupModel>> stream, {
    required String errorPrefix,
  }) {
    _groupsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    _startInitialLoadTimeout();
    notifyListeners();

    _groupsSubscription = stream.listen((groups) {
      _initialLoadTimer?.cancel();
      _groups = groups;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }, onError: (Object error) => _handleStreamError(error, errorPrefix));
  }

  void _listenToStudents(
    Stream<List<StudentModel>> stream, {
    required String errorPrefix,
  }) {
    _studentsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    _startInitialLoadTimeout();
    notifyListeners();

    _studentsSubscription = stream.listen((students) {
      _initialLoadTimer?.cancel();
      _students = students;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }, onError: (Object error) => _handleStreamError(error, errorPrefix));
  }

  void _listenToTeachers(
    Stream<List<TeacherModel>> stream, {
    required String errorPrefix,
  }) {
    _teachersSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    _startInitialLoadTimeout();
    notifyListeners();

    _teachersSubscription = stream.listen((teachers) {
      _initialLoadTimer?.cancel();
      _teachers = teachers;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }, onError: (Object error) => _handleStreamError(error, errorPrefix));
  }

  void _handleStreamError(Object error, String errorPrefix) {
    _initialLoadTimer?.cancel();
    _errorMessage = userFriendlyErrorMessage(
      error,
      fallback: '$errorPrefix. Intenta nuevamente.',
    );
    _isLoading = false;
    notifyListeners();
  }

  void _startInitialLoadTimeout() {
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(const Duration(seconds: 12), () {
      if (!_isLoading) return;
      _isLoading = false;
      _errorMessage =
          'La conexión está tardando demasiado. Revisa tu internet e intenta nuevamente.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _studentsSubscription?.cancel();
    _teachersSubscription?.cancel();
    _initialLoadTimer?.cancel();
    super.dispose();
  }
}
