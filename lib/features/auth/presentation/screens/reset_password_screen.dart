import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/core/widgets/app_logo.dart';
import 'package:prototipo_2/features/auth/presentation/widgets/auth_decorated_background.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/core/connectivity/network_status_controller.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _emailSent = false;
  bool _showValidationErrors = false;
  String _submittedEmail = '';
  int _validationCycle = 0;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!_validateFormWithTemporaryErrors() || _isLoading) return;

    final network = context.read<NetworkStatusController>();
    await network.checkNow();
    if (!mounted) return;
    if (network.isOffline) {
      _showSnackBar('Sin conexión. Revisa tu Wi-Fi o datos móviles.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      await _auth.setLanguageCode('es');
      await _auth
          .sendPasswordResetEmail(email: email)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      _showSuccess(email);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      if (error.code == 'invalid-email') {
        _showSnackBar('Correo no valido.');
      } else if (error.code == 'too-many-requests') {
        _showSnackBar('Demasiados intentos. Intenta mas tarde.');
      } else if (error.code == 'user-not-found') {
        _showSnackBar('Correo no registrado.');
      } else if (error.code == 'network-request-failed') {
        _showSnackBar('Sin conexion. Intenta nuevamente.');
      } else {
        _showSnackBar('No se pudo enviar. Intenta nuevamente.');
      }
    } on TimeoutException {
      if (!mounted) return;
      _showSnackBar('La conexión está tardando. Revisa tu internet.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('No se pudo enviar. Intenta nuevamente.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccess(String email) {
    setState(() {
      _emailSent = true;
      _submittedEmail = email;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryRed,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  bool _isValidEmailFormat(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  bool _isAllowedEmail(String email) {
    final normalized = email.toLowerCase();
    return normalized.endsWith('@gmail.com') ||
        normalized.endsWith('@cintlimontessori.edu.mx');
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: AuthDecoratedBackground(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(
                      AppIcons.arrowBackRounded,
                      color: AppColors.textPrimary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bottomInset =
                          MediaQuery.viewInsetsOf(context).bottom;
                      final isShortScreen = constraints.maxHeight < 680;
                      final isNarrowScreen = constraints.maxWidth < 360;
                      final horizontalPadding = isNarrowScreen ? 18.0 : 24.0;
                      final verticalPadding = isShortScreen ? 12.0 : 24.0;

                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          verticalPadding,
                          horizontalPadding,
                          bottomInset + verticalPadding + 12,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - verticalPadding,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppLogo(
                                    size: isShortScreen ? 104 : 126,
                                    subtitleColor: AppColors.textPrimary(
                                      context,
                                    ),
                                  ),
                                  SizedBox(height: isShortScreen ? 18 : 28),
                                  _ResetCard(
                                    formKey: _formKey,
                                    emailController: _emailController,
                                    isLoading: _isLoading,
                                    emailSent: _emailSent,
                                    submittedEmail: _submittedEmail,
                                    isDarkMode: isDarkMode,
                                    isCompact: isShortScreen || isNarrowScreen,
                                    showValidationErrors: _showValidationErrors,
                                    isValidEmailFormat: _isValidEmailFormat,
                                    isAllowedEmail: _isAllowedEmail,
                                    onSubmit: _sendPasswordResetEmail,
                                    onFieldChanged: _validateVisibleErrors,
                                    onBackToLogin: () => Navigator.pop(context),
                                    onEditEmail: () {
                                      setState(() {
                                        _emailSent = false;
                                        _submittedEmail = '';
                                      });
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetCard extends StatelessWidget {
  const _ResetCard({
    required this.formKey,
    required this.emailController,
    required this.isLoading,
    required this.emailSent,
    required this.submittedEmail,
    required this.isDarkMode,
    required this.isCompact,
    required this.showValidationErrors,
    required this.isValidEmailFormat,
    required this.isAllowedEmail,
    required this.onSubmit,
    required this.onFieldChanged,
    required this.onBackToLogin,
    required this.onEditEmail,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isLoading;
  final bool emailSent;
  final String submittedEmail;
  final bool isDarkMode;
  final bool isCompact;
  final bool showValidationErrors;
  final bool Function(String email) isValidEmailFormat;
  final bool Function(String email) isAllowedEmail;
  final VoidCallback onSubmit;
  final VoidCallback onFieldChanged;
  final VoidCallback onBackToLogin;
  final VoidCallback onEditEmail;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.86),
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDarkMode
                    ? Colors.black.withValues(alpha: 0.28)
                    : const Color(0xFF8EB5D8).withValues(alpha: 0.26),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          if (!isDarkMode)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.95),
              blurRadius: 12,
              offset: const Offset(-6, -6),
            ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 20 : 26),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: emailSent ? _buildSuccess(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        key: const ValueKey('reset-form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderIcon(
            icon: AppIcons.lockResetRounded,
            backgroundColor: AppColors.softBlue,
            iconColor: AppColors.primaryBlue,
          ),
          const SizedBox(height: 18),
          Text(
            'Recuperar acceso',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: isCompact ? 24 : 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa el correo registrado en la escuela. Te enviaremos instrucciones para crear una nueva contraseña.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => onFieldChanged(),
            onFieldSubmitted: (_) => onSubmit(),
            decoration: _fieldDecoration(context),
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            validator: (value) {
              if (!showValidationErrors) return null;
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Ingresa tu correo';
              if (!isValidEmailFormat(email)) return 'Correo no valido';
              if (!isAllowedEmail(email)) {
                return 'Correo no autorizado';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
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
                onPressed: isLoading ? null : onSubmit,
                child:
                    isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Enviar instrucciones',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: isLoading ? null : onBackToLogin,
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode
                        ? const Color(0xFF8CCBFF)
                        : AppColors.primaryBlue,
                minimumSize: const Size(0, 44),
              ),
              child: const Text(
                'Volver al inicio de sesion',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      key: const ValueKey('reset-success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeaderIcon(
          icon: AppIcons.markEmailReadRounded,
          backgroundColor: Color(0xFFE9FBE8),
          iconColor: AppColors.primaryGreen,
        ),
        const SizedBox(height: 18),
        Text(
          'Revisa tu correo',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: isCompact ? 24 : 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enviamos un enlace a $submittedEmail para restablecer la contraseña.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 14.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? AppColors.darkSurfaceAlt
                    : AppColors.softBlue.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFCFE6FF),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                AppIcons.infoOutlineRounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tambien revisa la carpeta de spam o correo no deseado.',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              onPressed: onBackToLogin,
              child: const Text(
                'Volver al inicio de sesion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: onEditEmail,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDarkMode ? const Color(0xFF8CCBFF) : AppColors.primaryBlue,
              minimumSize: const Size(0, 44),
            ),
            child: const Text(
              'Usar otro correo',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);

    return InputDecoration(
      labelText: 'Correo electronico',
      labelStyle: TextStyle(
        color: AppColors.textSecondary(context),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: const Icon(
        AppIcons.emailRounded,
        color: AppColors.primaryBlue,
      ),
      filled: true,
      fillColor: isDarkMode ? AppColors.darkSurfaceAlt : Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFD8E3EE),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: iconColor, size: 30),
    );
  }
}
