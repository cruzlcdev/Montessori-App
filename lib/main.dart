import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/config/app_feature_flags.dart';
import 'package:prototipo_2/features/auth/data/repositories/firestore_current_user_repository.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:prototipo_2/screens/calendar_screen.dart';
import 'package:prototipo_2/people/teachers_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'news/news_screen.dart';
import 'academics/grades_screen.dart';
import 'people/students_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/firebase_options.dart';
import 'screens/splash_screen.dart';
import 'features/auth/presentation/screens/unauthorized_screen.dart';
import 'core/theme/colors.dart'; // Manejo de colores personalizados
import 'core/utils/app_info.dart'; // Información de la app (versión, build, etc.)
import 'core/widgets/app_loading_skeleton.dart';
import 'core/connectivity/network_status_controller.dart';

// --------------------- CONTROL DE TEMA ---------------------
// Clase que maneja el modo claro/oscuro usando Provider
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  final SharedPreferences _prefs;

  ThemeNotifier(this._prefs) {
    // Al iniciar, cargamos la preferencia guardada en SharedPreferences
    _themeMode =
        _prefs.getBool('darkMode') ?? false ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeMode get themeMode => _themeMode;

  // Cambiar tema dinámicamente y guardar en SharedPreferences
  void toggleTheme(bool isDark) {
    final nextMode = isDark ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) return;

    _themeMode = nextMode;
    notifyListeners();
    unawaited(_prefs.setBool('darkMode', isDark));
  }
}

// --------------------- MAIN ---------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Estas tareas no dependen entre sí; ejecutarlas en paralelo reduce el tiempo
  // que Android e iOS permanecen esperando antes de montar la interfaz.
  final preferencesFuture = SharedPreferences.getInstance();
  await Future.wait<void>([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then<void>((_) {}),
    initializeDateFormatting('es_MX'),
    AppInfo.loadAppInfo(),
  ]);
  final prefs = await preferencesFuture;

  // MultiProvider: inyectamos estados globales (AppState y ThemeNotifier)
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => ThemeNotifier(prefs)),
        ChangeNotifierProvider(create: (context) => NetworkStatusController()),
        ChangeNotifierProvider(
          create:
              (context) => CurrentUserController(
                repository: FirestoreCurrentUserRepository(),
              ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

// --------------------- RAÍZ DE LA APP ---------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<ThemeNotifier, ThemeMode>(
      (notifier) => notifier.themeMode,
    );

    return MaterialApp(
      title: 'Cintli Montessori',

      // ---------- Tema claro ----------
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: AppColors.primaryBlue,
        fontFamily: 'LettersForLearners',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
        ),
      ),

      // ---------- Tema oscuro ----------
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: AppColors.primaryBlue,
        fontFamily: 'LettersForLearners',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        cardColor: AppColors.darkSurface,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryBlue,
          secondary: AppColors.primaryTurquoise,
          surface: AppColors.darkSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.brandBlueSurface,
          foregroundColor: Colors.white,
        ),

        /*cardTheme: CardTheme(
          color: Colors.grey[800],
        ),*/
      ),

      // Cambia dinámicamente según ThemeNotifier (modo claro/oscuro)
      themeMode: themeMode,

      builder: (context, child) {
        final accessState = context.select<
          CurrentUserController,
          ({bool authenticated, bool loading, bool hasAccess})
        >(
          (controller) => (
            authenticated: controller.isAuthenticated,
            loading: controller.isLoading,
            hasAccess: controller.hasAppAccess,
          ),
        );

        if (!accessState.authenticated) {
          return child ?? const SizedBox.shrink();
        }

        if (accessState.loading) {
          // Preserve the current route while the live profile refreshes.
          // Replacing the Navigator here remounts the splash and restarts it.
          return child ?? const SizedBox.shrink();
        }

        if (!accessState.hasAccess) {
          return const UnauthorizedScreen();
        }

        return child ?? const SizedBox.shrink();
      },

      // Pantalla inicial → SplashScreen
      initialRoute: '/splash',

      // ---------- Rutas de la aplicación ----------
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LoginScreen(),
        '/home': (context) => const AppAccessPage(child: HomeScreen()),
        '/news':
            (context) => const MobileFeaturePage(
              allowDisabledMobileAdmin: AppFeatureFlags.enableMobileAdminNews,
              child: NewsScreen(),
            ),
        '/calendar':
            (context) => const MobileFeaturePage(
              allowDisabledMobileAdmin:
                  AppFeatureFlags.enableMobileAdminCalendar,
              child: CalendarScreen(),
            ),
        '/grades': (context) => const MobileFeaturePage(child: GradesScreen()),
        '/stats': (context) => const MobileFeaturePage(child: StatsScreen()),
        '/settings': (context) => const AppAccessPage(child: SettingsScreen()),
      },

      // ---------- Rutas especiales con permisos ----------
      onGenerateRoute: (settings) {
        if (settings.name == '/students') {
          return MaterialPageRoute(
            builder: (_) => const AdminOnlyPage(child: StudentsScreen()),
          );
        }

        if (settings.name == '/teachers') {
          return MaterialPageRoute(
            builder: (_) => const AdminOnlyPage(child: TeachersScreen()),
          );
        }

        return null; // Si no hay coincidencia, usa ruta por defecto
      },

      debugShowCheckedModeBanner: false, // Oculta el banner de debug
    );
  }
}

class AppAccessPage extends StatelessWidget {
  const AppAccessPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accessState = context
        .select<CurrentUserController, ({bool loading, bool hasAccess})>(
          (controller) => (
            loading: controller.isLoading,
            hasAccess: controller.hasAppAccess,
          ),
        );

    if (accessState.loading) {
      return const AppLoadingSkeleton();
    }

    return accessState.hasAccess ? child : const UnauthorizedScreen();
  }
}

class MobileFeaturePage extends StatelessWidget {
  const MobileFeaturePage({
    super.key,
    required this.child,
    this.allowDisabledMobileAdmin = false,
  });

  final Widget child;
  final bool allowDisabledMobileAdmin;

  @override
  Widget build(BuildContext context) {
    final accessState = context.select<
      CurrentUserController,
      ({bool loading, bool isAdmin, bool hasAccess})
    >(
      (controller) => (
        loading: controller.isLoading,
        isAdmin: controller.isAdmin,
        hasAccess: controller.hasAppAccess,
      ),
    );

    if (accessState.loading) {
      return const AppLoadingSkeleton();
    }

    final adminMobileDisabled =
        accessState.isAdmin &&
        !AppFeatureFlags.enableMobileAdmin &&
        !allowDisabledMobileAdmin;

    return accessState.hasAccess && !adminMobileDisabled
        ? child
        : const UnauthorizedScreen();
  }
}

class AdminOnlyPage extends StatelessWidget {
  const AdminOnlyPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accessState = context
        .select<CurrentUserController, ({bool loading, bool isAdmin})>(
          (controller) => (
            loading: controller.isLoading,
            isAdmin: controller.isAdmin,
          ),
        );

    if (accessState.loading) {
      return const AppLoadingSkeleton();
    }

    return accessState.isAdmin && AppFeatureFlags.enableMobileAdmin
        ? child
        : const UnauthorizedScreen();
  }
}
