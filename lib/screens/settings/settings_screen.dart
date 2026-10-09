import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/components/settings_row.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/task.dart';
import '../../providers/team_member_provider.dart';
import '../onboarding/onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: topPadding + 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Settings',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w200,
                letterSpacing: -1.5,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Profile section
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceLight,
                    ),
                    child: Center(
                      child: Text(
                        currentUser.avatarInitials,
                        style: AppTypography.labelLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser.name,
                          style: AppTypography.bodyLarge.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          currentUser.role,
                          style: AppTypography.caption.copyWith(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 0.5,
              color: AppColors.divider.withValues(alpha: 0.3),
            ),
          ),

          const SizedBox(height: 8),

          // About section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SettingsRow(
              icon: LucideIcons.info,
              label: 'About Pulse',
              subtitle: 'SLA Tracker v1.0',
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SettingsRow(
              icon: LucideIcons.shield,
              label: 'Privacy',
              subtitle: 'All data stored locally',
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 0.5,
              color: AppColors.divider.withValues(alpha: 0.3),
            ),
          ),

          const SizedBox(height: 8),

          // Danger zone
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SettingsRow(
              icon: LucideIcons.trash2,
              label: 'Clear All Tasks',
              isDestructive: true,
              onTap: () => _showClearTasks(context, ref),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SettingsRow(
              icon: LucideIcons.logOut,
              label: 'Log Out',
              isDestructive: true,
              onTap: () => _showLogout(context, ref),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
        ],
      ),
    );
  }

  void _showClearTasks(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Clear all tasks?'),
        message: const Text('This will permanently delete all tasks.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticFeedback.heavyImpact();
              await Hive.box<Task>('tasks').clear();
              // ignore: unused_result
              ref.refresh(Provider<void>((ref) {}));
            },
            child: const Text('Clear All'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showLogout(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Log out?'),
        message: const Text(
          'Your tasks and team data will be kept. You\'ll need to set up your profile again.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticFeedback.heavyImpact();

              final repo = ref.read(teamMemberRepositoryProvider);
              await repo.deleteMember('current_user');
              ref.read(currentUserProvider.notifier).state = null;

              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
