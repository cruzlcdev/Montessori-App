import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/core/config/app_feature_flags.dart';
import 'package:prototipo_2/core/layout/responsive_layout.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:prototipo_2/screens/teacher_group_screen.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/custom_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<CurrentUserController>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: const CustomAppBar(title: 'Cintli Montessori'),
      drawer: const CustomDrawer(),
      body:
          currentUser.isLoading
              ? HomeLoadingSkeleton(isDarkMode: isDarkMode)
              : _buildBody(context, currentUser, isDarkMode),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CurrentUserController currentUser,
    bool isDarkMode,
  ) {
    if (!currentUser.hasAppAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            currentUser.errorMessage ??
                'No tienes permisos para ver funciones.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (currentUser.isAdmin && !AppFeatureFlags.enableMobileAdmin) {
      return _buildAdminWebNotice(context, isDarkMode);
    }

    final features = _featuresByRole(currentUser);

    return ColoredBox(
      color: AppColors.background(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.horizontalPadding(context),
                ResponsiveLayout.isShortScreen(context) ? 18 : 24,
                ResponsiveLayout.horizontalPadding(context),
                18,
              ),
              child: _buildRoleHeader(context, currentUser),
            ),
          ),
          SliverPadding(
            padding: ResponsiveLayout.pagePadding(context, top: 0, bottom: 28),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount =
                    constraints.crossAxisExtent >= 720
                        ? 3
                        : features.length == 1
                        ? 1
                        : 2;
                final spacing =
                    ResponsiveLayout.isCompactPhone(context) ? 12.0 : 16.0;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: ResponsiveLayout.homeCardExtent(
                      context,
                      crossAxisCount,
                    ),
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _buildFeatureCard(
                      context,
                      features[index],
                      isDarkMode,
                    );
                  }, childCount: features.length),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminWebNotice(BuildContext context, bool isDarkMode) {
    return ColoredBox(
      color: AppColors.background(context),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        isDarkMode
                            ? Colors.white10
                            : Colors.white.withValues(alpha: 0.92),
                  ),
                  boxShadow: _cardShadows(isDarkMode),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(
                            alpha: isDarkMode ? 0.18 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          AppIcons.adminPanelSettingsRounded,
                          color: AppColors.primaryBlue,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Administración desde web',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Por seguridad y comodidad, las funciones administrativas se gestionarán desde el futuro panel web privado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softBlue.withValues(
                            alpha: isDarkMode ? 0.10 : 1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.lockOutlineRounded,
                              color: AppColors.adaptiveBlue(context),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Admin móvil desactivado temporalmente',
                                style: TextStyle(
                                  color: AppColors.adaptiveBlue(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (AppFeatureFlags.enableMobileAdminNews) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                () => Navigator.pushNamed(context, '/news'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(AppIcons.newspaperRounded),
                            label: const Text(
                              'Crear noticia de prueba',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (AppFeatureFlags.enableMobileAdminCalendar) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                () => Navigator.pushNamed(context, '/calendar'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(AppIcons.calendarMonthRounded),
                            label: const Text(
                              'Crear evento de prueba',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleHeader(
    BuildContext context,
    CurrentUserController currentUser,
  ) {
    final title =
        currentUser.isTeacher
            ? 'Panel docente'
            : currentUser.isParent
            ? 'Seguimiento familiar'
            : 'Accesos principales';
    final subtitle =
        currentUser.isTeacher
            ? 'Gestiona tus grupos y evaluaciones'
            : currentUser.isParent
            ? 'Consulta el avance escolar de tu hijo desde un solo lugar'
            : 'Herramientas disponibles para tu perfil';
    final chips = _roleChips(currentUser);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: ResponsiveLayout.titleSize(context, 22),
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                chips
                    .map(
                      (chip) => _buildInfoChip(
                        context,
                        chip.label,
                        chip.icon,
                        chip.color,
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }

  List<BoxShadow> _cardShadows(bool isDarkMode) {
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
        color: const Color(0xFFC9D8E8).withValues(alpha: 0.52),
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

  List<_HomeFeature> _featuresByRole(CurrentUserController currentUser) {
    final user = currentUser.user;

    if (currentUser.isAdmin) {
      return [
        _HomeFeature(
          icon: AppIcons.groupsRounded,
          title: 'Estudiantes',
          subtitle: 'Consulta y administra alumnos',
          color: AppColors.primaryBlue,
          onTap: (context) => Navigator.pushNamed(context, '/students'),
        ),
        _HomeFeature(
          icon: AppIcons.schoolRounded,
          title: 'Profesores',
          subtitle: 'Gestiona docentes registrados',
          color: AppColors.primaryGreen,
          onTap: (context) => Navigator.pushNamed(context, '/teachers'),
        ),
        _HomeFeature(
          icon: AppIcons.assignmentRounded,
          title: 'Boletas',
          subtitle: 'Revisa reportes académicos',
          color: AppColors.primaryOrange,
          onTap: (context) => Navigator.pushNamed(context, '/grades'),
        ),
        _HomeFeature(
          icon: AppIcons.barChartRounded,
          title: 'Estadísticas',
          subtitle: 'Analiza desempeño general',
          color: AppColors.primaryTurquoise,
          onTap: (context) => Navigator.pushNamed(context, '/stats'),
        ),
        _HomeFeature(
          icon: AppIcons.calendarMonthRounded,
          title: 'Calendario',
          subtitle: 'Coordina eventos escolares',
          color: AppColors.primaryRed,
          onTap: (context) => Navigator.pushNamed(context, '/calendar'),
        ),
        _HomeFeature(
          icon: AppIcons.newspaperRounded,
          title: 'Noticias',
          subtitle: 'Publicaciones institucionales',
          color: AppColors.primaryOrange,
          onTap: (context) => Navigator.pushNamed(context, '/news'),
        ),
      ];
    }

    if (currentUser.isTeacher) {
      final groupCount = user?.groupIds.length ?? 0;

      return [
        _HomeFeature(
          icon: AppIcons.editRounded,
          title: 'Evaluaciones',
          subtitle:
              groupCount == 0
                  ? 'Sin grupos asignados'
                  : 'Captura avances por grupo',
          color: AppColors.primaryRed,
          onTap:
              (context) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeacherGroupsScreen(),
                ),
              ),
        ),
        _HomeFeature(
          icon: AppIcons.assignmentRounded,
          title: 'Boletas',
          subtitle:
              groupCount == 0
                  ? 'No hay grupos vinculados'
                  : 'Consulta reportes del grupo',
          color: AppColors.primaryBlue,
          onTap: (context) => Navigator.pushNamed(context, '/grades'),
        ),
      ];
    }

    if (currentUser.isParent) {
      final studentCount = user?.studentIds.length ?? 0;

      return [
        _HomeFeature(
          icon: AppIcons.assignmentRounded,
          title: 'Boletas',
          subtitle:
              studentCount == 0
                  ? 'Hijo pendiente de vincular'
                  : 'Consulta el avance académico de tu hijo',
          color: AppColors.primaryBlue,
          onTap: (context) => Navigator.pushNamed(context, '/grades'),
        ),
      ];
    }

    return [
      _HomeFeature(
        icon: AppIcons.assignmentRounded,
        title: 'Boletas',
        subtitle: 'Consulta el avance académico',
        color: AppColors.primaryBlue,
        onTap: (context) => Navigator.pushNamed(context, '/grades'),
      ),
    ];
  }

  Widget _buildFeatureCard(
    BuildContext context,
    _HomeFeature feature,
    bool isDarkMode,
  ) {
    final radius = ResponsiveLayout.cardRadius(context);
    final iconSize = ResponsiveLayout.iconBoxSize(context);
    final cardPadding = ResponsiveLayout.isCompactPhone(context) ? 14.0 : 15.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: _cardShadows(isDarkMode),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => feature.onTap(context),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: feature.color.withValues(
                          alpha: isDarkMode ? 0.18 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        feature.icon,
                        color: feature.color,
                        size:
                            ResponsiveLayout.isCompactPhone(context) ? 26 : 28,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: feature.color.withValues(
                          alpha: isDarkMode ? 0.18 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        AppIcons.arrowForwardRounded,
                        color: feature.color,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  feature.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: ResponsiveLayout.titleSize(context, 18),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  feature.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_HomeInfoChip> _roleChips(CurrentUserController currentUser) {
    final user = currentUser.user;

    if (currentUser.isTeacher) {
      final groupCount = user?.groupIds.length ?? 0;
      return [
        _HomeInfoChip(
          icon: AppIcons.groupsRounded,
          label: _countLabel(groupCount, 'grupo asignado', 'grupos asignados'),
          color: AppColors.primaryBlue,
        ),
      ];
    }

    if (currentUser.isParent) {
      final studentCount = user?.studentIds.length ?? 0;
      return [
        _HomeInfoChip(
          icon: AppIcons.childCareRounded,
          label: _countLabel(
            studentCount,
            'hijo vinculado',
            'hijos vinculados',
          ),
          color: AppColors.primaryGreen,
        ),
      ];
    }

    return const [];
  }

  String _countLabel(int count, String singular, String plural) {
    if (count == 0) return 'Sin ${plural.split(' ').first}';
    return '$count ${count == 1 ? singular : plural}';
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeFeature {
  const _HomeFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final void Function(BuildContext context) onTap;
}

class _HomeInfoChip {
  const _HomeInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}
