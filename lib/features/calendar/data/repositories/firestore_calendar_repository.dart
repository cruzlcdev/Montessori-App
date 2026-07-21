import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../models/calendar_event_model.dart';
import 'calendar_repository.dart';

class FirestoreCalendarRepository implements CalendarRepository {
  FirestoreCalendarRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _eventsCollection(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('calendarEvents');
  }

  CollectionReference<Map<String, dynamic>> _groupEventsCollection(
    String schoolId,
    String groupId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('calendarAudience')
        .doc(groupId)
        .collection('items');
  }

  DocumentReference<Map<String, dynamic>> _userDocument(
    String schoolId,
    String userId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .doc(userId);
  }

  @override
  Stream<List<CalendarEventModel>> watchPublishedEvents({
    required String schoolId,
    required DateTime startDate,
    required DateTime endDate,
    required bool canReadAll,
    required List<String> visibleGroupIds,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    if (canReadAll) {
      return _eventsCollection(schoolId)
          .where('status', isEqualTo: 'published')
          .snapshots()
          .map((snapshot) => _readPublishedEvents(snapshot, start, end));
    }

    return _watchAudienceEvents(
      schoolId: schoolId,
      startDate: start,
      endDate: end,
      visibleGroupIds: visibleGroupIds,
    );
  }

  @override
  Future<List<CalendarEventModel>> getPublishedEvents({
    required String schoolId,
    required DateTime startDate,
    required DateTime endDate,
    required bool canReadAll,
    required List<String> visibleGroupIds,
  }) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    if (canReadAll) {
      final snapshot =
          await _eventsCollection(
            schoolId,
          ).where('status', isEqualTo: 'published').get();
      docs = snapshot.docs;
    } else {
      docs = await _getAudienceEventDocs(
        schoolId: schoolId,
        visibleGroupIds: visibleGroupIds,
      );
    }

    final events = docs
        .map(CalendarEventModel.fromFirestore)
        .where((event) => _isInRange(event, startDate, endDate))
        .toList(growable: false);

    events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return events;
  }

  Stream<List<CalendarEventModel>> _watchAudienceEvents({
    required String schoolId,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> visibleGroupIds,
  }) {
    final controller = StreamController<List<CalendarEventModel>>();
    final docsByAudience = <String, Map<String, CalendarEventModel>>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final docsById = <String, CalendarEventModel>{};
      for (final eventsById in docsByAudience.values) {
        docsById.addAll(eventsById);
      }

      final events = docsById.values
          .where((event) => _isInRange(event, startDate, endDate))
          .toList(growable: false)
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

      if (!controller.isClosed) controller.add(events);
    }

    void listenToAudience(
      String audienceId,
      Query<Map<String, dynamic>> query,
    ) {
      final subscription = query.snapshots().listen(
        (snapshot) {
          docsByAudience[audienceId] = {
            for (final doc in snapshot.docs)
              doc.id: CalendarEventModel.fromFirestore(doc),
          };
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            docsByAudience[audienceId] = const {};
            emit();
            return;
          }

          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );

      subscriptions.add(subscription);
    }

    listenToAudience(
      'school',
      _eventsCollection(schoolId)
          .where('status', isEqualTo: 'published')
          .where('visibility', isEqualTo: 'school'),
    );

    final groupIds = visibleGroupIds
        .where((groupId) => groupId.trim().isNotEmpty)
        .take(29)
        .toList(growable: false);

    for (final groupId in groupIds) {
      listenToAudience(
        groupId,
        _groupEventsCollection(
          schoolId,
          groupId,
        ).where('status', isEqualTo: 'published'),
      );
    }

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  List<CalendarEventModel> _readPublishedEvents(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    DateTime startDate,
    DateTime endDate,
  ) {
    final events = snapshot.docs
        .map(CalendarEventModel.fromFirestore)
        .where((event) => _isInRange(event, startDate, endDate))
        .toList(growable: false)
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return events;
  }

  @override
  Future<void> createEvent(CalendarEventModel event) async {
    final data = event.toCreateMap();
    final docRef = await _eventsCollection(event.schoolId).add(data);

    if (event.targetGroupIds.contains('all')) return;

    final batch = _firestore.batch();
    for (final groupId in event.targetGroupIds) {
      final cleanGroupId = groupId.trim();
      if (cleanGroupId.isEmpty) continue;

      batch.set(
        _groupEventsCollection(event.schoolId, cleanGroupId).doc(docRef.id),
        data,
      );
    }

    await batch.commit();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getAudienceEventDocs({
    required String schoolId,
    required List<String> visibleGroupIds,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> schoolSnapshot;
    try {
      schoolSnapshot = await _schoolEventsQuery(schoolId: schoolId);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return const [];
      rethrow;
    }

    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in schoolSnapshot.docs) {
      docsById[doc.id] = doc;
    }

    final groupIds = visibleGroupIds
        .where((groupId) => groupId.trim().isNotEmpty)
        .take(29)
        .toList(growable: false);

    for (final groupId in groupIds) {
      try {
        final snapshot =
            await _groupEventsCollection(
              schoolId,
              groupId,
            ).where('status', isEqualTo: 'published').get();
        for (final doc in snapshot.docs) {
          docsById[doc.id] = doc;
        }
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }
    }

    return docsById.values.toList(growable: false);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _schoolEventsQuery({
    required String schoolId,
  }) {
    return _eventsCollection(schoolId)
        .where('status', isEqualTo: 'published')
        .where('visibility', isEqualTo: 'school')
        .get();
  }

  @override
  Future<bool> isAdmin({
    required String schoolId,
    required String userId,
  }) async {
    final snapshot = await _userDocument(schoolId, userId).get();
    final role = snapshot.data()?['role']?.toString().toLowerCase();

    return role == 'owner' || role == 'admin';
  }

  @override
  Future<CalendarUserAudience> getUserAudience({
    required String schoolId,
    required String userId,
  }) async {
    final snapshot = await _userDocument(schoolId, userId).get();
    final data = snapshot.data() ?? {};
    final role = data['role']?.toString().toLowerCase();
    final isAdmin = role == 'owner' || role == 'admin';

    return CalendarUserAudience(
      canReadAll: isAdmin,
      groupIds: _readStringList(data['groupIds']),
      isAdmin: isAdmin,
    );
  }

  bool _isInRange(
    CalendarEventModel event,
    DateTime startDate,
    DateTime endDate,
  ) {
    return !event.eventDate.isBefore(startDate) &&
        !event.eventDate.isAfter(endDate);
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
