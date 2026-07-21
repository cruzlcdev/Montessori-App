import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/core/utils/user_error_messages.dart';

import '../../data/models/news_model.dart';
import '../../data/repositories/news_repository.dart';

class NewsController extends ChangeNotifier {
  NewsController({
    required NewsRepository repository,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _repository = repository,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final NewsRepository _repository;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final String schoolId;
  StreamSubscription<List<NewsModel>>? _newsSubscription;
  Timer? _expirationTimer;
  Timer? _initialLoadTimer;

  List<NewsModel> _news = [];
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _canReadAllNews = false;
  List<String> _visibleGroupIds = const [];
  String? _errorMessage;

  List<NewsModel> get news => List.unmodifiable(_news);
  bool get isLoading => _isLoading;
  bool get isAdmin => _isAdmin;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _auth.currentUser;

  Future<void> initialize() async {
    await loadUserAudience();
    watchNews();
  }

  Future<void> loadAdminStatus() async {
    await loadUserAudience();
  }

  Future<void> loadUserAudience() async {
    final user = _auth.currentUser;
    if (user == null) {
      _isAdmin = false;
      _canReadAllNews = false;
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
      _canReadAllNews = audience.canReadAll;
      _visibleGroupIds = audience.groupIds;
      notifyListeners();
    } catch (_) {
      _isAdmin = false;
      _canReadAllNews = false;
      _visibleGroupIds = const [];
      notifyListeners();
    }
  }

  void watchNews() {
    _newsSubscription?.cancel();
    _expirationTimer?.cancel();

    _isLoading = true;
    _errorMessage = null;
    _startInitialLoadTimeout();
    notifyListeners();

    _newsSubscription = _repository
        .watchPublishedNews(
          schoolId: schoolId,
          canReadAll: _canReadAllNews,
          visibleGroupIds: _visibleGroupIds,
        )
        .listen(
          (news) {
            _initialLoadTimer?.cancel();
            _news = news;
            _isLoading = false;
            _errorMessage = null;
            _scheduleExpirationRefresh();
            notifyListeners();
          },
          onError: (Object error) {
            _initialLoadTimer?.cancel();
            _errorMessage = userFriendlyErrorMessage(
              error,
              fallback:
                  'No se pudieron cargar las noticias. Intenta nuevamente.',
            );
            _news = [];
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> loadNews() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _news = await _repository
          .getPublishedNews(
            schoolId: schoolId,
            canReadAll: _canReadAllNews,
            visibleGroupIds: _visibleGroupIds,
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      _errorMessage = userFriendlyErrorMessage(
        e,
        fallback: 'No se pudieron cargar las noticias. Intenta nuevamente.',
      );
      _news = [];
    } finally {
      _isLoading = false;
      _scheduleExpirationRefresh();
      notifyListeners();
    }
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

  Future<void> createNews({
    required String title,
    required String content,
    required List<String> targetGroupIds,
    required DateTime? expiresAt,
    File? image,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    if (!_isAdmin) {
      throw Exception('No tienes permisos para crear noticias');
    }

    final imageUrl = await _uploadImage(image);
    final now = DateTime.now();

    final news = NewsModel(
      id: '',
      schoolId: schoolId,
      title: title,
      content: content,
      targetGroupIds: targetGroupIds,
      authorId: user.uid,
      authorName: user.displayName ?? 'Administrador',
      authorEmail: user.email,
      status: 'published',
      publishedAt: now,
      createdAt: now,
      updatedAt: now,
      imageUrl: imageUrl,
      expiresAt: expiresAt,
    );

    await _repository.createNews(news);
  }

  Future<String?> _uploadImage(File? image) async {
    if (image == null) return null;

    final fileName = DateTime.now().microsecondsSinceEpoch;
    final storageRef = _storage.ref().child(
      'schools/$schoolId/news_images/$fileName.jpg',
    );

    await storageRef.putFile(image);
    return storageRef.getDownloadURL();
  }

  void _scheduleExpirationRefresh() {
    _expirationTimer?.cancel();

    final now = DateTime.now();
    final nextExpiration = _news
        .map((news) => news.expiresAt)
        .whereType<DateTime>()
        .where((date) => date.isAfter(now))
        .fold<DateTime?>(null, (current, date) {
          if (current == null || date.isBefore(current)) return date;
          return current;
        });

    if (nextExpiration == null) return;

    final delay = nextExpiration.difference(now) + const Duration(seconds: 1);
    _expirationTimer = Timer(delay, () {
      final currentTime = DateTime.now();
      _news = _news
          .where((news) {
            final expiresAt = news.expiresAt;
            return expiresAt == null || expiresAt.isAfter(currentTime);
          })
          .toList(growable: false);

      _scheduleExpirationRefresh();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _newsSubscription?.cancel();
    _expirationTimer?.cancel();
    _initialLoadTimer?.cancel();
    super.dispose();
  }
}
