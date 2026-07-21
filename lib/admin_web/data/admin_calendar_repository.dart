import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../features/calendar/data/models/calendar_event_model.dart';
import '../../features/directory/data/models/school_group_model.dart';

class AdminCalendarRepository {
  AdminCalendarRepository({
    FirebaseFirestore? firestore,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String schoolId;

  CollectionReference<Map<String, dynamic>> get _eventsCollection {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('calendarEvents');
  }

  CollectionReference<Map<String, dynamic>> get _groupsCollection {
    return _firestore.collection('schools').doc(schoolId).collection('groups');
  }

  CollectionReference<Map<String, dynamic>> _audienceCollection(
    String groupId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('calendarAudience')
        .doc(groupId)
        .collection('items');
  }

  Stream<List<CalendarEventModel>> watchEvents() {
    return _eventsCollection.snapshots().map((snapshot) {
      final events =
          snapshot.docs.map(CalendarEventModel.fromFirestore).toList()
            ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

      return events;
    });
  }

  Stream<List<SchoolGroupModel>> watchActiveGroups() {
    return _groupsCollection.snapshots().map((snapshot) {
      final groups =
          snapshot.docs
              .map(SchoolGroupModel.fromFirestore)
              .where((group) => group.status == 'active')
              .toList()
            ..sort((a, b) {
              final sortComparison = a.sortOrder.compareTo(b.sortOrder);
              if (sortComparison != 0) return sortComparison;
              return a.name.compareTo(b.name);
            });

      return groups;
    });
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime eventDate,
    required List<String> targetGroupIds,
    required String createdBy,
    String? startTime,
    String? endTime,
  }) async {
    final now = Timestamp.now();
    final visibility = targetGroupIds.contains('all') ? 'school' : 'groups';
    final data = <String, dynamic>{
      'schoolId': schoolId,
      'title': title.trim(),
      'description': description.trim(),
      'eventDate': Timestamp.fromDate(_dateOnly(eventDate)),
      'startTime': _cleanTime(startTime),
      'endTime': _cleanTime(endTime),
      'status': 'published',
      'visibility': visibility,
      'targetGroupIds': targetGroupIds,
      'createdBy': createdBy,
      'createdAt': now,
      'updatedAt': now,
    };

    final docRef = await _eventsCollection.add(data);
    await _syncAudienceCopies(eventId: docRef.id, data: data);
  }

  Future<void> updateEvent({
    required CalendarEventModel event,
    required String title,
    required String description,
    required DateTime eventDate,
    required List<String> targetGroupIds,
    String? startTime,
    String? endTime,
  }) async {
    final visibility = targetGroupIds.contains('all') ? 'school' : 'groups';
    final data = <String, dynamic>{
      'schoolId': schoolId,
      'title': title.trim(),
      'description': description.trim(),
      'eventDate': Timestamp.fromDate(_dateOnly(eventDate)),
      'startTime': _cleanTime(startTime),
      'endTime': _cleanTime(endTime),
      'status': event.status,
      'visibility': visibility,
      'targetGroupIds': targetGroupIds,
      'createdBy': event.createdBy,
      'createdAt': Timestamp.fromDate(event.createdAt),
      'updatedAt': Timestamp.now(),
    };

    await _eventsCollection.doc(event.id).set(data);
    await _syncAudienceCopies(
      eventId: event.id,
      data: data,
      previousGroupIds: event.targetGroupIds,
    );
  }

  Future<void> archiveEvent(CalendarEventModel event) async {
    await _eventsCollection.doc(event.id).update({
      'status': 'archived',
      'updatedAt': Timestamp.now(),
    });
    await _deleteAudienceCopies(event.id, event.targetGroupIds);
  }

  Future<void> publishEvent(CalendarEventModel event) async {
    await _eventsCollection.doc(event.id).update({
      'status': 'published',
      'updatedAt': Timestamp.now(),
    });

    final snapshot = await _eventsCollection.doc(event.id).get();
    final data = snapshot.data();
    if (data == null) return;

    await _syncAudienceCopies(eventId: event.id, data: data);
  }

  Future<void> deleteEvent(CalendarEventModel event) async {
    await _eventsCollection.doc(event.id).delete();
    await _deleteAudienceCopies(event.id, event.targetGroupIds);
  }

  Future<void> _syncAudienceCopies({
    required String eventId,
    required Map<String, dynamic> data,
    List<String> previousGroupIds = const [],
  }) async {
    final nextGroupIds = _groupOnlyIds(data['targetGroupIds']);
    final oldGroupIds = _groupOnlyIds(previousGroupIds);
    final batch = _firestore.batch();

    for (final groupId in oldGroupIds.where(
      (id) => !nextGroupIds.contains(id),
    )) {
      batch.delete(_audienceCollection(groupId).doc(eventId));
    }

    if (data['status'] == 'published') {
      for (final groupId in nextGroupIds) {
        batch.set(_audienceCollection(groupId).doc(eventId), data);
      }
    }

    await batch.commit();
  }

  Future<void> _deleteAudienceCopies(
    String eventId,
    List<String> targetGroupIds,
  ) async {
    final batch = _firestore.batch();
    for (final groupId in _groupOnlyIds(targetGroupIds)) {
      batch.delete(_audienceCollection(groupId).doc(eventId));
    }
    await batch.commit();
  }

  List<String> _groupOnlyIds(dynamic rawIds) {
    if (rawIds is! List) return const [];
    return rawIds
        .map((item) => item.toString().trim())
        .where((id) => id.isNotEmpty && id != 'all')
        .toSet()
        .toList(growable: false);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String? _cleanTime(String? value) {
    final cleanValue = value?.trim();
    return cleanValue == null || cleanValue.isEmpty ? null : cleanValue;
  }
}
