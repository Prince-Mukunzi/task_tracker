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
                  _SheetTextField(
                    controller: nameCtrl,
                    hint: 'Name',
                    autofocus: true,
                  ),
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
                  ...options.map(
                    (opt) => PressableScale(
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
                              Icon(
                                LucideIcons.check,
                                size: 16,
                                color: AppColors.white,
                              ),
                          ],
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

  void _showSLAThresholdPicker() {
    HapticFeedback.lightImpact();
    final options = [4.0, 8.0, 12.0, 24.0, 48.0, 72.0];
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
                    'At-Risk Threshold',
                    style: AppTypography.headingLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tasks are marked "at risk" when remaining time falls below this threshold.',
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((hours) {
                    final isSelected = _atRiskThreshold == hours;
                    final label = hours >= 24
                        ? '${(hours / 24).toInt()} ${(hours / 24).toInt() == 1 ? 'day' : 'days'}'
                        : '${hours.toInt()} hours';
                    return PressableScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _atRiskThreshold = hours);
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
                              label,
                              style: AppTypography.bodyLarge.copyWith(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(
                                LucideIcons.check,
                                size: 16,
                                color: AppColors.white,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSLAUnitPicker() {
    HapticFeedback.lightImpact();
    final options = ['Hours', 'Business Hours', 'Days', 'Business Days'];
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
                    'SLA Time Unit',
                    style: AppTypography.headingLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final isSelected = _slaUnit == opt;
                    return PressableScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _slaUnit = opt);
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
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(
                                LucideIcons.check,
                                size: 16,
                                color: AppColors.white,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showClearAllTasks() {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Clear all tasks?'),
        message: const Text(
          'This will permanently delete all tasks and cannot be undone.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticFeedback.heavyImpact();
              await Hive.box<Task>('tasks').clear();
              ref.invalidate(tasksProvider);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All tasks cleared'),
                  backgroundColor: AppColors.surfaceLight,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear All Tasks'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showResetApp() {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Reset App?'),
        message: const Text(
          'This will delete all tasks, team members, comments, and log you out. This cannot be undone.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticFeedback.heavyImpact();
              await Hive.box<Task>('tasks').clear();
              final repo = ref.read(teamMemberRepositoryProvider);
              await repo.deleteMember('current_user');
              ref.read(currentUserProvider.notifier).state = null;
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            child: const Text('Reset Everything'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showLogout() {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Sign out?'),
        message: const Text('Your tasks and workspace data will be kept.'),
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
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAddMember() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();

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
                    'Add Member',
                    style: AppTypography.headingLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SheetTextField(
                    controller: nameCtrl,
                    hint: 'Name',
                    autofocus: true,
                  ),
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

                      final id =
                          'member_${DateTime.now().millisecondsSinceEpoch}';
                      final member = TeamMember(
                        id: id,
                        name: name,
                        role: role.isNotEmpty ? role : 'Team Member',
                        avatarInitials: initials,
                      );

                      await ref
                          .read(teamMemberRepositoryProvider)
                          .saveMember(member);
                      ref.invalidate(teamMembersProvider);

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
                          'Add',
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

  void _removeMember(TeamMember member) {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Remove ${member.name}?'),
        message: const Text('They will no longer appear in your workspace.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticFeedback.heavyImpact();
              await ref
                  .read(teamMemberRepositoryProvider)
                  .deleteMember(member.id);
              ref.invalidate(teamMembersProvider);
              setState(() {});
            },
            child: const Text('Remove'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final tasks = ref.watch(tasksProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final activeTasks = totalTasks - completedTasks;

    final thresholdLabel = _atRiskThreshold >= 24
        ? '${(_atRiskThreshold / 24).toInt()} ${(_atRiskThreshold / 24).toInt() == 1 ? 'day' : 'days'}'
        : '${_atRiskThreshold.toInt()} hours';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 20)),

          // Header
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.0, 0.2),
              child: Padding(
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
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 28)),

          // User profile card
          if (currentUser != null)
            SliverToBoxAdapter(
              child: FadeSlideIn(
                parentAnimation: _entranceCtrl,
                interval: const Interval(0.05, 0.25),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TiltCard(
                    maxAngle: 0.015,
                    liftScale: 1.008,
                    child: PressableScale(
                      onTap: _showEditProfile,
                      pressedScale: 0.99,
                      child: FrostedContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(20),
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
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
                            Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: AppColors.textTertiary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Stats summary — inline text
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.08, 0.28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text(
                  totalTasks == 0
                      ? 'No tasks yet'
                      : '$totalTasks ${totalTasks == 1 ? 'task' : 'tasks'} · $activeTasks active · $completedTasks done',
                  style: AppTypography.caption.copyWith(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),

          // ─── SLA CONFIGURATION ───
          _buildSectionHeader('SLA CONFIGURATION', 0.1),
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.12, 0.32),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: FrostedContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SettingsRow(
                        icon: LucideIcons.alertTriangle,
                        label: 'At-Risk Threshold',
                        subtitle: thresholdLabel,
                        onTap: _showSLAThresholdPicker,
                      ),
                      SettingsRow(
                        icon: LucideIcons.timer,
                        label: 'Time Unit',
                        subtitle: _slaUnit,
                        onTap: _showSLAUnitPicker,
                        showBorder: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── NOTIFICATIONS ───
          _buildSectionHeader('NOTIFICATIONS', 0.18),
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.2, 0.4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: FrostedContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ToggleRow(
                        icon: LucideIcons.bell,
                        label: 'Push Notifications',
                        subtitle: 'Receive alerts for updates',
                        value: _pushNotifications,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _pushNotifications = v);
                        },
                      ),
                      ToggleRow(
                        icon: LucideIcons.clock,
                        label: 'Deadline Alerts',
                        subtitle: 'Notify before tasks are due',
                        value: _deadlineAlerts,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _deadlineAlerts = v);
                        },
                      ),
                      ToggleRow(
                        icon: LucideIcons.atSign,
                        label: 'Mention Alerts',
                        subtitle: 'When someone @mentions you',
                        value: _mentionAlerts,
                        showBorder: false,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _mentionAlerts = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── WORKSPACE ───
          _buildSectionHeader('WORKSPACE', 0.28),
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.3, 0.5),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: FrostedContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ...ref.watch(teamMembersProvider).map((member) {
                        final isCurrentUser =
                            member.id == (currentUser?.id ?? '');
                        final isLast =
                            member == ref.watch(teamMembersProvider).last;
                        return _MemberRow(
                          member: member,
                          isCurrentUser: isCurrentUser,
                          showBorder: !isLast,
                          onRemove: isCurrentUser
                              ? null
                              : () => _removeMember(member),
                        );
                      }),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.divider.withValues(alpha: 0.08),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: SettingsRow(
                          icon: LucideIcons.userPlus,
                          label: 'Add Member',
                          showBorder: false,
                          onTap: _showAddMember,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── APP ───
          _buildSectionHeader('APP', 0.38),
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.4, 0.58),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: FrostedContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SettingsRow(
                        icon: LucideIcons.layout,
                        label: 'Default View',
                        subtitle: _defaultView,
                        onTap: _showDefaultViewPicker,
                      ),
                      SettingsRow(
                        icon: LucideIcons.shield,
                        label: 'Privacy',
                        subtitle: 'All data stored locally on device',
                      ),
                      SettingsRow(
                        icon: LucideIcons.info,
                        label: 'About',
                        subtitle: 'Pulse — SLA Tracker v1.0',
                        showBorder: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── DATA MANAGEMENT ───
          _buildSectionHeader('DATA MANAGEMENT', 0.48),
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.5, 0.68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: FrostedContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SettingsRow(
                        icon: LucideIcons.trash2,
                        label: 'Clear All Tasks',
                        isDestructive: true,
                        onTap: _showClearAllTasks,
                      ),
                      SettingsRow(
                        icon: LucideIcons.rotateCcw,
                        label: 'Reset App',
                        subtitle: 'Delete everything and start over',
                        isDestructive: true,
                        showBorder: false,
                        onTap: _showResetApp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Sign Out ───
          _buildSectionHeader('', 0.58),
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.6, 0.75),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: FrostedContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SettingsRow(
                    icon: LucideIcons.logOut,
                    label: 'Sign Out',
                    isDestructive: true,
                    showBorder: false,
                    onTap: _showLogout,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 120)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, double startInterval) {
    return SliverToBoxAdapter(
      child: FadeSlideIn(
        parentAnimation: _entranceCtrl,
        interval: Interval(
          startInterval,
          (startInterval + 0.18).clamp(0.0, 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty)
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Member Row ───
class _MemberRow extends StatelessWidget {
  final TeamMember member;
  final bool isCurrentUser;
  final bool showBorder;
  final VoidCallback? onRemove;

  const _MemberRow({
    required this.member,
    required this.isCurrentUser,
    this.showBorder = true,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceLight,
            ),
            child: Center(
              child: Text(
                member.avatarInitials,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.name,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'You',
                          style: AppTypography.caption.copyWith(
                            fontSize: 9,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  member.role,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            PressableScale(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.x,
                  size: 14,
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Reusable text field for sheets ───
class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  const _SheetTextField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
      cursorColor: AppColors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.textTertiary,
        ),
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.white),
        ),
      ),
    );
  }
}
