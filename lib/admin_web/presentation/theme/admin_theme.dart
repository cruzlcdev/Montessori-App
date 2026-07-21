import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/colors.dart';

enum AdminThemePreference { system, light, dark }

class AdminThemeController extends ChangeNotifier {
  AdminThemeController._(this._preference);

  static const _preferenceKey = 'admin_web_theme_preference';

  AdminThemePreference _preference;

  AdminThemePreference get preference => _preference;

  ThemeMode get themeMode => switch (_preference) {
    AdminThemePreference.system => ThemeMode.system,
    AdminThemePreference.light => ThemeMode.light,
    AdminThemePreference.dark => ThemeMode.dark,
  };

  static Future<AdminThemeController> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedValue = preferences.getString(_preferenceKey);
    final preference = AdminThemePreference.values.firstWhere(
      (value) => value.name == savedValue,
      orElse: () => AdminThemePreference.system,
    );
    return AdminThemeController._(preference);
  }

  Future<void> setPreference(AdminThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, preference.name);
  }
}

class AdminThemeScope extends InheritedNotifier<AdminThemeController> {
  const AdminThemeScope({
    super.key,
    required AdminThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdminThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminThemeScope>();
    assert(
      scope != null,
      'AdminThemeScope no está disponible en este contexto.',
    );
    return scope!.notifier!;
  }
}

@immutable
class AdminPalette extends ThemeExtension<AdminPalette> {
  const AdminPalette({
    required this.canvas,
    required this.sidebar,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.inputFill,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shadow,
  });

  final Color canvas;
  final Color sidebar;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color inputFill;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color shadow;

  static const light = AdminPalette(
    canvas: Color(0xFFF4F8FC),
    sidebar: Colors.white,
    surface: Colors.white,
    surfaceMuted: Color(0xFFF1F7FD),
    surfaceElevated: Color(0xFFF8FBFE),
    inputFill: Colors.white,
    border: Color(0xFFE6EDF5),
    borderStrong: Color(0xFFD6E5F5),
    textPrimary: Color(0xFF1D2530),
    textSecondary: Color(0xFF667085),
    textMuted: Color(0xFF98A2B3),
    shadow: Color(0x241D2530),
  );

  static const dark = AdminPalette(
    canvas: Color(0xFF0D1422),
    sidebar: Color(0xFF111B2C),
    surface: Color(0xFF172235),
    surfaceMuted: Color(0xFF1B2940),
    surfaceElevated: Color(0xFF202F47),
    inputFill: Color(0xFF131E30),
    border: Color(0xFF2A3C55),
    borderStrong: Color(0xFF39516E),
    textPrimary: Color(0xFFF4F7FB),
    textSecondary: Color(0xFFB9C7D9),
    textMuted: Color(0xFF8799B0),
    shadow: Color(0x66000000),
  );

  @override
  AdminPalette copyWith({
    Color? canvas,
    Color? sidebar,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? inputFill,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? shadow,
  }) {
    return AdminPalette(
      canvas: canvas ?? this.canvas,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      inputFill: inputFill ?? this.inputFill,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AdminPalette lerp(covariant AdminPalette? other, double t) {
    if (other == null) return this;
    return AdminPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AdminThemeContext on BuildContext {
  AdminPalette get adminPalette =>
      Theme.of(this).extension<AdminPalette>() ?? AdminPalette.light;
}

class AdminThemeData {
  const AdminThemeData._();

  static ThemeData get light => _build(Brightness.light, AdminPalette.light);

  static ThemeData get dark => _build(Brightness.dark, AdminPalette.dark);

  static ThemeData _build(Brightness brightness, AdminPalette palette) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF4AA3F2) : AppColors.primaryBlue;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: brightness,
      primary: primary,
      secondary: isDark ? const Color(0xFF42D1DF) : AppColors.primaryTurquoise,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      error: isDark ? const Color(0xFFFF746B) : AppColors.primaryRed,
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: palette.borderStrong),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.surface,
      cardColor: palette.surface,
      dividerColor: palette.border,
      fontFamily: 'LettersForLearners',
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        labelStyle: TextStyle(color: palette.textSecondary),
        hintStyle: TextStyle(color: palette.textMuted),
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        actionTextColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        textStyle: TextStyle(color: palette.textPrimary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? primary
                  : palette.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? primary.withValues(alpha: 0.36)
                  : palette.borderStrong,
        ),
      ),
    );
  }
}
