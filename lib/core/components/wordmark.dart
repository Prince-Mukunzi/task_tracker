import 'package:flutter/material.dart';
import '../animations/animation_helpers.dart';
import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'painters/wordmark_painter.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Breathing(
      intensity: 0.02,
      period: const Duration(milliseconds: 4000),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CustomPaint(painter: WordmarkPainter()),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'pulse',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 2,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
