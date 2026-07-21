import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prototipo_2/admin_web/presentation/theme/admin_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses the system theme when no preference has been saved', () async {
    final controller = await AdminThemeController.load();

    expect(controller.preference, AdminThemePreference.system);
    expect(controller.themeMode, ThemeMode.system);
  });

  test('persists the selected admin theme', () async {
    final controller = await AdminThemeController.load();

    await controller.setPreference(AdminThemePreference.dark);
    final restoredController = await AdminThemeController.load();

    expect(restoredController.preference, AdminThemePreference.dark);
    expect(restoredController.themeMode, ThemeMode.dark);
  });
}
