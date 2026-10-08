import 'package:flutter/material.dart';

class SonarPainter extends CustomPainter {
  final Offset origin;
  final double progress;
  final Color color;

  const SonarPainter({
    required this.origin,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = progress * 160;
    final opacity = progress < 0.4 ? progress / 0.4 : 1.0 - ((progress - 0.4) / 0.6);

    final paint = Paint()
      ..color = color.withValues(alpha: (opacity * 0.5).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * (1.0 - progress * 0.7);

    canvas.drawCircle(origin, radius, paint);

    if (progress > 0.15) {
      final radius2 = (progress - 0.15) * 160;
      canvas.drawCircle(
        origin,
        radius2,
        paint
          ..color = color.withValues(alpha: (opacity * 0.25).clamp(0.0, 1.0))
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(SonarPainter old) => old.progress != progress;
}
