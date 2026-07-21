// colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Colores base (sin tema)
  static const Color primaryRed = Color(0xFFFF5E52);
  static const Color primaryGreen = Color(0xFF2DC121);
  static const Color primaryYellow = Color(0xFFFFD731);
  static const Color primaryBlue = Color(0xFF0073DB);
  static const Color primaryTurquoise = Color(0xFF01B7CE);
  static const Color primaryOrange = Color(0xFFFAA619);
  static const Color brandBlueSurface = Color(0xFF003E9F);
  static const Color ink = Color(0xFF1D2530);
  static const Color softBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF5FF);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF172033);
  static const Color darkSurfaceAlt = Color(0xFF1D2A44);

  // --- Colores adaptativos al modo claro/oscuro ---

  // Método para obtener el azul según el modo (claro u oscuro)
  static Color getBlue(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF66B2FF) : primaryBlue;
  }

  /// Fondo principal de la app
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBackground
          : softBackground;

  /// Color del texto principal
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white : ink;

  /// Texto secundario o menos importante
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFD6E1F0)
          : Colors.black54;

  /// Azul adaptado al modo oscuro (más claro para legibilidad)
  static Color adaptiveBlue(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF66B2FF) // Azul más claro para dark mode
          : primaryBlue;

  /// Fondo de tarjetas
  static Color cardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : Colors.white;

  /// Color de íconos o botones en AppBar
  static Color iconColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;

  /// Color de bordes o divisores
  static Color borderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white30
          : Colors.grey[300]!;
}
