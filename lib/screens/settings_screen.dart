import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:prototipo_2/core/widgets/custom_drawer.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart'; // ThemeNotifier
import '../core/utils/app_info.dart'; // Importamos AppInfo para mostrar versión

// Pantalla de Configuración
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage =
      'Español'; // Idioma seleccionado (por ahora solo Español)

  @override
  Widget build(BuildContext context) {
    // Usamos Provider para acceder al estado global del tema
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final currentUser = context.watch<CurrentUserController>();
    final user = currentUser.user;
    bool isDarkMode = themeNotifier.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor:
            isDarkMode ? AppColors.brandBlueSurface : AppColors.primaryBlue,
        foregroundColor: Colors.white,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(AppIcons.menu),
                onPressed:
                    () =>
                        Scaffold.of(
                          context,
                        ).openDrawer(), // Abre el menú lateral
              ),
        ),
      ),
      drawer: const CustomDrawer(), // Drawer personalizado
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDarkMode
                    ? [AppColors.darkSurfaceAlt, AppColors.darkBackground]
                    : [const Color(0xFFF4F9FF), const Color(0xFFFDFEFF)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            _buildProfileHeader(
              isDarkMode: isDarkMode,
              name: user?.name,
              email: user?.email,
              role: _roleLabel(currentUser),
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: 'Preferencias',
              children: [
                _buildSettingTile(
                  isDarkMode: isDarkMode,
                  icon:
                      isDarkMode
                          ? AppIcons.darkModeRounded
                          : AppIcons.lightModeRounded,
                  iconColor: AppColors.primaryBlue,
                  title: 'Apariencia',
                  subtitle:
                      isDarkMode ? 'Modo oscuro activo' : 'Modo claro activo',
                  trailing: Switch.adaptive(
                    value: isDarkMode,
                    activeThumbColor: AppColors.primaryBlue,
                    onChanged: themeNotifier.toggleTheme,
                  ),
                ),
                _buildTileDivider(isDarkMode),
                _buildSettingTile(
                  isDarkMode: isDarkMode,
                  icon: AppIcons.translateRounded,
                  iconColor: AppColors.primaryTurquoise,
                  title: 'Idioma',
                  subtitle: 'Interfaz en español',
                  trailing: DropdownButton<String>(
                    value: _selectedLanguage,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(14),
                    onChanged: (String? newValue) {
                      if (newValue == null) return;
                      setState(() => _selectedLanguage = newValue);
                    },
                    items:
                        <String>['Español'].map<DropdownMenuItem<String>>((
                          value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                  ),
                ),
              ],
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: 'Información',
              children: [
                _buildSettingTile(
                  isDarkMode: isDarkMode,
                  icon: AppIcons.infoOutlineRounded,
                  iconColor: AppColors.primaryOrange,
                  title: 'Acerca de la app',
                  subtitle: 'Versión ${AppInfo.displayVersion}',
                  trailing: const Icon(AppIcons.chevronRightRounded),
                  onTap: () => _showAboutDialog(context),
                ),
                _buildTileDivider(isDarkMode),
                _buildSettingTile(
                  isDarkMode: isDarkMode,
                  icon: AppIcons.privacyTipOutlined,
                  iconColor: AppColors.primaryGreen,
                  title: 'Política de privacidad',
                  subtitle: 'Uso y cuidado de los datos',
                  trailing: const Icon(AppIcons.chevronRightRounded),
                  onTap: () => _showPrivacyPolicy(context),
                ),
              ],
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 22),
            _buildLogoutButton(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required bool isDarkMode,
    required String? name,
    required String? email,
    required String role,
  }) {
    final displayName = _displayName(name: name, email: email);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2EAF3),
        ),
        boxShadow: _softShadows(isDarkMode),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(
                alpha: isDarkMode ? 0.22 : 0.12,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              AppIcons.verifiedUserRounded,
              color: AppColors.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2EAF3),
            ),
            boxShadow: _softShadows(isDarkMode),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required bool isDarkMode,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: isDarkMode ? 0.18 : 0.11),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: iconColor, size: 23),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      trailing: trailing,
    );
  }

  Widget _buildTileDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      indent: 70,
      color:
          isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE8EEF5),
    );
  }

  Widget _buildLogoutButton(bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(AppIcons.logoutRounded),
        label: const Text(
          'Cerrar sesión',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        onPressed: () => _logout(context),
      ),
    );
  }

  String _displayName({required String? name, required String? email}) {
    final cleanName = name?.trim();
    if (cleanName != null && cleanName.isNotEmpty) return cleanName;

    final cleanEmail = email?.trim();
    if (cleanEmail == null || cleanEmail.isEmpty) return 'Usuario';
    return cleanEmail.split('@').first;
  }

  String _roleLabel(CurrentUserController currentUser) {
    if (currentUser.isAdmin) return 'Administración';
    if (currentUser.isTeacher) return 'Docente';
    if (currentUser.isParent) return 'Familia';
    return 'Usuario';
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
        color: const Color(0xFFC9D8E8).withValues(alpha: 0.36),
        blurRadius: 20,
        offset: const Offset(7, 11),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.92),
        blurRadius: 16,
        offset: const Offset(-6, -8),
      ),
    ];
  }

  // ------------------ Acerca de la app ------------------
  void _showAboutDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildAppDialogShell(
              isDarkMode: isDarkMode,
              icon: AppIcons.infoOutlineRounded,
              iconColor: AppColors.primaryOrange,
              title: 'Acerca de la app',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogInfoRow(
                    isDarkMode: isDarkMode,
                    icon: AppIcons.schoolRounded,
                    title: 'Cintli Montessori App',
                    subtitle: 'Aplicación escolar institucional',
                  ),
                  const SizedBox(height: 12),
                  _buildDialogInfoRow(
                    isDarkMode: isDarkMode,
                    icon: AppIcons.verifiedRounded,
                    title: 'Versión ${AppInfo.displayVersion}',
                    subtitle: 'Compilación actual instalada',
                  ),
                  const SizedBox(height: 12),
                  _buildDialogInfoRow(
                    isDarkMode: isDarkMode,
                    icon: AppIcons.copyrightRounded,
                    title: '© 2025 Cintli Montessori',
                    subtitle: 'Todos los derechos reservados',
                  ),
                ],
              ),
              actionLabel: 'Cerrar',
              onAction: () => Navigator.pop(dialogContext),
            ),
          ),
    );
  }

  // ------------------ Política de privacidad ------------------
  void _showPrivacyPolicy(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildAppDialogShell(
              isDarkMode: isDarkMode,
              icon: AppIcons.privacyTipOutlined,
              iconColor: AppColors.primaryGreen,
              title: 'Política de privacidad',
              maxHeightFactor: 0.78,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPolicyHeader(isDarkMode),
                    const SizedBox(height: 16),
                    _buildPolicySection(
                      isDarkMode: isDarkMode,
                      title: '1. Compromiso con la privacidad',
                      body:
                          'En Montessori App valoramos profundamente la privacidad de los estudiantes, sus familias, docentes y personal administrativo. Garantizamos que la información no será utilizada con fines comerciales, publicitarios ni de lucro. Nos comprometemos a manejar los datos con el máximo respeto y responsabilidad, incluso en esta etapa de desarrollo.',
                    ),
                    _buildPolicySection(
                      isDarkMode: isDarkMode,
                      title: '2. Estado actual de la aplicación',
                      body:
                          'Montessori App se encuentra actualmente en fase de desarrollo y pruebas. Esto significa que la aplicación aún no ha sido lanzada oficialmente ni se encuentra en producción. Durante esta etapa, únicamente se están utilizando nombres reales de estudiantes, docentes y personal administrativo con fines de prueba interna. No se está utilizando ningún otro dato personal o sensible como direcciones, teléfonos, fotografías, identificaciones, ni datos académicos o médicos.',
                    ),
                    _buildPolicySection(
                      isDarkMode: isDarkMode,
                      title: '3. Uso de los datos',
                      body:
                          'La información utilizada durante esta fase es exclusivamente para fines de desarrollo y verificación funcional. No se recolecta, comparte ni comercializa ningún dato con terceros. La base de datos está limitada a un entorno de pruebas y no tiene conexión con servidores públicos o productivos.',
                    ),
                    _buildPolicySection(
                      isDarkMode: isDarkMode,
                      title: '4. Seguridad de la información',
                      body:
                          'Aunque se están utilizando únicamente nombres reales, hemos implementado medidas básicas de seguridad para evitar accesos no autorizados. El acceso a los datos está restringido únicamente al equipo de desarrollo responsable del proyecto. La información no puede ser vista ni manipulada por usuarios externos.',
                    ),
                    _buildPolicySection(
                      isDarkMode: isDarkMode,
                      title: '5. Consentimiento informado',
                      body:
                          'Al utilizar esta aplicación en su versión de prueba, usted reconoce y acepta que:\n'
                          '- La app no se encuentra en producción.\n'
                          '- Los únicos datos reales utilizados son los nombres.\n'
                          '- No se recopilan datos sensibles o privados.\n'
                          '- La información no será utilizada con fines ajenos al desarrollo del sistema.',
                    ),
                    _buildPolicySection(
                      isDarkMode: isDarkMode,
                      title: '6. Modificaciones a esta política',
                      body:
                          'Esta política de privacidad podrá ser modificada en el futuro conforme se avance en el desarrollo o publicación de la aplicación. Cualquier cambio será informado claramente dentro de la app o a través de medios oficiales antes de su implementación.',
                    ),
                    _buildPolicySection(
                      isDarkMode: isDarkMode,
                      title: '7. Contacto',
                      body:
                          'Si tiene alguna pregunta, sugerencia o inquietud relacionada con esta política, puede contactarnos al correo: montessoriapp@gmail.com.',
                    ),
                  ],
                ),
              ),
              actionLabel: 'Cerrar',
              onAction: () => Navigator.pop(dialogContext),
            ),
          ),
    );
  }

  Widget _buildAppDialogShell({
    required bool isDarkMode,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    required String actionLabel,
    required VoidCallback onAction,
    double? maxHeightFactor,
  }) {
    final maxHeight =
        MediaQuery.sizeOf(context).height * (maxHeightFactor ?? 0.86);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color:
                isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2EAF3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.32 : 0.18),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(
                      alpha: isDarkMode ? 0.18 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(child: child),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogInfoRow({
    required bool isDarkMode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDarkMode
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF4F9FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(
                alpha: isDarkMode ? 0.18 : 0.11,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(
          alpha: isDarkMode ? 0.16 : 0.09,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cintli Montessori App',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fecha de entrada en vigor: 16 de junio de 2025',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection({
    required bool isDarkMode,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.38,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ Cerrar sesión ------------------
  void _logout(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color:
                      isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2EAF3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDarkMode ? 0.32 : 0.18,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withValues(
                            alpha: isDarkMode ? 0.18 : 0.11,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          AppIcons.logoutRounded,
                          color: AppColors.primaryRed,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF4F9FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Tu sesión se cerrará en este dispositivo. Para volver a entrar necesitarás iniciar sesión nuevamente.',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary(context),
                            side: BorderSide(
                              color: AppColors.borderColor(context),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (!dialogContext.mounted) return;
                            Navigator.pushNamedAndRemoveUntil(
                              dialogContext,
                              '/',
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Salir',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
