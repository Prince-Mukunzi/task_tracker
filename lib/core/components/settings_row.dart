import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';

class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final bool showBorder;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.isDestructive = false,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.overdue : AppColors.textPrimary;

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: showBorder
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.divider.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isDestructive
                  ? AppColors.overdue.withValues(alpha: 0.7)
                  : AppColors.textTertiary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: color,
                      fontSize: 15,
                      fontWeight: isDestructive ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null && !isDestructive)
              Icon(LucideIcons.chevronRight,
                  size: 14,
                  color: AppColors.textTertiary.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
