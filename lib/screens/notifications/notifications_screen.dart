import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/components/dismissible_backgrounds.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/notification_repository.dart';
import '../../models/app_notification.dart';

class NotificationsScreen extends StatefulWidget {

  final void Function(String taskId)? onOpenTask;

  const NotificationsScreen({super.key, this.onOpenTask});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationRepository();


  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Couldn\'t load notifications';
      });
    }
  }

  Future<void> _open(AppNotification notification) async {
    final id = notification.id;
    if (!notification.isRead && id != null) {
      await _repo.markAsRead(id);
      await _load();
    }
    if (!mounted) return;

    final taskId = notification.taskId;
    if (taskId != null && widget.onOpenTask != null) {
      widget.onOpenTask!(taskId);
    }
  }

  Future<void> _markAllRead() async {
    await _repo.markAllAsRead();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _delete(AppNotification notification) async {

    setState(() => _notifications.remove(notification));

    final id = notification.id;
    if (id != null) await _repo.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;
    final shown = _showUnreadOnly
        ? _notifications.where((n) => !n.isRead).toList()
        : _notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            SizedBox(
              height: 48,
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
                    if (unread > 0)
                      PressableScale(
                        onTap: _markAllRead,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Mark all read',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Title and unread count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Notifications',
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                unread == 0 ? 'You\'re all caught up' : '$unread unread',
                style: AppTypography.caption.copyWith(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Filter chips
            Padding(
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
                    label: 'Unread',
                    selected: _showUnreadOnly,
                    onTap: () => setState(() => _showUnreadOnly = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // The list fills the rest of the screen
            Expanded(child: _buildList(shown)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<AppNotification> shown) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return _Message(
        icon: LucideIcons.alertTriangle,
        title: _error!,
        actionLabel: 'Try again',
        onAction: () {
          setState(() => _isLoading = true);
          _load();
        },
      );
    }

    if (shown.isEmpty) {
      return _Message(
        icon: LucideIcons.bellOff,
        title: _showUnreadOnly
            ? 'No unread notifications'
            : 'No notifications yet',
      );
    }

    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final notification = shown[index];
        return Dismissible(
          key: ValueKey(notification.id),
          direction: DismissDirection.endToStart,
          background: const DeleteSwipeBackground(),
          onDismissed: (_) => _delete(notification),
          child: _NotificationTile(
            notification: notification,
            onTap: () => _open(notification),
          ),
        );
      },
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coloured icon: yellow = at risk, red = overdue, green = done
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
                    style: AppTypography.labelLarge.copyWith(
                      fontSize: 13,
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      color: isRead
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatTimeAgo(notification.createdAt),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            // White dot = unread
            if (!isRead)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(left: 8, top: 4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                ),
              ),
          ],
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
      child: Container(
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
          ),
        ),
      ),
    );
  }
}

// empty message
class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.headingSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

// notification bell
class NotificationBell extends StatefulWidget {
  final void Function(String taskId)? onOpenTask;

  const NotificationBell({super.key, this.onOpenTask});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    // Count the unread notifications
    NotificationRepository().refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.9,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(onOpenTask: widget.onOpenTask),
          ),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceLight,
        ),

        child: ValueListenableBuilder<int>(
          valueListenable: NotificationRepository.unreadCount,
          builder: (context, count, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  LucideIcons.bell,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
                if (count > 0)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.overdue,
                        border: Border.all(
                          color: AppColors.background,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: AppTypography.caption.copyWith(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
