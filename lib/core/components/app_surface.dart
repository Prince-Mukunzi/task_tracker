import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../constants/app_spacing.dart';

class AppSurface extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool glowBorder;

  const AppSurface({
    super.key,
    required this.child,
    this.color,
    this.borderRadius,
    this.padding,
    this.glowBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSpacing.radiusLg,
        ),
        border: Border.all(
          color: glowBorder
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
