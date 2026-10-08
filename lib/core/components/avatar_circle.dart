import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AvatarCircle extends StatelessWidget {
  final String initials;
  final double size;
  final Color? backgroundColor;
  final double? fontSize;

  const AvatarCircle({
    super.key,
    required this.initials,
    this.size = 28,
    this.backgroundColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppColors.surfaceLight,
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTypography.caption.copyWith(
            fontSize: fontSize ?? size * 0.35,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
