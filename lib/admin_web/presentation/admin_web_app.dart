import 'package:flutter/material.dart';

import 'screens/admin_auth_gate.dart';
import 'theme/admin_theme.dart';

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key, required this.themeController});

  final AdminThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AdminThemeScope(
      controller: themeController,
      child: ListenableBuilder(
        listenable: themeController,
        builder:
            (context, _) => MaterialApp(
              title: 'Panel Admin Cintli',
              debugShowCheckedModeBanner: false,
              theme: AdminThemeData.light,
              darkTheme: AdminThemeData.dark,
              themeMode: themeController.themeMode,
              themeAnimationDuration: const Duration(milliseconds: 280),
              themeAnimationCurve: Curves.easeOutCubic,
              home: const AdminAuthGate(),
            ),
      ),
    );
  }
}
