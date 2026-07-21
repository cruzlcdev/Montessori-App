import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/app_versions.dart';
import '../../../features/auth/data/models/app_user.dart';
import '../../data/admin_session_preferences.dart';
import '../theme/admin_theme.dart';
import 'admin_calendar_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_families_screen.dart';
import 'admin_groups_screen.dart';
import 'admin_news_screen.dart';
import 'admin_students_screen.dart';
import 'admin_subjects_screen.dart';
import 'admin_teachers_screen.dart';

enum _AdminSection {
  dashboard,
  news,
  calendar,
  groups,
  subjects,
  students,
  families,
  teachers,
}

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  _AdminSection _section = _AdminSection.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _AdminSidebar(
            user: widget.user,
            selectedSection: _section,
            onSectionSelected: (section) => setState(() => _section = section),
          ),
          Expanded(child: _buildSelectedSection()),
        ],
      ),
    );
  }

  Widget _buildSelectedSection() {
    return switch (_section) {
      _AdminSection.dashboard => AdminDashboardScreen(user: widget.user),
      _AdminSection.news => const AdminNewsScreen(),
      _AdminSection.calendar => const AdminCalendarScreen(),
      _AdminSection.groups => const AdminGroupsScreen(),
      _AdminSection.subjects => const AdminSubjectsScreen(),
      _AdminSection.students => const AdminStudentsScreen(),
      _AdminSection.families => const AdminFamiliesScreen(),
      _AdminSection.teachers => const AdminTeachersScreen(),
    };
  }
}

class _AdminSidebar extends StatefulWidget {
  const _AdminSidebar({
    required this.user,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final AppUser user;
  final _AdminSection selectedSection;
  final ValueChanged<_AdminSection> onSectionSelected;

  @override
  State<_AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<_AdminSidebar> {
  bool _isAccountMenuOpen = false;
  bool _keepSignedIn = true;
  bool _isUpdatingPersistence = false;

  AppUser get user => widget.user;
  _AdminSection get selectedSection => widget.selectedSection;
  ValueChanged<_AdminSection> get onSectionSelected => widget.onSectionSelected;

  @override
  void initState() {
    super.initState();
    _loadSessionPreference();
  }

  Future<void> _loadSessionPreference() async {
    final keepSignedIn = await AdminSessionPreferences.keepSignedIn();
    if (!mounted) return;
    setState(() => _keepSignedIn = keepSignedIn);
  }

  Future<void> _changeSessionPersistence(bool value) async {
    if (_isUpdatingPersistence) return;
    setState(() => _isUpdatingPersistence = true);

    try {
      await AdminSessionPreferences.setKeepSignedIn(value);
      if (!mounted) return;
      setState(() => _keepSignedIn = value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar la preferencia de sesión.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isUpdatingPersistence = false);
    }
  }

  Future<void> _requestSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => const _SignOutDialog(),
    );

    if (shouldSignOut == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.adminPalette;

    return Container(
      width: 286,
      decoration: BoxDecoration(
        color: palette.sidebar,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            AdminIcons.schoolRounded,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cintli Montessori',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: palette.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Administración escolar',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AdminIcons.cloudDoneRounded,
                            color: AppColors.primaryGreen,
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Sistema sincronizado',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const _SidebarSectionLabel('PRINCIPAL'),
                    _NavItem(
                      icon: AdminIcons.dashboardRounded,
                      label: 'Resumen',
                      selected: selectedSection == _AdminSection.dashboard,
                      onTap: () => onSectionSelected(_AdminSection.dashboard),
                    ),
                    _NavItem(
                      icon: AdminIcons.campaignRounded,
                      label: 'Noticias',
                      selected: selectedSection == _AdminSection.news,
                      onTap: () => onSectionSelected(_AdminSection.news),
                    ),
                    _NavItem(
                      icon: AdminIcons.calendarMonthRounded,
                      label: 'Calendario',
                      selected: selectedSection == _AdminSection.calendar,
                      onTap: () => onSectionSelected(_AdminSection.calendar),
                    ),
                    const SizedBox(height: 10),
                    const _SidebarSectionLabel('GESTIÓN ESCOLAR'),
                    _NavItem(
                      icon: AdminIcons.groupsRounded,
                      label: 'Grupos',
                      selected: selectedSection == _AdminSection.groups,
                      onTap: () => onSectionSelected(_AdminSection.groups),
                    ),
                    _NavItem(
                      icon: AdminIcons.menuBookRounded,
                      label: 'Materias',
                      selected: selectedSection == _AdminSection.subjects,
                      onTap: () => onSectionSelected(_AdminSection.subjects),
                    ),
                    _NavItem(
                      icon: AdminIcons.personRounded,
                      label: 'Alumnos',
                      selected: selectedSection == _AdminSection.students,
                      onTap: () => onSectionSelected(_AdminSection.students),
                    ),
                    _NavItem(
                      icon: AdminIcons.familyRestroomRounded,
                      label: 'Familias',
                      selected: selectedSection == _AdminSection.families,
                      onTap: () => onSectionSelected(_AdminSection.families),
                    ),
                    _NavItem(
                      icon: AdminIcons.coPresentRounded,
                      label: 'Profesores',
                      selected: selectedSection == _AdminSection.teachers,
                      onTap: () => onSectionSelected(_AdminSection.teachers),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primaryOrange.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            AdminIcons.shieldOutlined,
                            color: AppColors.primaryOrange,
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Los cambios se reflejan en la app en tiempo real.',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child:
                    _isAccountMenuOpen
                        ? Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AccountSessionMenu(
                            user: user,
                            keepSignedIn: _keepSignedIn,
                            isUpdating: _isUpdatingPersistence,
                            onKeepSignedInChanged: _changeSessionPersistence,
                            onSignOut: _requestSignOut,
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
              Material(
                color: palette.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                  side: BorderSide(color: palette.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap:
                      () => setState(
                        () => _isAccountMenuOpen = !_isAccountMenuOpen,
                      ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            AdminIcons.adminPanelSettingsRounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name.isEmpty ? 'Administrador' : user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                user.role == 'owner' ? 'Owner' : 'Admin',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isAccountMenuOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            AdminIcons.keyboardArrowDownRounded,
                            color: palette.textSecondary,
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
      ),
    );
  }
}

class _AccountSessionMenu extends StatelessWidget {
  const _AccountSessionMenu({
    required this.user,
    required this.keepSignedIn,
    required this.isUpdating,
    required this.onKeepSignedInChanged,
    required this.onSignOut,
  });

  final AppUser user;
  final bool keepSignedIn;
  final bool isUpdating;
  final ValueChanged<bool> onKeepSignedInChanged;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final email = user.email.trim();
    final palette = context.adminPalette;
    final themeController = AdminThemeScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionAccent = AppColors.adaptiveBlue(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  AdminIcons.verifiedUserRounded,
                  color: AppColors.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sesión administrativa activa',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 5),
            Tooltip(
              message: 'Compilación ${AppVersions.adminWeb.full}',
              child: Text(
                'Panel web v${AppVersions.adminWeb.display}',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? palette.surfaceElevated
                        : AppColors.softBlue.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color:
                      isDark
                          ? palette.borderStrong
                          : AppColors.primaryBlue.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    AdminIcons.devicesRounded,
                    color: sessionAccent,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mantener sesión abierta',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          keepSignedIn
                              ? 'Continúa al volver al navegador'
                              : 'Finaliza al cerrar el navegador',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: keepSignedIn,
                    onChanged: isUpdating ? null : onKeepSignedInChanged,
                    activeTrackColor: sessionAccent,
                    activeThumbColor:
                        isDark ? const Color(0xFFE3F2FF) : Colors.white,
                    inactiveTrackColor:
                        isDark ? palette.borderStrong : const Color(0xFFD8E6F3),
                    inactiveThumbColor:
                        isDark
                            ? const Color(0xFF9DB3CA)
                            : const Color(0xFF7890A8),
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (states) =>
                          states.contains(WidgetState.selected)
                              ? sessionAccent.withValues(alpha: 0.42)
                              : palette.borderStrong,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ThemePreferenceSelector(
              preference: themeController.preference,
              onChanged: themeController.setPreference,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: Icon(AdminIcons.logoutRounded, size: 18),
              label: Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                side: BorderSide(
                  color: AppColors.primaryRed.withValues(alpha: 0.25),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog();

  @override
  Widget build(BuildContext context) {
    final palette = context.adminPalette;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: 0.28),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      AdminIcons.logoutRounded,
                      color: AppColors.primaryRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Finalizarás tu acceso al panel administrativo.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context, false),
                    icon: Icon(
                      AdminIcons.closeRounded,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AdminIcons.infoOutlineRounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Para volver a entrar tendrás que escribir nuevamente tus credenciales.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final keepButton = OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: BorderSide(color: palette.borderStrong),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Mantener sesión',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                  final signOutButton = FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(AdminIcons.logoutRounded, size: 18),
                    label: const Text('Cerrar sesión'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        signOutButton,
                        const SizedBox(height: 10),
                        keepButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: keepButton),
                      const SizedBox(width: 12),
                      Expanded(child: signOutButton),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Text(
        label,
        style: TextStyle(
          color: context.adminPalette.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.adminPalette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color:
            selected
                ? AppColors.primaryBlue
                : palette.surface.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          minTileHeight: 52,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13),
          onTap: onTap,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  selected
                      ? Colors.white.withValues(alpha: 0.16)
                      : palette.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: selected ? Colors.white : palette.textSecondary,
            ),
          ),
          title: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : palette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          trailing:
              selected
                  ? Icon(
                    AdminIcons.chevronRightRounded,
                    color: Colors.white,
                    size: 20,
                  )
                  : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _ThemePreferenceSelector extends StatelessWidget {
  const _ThemePreferenceSelector({
    required this.preference,
    required this.onChanged,
  });

  final AdminThemePreference preference;
  final ValueChanged<AdminThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.adminPalette;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 7),
            child: Row(
              children: [
                Icon(
                  AdminIcons.contrastRounded,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Apariencia',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children:
                AdminThemePreference.values.map((value) {
                  final selected = preference == value;
                  final (icon, tooltip) = switch (value) {
                    AdminThemePreference.system => (
                      AdminIcons.settingsSuggestRounded,
                      'Usar tema del sistema',
                    ),
                    AdminThemePreference.light => (
                      AdminIcons.lightModeRounded,
                      'Usar modo claro',
                    ),
                    AdminThemePreference.dark => (
                      AdminIcons.darkModeRounded,
                      'Usar modo oscuro',
                    ),
                  };

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Tooltip(
                        message: tooltip,
                        child: Material(
                          color:
                              selected
                                  ? AppColors.primaryBlue
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onChanged(value),
                            child: SizedBox(
                              height: 38,
                              child: Icon(
                                icon,
                                size: 18,
                                color:
                                    selected
                                        ? Colors.white
                                        : palette.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
