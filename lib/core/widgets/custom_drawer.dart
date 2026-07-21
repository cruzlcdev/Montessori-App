import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:prototipo_2/core/config/app_feature_flags.dart';
import 'package:prototipo_2/core/layout/responsive_layout.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';

// Drawer (menú lateral) que se usa en toda la app
class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Detecta si está en modo oscuro para adaptar colores
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.watch<CurrentUserController>();
    final user = currentUser.user;
    final isAdmin = currentUser.isAdmin && AppFeatureFlags.enableMobileAdmin;
    final isMobileAdminInactive =
        currentUser.isAdmin && !AppFeatureFlags.enableMobileAdmin;
    final canViewCalendar =
        !isMobileAdminInactive ||
        (currentUser.isAdmin && AppFeatureFlags.enableMobileAdminCalendar);
    final canViewNews =
        !isMobileAdminInactive ||
        (currentUser.isAdmin && AppFeatureFlags.enableMobileAdminNews);
    final canViewStats =
        !isMobileAdminInactive &&
        (currentUser.isAdmin || currentUser.isTeacher || currentUser.isParent);
    final currentRoute = ModalRoute.of(context)?.settings.name;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = math.min(
      screenWidth * (ResponsiveLayout.isCompactPhone(context) ? 0.88 : 0.84),
      ResponsiveLayout.isTablet(context) ? 360.0 : 340.0,
    );

    return Drawer(
      width: drawerWidth,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(
            context: context,
            isDarkMode: isDarkMode,
            name: user?.name,
            email: user?.email,
            role: _roleLabel(currentUser),
          ),
          _buildSectionLabel('Principal', isDarkMode),

          // --------- Opciones del menú ---------
          _buildDrawerItem(
            context,
            AppIcons.home,
            'Inicio',
            () => Navigator.pushReplacementNamed(context, '/home'),
            isDarkMode,
            isSelected: currentRoute == '/home',
          ),
          if (canViewCalendar)
            _buildDrawerItem(
              context,
              AppIcons.calendarToday,
              'Calendario',
              () => Navigator.pushReplacementNamed(context, '/calendar'),
              isDarkMode,
              isSelected: currentRoute == '/calendar',
            ),
          if (canViewNews)
            _buildDrawerItem(
              context,
              AppIcons.newspaper,
              'Noticias',
              () => Navigator.pushReplacementNamed(context, '/news'),
              isDarkMode,
              isSelected: currentRoute == '/news',
            ),
          if (canViewStats)
            _buildDrawerItem(
              context,
              AppIcons.barChart,
              'Estadísticas',
              () => Navigator.pushReplacementNamed(context, '/stats'),
              isDarkMode,
              isSelected: currentRoute == '/stats',
            ),

          // Solo visible si el usuario es admin
          if (isAdmin) ...[
            _buildSectionLabel('Administración', isDarkMode),
            _buildDrawerItem(
              context,
              AppIcons.groupsRounded,
              'Estudiantes',
              () => Navigator.pushReplacementNamed(context, '/students'),
              isDarkMode,
              isSelected: currentRoute == '/students',
            ),
            _buildDrawerItem(
              context,
              AppIcons.school,
              'Profesores',
              () => Navigator.pushReplacementNamed(context, '/teachers'),
              isDarkMode,
              isSelected: currentRoute == '/teachers',
            ),
          ],

          // Separador
          Divider(
            color: isDarkMode ? Colors.white12 : const Color(0xFFE5E7EB),
            thickness: 1,
            height: 28,
            indent: 16,
            endIndent: 16,
          ),

          // Configuración
          _buildDrawerItem(
            context,
            AppIcons.settings,
            'Configuración',
            () => Navigator.pushReplacementNamed(context, '/settings'),
            isDarkMode,
            isSelected: currentRoute == '/settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required bool isDarkMode,
    required String? name,
    required String? email,
    required String role,
  }) {
    final displayName = _displayName(name: name, email: email, role: role);

    final topPadding = MediaQuery.viewPaddingOf(context).top;

    final compact = ResponsiveLayout.isCompactPhone(context);
    final horizontalPadding = compact ? 20.0 : 24.0;

    return SizedBox(
      height: topPadding + (compact ? 146 : 156),
      child: DecoratedBox(
        decoration: BoxDecoration(boxShadow: _softShadows(isDarkMode)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDarkMode
                          ? [const Color(0xFF0F172A), const Color(0xFF1E3A8A)]
                          : [AppColors.brandBlueSurface, AppColors.primaryBlue],
                ),
              ),
            ),
            const CustomPaint(painter: _CintliHeaderPainter()),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding + (compact ? 22 : 28),
                horizontalPadding,
                compact ? 20 : 24,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 220 : 252),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 18 : 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName({
    required String? name,
    required String? email,
    required String role,
  }) {
    final cleanName = name?.trim();
    if (cleanName != null && cleanName.isNotEmpty) return cleanName;

    final cleanEmail = email?.trim();
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      final localPart = cleanEmail.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
    }

    return role == 'Familia' ? 'Responsable familiar' : 'Usuario';
  }

  List<BoxShadow> _softShadows(bool isDarkMode) {
    if (isDarkMode) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ];
    }

    return [
      BoxShadow(
        color: const Color(0xFFD6E1EC).withValues(alpha: 0.75),
        blurRadius: 22,
        offset: const Offset(8, 12),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.95),
        blurRadius: 18,
        offset: const Offset(-8, -10),
      ),
    ];
  }

  Widget _buildSectionLabel(String label, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDarkMode ? Colors.white54 : const Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }

  String _roleLabel(CurrentUserController currentUser) {
    if (currentUser.isAdmin) return 'Administración';
    if (currentUser.isTeacher) return 'Profesor';
    if (currentUser.isParent) return 'Familia';
    return 'Usuario';
  }

  // Método que construye cada opción del Drawer
  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isDarkMode, {
    required bool isSelected,
  }) {
    final activeColor =
        isDarkMode ? AppColors.primaryYellow : AppColors.primaryBlue;
    final inactiveColor = isDarkMode ? Colors.white70 : const Color(0xFF374151);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.isCompactPhone(context) ? 16 : 18,
        vertical: 2,
      ),
      leading: Icon(icon, color: isSelected ? activeColor : inactiveColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? activeColor : inactiveColor,
          letterSpacing: 0,
        ),
      ),
      onTap: onTap, // Acción al hacer clic
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      selected: isSelected,
      selectedTileColor: Colors.transparent,
      hoverColor:
          isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.softBlue,
    );
  }
}

class _CintliHeaderPainter extends CustomPainter {
  const _CintliHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final softLinePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
    final dashedLinePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;

    final path =
        Path()
          ..moveTo(0, size.height * 0.34)
          ..quadraticBezierTo(
            size.width * 0.28,
            size.height * 0.18,
            size.width * 0.58,
            size.height * 0.30,
          )
          ..quadraticBezierTo(
            size.width * 0.78,
            size.height * 0.42,
            size.width,
            size.height * 0.24,
          );
    canvas.drawPath(path, softLinePaint);

    final lowerWave =
        Path()
          ..moveTo(size.width * 0.04, size.height * 0.48)
          ..quadraticBezierTo(
            size.width * 0.24,
            size.height * 0.30,
            size.width * 0.48,
            size.height * 0.44,
          )
          ..quadraticBezierTo(
            size.width * 0.72,
            size.height * 0.58,
            size.width * 0.96,
            size.height * 0.36,
          );
    _drawDashedPath(
      canvas,
      lowerWave,
      dashedLinePaint,
      dashLength: 12,
      gap: 10,
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLength + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
