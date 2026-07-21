import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../controllers/current_user_controller.dart';
import '../widgets/auth_decorated_background.dart';

class UnauthorizedScreen extends StatefulWidget {
  const UnauthorizedScreen({super.key});

  @override
  State<UnauthorizedScreen> createState() => _UnauthorizedScreenState();
}

class _UnauthorizedScreenState extends State<UnauthorizedScreen> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<CurrentUserController>();
    final state = _AccessState.from(currentUser);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: AuthDecoratedBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth < 380 ? 18.0 : 24.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  28,
                  horizontalPadding,
                  28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0, end: 1),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppLogo(
                              size: 126,
                              subtitleColor: AppColors.textPrimary(context),
                            ),
                            const SizedBox(height: 28),
                            _AccessCard(
                              state: state,
                              isDark: isDark,
                              isSigningOut: _isSigningOut,
                              onPrimaryAction:
                                  state.canReturnHome ? _returnHome : _signOut,
                              onSignOut: state.canReturnHome ? _signOut : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _returnHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.state,
    required this.isDark,
    required this.isSigningOut,
    required this.onPrimaryAction,
    required this.onSignOut,
  });

  final _AccessState state;
  final bool isDark;
  final bool isSigningOut;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final cardColor = AppColors.cardBackground(context);
    final secondaryText = AppColors.textSecondary(context);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFD9E8F5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: isDark ? 0.96 : 0.98),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(
              alpha: isDark ? 0.16 : 0.08,
            ),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: state.color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: state.color.withValues(alpha: isDark ? 0.32 : 0.18),
              ),
            ),
            child: Icon(state.icon, color: state.color, size: 34),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: state.color.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              state.label,
              style: TextStyle(
                color: state.color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            state.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.softBlue.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.shieldOutlined,
                  color: AppColors.adaptiveBlue(context),
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.supportMessage,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: isSigningOut ? null : onPrimaryAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryBlue.withValues(
                  alpha: 0.55,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon:
                  isSigningOut
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Icon(
                        state.canReturnHome
                            ? AppIcons.homeRounded
                            : AppIcons.logoutRounded,
                      ),
              label: Text(
                isSigningOut
                    ? 'Cerrando sesión...'
                    : state.canReturnHome
                    ? 'Volver al inicio'
                    : 'Cerrar sesión',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (onSignOut != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: isSigningOut ? null : onSignOut,
              icon: const Icon(AppIcons.logoutRounded, size: 18),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessState {
  const _AccessState({
    required this.label,
    required this.title,
    required this.description,
    required this.supportMessage,
    required this.icon,
    required this.color,
    required this.canReturnHome,
  });

  final String label;
  final String title;
  final String description;
  final String supportMessage;
  final IconData icon;
  final Color color;
  final bool canReturnHome;

  factory _AccessState.from(CurrentUserController controller) {
    final user = controller.user;

    if (user != null && !user.isActive) {
      return const _AccessState(
        label: 'CUENTA INACTIVA',
        title: 'Tu acceso está pausado',
        description:
            'La escuela desactivó temporalmente tu perfil. Mientras permanezca inactivo no podrás consultar información académica.',
        supportMessage:
            'Tu información permanece protegida. Comunícate con la administración de Cintli Montessori para solicitar la reactivación.',
        icon: AppIcons.personOffRounded,
        color: AppColors.primaryOrange,
        canReturnHome: false,
      );
    }

    if (user == null) {
      return const _AccessState(
        label: 'PERFIL NO DISPONIBLE',
        title: 'No encontramos tu perfil escolar',
        description:
            'La cuenta inició sesión, pero no tiene un perfil vinculado dentro de la escuela.',
        supportMessage:
            'Solicita a la administración que revise tu correo y vinculación antes de volver a ingresar.',
        icon: AppIcons.manageAccountsOutlined,
        color: AppColors.primaryRed,
        canReturnHome: false,
      );
    }

    if (!controller.hasSupportedRole) {
      return const _AccessState(
        label: 'ROL SIN ACCESO',
        title: 'Tu perfil no tiene acceso móvil',
        description:
            'El rol asignado a esta cuenta no incluye acceso a las funciones de la aplicación.',
        supportMessage:
            'La administración puede revisar el rol asociado a tu cuenta si consideras que se trata de un error.',
        icon: AppIcons.adminPanelSettingsOutlined,
        color: AppColors.primaryRed,
        canReturnHome: false,
      );
    }

    return const _AccessState(
      label: 'FUNCIÓN WEB',
      title: 'Esta función no está disponible aquí',
      description:
          'La gestión administrativa se realiza desde el panel web para mantener una experiencia más clara y segura.',
      supportMessage:
          'Puedes volver al inicio de la aplicación o cerrar tu sesión de forma segura.',
      icon: AppIcons.desktopWindowsRounded,
      color: AppColors.primaryBlue,
      canReturnHome: true,
    );
  }
}
