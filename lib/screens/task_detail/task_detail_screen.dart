import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/avatar_circle.dart';
import '../../core/components/bottom_sheet_handle.dart';
import '../../core/components/info_row.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/comment_repository.dart';
import '../../models/enums.dart';
import '../../models/task.dart';
import '../../models/team_member.dart';
import '../../providers/comment_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_member_provider.dart';
import '../create_task/create_task_screen.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late ConfettiController _confettiCtrl;
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  bool _showMentionPicker = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _confettiCtrl = ConfettiController(duration: const Duration(milliseconds: 800));
    _commentCtrl.addListener(_onCommentChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
    });
  }

  void _onCommentChanged() {
    final text = _commentCtrl.text;
    final cursor = _commentCtrl.selection.baseOffset;
    if (cursor < 0) return;

    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx >= 0 && !before.substring(atIdx).contains(' ')) {
      if (!_showMentionPicker) setState(() => _showMentionPicker = true);
    } else {
      if (_showMentionPicker) setState(() => _showMentionPicker = false);
    }
  }

  @override
  void dispose() {
    _commentCtrl.removeListener(_onCommentChanged);
    _entranceCtrl.dispose();
    _confettiCtrl.dispose();
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Task? get _task =>
      ref.read(taskRepositoryProvider).getTaskById(widget.taskId);

  Future<void> _toggleComplete() async {
    final task = _task;
    if (task == null) return;
    HapticFeedback.heavyImpact();

    final newStatus = task.isCompleted ? TaskStatus.open : TaskStatus.done;
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      status: newStatus,
    );
    await ref.read(taskRepositoryProvider).updateTask(updated);
    ref.invalidate(tasksProvider);

    if (!task.isCompleted) {
      _confettiCtrl.play();
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  void _editTask() {
    final task = _task;
    if (task == null) return;
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(SheetRoute(page: CreateTaskScreen(editTask: task)))
        .then((_) => setState(() {}));
  }

  void _showDeleteSheet() {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Delete this task?'),
        message: const Text('This cannot be undone.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticFeedback.heavyImpact();
              await ref
                  .read(taskRepositoryProvider)
                  .deleteTask(widget.taskId);
              ref.invalidate(tasksProvider);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _changeStatus() {
    final task = _task;
    if (task == null) return;
    HapticFeedback.lightImpact();

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
                  const BottomSheetHandle(title: 'Status'),
                  const SizedBox(height: 16),
                  ...TaskStatus.values.map((s) {
                    final isSelected = task.status == s;
                    final color = taskStatusColor(s);
                    return PressableScale(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final isDone = s == TaskStatus.done;
                        final updated = task.copyWith(
                          status: s,
                          isCompleted: isDone,
                        );
                        await ref.read(taskRepositoryProvider).updateTask(updated);
                        ref.invalidate(tasksProvider);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (isDone && !task.isCompleted) {
                          _confettiCtrl.play();
                          await Future.delayed(const Duration(milliseconds: 800));
                          if (!mounted) return;
                          Navigator.of(context).pop();
                        } else {
                          setState(() {});
                        }
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
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              taskStatusLabel(s),
                              style: AppTypography.bodyLarge.copyWith(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(LucideIcons.check, size: 16, color: AppColors.white),
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

  void _insertMention(TeamMember member) {
    final text = _commentCtrl.text;
    final selection = _commentCtrl.selection;
    final insert = '@${member.name.split(' ').first} ';

    final newText =
        text.replaceRange(selection.start, selection.end, insert);
    _commentCtrl.text = newText;
    _commentCtrl.selection = TextSelection.collapsed(
      offset: selection.start + insert.length,
    );
    setState(() => _showMentionPicker = false);
    _commentFocus.requestFocus();
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final members = ref.read(teamMembersProvider);

    final mentions = <String>[];
    final mentionRegex = RegExp(r'@(\w+)');
    for (final match in mentionRegex.allMatches(text)) {
      final name = match.group(1)!.toLowerCase();
      final member = members
          .where((m) => m.name.split(' ').first.toLowerCase() == name)
          .firstOrNull;
      if (member != null) {
        mentions.add(member.id);
      }
    }

    final comment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorId: user?.id ?? 'current_user',
      authorName: user?.name ?? 'You',
      authorInitials: user?.avatarInitials ?? 'ME',
      content: text,
      createdAt: DateTime.now(),
      mentions: mentions,
    );

    HapticFeedback.lightImpact();
    await ref.read(commentRepositoryProvider).addComment(widget.taskId, comment);
    ref.invalidate(commentsProvider(widget.taskId));
    _commentCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    if (task == null) {
      return Container(
        color: AppColors.surface,
        child: Center(
          child: Text('Task not found', style: AppTypography.bodyMedium),
        ),
      );
    }

    final statusColor = AppColors.statusColor(task.slaStatus);
    final timeLeft = task.deadline.difference(DateTime.now());
    final members = ref.watch(teamMembersProvider);
    final assignees = task.assigneeIds
        .map((id) => members.where((m) => m.id == id).firstOrNull)
        .where((m) => m != null)
        .cast<TeamMember>()
        .toList();
    final comments = ref.watch(commentsProvider(widget.taskId));

    final totalDuration = task.deadline.difference(task.createdAt);
    final elapsed = DateTime.now().difference(task.createdAt);
    final progress = totalDuration.inMinutes > 0
        ? (elapsed.inMinutes / totalDuration.inMinutes).clamp(0.0, 1.0)
        : 1.0;

    return Stack(
      children: [
        Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PressableScale(
                    onTap: _editTask,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(LucideIcons.pencil,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PressableScale(
                    onTap: _showDeleteSheet,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(LucideIcons.trash2,
                          size: 16, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Status + time
                    FadeSlideIn(
                      parentAnimation: _entranceCtrl,
                      interval: const Interval(0.0, 0.2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: task.isCompleted
                                  ? AppColors.completed
                                  : statusColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            task.isCompleted
                                ? 'Completed'
                                : slaStatusLabel(task.slaStatus),
                            style: AppTypography.labelSmall.copyWith(
                              color: task.isCompleted
                                  ? AppColors.completed
                                  : statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                          if (!task.isCompleted) ...[
                            const SizedBox(width: 8),
                            Text(
                              '·',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatCountdown(timeLeft),
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 11,
                                color: statusColor.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title
                    FadeSlideIn(
                      parentAnimation: _entranceCtrl,
                      interval: const Interval(0.05, 0.25),
                      child: Text(
                        task.title,
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.2,
                          height: 1.1,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppColors.textTertiary,
                          color: task.isCompleted
                              ? AppColors.textTertiary
                              : null,
                        ),
                      ),
                    ),

                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      FadeSlideIn(
                        parentAnimation: _entranceCtrl,
                        interval: const Interval(0.1, 0.3),
                        child: Text(
                          task.description,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    // Tags (right below title/description)
                    if (task.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        parentAnimation: _entranceCtrl,
                        interval: const Interval(0.12, 0.32),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: task.tags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              tag,
                              style: AppTypography.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],

                    // Progress bar
                    if (!task.isCompleted) ...[
                      const SizedBox(height: 28),
                      FadeSlideIn(
                        parentAnimation: _entranceCtrl,
                        interval: const Interval(0.15, 0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Progress',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: statusColor
                                        .withValues(alpha: 0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 3,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: AppColors.surfaceLight,
                                  valueColor: AlwaysStoppedAnimation(
                                    statusColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Details
                    FadeSlideIn(
                      parentAnimation: _entranceCtrl,
                      interval: const Interval(0.2, 0.5),
                      child: Column(
                        children: [
                          PressableScale(
                            onTap: _changeStatus,
                            pressedScale: 0.99,
                            child: InfoRow(
                              icon: LucideIcons.circleCheck,
                              label: 'Status',
                              value: taskStatusLabel(task.status),
                              valueColor: taskStatusColor(task.status),
                              showChevron: true,
                            ),
                          ),
                          InfoRow(
                            icon: LucideIcons.flag,
                            label: 'Priority',
                            value: priorityLabel(task.priority),
                            valueColor:
                                AppColors.priorityColor(task.priority),
                          ),
                          InfoRow(
                            icon: LucideIcons.calendar,
                            label: 'Deadline',
                            value: formatDate(task.deadline),
                          ),
                          InfoRow(
                            icon: LucideIcons.clock,
                            label: 'Created',
                            value: formatDate(task.createdAt),
                          ),
                        ],
                      ),
                    ),

                    // Assignees
                    if (assignees.isNotEmpty)
                      FadeSlideIn(
                        parentAnimation: _entranceCtrl,
                        interval: const Interval(0.25, 0.55),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.divider
                                    .withValues(alpha: 0.12),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.users,
                                  size: 15, color: AppColors.textTertiary),
                              const SizedBox(width: 14),
                              Text(
                                'Assigned',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              ...assignees.map((a) => Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: AvatarCircle(
                                      initials: a.avatarInitials,
                                      size: 26,
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 28),

                    // Comments section
                    FadeSlideIn(
                      parentAnimation: _entranceCtrl,
                      interval: const Interval(0.3, 0.6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.messageCircle,
                                  size: 14, color: AppColors.textTertiary),
                              const SizedBox(width: 8),
                              Text(
                                'Comments',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (comments.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${comments.length}',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Comment list
                          ...comments.map((comment) => _CommentBubble(
                                comment: comment,
                                members: members,
                              )),

                          // Mention picker
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Anim.spring,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _showMentionPicker ? 1.0 : 0.0,
                              child: _showMentionPicker
                                  ? Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: members.asMap().entries.map((e) {
                                          final m = e.value;
                                          return PopIn(
                                            delay: Duration(milliseconds: 40 * e.key),
                                            duration: const Duration(milliseconds: 300),
                                            child: PressableScale(
                                              onTap: () => _insertMention(m),
                                              pressedScale: 0.94,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '@${m.name.split(' ').first}',
                                                  style:
                                                      AppTypography.caption.copyWith(
                                                    fontSize: 12,
                                                    color: AppColors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),

                          // Comment input
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(19),
                                  ),
                                  alignment: Alignment.center,
                                  child: TextField(
                                    controller: _commentCtrl,
                                    focusNode: _commentFocus,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                    cursorColor: AppColors.white,
                                    textAlignVertical: TextAlignVertical.center,
                                    decoration: InputDecoration(
                                      hintText: 'Add a comment...',
                                      hintStyle: AppTypography.bodyMedium
                                          .copyWith(
                                        color: AppColors.textTertiary
                                            .withValues(alpha: 0.5),
                                        fontSize: 13,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 0),
                                      isCollapsed: true,
                                    ),
                                    onSubmitted: (_) => _postComment(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SendButton(onTap: _postComment),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Action button
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: FadeSlideIn(
                parentAnimation: _entranceCtrl,
                interval: const Interval(0.4, 0.7),
                child: PressableScale(
                  onTap: _toggleComplete,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? AppColors.surfaceLight
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(
                      child: task.isCompleted
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.rotateCcw,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Mark Incomplete',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            )
                          : ShimmerSweep(
                              highlightColor: const Color(0x22000000),
                              period: const Duration(milliseconds: 3000),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.check,
                                      size: 16, color: AppColors.black),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Complete',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: AppColors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
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
          ],
        ),
      ),
    ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 20,
            maxBlastForce: 25,
            minBlastForce: 5,
            gravity: 0.3,
            colors: const [
              AppColors.onTrack,
              AppColors.white,
              AppColors.atRisk,
            ],
          ),
        ),
      ],
    );
  }

}

// ─────────────────────────────────────────────
// Comment Bubble with @mention highlighting
// ─────────────────────────────────────────────
class _CommentBubble extends StatefulWidget {
  final Comment comment;
  final List<TeamMember> members;

  const _CommentBubble({
    required this.comment,
    required this.members,
  });

  @override
  State<_CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<_CommentBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Anim.spring));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Comment get comment => widget.comment;
  List<TeamMember> get members => widget.members;

  @override
  Widget build(BuildContext context) {
    final timeAgo = formatTimeAgo(comment.createdAt);

    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: _slide.value, child: child),
        );
      },
      child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarCircle(
            initials: comment.authorInitials,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName.split(' ').first,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildCommentText(comment.content),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCommentText(String text) {
    final spans = <InlineSpan>[];
    final mentionRegex = RegExp(r'@(\w+)');
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

}

class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _fire() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _fire,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
          ),
          child: const Center(
            child: Icon(LucideIcons.arrowUp,
                size: 14, color: AppColors.black),
          ),
        ),
      ),
    );
  }
}
