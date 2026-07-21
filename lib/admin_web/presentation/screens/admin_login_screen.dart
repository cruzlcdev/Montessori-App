import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/app_versions.dart';
import '../theme/admin_theme.dart';
import '../../../core/widgets/app_logo.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _messageFor(error.code));
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesion. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Ingresa un correo valido.';
      case 'user-not-found':
        return 'No encontramos una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contrasena incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta mas tarde.';
      case 'network-request-failed':
        return 'No se pudo conectar. Revisa tu internet.';
      default:
        return 'No se pudo iniciar sesion. Intenta de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = context.adminPalette;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        body: Stack(
          children: [
            const _AdminLoginBackground(),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: (isDark ? palette.surface : AppColors.softBlue)
                          .withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color:
                            isDark
                                ? palette.borderStrong
                                : AppColors.primaryBlue.withValues(alpha: 0.16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadow.withValues(
                            alpha: isDark ? 0.42 : 0.16,
                          ),
                          blurRadius: 38,
                          offset: const Offset(0, 24),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(34),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppLogo(
                              size: 118,
                              subtitleColor: context.adminPalette.textPrimary,
                            ),
                            const SizedBox(height: 26),
                            Text(
                              'Panel administrativo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: context.adminPalette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Gestiona la informacion escolar conectada a la app.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.adminPalette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'Correo administrativo',
                                icon: AdminIcons.mailRounded,
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) return 'Ingresa tu correo';
                                if (!email.contains('@')) {
                                  return 'Ingresa un correo valido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onFieldSubmitted: (_) => _login(),
                              decoration: _inputDecoration(
                                label: 'Contrasena',
                                icon: AdminIcons.lockRounded,
                                suffix: IconButton(
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _obscurePassword =
                                                !_obscurePassword,
                                      ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? AdminIcons.visibilityRounded
                                        : AdminIcons.visibilityOffRounded,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Ingresa tu contrasena';
                                }
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              _InlineError(message: _error!),
                            ],
                            const SizedBox(height: 22),
                            FilledButton(
                              onPressed: _isLoading ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                      : Text(
                                        'Ingresar al panel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                            ),
                            const SizedBox(height: 18),
                            Tooltip(
                              message:
                                  'Compilación ${AppVersions.adminWeb.full}',
                              child: Text(
                                'Panel web v${AppVersions.adminWeb.display}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.adminPalette.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = context.adminPalette;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.adaptiveBlue(context)),
      suffixIcon: suffix,
      filled: true,
      fillColor:
          isDark ? palette.inputFill : Colors.white.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color:
              isDark
                  ? palette.borderStrong
                  : AppColors.primaryBlue.withValues(alpha: 0.18),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppColors.adaptiveBlue(context),
          width: 1.6,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            AdminIcons.errorOutlineRounded,
            color: AppColors.primaryRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.adminPalette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLoginBackground extends StatelessWidget {
  const _AdminLoginBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.adminPalette.canvas,
            context.adminPalette.surfaceMuted,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LoginWavesPainter(
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -90,
            child: _Blob(color: AppColors.primaryTurquoise, size: 300),
          ),
          Positioned(
            right: -120,
            top: -70,
            child: _Blob(color: AppColors.primaryYellow, size: 260),
          ),
          Positioned(
            left: -80,
            bottom: -110,
            child: _Blob(color: AppColors.primaryRed, size: 290),
          ),
          Positioned(
            right: 80,
            bottom: 70,
            child: _Blob(color: AppColors.primaryGreen, size: 160),
          ),
        ],
      ),
    );
  }
}

class _LoginWavesPainter extends CustomPainter {
  const _LoginWavesPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = isDark ? 0.36 : 0.30;

    final upperSolid =
        Path()
          ..moveTo(-size.width * 0.06, size.height * 0.18)
          ..cubicTo(
            size.width * 0.14,
            size.height * 0.09,
            size.width * 0.30,
            size.height * 0.29,
            size.width * 0.48,
            size.height * 0.18,
          )
          ..cubicTo(
            size.width * 0.66,
            size.height * 0.07,
            size.width * 0.78,
            size.height * 0.25,
            size.width * 1.06,
            size.height * 0.12,
          );
    _drawPath(
      canvas,
      upperSolid,
      color: AppColors.primaryBlue.withValues(alpha: opacity),
      width: 1.8,
    );

    final upperDashed =
        Path()
          ..moveTo(-size.width * 0.03, size.height * 0.31)
          ..cubicTo(
            size.width * 0.18,
            size.height * 0.23,
            size.width * 0.28,
            size.height * 0.39,
            size.width * 0.48,
            size.height * 0.30,
          )
          ..cubicTo(
            size.width * 0.70,
            size.height * 0.20,
            size.width * 0.78,
            size.height * 0.39,
            size.width * 1.04,
            size.height * 0.27,
          );
    _drawDashedPath(
      canvas,
      upperDashed,
      color: AppColors.primaryTurquoise.withValues(alpha: opacity + 0.12),
      width: 2.5,
      dashLength: 14,
      gapLength: 10,
    );

    final lowerSolid =
        Path()
          ..moveTo(-size.width * 0.05, size.height * 0.78)
          ..cubicTo(
            size.width * 0.15,
            size.height * 0.67,
            size.width * 0.30,
            size.height * 0.88,
            size.width * 0.48,
            size.height * 0.76,
          )
          ..cubicTo(
            size.width * 0.66,
            size.height * 0.64,
            size.width * 0.84,
            size.height * 0.86,
            size.width * 1.05,
            size.height * 0.73,
          );
    _drawPath(
      canvas,
      lowerSolid,
      color: AppColors.primaryGreen.withValues(alpha: opacity),
      width: 2,
    );

    final lowerDashed =
        Path()
          ..moveTo(size.width * 0.42, size.height * 0.91)
          ..cubicTo(
            size.width * 0.56,
            size.height * 0.82,
            size.width * 0.68,
            size.height * 1.01,
            size.width * 0.82,
            size.height * 0.89,
          )
          ..cubicTo(
            size.width * 0.90,
            size.height * 0.82,
            size.width * 0.97,
            size.height * 0.87,
            size.width * 1.05,
            size.height * 0.83,
          );
    _drawDashedPath(
      canvas,
      lowerDashed,
      color: AppColors.primaryRed.withValues(alpha: opacity + 0.08),
      width: 2.4,
      dashLength: 10,
      gapLength: 8,
    );
  }

  void _drawPath(
    Canvas canvas,
    Path path, {
    required Color color,
    required double width,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path, {
    required Color color,
    required double width,
    required double dashLength,
    required double gapLength,
  }) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(
            distance,
            end < metric.length ? end : metric.length,
          ),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LoginWavesPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}
