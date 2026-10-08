import 'dart:math' as math;
import 'package:flutter/material.dart';

class CrystallisePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final String initials;
  final Color color;

  const CrystallisePainter({
    required this.center,
    required this.progress,
    required this.initials,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: (progress * 0.55).clamp(0, 0.55));
    canvas.drawRect(Offset.zero & size, dimPaint);

    double scale;
    if (progress < 0.7) {
      scale = progress / 0.7;
    } else {
      final t = (progress - 0.7) / 0.3;
      scale = 1.0 + 0.08 * math.sin(t * math.pi) * (1.0 - t);
    }

    final radius = 56.0 * scale;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: (0.25 * progress).clamp(0, 0.25))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, radius + 20, glowPaint);

    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.85,
        colors: [
          color.withValues(alpha: 0.40),
          color.withValues(alpha: 0.18),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fillPaint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: progress.clamp(0, 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, borderPaint);

    if (progress > 0.4 && initials.isNotEmpty) {
      final textOpacity = ((progress - 0.4) / 0.3).clamp(0.0, 1.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: initials,
          style: TextStyle(
            color: color.withValues(alpha: textOpacity),
            fontSize: 28 * scale,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(CrystallisePainter old) =>
      old.progress != progress || old.initials != initials;
}
