import '../models/news_model.dart';

class NewsUserAudience {
  const NewsUserAudience({
    required this.canReadAll,
    required this.groupIds,
    required this.isAdmin,
  });

  final bool canReadAll;
  final List<String> groupIds;
  final bool isAdmin;
}

abstract class NewsRepository {
  Stream<List<NewsModel>> watchPublishedNews({
    required String schoolId,
    required bool canReadAll,
    required List<String> visibleGroupIds,
  });

  Future<List<NewsModel>> getPublishedNews({
    required String schoolId,
    required bool canReadAll,
    required List<String> visibleGroupIds,
  });

  Future<void> createNews(NewsModel news);

  Future<bool> isAdmin({required String schoolId, required String userId});

  Future<NewsUserAudience> getUserAudience({
    required String schoolId,
    required String userId,
  });
}
