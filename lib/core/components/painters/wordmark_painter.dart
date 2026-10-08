import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class WordmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final fillPaint = Paint()..color = AppColors.accent;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(15 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 16, height: 16),
        const Radius.circular(3),
      ),
      fillPaint,
    );
    canvas.restore();

    final strokePaint = Paint()
      ..color = AppColors.completed.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-10 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 20),
        const Radius.circular(4),
      ),
      strokePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(WordmarkPainter old) => false;
}
