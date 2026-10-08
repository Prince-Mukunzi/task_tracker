import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// Ambient living background with multiple drifting orbs.
// On pure black, these create barely-visible warm spots
// that drift independently so the screen never feels dead.
class AnimatedBackground extends StatefulWidget {
  final Widget? child;

  const AnimatedBackground({super.key, this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _ctrl1;
  late AnimationController _ctrl2;

  @override
  void initState() {
    super.initState();
    _ctrl1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _ctrl2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl1, _ctrl2]),
      builder: (context, child) {
        final t1 = _ctrl1.value;
        final t2 = _ctrl2.value;
        return CustomPaint(
          painter: _OrbPainter(t1: t1, t2: t2),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t1;
  final double t2;

  _OrbPainter({required this.t1, required this.t2});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.background,
    );

    // Primary orb — drifts upper-centre
    _drawOrb(
      canvas, size,
      cx: size.width * (0.3 + 0.4 * math.sin(t1 * math.pi)),
      cy: size.height * (0.2 + 0.15 * math.cos(t1 * math.pi * 0.7)),
      radius: size.width * 0.6,
      alpha: 0.025,
    );

    // Secondary orb — drifts lower, out of phase
    _drawOrb(
      canvas, size,
      cx: size.width * (0.7 - 0.3 * math.sin(t2 * math.pi * 0.8)),
      cy: size.height * (0.6 + 0.2 * math.cos(t2 * math.pi)),
      radius: size.width * 0.5,
      alpha: 0.018,
    );
  }

  void _drawOrb(
    Canvas canvas,
    Size size, {
    required double cx,
    required double cy,
    required double radius,
    required double alpha,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.white.withValues(alpha: alpha),
          AppColors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t1 != t1 || old.t2 != t2;
}
