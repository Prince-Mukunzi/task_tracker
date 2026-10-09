import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/dismissible_backgrounds.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';

// Shows every notification saved in SQLite, newest first.
class NotificationsScreen extends ConsumerStatefulWidget {

  final void Function(String taskId)? onOpenTask;

  const NotificationsScreen({super.key, this.onOpenTask});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;

  bool _showUnreadOnly = false;
  final Set<int> _hiddenIds = {};

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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

  Future<void> _onTapNotification(AppNotification notification) async {
    final id = notification.id;
    if (!notification.isRead && id != null) {
      await ref.read(notificationRepositoryProvider).markAsRead(id);
      if (!mounted) return;
      refreshNotifications(ref);
    }

    final taskId = notification.taskId;
    if (taskId != null && widget.onOpenTask != null) {
      widget.onOpenTask!(taskId);
    }
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllAsRead();
    if (!mounted) return;
    refreshNotifications(ref);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _delete(AppNotification notification) async {
    final id = notification.id;
    if (id == null) return;


    setState(() => _hiddenIds.add(id));

    await ref.read(notificationRepositoryProvider).delete(id);
    if (!mounted) return;
    refreshNotifications(ref);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Take the list out of the AsyncValue
    final allNotifications = notificationsAsync.when(
      data: (list) => list,
      loading: () => <AppNotification>[],
      error: (error, stack) => <AppNotification>[],
    );
    final visible = allNotifications
        .where((n) => !_hiddenIds.contains(n.id))
        .toList();
    final unreadCount = visible.where((n) => !n.isRead).length;
    final shown = _showUnreadOnly
        ? visible.where((n) => !n.isRead).toList()
        : visible;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),

          // Top bar
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      PressableScale(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            LucideIcons.chevronLeft,
                            size: 22,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (unreadCount > 0)
                      PressableScale(
                        onTap: _markAllRead,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.check,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mark all read',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Title
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.0, 0.2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Notifications',
                  style: AppTypography.displayLarge.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Subtitle: unread count
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.05, 0.25),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  unreadCount == 0
                      ? 'You\'re all caught up'
                      : '$unreadCount unread',
                  style: AppTypography.caption.copyWith(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),


          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.1, 0.3),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: !_showUnreadOnly,
                      onTap: () => setState(() => _showUnreadOnly = false),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: unreadCount > 0
                          ? 'Unread · $unreadCount'
                          : 'Unread',
                      selected: _showUnreadOnly,
                      onTap: () => setState(() => _showUnreadOnly = true),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                height: 0.5,
                color: AppColors.divider.withValues(alpha: 0.2),
              ),
            ),
          ),

          // The list
          notificationsAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: _MessageState(
                icon: LucideIcons.alertTriangle,
                title: 'Couldn\'t load notifications',
                subtitle: 'Something went wrong reading the database.',
                actionLabel: 'Try again',
                onAction: () => refreshNotifications(ref),
              ),
            ),
            data: (_) {
              if (shown.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(
                    icon: LucideIcons.bellOff,
                    title: _showUnreadOnly
                        ? 'No unread notifications'
                        : 'No notifications yet',
                    subtitle:
                    'New tasks and approaching deadlines will show up here',
                  ),
                );
              }
              return SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final notification = shown[index];
                  return SliverStaggerItem(
                    index: index,
                    child: Dismissible(
                      key: ValueKey(notification.id),
                      direction: DismissDirection.endToStart,
                      background: const DeleteSwipeBackground(),
                      onDismissed: (_) => _delete(notification),
                      child: _NotificationTile(
                        notification: notification,
                        onTap: () => _onTapNotification(notification),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 120)),
        ],
      ),
    );
  }
}


class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(notification.type);
    final isRead = notification.isRead;

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(_iconFor(notification.type), size: 15, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 13,
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                        color: isRead
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTimeAgo(notification.createdAt),
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.taskCreated:
        return LucideIcons.plus;
      case NotificationType.taskUpdated:
        return LucideIcons.pencil;
      case NotificationType.taskCompleted:
        return LucideIcons.circleCheck;
      case NotificationType.atRisk:
        return LucideIcons.clock;
      case NotificationType.overdue:
        return LucideIcons.alertTriangle;
      case NotificationType.mention:
        return LucideIcons.atSign;
    }
  }

  static Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.atRisk:
        return AppColors.atRisk;
      case NotificationType.overdue:
        return AppColors.overdue;
      case NotificationType.taskCompleted:
        return AppColors.onTrack;
      case NotificationType.taskCreated:
      case NotificationType.taskUpdated:
      case NotificationType.mention:
        return AppColors.textSecondary;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? AppColors.black : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

// empty and error message
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlowPulse(
              color: AppColors.white,
              radius: 36,
              period: const Duration(milliseconds: 3000),
              child: Floating(
                amplitude: 4,
                period: const Duration(milliseconds: 4000),
                child: Icon(icon, size: 32, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              PressableScale(
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    actionLabel!,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
