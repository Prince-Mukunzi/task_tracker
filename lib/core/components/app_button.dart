import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../constants/app_spacing.dart';
import 'pressable_scale.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final bool isFullWidth;
  final Widget? leadingIcon;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.isFullWidth = false,
    this.leadingIcon,
  });

  _ButtonStyle _resolveStyle() {
    switch (variant) {
      case AppButtonVariant.primary:
        return _ButtonStyle(
          background: AppColors.accent,
          textColor: AppColors.onAccent,
          borderColor: Colors.transparent,
        );
      case AppButtonVariant.secondary:
        return _ButtonStyle(
          background: AppColors.surfaceLight,
          textColor: AppColors.textPrimary,
          borderColor: AppColors.divider,
        );
      case AppButtonVariant.ghost:
        return _ButtonStyle(
          background: Colors.transparent,
          textColor: AppColors.accent,
          borderColor: Colors.transparent,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle();

    return PressableScale(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: style.borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                leadingIcon!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: style.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonStyle {
  final Color background;
  final Color textColor;
  final Color borderColor;

  const _ButtonStyle({
    required this.background,
    required this.textColor,
    required this.borderColor,
  });
}
