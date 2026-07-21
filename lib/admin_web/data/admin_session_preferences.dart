import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSessionPreferences {
  const AdminSessionPreferences._();

  static const String _keepSignedInKey = 'admin_web_keep_signed_in';

  static Future<bool> keepSignedIn() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keepSignedInKey) ?? true;
  }

  static Future<void> applySavedPreference() async {
    await _applyPersistence(await keepSignedIn());
  }

  static Future<void> setKeepSignedIn(bool value) async {
    await _applyPersistence(value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_keepSignedInKey, value);
  }

  static Future<void> _applyPersistence(bool keepSignedIn) {
    return FirebaseAuth.instance.setPersistence(
      keepSignedIn ? Persistence.LOCAL : Persistence.SESSION,
    );
  }
}
