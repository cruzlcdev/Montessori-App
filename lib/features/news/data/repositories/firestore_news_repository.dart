import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/news_model.dart';
import 'news_repository.dart';

class FirestoreNewsRepository implements NewsRepository {
  FirestoreNewsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _newsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('news');
  }

  CollectionReference<Map<String, dynamic>> _groupNewsCollection(
    String schoolId,
    String groupId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('newsAudience')
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
  Stream<List<NewsModel>> watchPublishedNews({
    required String schoolId,
    required bool canReadAll,
    required List<String> visibleGroupIds,
  }) {
    if (canReadAll) {
      return _newsCollection(schoolId)
          .where('status', isEqualTo: 'published')
          .snapshots()
          .map(_readPublishedNews);
    }

    return _watchAudienceNews(
      schoolId: schoolId,
      visibleGroupIds: visibleGroupIds,
    );
  }

  @override
  Future<List<NewsModel>> getPublishedNews({
    required String schoolId,
    required bool canReadAll,
    required List<String> visibleGroupIds,
  }) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    if (canReadAll) {
      try {
        final snapshot =
            await _newsCollection(
              schoolId,
            ).where('status', isEqualTo: 'published').get();
        docs = snapshot.docs;
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') return const [];
        rethrow;
      }
    } else {
      docs = await _getAudienceNewsDocs(
        schoolId: schoolId,
        visibleGroupIds: visibleGroupIds,
      );
    }

    final news = docs
        .map(NewsModel.fromFirestore)
        .where((news) => news.status == 'published' && !news.isExpired)
        .toList(growable: false);

    news.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return news;
  }

  Stream<List<NewsModel>> _watchAudienceNews({
    required String schoolId,
    required List<String> visibleGroupIds,
  }) {
    final controller = StreamController<List<NewsModel>>();
    final docsByAudience = <String, Map<String, NewsModel>>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final docsById = <String, NewsModel>{};
      for (final newsById in docsByAudience.values) {
        docsById.addAll(newsById);
      }

      final news = docsById.values
          .where((news) => news.status == 'published' && !news.isExpired)
          .toList(growable: false)
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      if (!controller.isClosed) controller.add(news);
    }

    void listenToAudience(
      String audienceId,
      Query<Map<String, dynamic>> query,
    ) {
      final subscription = query.snapshots().listen(
        (snapshot) {
          docsByAudience[audienceId] = {
            for (final doc in snapshot.docs)
              doc.id: NewsModel.fromFirestore(doc),
          };
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );

      subscriptions.add(subscription);
    }

    listenToAudience(
      'school',
      _newsCollection(schoolId)
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
        _groupNewsCollection(
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

  List<NewsModel> _readPublishedNews(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final news = snapshot.docs
        .map(NewsModel.fromFirestore)
        .where((news) => news.status == 'published' && !news.isExpired)
        .toList(growable: false)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return news;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getAudienceNewsDocs({
    required String schoolId,
    required List<String> visibleGroupIds,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> generalSnapshot;
    try {
      generalSnapshot = await _schoolNewsQuery(schoolId: schoolId);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return const [];
      rethrow;
    }

    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in generalSnapshot.docs) {
      docsById[doc.id] = doc;
    }

    final groupIds = visibleGroupIds
        .where((groupId) => groupId.trim().isNotEmpty)
        .take(29)
        .toList(growable: false);

    for (final groupId in groupIds) {
      try {
        final snapshot = await _audienceNewsQuery(
          schoolId: schoolId,
          audienceId: groupId,
        );
        for (final doc in snapshot.docs) {
          docsById[doc.id] = doc;
        }
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }
    }

    return docsById.values.toList(growable: false);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _audienceNewsQuery({
    required String schoolId,
    required String audienceId,
  }) {
    return _groupNewsCollection(
      schoolId,
      audienceId,
    ).where('status', isEqualTo: 'published').get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _schoolNewsQuery({
    required String schoolId,
  }) {
    return _newsCollection(schoolId)
        .where('status', isEqualTo: 'published')
        .where('visibility', isEqualTo: 'school')
        .get();
  }

  @override
  Future<void> createNews(NewsModel news) async {
    final data = news.toCreateMap();
    final docRef = await _newsCollection(news.schoolId).add(data);

    if (news.targetGroupIds.contains('all')) return;

    final batch = _firestore.batch();
    for (final groupId in news.targetGroupIds) {
      final cleanGroupId = groupId.trim();
      if (cleanGroupId.isEmpty) continue;

      batch.set(
        _groupNewsCollection(news.schoolId, cleanGroupId).doc(docRef.id),
        data,
      );
    }

    await batch.commit();
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
  Future<NewsUserAudience> getUserAudience({
    required String schoolId,
    required String userId,
  }) async {
    final snapshot = await _userDocument(schoolId, userId).get();
    final data = snapshot.data() ?? {};
    final role = data['role']?.toString().toLowerCase();
    final isAdmin = role == 'owner' || role == 'admin';

    return NewsUserAudience(
      canReadAll: isAdmin,
      groupIds: _readStringList(data['groupIds']),
      isAdmin: isAdmin,
    );
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
