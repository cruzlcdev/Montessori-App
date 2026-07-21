import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../features/directory/data/models/school_group_model.dart';
import '../../features/news/data/models/news_model.dart';

class AdminNewsRepository {
  AdminNewsRepository({
    FirebaseFirestore? firestore,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String schoolId;

  CollectionReference<Map<String, dynamic>> get _newsCollection {
    return _firestore.collection('schools').doc(schoolId).collection('news');
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
        .collection('newsAudience')
        .doc(groupId)
        .collection('items');
  }

  Stream<List<NewsModel>> watchNews() {
    return _newsCollection.snapshots().map((snapshot) {
      final news =
          snapshot.docs.map(NewsModel.fromFirestore).toList()
            ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      return news;
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

  Future<void> createNews({
    required String title,
    required String content,
    required List<String> targetGroupIds,
    required String authorId,
    required String authorName,
    required String? authorEmail,
    required DateTime expiresAt,
  }) async {
    _ensureFutureExpiration(expiresAt);
    final now = Timestamp.now();
    final publishedAt = Timestamp.fromDate(DateTime.now());
    final visibility = targetGroupIds.contains('all') ? 'school' : 'groups';
    final data = <String, dynamic>{
      'schoolId': schoolId,
      'title': title.trim(),
      'content': content.trim(),
      'targetGroupIds': targetGroupIds,
      'visibility': visibility,
      'authorId': authorId,
      'authorName': authorName.trim().isEmpty ? 'Administrador' : authorName,
      'authorEmail': authorEmail,
      'status': 'published',
      'publishedAt': publishedAt,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'imageUrl': null,
      'createdAt': now,
      'updatedAt': now,
    };

    final docRef = await _newsCollection.add(data);
    await _syncAudienceCopies(newsId: docRef.id, data: data);
  }

  Future<void> updateNews({
    required NewsModel news,
    required String title,
    required String content,
    required List<String> targetGroupIds,
    required DateTime expiresAt,
  }) async {
    _ensureFutureExpiration(expiresAt);
    final previousGroupIds = news.targetGroupIds;
    final visibility = targetGroupIds.contains('all') ? 'school' : 'groups';
    final data = <String, dynamic>{
      'schoolId': schoolId,
      'title': title.trim(),
      'content': content.trim(),
      'targetGroupIds': targetGroupIds,
      'visibility': visibility,
      'authorId': news.authorId,
      'authorName': news.authorName,
      'authorEmail': news.authorEmail,
      'status': news.status,
      'publishedAt': Timestamp.fromDate(news.publishedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'imageUrl': news.imageUrl,
      'createdAt': Timestamp.fromDate(news.createdAt),
      'updatedAt': Timestamp.now(),
    };

    await _newsCollection.doc(news.id).set(data);
    await _syncAudienceCopies(
      newsId: news.id,
      data: data,
      previousGroupIds: previousGroupIds,
    );
  }

  Future<void> archiveNews(NewsModel news) async {
    await _newsCollection.doc(news.id).update({
      'status': 'archived',
      'updatedAt': Timestamp.now(),
    });

    await _deleteAudienceCopies(news.id, news.targetGroupIds);
  }

  Future<void> publishNews(NewsModel news) async {
    await _newsCollection.doc(news.id).update({
      'status': 'published',
      'updatedAt': Timestamp.now(),
    });

    final snapshot = await _newsCollection.doc(news.id).get();
    final data = snapshot.data();
    if (data == null) return;

    await _syncAudienceCopies(newsId: news.id, data: data);
  }

  Future<void> deleteNews(NewsModel news) async {
    await _newsCollection.doc(news.id).delete();
    await _deleteAudienceCopies(news.id, news.targetGroupIds);
  }

  Future<void> _syncAudienceCopies({
    required String newsId,
    required Map<String, dynamic> data,
    List<String> previousGroupIds = const [],
  }) async {
    final nextGroupIds = _groupOnlyIds(data['targetGroupIds']);
    final oldGroupIds = _groupOnlyIds(previousGroupIds);
    final batch = _firestore.batch();

    for (final groupId in oldGroupIds.where(
      (id) => !nextGroupIds.contains(id),
    )) {
      batch.delete(_audienceCollection(groupId).doc(newsId));
    }

    for (final groupId in nextGroupIds) {
      batch.set(_audienceCollection(groupId).doc(newsId), data);
    }

    await batch.commit();
  }

  Future<void> _deleteAudienceCopies(
    String newsId,
    List<String> targetGroupIds,
  ) async {
    final batch = _firestore.batch();
    for (final groupId in _groupOnlyIds(targetGroupIds)) {
      batch.delete(_audienceCollection(groupId).doc(newsId));
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

  void _ensureFutureExpiration(DateTime expiresAt) {
    if (!expiresAt.isAfter(DateTime.now())) {
      throw ArgumentError(
        'La fecha y hora de finalización deben ser posteriores al momento actual.',
      );
    }
  }
}
