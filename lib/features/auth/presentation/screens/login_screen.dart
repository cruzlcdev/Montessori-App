import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototipo_2/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';
import 'package:prototipo_2/features/auth/presentation/widgets/auth_decorated_background.dart';
import 'package:prototipo_2/screens/home_screen.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_loading_skeleton.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/connectivity/network_status_controller.dart';

// Pantalla de inicio de sesión
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Llave para validar formulario
  final _emailController = TextEditingController(); // Controlador para email
  final _passwordController =
      TextEditingController(); // Controlador para contraseña
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // Instancia de Firebase Auth
  bool _isLoading = false;
  bool _isLoadingProfile = false;
  bool _obscurePassword = true;
  bool _showValidationErrors = false;
  int _validationCycle = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmailFormat(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  bool _isAllowedEmailDomain(String email) {
    final normalized = email.toLowerCase();
    return normalized.endsWith('@gmail.com') ||
        normalized.endsWith('@cintlimontessori.edu.mx');
  }

  // Inicio de sesión con Firebase
  Future<void> _signInWithEmailAndPassword() async {
    if (!_validateFormWithTemporaryErrors()) return;
    if (_isLoading) return;

    final network = context.read<NetworkStatusController>();
    await network.checkNow();
    if (!mounted) return;
    if (network.isOffline) {
      _showErrorSnackbar(
        'Sin conexión a internet. Revisa tu Wi-Fi o datos móviles.',
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    setState(() => _isLoading = true);
    var navigatingToHome = false;

    try {
      // Autenticación con Firebase
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() => _isLoadingProfile = true);
      final currentUserController = context.read<CurrentUserController>();
      await currentUserController.loadCurrentUser(authUser: credential.user);

      if (!mounted) return;
      if (!currentUserController.hasAppAccess) {
        final message =
            currentUserController.errorMessage ??
            'No tienes permisos para acceder a la aplicación.';
        final isInactiveProfile =
            currentUserController.user != null &&
            !currentUserController.user!.isActive;
        await _auth.signOut();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isLoadingProfile = false;
        });
        if (isInactiveProfile) {
          await _showInactiveAccessSheet();
        } else {
          _showErrorSnackbar(message);
        }
        return;
      }

      // Navega al Home si el login fue exitoso
      navigatingToHome = true;
      Navigator.of(context).pushReplacement<void, void>(
        PageRouteBuilder<void>(
          settings: const RouteSettings(name: '/home'),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder:
              (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) => child,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint(
        'Firebase Auth login error: code=${e.code}, message=${e.message}',
      );

      // Manejo de errores comunes
      _showErrorSnackbar(_authErrorMessage(e));
    } on TimeoutException {
      if (!mounted) return;
      _showErrorSnackbar(
        'La conexión está tardando demasiado. Revisa tu internet e inténtalo nuevamente.',
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected login error: $e');
      _showErrorSnackbar('Error al iniciar sesión');
    } finally {
      if (mounted && !navigatingToHome) {
        setState(() {
          _isLoading = false;
          _isLoadingProfile = false;
        });
      }
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    final debugSuffix = kDebugMode ? ' (${error.code})' : '';

    switch (error.code) {
      case 'wrong-password':
        return 'La contraseña no coincide con este correo$debugSuffix';
      case 'invalid-credential':
        return 'Correo o contraseña no coinciden$debugSuffix';
      case 'user-not-found':
        return 'No encontramos una cuenta con ese correo$debugSuffix';
      case 'invalid-email':
        return 'El correo ingresado no es valido$debugSuffix';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada por la escuela$debugSuffix';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta mas tarde$debugSuffix';
      case 'network-request-failed':
        return 'No se pudo conectar. Revisa tu internet$debugSuffix';
      case 'operation-not-allowed':
        return 'El inicio con correo y contraseña no está habilitado$debugSuffix';
      case 'app-not-authorized':
        return 'Esta app iOS no está autorizada en Firebase$debugSuffix';
      case 'invalid-api-key':
        return 'La clave de Firebase no es válida para esta app$debugSuffix';
      case 'internal-error':
        return 'Firebase rechazó la solicitud. Revisa la configuración$debugSuffix';
      case 'unknown':
        return 'Firebase no pudo procesar el inicio de sesión$debugSuffix';
      default:
        return 'No se pudo iniciar sesion. Intenta nuevamente$debugSuffix';
    }
  }

  // Función auxiliar para mostrar errores en SnackBar
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Future<void> _showInactiveAccessSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground(sheetContext),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFD9E8F5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderColor(sheetContext),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      AppIcons.personOffRounded,
                      color: AppColors.primaryOrange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu acceso está pausado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary(sheetContext),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'La escuela desactivó temporalmente tu perfil. Mientras permanezca inactivo no podrás ingresar a la aplicación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary(sheetContext),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.softBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.shieldOutlined,
                          color: AppColors.adaptiveBlue(sheetContext),
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Comunícate con la administración de Cintli Montessori para solicitar la reactivación.',
                            style: TextStyle(
                              color: AppColors.textSecondary(sheetContext),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Entendido',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _validateFormWithTemporaryErrors() {
    setState(() => _showValidationErrors = true);
    final isValid = _formKey.currentState!.validate();

    if (!isValid) {
      final cycle = ++_validationCycle;
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted || cycle != _validationCycle) return;
        setState(() => _showValidationErrors = false);
        _formKey.currentState?.validate();
      });
    }

    return isValid;
  }

  void _validateVisibleErrors() {
    if (_showValidationErrors) {
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) return const AppLoadingSkeleton();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: AuthDecoratedBackground(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
                final isShortScreen = constraints.maxHeight < 680;
                final isNarrowScreen = constraints.maxWidth < 360;
                final horizontalPadding = isNarrowScreen ? 16.0 : 24.0;
                final verticalPadding = isShortScreen ? 18.0 : 28.0;
                final logoSize = isShortScreen ? 112.0 : 144.0;

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    bottomInset + verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (verticalPadding * 2),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppLogo(
                              size: logoSize,
                              subtitleColor: AppColors.textPrimary(context),
                            ),
                            SizedBox(height: isShortScreen ? 26 : 38),
                            _LoginCard(
                              formKey: _formKey,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              isCompact: isNarrowScreen || isShortScreen,
                              isLoading: _isLoading,
                              isPasswordObscured: _obscurePassword,
                              showValidationErrors: _showValidationErrors,
                              isValidEmailFormat: _isValidEmailFormat,
                              isAllowedEmailDomain: _isAllowedEmailDomain,
                              onLogin: _signInWithEmailAndPassword,
                              onFieldChanged: _validateVisibleErrors,
                              onTogglePasswordVisibility: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onForgotPassword: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const ResetPasswordScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isCompact,
    required this.isLoading,
    required this.isPasswordObscured,
    required this.showValidationErrors,
    required this.isValidEmailFormat,
    required this.isAllowedEmailDomain,
    required this.onLogin,
    required this.onFieldChanged,
    required this.onTogglePasswordVisibility,
    required this.onForgotPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isCompact;
  final bool isLoading;
  final bool isPasswordObscured;
  final bool showValidationErrors;
  final bool Function(String email) isValidEmailFormat;
  final bool Function(String email) isAllowedEmailDomain;
  final VoidCallback onLogin;
  final VoidCallback onFieldChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final cardPadding = EdgeInsets.symmetric(
      horizontal: isCompact ? 18 : 24,
      vertical: isCompact ? 22 : 28,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8EB5D8).withValues(alpha: 0.26),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.92),
            blurRadius: 18,
            offset: const Offset(-8, -8),
          ),
        ],
      ),
      child: Padding(
        padding: cardPadding,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) => onFieldChanged(),
                decoration: _fieldDecoration(
                  labelText: 'Correo electrónico',
                  icon: AppIcons.emailRounded,
                ),
                style: const TextStyle(color: Color(0xFF263238), fontSize: 16),
                validator: (value) {
                  if (!showValidationErrors) return null;
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Ingresa tu correo electronico';
                  }
                  if (!isValidEmailFormat(email)) {
                    return 'Ingresa un correo valido';
                  }
                  if (!isAllowedEmailDomain(email)) {
                    return 'Usa un correo autorizado por la escuela';
                  }
                  return null;
                },
              ),
              SizedBox(height: isCompact ? 16 : 20),
              TextFormField(
                controller: passwordController,
                obscureText: isPasswordObscured,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => onFieldChanged(),
                onFieldSubmitted: (_) => onLogin(),
                decoration: _fieldDecoration(
                  labelText: 'Contraseña',
                  icon: AppIcons.lockRounded,
                  suffixIcon: IconButton(
                    tooltip:
                        isPasswordObscured
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                    onPressed: onTogglePasswordVisibility,
                    icon: Icon(
                      isPasswordObscured
                          ? AppIcons.visibilityRounded
                          : AppIcons.visibilityOffRounded,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                style: const TextStyle(color: Color(0xFF263238), fontSize: 16),
                validator: (value) {
                  if (!showValidationErrors) return null;
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu contraseña';
                  }
                  return null;
                },
              ),
              SizedBox(height: isCompact ? 24 : 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(alpha: 0.34),
                        blurRadius: 16,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    onPressed: isLoading ? null : onLogin,
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'INGRESAR',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: isLoading ? null : onForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final borderRadius = BorderRadius.circular(18);

    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: Color(0xFF69727B),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: AppColors.primaryBlue),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FBFF),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: Color(0xFFD9E5F1), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 18),
    );
  }
}
