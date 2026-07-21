import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/core/utils/user_error_messages.dart';

import '../../data/models/calendar_event_model.dart';
import '../../data/repositories/calendar_repository.dart';

class CalendarController extends ChangeNotifier {
  CalendarController({
    required CalendarRepository repository,
    FirebaseAuth? auth,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _repository = repository,
       _auth = auth ?? FirebaseAuth.instance;

  final CalendarRepository _repository;
  final FirebaseAuth _auth;
  final String schoolId;

  List<CalendarEventModel> _events = [];
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _canReadAllEvents = false;
  List<String> _visibleGroupIds = const [];
  String? _errorMessage;
  StreamSubscription<List<CalendarEventModel>>? _eventsSubscription;
  Timer? _initialLoadTimer;

  List<CalendarEventModel> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  bool get isAdmin => _isAdmin;
  String? get errorMessage => _errorMessage;

  Future<void> initialize({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await loadUserAudience();
    watchEvents(startDate: startDate, endDate: endDate);
  }

  Future<void> loadAdminStatus() async {
    await loadUserAudience();
  }

  Future<void> loadUserAudience() async {
    final user = _auth.currentUser;
    if (user == null) {
      _isAdmin = false;
      _canReadAllEvents = false;
      _visibleGroupIds = const [];
      notifyListeners();
      return;
    }

    try {
      final audience = await _repository.getUserAudience(
        schoolId: schoolId,
        userId: user.uid,
      );
      _isAdmin = audience.isAdmin;
      _canReadAllEvents = audience.canReadAll;
      _visibleGroupIds = audience.groupIds;
    } catch (_) {
      _isAdmin = false;
      _canReadAllEvents = false;
      _visibleGroupIds = const [];
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _repository
          .getPublishedEvents(
            schoolId: schoolId,
            startDate: DateUtils.dateOnly(startDate),
            endDate: DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
              23,
              59,
              59,
            ),
            canReadAll: _canReadAllEvents,
            visibleGroupIds: _visibleGroupIds,
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      _events = [];
      _errorMessage = userFriendlyErrorMessage(
        e,
        fallback: 'No se pudo cargar el calendario. Intenta nuevamente.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void watchEvents({required DateTime startDate, required DateTime endDate}) {
    _eventsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    _startInitialLoadTimeout();
    notifyListeners();

    _eventsSubscription = _repository
        .watchPublishedEvents(
          schoolId: schoolId,
          startDate: DateUtils.dateOnly(startDate),
          endDate: DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
            23,
            59,
            59,
          ),
          canReadAll: _canReadAllEvents,
          visibleGroupIds: _visibleGroupIds,
        )
        .listen(
          (events) {
            _initialLoadTimer?.cancel();
            _events = events;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error) {
            _initialLoadTimer?.cancel();
            _events = [];
            _isLoading = false;
            _errorMessage = userFriendlyErrorMessage(
              error,
              fallback: 'No se pudo cargar el calendario. Intenta nuevamente.',
            );
            notifyListeners();
          },
        );
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

  List<CalendarEventModel> eventsForDay(DateTime day) {
    final selectedDay = DateUtils.dateOnly(day);

    return _events
        .where((event) {
          return DateUtils.isSameDay(event.eventDate, selectedDay);
        })
        .toList(growable: false);
  }

  List<CalendarEventModel> upcomingEvents({
    required DateTime afterDay,
    int limit = 5,
  }) {
    final referenceDay = DateUtils.dateOnly(afterDay);
    final upcoming =
        _events.where((event) {
            return DateUtils.dateOnly(event.eventDate).isAfter(referenceDay);
          }).toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return upcoming.take(limit).toList(growable: false);
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime eventDate,
    required List<String> targetGroupIds,
    String? startTime,
    String? endTime,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    if (!_isAdmin) {
      throw Exception('No tienes permisos para crear eventos');
    }

    final now = DateTime.now();
    final event = CalendarEventModel(
      id: '',
      schoolId: schoolId,
      title: title,
      description: description,
      eventDate: DateUtils.dateOnly(eventDate),
      startTime: startTime,
      endTime: endTime,
      status: 'published',
      visibility: targetGroupIds.contains('all') ? 'school' : 'groups',
      targetGroupIds: targetGroupIds,
      createdBy: user.uid,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.createEvent(event);
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _initialLoadTimer?.cancel();
    super.dispose();
  }
}
