import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/colors.dart';

class AuthDecoratedBackground extends StatefulWidget {
  const AuthDecoratedBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuthDecoratedBackground> createState() =>
      _AuthDecoratedBackgroundState();
}

class _AuthDecoratedBackgroundState extends State<AuthDecoratedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0.18;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _AuthBackgroundPainter(animation: _controller),
              isComplex: true,
              willChange: true,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuthBackgroundPainter extends CustomPainter {
  _AuthBackgroundPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    final wave = math.sin(progress * math.pi * 2);
    final drift = math.cos(progress * math.pi * 2);

    _drawCircle(
      canvas,
      Offset(size.width * 1.04, -size.height * 0.02),
      size.width * 0.22,
      AppColors.primaryYellow.withValues(alpha: 0.5),
    );
    _drawCircle(
      canvas,
      Offset(-size.width * 0.17, size.height * 0.88),
      size.width * 0.3,
      AppColors.primaryRed.withValues(alpha: 0.34),
    );
    _drawCircle(
      canvas,
      Offset(-size.width * 0.08, size.height * 0.08),
      size.width * 0.18,
      AppColors.primaryTurquoise.withValues(alpha: 0.26),
    );
    _drawCircle(
      canvas,
      Offset(size.width * 1.08, size.height * 0.78),
      size.width * 0.22,
      AppColors.primaryGreen.withValues(alpha: 0.22),
    );

    _drawSoftWave(
      canvas,
      size,
      start: Offset(-size.width * 0.14, size.height * 0.09 + wave * 4),
      end: Offset(size.width * 1.12, size.height * 0.16 + drift * 5),
      amplitude: size.height * 0.022,
      color: AppColors.primaryBlue.withValues(alpha: 0.16),
      strokeWidth: 1.1,
      dashed: false,
      phase: progress,
    );
    _drawSoftWave(
      canvas,
      size,
      start: Offset(-size.width * 0.12, size.height * 0.18 + drift * 5),
      end: Offset(size.width * 1.1, size.height * 0.13 + wave * 5),
      amplitude: size.height * 0.032,
      color: AppColors.primaryTurquoise.withValues(alpha: 0.5),
      strokeWidth: 2.6,
      dashed: true,
      phase: progress + 0.28,
    );
    _drawLoopingTrail(
      canvas,
      size,
      origin: Offset(size.width * 0.02, size.height * 0.76 + wave * 8),
      color: AppColors.primaryBlue.withValues(alpha: 0.2),
      phase: progress,
    );
    _drawSoftWave(
      canvas,
      size,
      start: Offset(-size.width * 0.16, size.height * 0.93 + drift * 4),
      end: Offset(size.width * 1.1, size.height * 0.86 + wave * 7),
      amplitude: size.height * 0.035,
      color: AppColors.primaryRed.withValues(alpha: 0.22),
      strokeWidth: 1.4,
      dashed: false,
      phase: progress + 0.62,
    );

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dots = [
      (
        Offset(size.width * 0.13, size.height * 0.18),
        7.0,
        AppColors.primaryGreen,
      ),
      (
        Offset(size.width * 0.88, size.height * 0.15),
        5.5,
        AppColors.primaryOrange,
      ),
      (
        Offset(size.width * 0.77, size.height * 0.9),
        6.5,
        AppColors.primaryYellow,
      ),
    ];

    for (final dot in dots) {
      dotPaint.color = dot.$3.withValues(alpha: 0.9);
      canvas.drawCircle(
        Offset(dot.$1.dx + drift * 4, dot.$1.dy + wave * 3),
        dot.$2,
        dotPaint,
      );
    }
  }

  void _drawCircle(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  void _drawSoftWave(
    Canvas canvas,
    Size size, {
    required Offset start,
    required Offset end,
    required double amplitude,
    required Color color,
    required double strokeWidth,
    required bool dashed,
    required double phase,
  }) {
    final path = Path()..moveTo(start.dx, start.dy);
    final width = end.dx - start.dx;
    final segments = 5;

    for (var i = 0; i < segments; i++) {
      final fromT = i / segments;
      final toT = (i + 1) / segments;
      final midT = (fromT + toT) / 2;
      final direction = i.isEven ? -1.0 : 1.0;
      final control = Offset(
        start.dx + width * midT,
        _lerp(start.dy, end.dy, midT) +
            (amplitude * direction) +
            math.sin((phase + midT) * math.pi * 2) * 5,
      );
      final target = Offset(
        start.dx + width * toT,
        _lerp(start.dy, end.dy, toT),
      );
      path.quadraticBezierTo(control.dx, control.dy, target.dx, target.dy);
    }

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    if (dashed) {
      _drawDashedPath(canvas, path, paint, dashWidth: 16, dashSpace: 13);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawLoopingTrail(
    Canvas canvas,
    Size size, {
    required Offset origin,
    required Color color,
    required double phase,
  }) {
    final path = Path()..moveTo(origin.dx, origin.dy);
    path.cubicTo(
      size.width * 0.18,
      origin.dy - size.height * 0.08,
      size.width * 0.26,
      origin.dy + size.height * 0.08,
      size.width * 0.36,
      origin.dy + size.height * 0.01,
    );
    path.cubicTo(
      size.width * 0.48,
      origin.dy - size.height * 0.07,
      size.width * 0.5,
      origin.dy + size.height * 0.1,
      size.width * 0.62,
      origin.dy + size.height * 0.02,
    );
    path.cubicTo(
      size.width * 0.78,
      origin.dy - size.height * 0.1,
      size.width * 0.92,
      origin.dy + size.height * 0.06,
      size.width * 1.1,
      origin.dy - size.height * 0.01,
    );

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(0, math.sin(phase * math.pi * 2) * 4);
    _drawDashedPath(canvas, path, paint, dashWidth: 13, dashSpace: 12);
    canvas.restore();
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashWidth,
    required double dashSpace,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  double _lerp(double start, double end, double t) {
    return start + ((end - start) * t);
  }

  @override
  bool shouldRepaint(covariant _AuthBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
