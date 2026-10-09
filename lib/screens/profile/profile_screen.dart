import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/components/settings_row.dart';
import '../../core/components/toggle_row.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/task.dart';
import '../../models/team_member.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_member_provider.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;

  bool _pushNotifications = true;
  bool _deadlineAlerts = true;
  bool _mentionAlerts = true;
  String _defaultView = 'Dashboard';

  // SLA thresholds (hours)
  double _atRiskThreshold = 24;
  String _slaUnit = 'Hours';

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

void _showEditProfile() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final nameCtrl = TextEditingController(text: currentUser.name);
    final roleCtrl = TextEditingController(text: currentUser.role);

    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Edit Profile',
                    style: AppTypography.headingLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SheetTextField(controller: nameCtrl, hint: 'Name', autofocus: true),
                  const SizedBox(height: 12),
                  _SheetTextField(controller: roleCtrl, hint: 'Role'),
                  const SizedBox(height: 24),
                  PressableScale(
                    onTap: () async {
                      final name = nameCtrl.text.trim();
                      final role = roleCtrl.text.trim();
                      if (name.length < 2) return;

                      final initials = name.split(' ').length >= 2
                          ? '${name.split(' ')[0][0]}${name.split(' ')[1][0]}'
                              .toUpperCase()
                          : name.substring(0, 2).toUpperCase();

                      final updated = currentUser.copyWith(
                        name: name,
                        role: role.isNotEmpty ? role : currentUser.role,
                        avatarInitials: initials,
                      );

                      await ref
                          .read(teamMemberRepositoryProvider)
                          .saveMember(updated);
                      ref.invalidate(teamMembersProvider);
                      ref.read(currentUserProvider.notifier).state = updated;

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      setState(() {});
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Text(
                          'Save',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDefaultViewPicker() {
    HapticFeedback.lightImpact();
    final options = ['Dashboard', 'Tasks'];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Default View',
                    style: AppTypography.headingLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) => PressableScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _defaultView = opt);
                      Navigator.of(ctx).pop();
                    },
                    pressedScale: 0.98,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.divider.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            opt,
                            style: AppTypography.bodyLarge.copyWith(
                              fontSize: 15,
                              fontWeight: _defaultView == opt
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _defaultView == opt
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (_defaultView == opt)
                            Icon(LucideIcons.check,
                                size: 16, color: AppColors.white),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  