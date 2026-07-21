import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/config/firebase_options.dart';
import '../core/utils/app_versions.dart';
import 'data/admin_session_preferences.dart';
import 'presentation/admin_web_app.dart';
import 'presentation/theme/admin_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es_MX');
  await AppVersions.loadAdminWeb();
  await AdminSessionPreferences.applySavedPreference();
  final themeController = await AdminThemeController.load();

  runApp(AdminWebApp(themeController: themeController));
}
