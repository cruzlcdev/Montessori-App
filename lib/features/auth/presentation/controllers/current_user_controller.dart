import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:prototipo_2/core/constants/app_constants.dart';
import 'package:prototipo_2/core/utils/user_error_messages.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/current_user_repository.dart';

class CurrentUserController extends ChangeNotifier {
  CurrentUserController({
    required CurrentUserRepository repository,
    FirebaseAuth? auth,
    this.schoolId = AppConstants.defaultSchoolId,
  }) : _repository = repository,
       _auth = auth ?? FirebaseAuth.instance {
    _authSubscription = _auth.authStateChanges().listen((user) {
      loadCurrentUser(authUser: user);
    });
  }

  final CurrentUserRepository _repository;
  final FirebaseAuth _auth;
  final String schoolId;
  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<AppUser?>? _profileSubscription;
  Future<AppUser?>? _pendingProfileLoad;
  String? _pendingProfileUid;

  AppUser? _user;
  bool _isLoading = true;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _auth.currentUser != null;
  bool get isAdmin => _user?.isAdmin == true && _user?.isActive == true;
  bool get isTeacher => _user?.isTeacher == true && _user?.isActive == true;
  bool get isParent => _user?.isParent == true && _user?.isActive == true;
  bool get isStaff => _user?.isStaff == true && _user?.isActive == true;
  bool get hasActiveProfile => _user?.isActive == true;
  bool get hasSupportedRole {
    final role = _user?.role;
    return role == 'owner' ||
        role == 'admin' ||
        role == 'teacher' ||
        role == 'parent';
  }

  bool get hasAppAccess => hasActiveProfile && hasSupportedRole;

  Future<AppUser?> loadCurrentUser({User? authUser}) {
    final currentAuthUser = authUser ?? _auth.currentUser;
    final uid = currentAuthUser?.uid;

    if (uid != null &&
        _pendingProfileUid == uid &&
        _pendingProfileLoad != null) {
      return _pendingProfileLoad!;
    }

    final operation = _loadCurrentUser(currentAuthUser);
    if (uid == null) return operation;

    _pendingProfileUid = uid;
    _pendingProfileLoad = operation;
    unawaited(
      operation.whenComplete(() {
        if (_pendingProfileUid != uid) return;
        _pendingProfileUid = null;
        _pendingProfileLoad = null;
      }),
    );
    return operation;
  }

  Future<AppUser?> _loadCurrentUser(User? currentAuthUser) async {
    if (currentAuthUser == null) {
      await _profileSubscription?.cancel();
      _profileSubscription = null;
      _user = null;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _repository
          .getCurrentUserProfile(schoolId: schoolId, uid: currentAuthUser.uid)
          .timeout(const Duration(seconds: 12));

      if (_user == null) {
        _errorMessage = 'Tu usuario no tiene perfil activo en la escuela.';
      } else if (!_user!.isActive) {
        _errorMessage = 'Tu perfil está inactivo. Contacta a la escuela.';
      } else if (!hasSupportedRole) {
        _errorMessage = 'Tu rol no tiene acceso a la aplicación móvil.';
      }

      _watchCurrentUserProfile(currentAuthUser.uid);
    } catch (e) {
      _user = null;
      _errorMessage = userFriendlyErrorMessage(
        e,
        fallback: 'No se pudo cargar tu perfil. Intenta nuevamente.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _user;
  }

  void _watchCurrentUserProfile(String uid) {
    _profileSubscription?.cancel();
    _profileSubscription = _repository
        .watchCurrentUserProfile(schoolId: schoolId, uid: uid)
        .listen(
          (profile) {
            _user = profile;
            _isLoading = false;

            if (profile == null) {
              _errorMessage =
                  'Tu usuario no tiene perfil activo en la escuela.';
            } else if (!profile.isActive) {
              _errorMessage = 'Tu perfil está inactivo. Contacta a la escuela.';
            } else if (!hasSupportedRole) {
              _errorMessage = 'Tu rol no tiene acceso a la aplicación móvil.';
            } else {
              _errorMessage = null;
            }

            notifyListeners();
          },
          onError: (Object error) {
            _user = null;
            _isLoading = false;
            _errorMessage = userFriendlyErrorMessage(
              error,
              fallback: 'No se pudo actualizar tu perfil. Intenta nuevamente.',
            );
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
