import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';

class AdminDashboardRepository {
  AdminDashboardRepository({
    FirebaseFirestore? firestore,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String schoolId;

  CollectionReference<Map<String, dynamic>> _schoolCollection(String name) {
    return _firestore.collection('schools').doc(schoolId).collection(name);
  }

  Stream<int> activeCount(String collectionName) {
    return _schoolCollection(collectionName).snapshots().map((snapshot) {
      return snapshot.docs.where((doc) {
        final status = doc.data()['status']?.toString().toLowerCase();
        return status == null || status == 'active';
      }).length;
    });
  }

  Stream<AdminMetricSnapshot> activeMetric(String collectionName) {
    return _schoolCollection(collectionName).snapshots().map((snapshot) {
      var active = 0;
      var total = 0;
      for (final doc in snapshot.docs) {
        final status =
            doc.data()['status']?.toString().toLowerCase() ?? 'active';
        if (status == 'archived') continue;
        total++;
        if (status == 'active') active++;
      }
      return AdminMetricSnapshot(value: active, total: total);
    });
  }

  Stream<AdminMetricSnapshot> activeFamiliesMetric() {
    return _schoolCollection('users').snapshots().map((snapshot) {
      var active = 0;
      var total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['role']?.toString().toLowerCase() != 'parent') continue;
        final status = data['status']?.toString().toLowerCase() ?? 'inactive';
        if (status == 'archived') continue;
        total++;
        if (status == 'active') active++;
      }
      return AdminMetricSnapshot(value: active, total: total);
    });
  }

  Stream<AdminMetricSnapshot> publishedMetric(String collectionName) {
    return _schoolCollection(collectionName).snapshots().map((snapshot) {
      var published = 0;
      var total = 0;
      for (final doc in snapshot.docs) {
        final status =
            doc.data()['status']?.toString().toLowerCase() ?? 'published';
        total++;
        if (status == 'published') published++;
      }
      return AdminMetricSnapshot(value: published, total: total);
    });
  }

  Stream<AdminMetricSnapshot> upcomingEventsMetric() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _schoolCollection('calendarEvents').snapshots().map((snapshot) {
      var upcoming = 0;
      var published = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase();
        if (status != 'published') continue;
        published++;
        final eventDate = _readDate(data['eventDate']);
        if (eventDate != null && !eventDate.isBefore(today)) upcoming++;
      }
      return AdminMetricSnapshot(value: upcoming, total: published);
    });
  }

  Stream<int> publishedCount(String collectionName) {
    return _schoolCollection(collectionName).snapshots().map((snapshot) {
      return snapshot.docs.where((doc) {
        final status = doc.data()['status']?.toString().toLowerCase();
        return status == 'published';
      }).length;
    });
  }

  Stream<int> upcomingEventsCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _schoolCollection('calendarEvents').snapshots().map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase();
        final eventDate = _readDate(data['eventDate']);
        return status == 'published' &&
            eventDate != null &&
            !eventDate.isBefore(today);
      }).length;
    });
  }

  Stream<List<AdminActivityItem>> recentNews() {
    return _schoolCollection('news').snapshots().map((snapshot) {
      final items =
          snapshot.docs.map((doc) {
              final data = doc.data();
              return AdminActivityItem(
                id: doc.id,
                title: data['title']?.toString() ?? 'Noticia sin titulo',
                subtitle: _audienceLabel(data['targetGroupIds']),
                status: data['status']?.toString() ?? 'published',
                date:
                    _readDate(data['publishedAt']) ??
                    _readDate(data['createdAt']) ??
                    DateTime.now(),
              );
            }).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      return items.take(5).toList(growable: false);
    });
  }

  Stream<List<AdminActivityItem>> upcomingEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _schoolCollection('calendarEvents').snapshots().map((snapshot) {
      final items =
          snapshot.docs
              .map((doc) {
                final data = doc.data();
                final eventDate = _readDate(data['eventDate']);
                if (eventDate == null || eventDate.isBefore(today)) {
                  return null;
                }

                return AdminActivityItem(
                  id: doc.id,
                  title: data['title']?.toString() ?? 'Evento sin titulo',
                  subtitle: _audienceLabel(data['targetGroupIds']),
                  status: data['status']?.toString() ?? 'published',
                  date: eventDate,
                );
              })
              .whereType<AdminActivityItem>()
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      return items.take(5).toList(growable: false);
    });
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static String _audienceLabel(dynamic value) {
    if (value is! List || value.isEmpty) return 'Sin audiencia';
    final ids = value.map((item) => item.toString()).toList(growable: false);
    if (ids.contains('all')) return 'Toda la escuela';
    if (ids.length == 1) return '1 grupo';
    return '${ids.length} grupos';
  }
}

class AdminActivityItem {
  const AdminActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final DateTime date;
}

class AdminMetricSnapshot {
  const AdminMetricSnapshot({required this.value, required this.total});

  final int value;
  final int total;

  double get ratio {
    if (total <= 0) return 0;
    return (value / total).clamp(0, 1);
  }

  int get percentage => (ratio * 100).round();
}
