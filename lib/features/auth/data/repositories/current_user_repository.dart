import '../models/app_user.dart';

abstract class CurrentUserRepository {
  Stream<AppUser?> watchCurrentUserProfile({
    required String schoolId,
    required String uid,
  });

  Future<AppUser?> getCurrentUserProfile({
    required String schoolId,
    required String uid,
  });
}
