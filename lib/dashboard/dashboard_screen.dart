import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:sprung/sprung.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/task.dart';
import '../../models/team_member.dart';
import '../../providers/comment_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_member_provider.dart';
import '../create_task/create_task_screen.dart';
import '../inbox/inbox_screen.dart';
import '../task_detail/task_detail_screen.dart';
import '../../core/utils/formatters.dart';
import '../../core/components/bottom_sheet_handle.dart';
import '../../core/components/dismissible_backgrounds.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;

  final Set<String> _expandedDates = {};

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Task> _todayTasks(List<Task> tasks) {
    final now = DateTime.now();
    return tasks.where((t) {
      if (t.deadline.isBefore(now) && !_isSameDay(t.deadline, now)) return true;
      return _isSameDay(t.deadline, now);
    }).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  List<Task> _upNextTasks(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return tasks.where((t) {
      final d = t.deadline;
      if (d.isBefore(tomorrow)) return false;
      return d.isBefore(weekEnd);
    }).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  List<Task> _laterTasks(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return tasks.where((t) {
      return !t.deadline.isBefore(weekEnd);
    }).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  Map<String, List<Task>> _groupByDate(List<Task> tasks) {
    final map = <String, List<Task>>{};
    for (final task in tasks) {
      final key = _dateKey(task.deadline);
      map.putIfAbsent(key, () => []).add(task);
    }
    return map;
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static const _dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _monthNamesUpper = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  void _openTaskDetail(Task task) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(SheetRoute(page: TaskDetailScreen(taskId: task.id)))
        .then((_) => setState(() {}));
  }

  Future<void> _completeTask(Task task) async {
    HapticFeedback.heavyImpact();
    final updated = task.copyWith(isCompleted: true, status: TaskStatus.done);
    await ref.read(taskRepositoryProvider).updateTask(updated);
    ref.invalidate(tasksProvider);
    setState(() {});
  }

  void _editTask(Task task) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(SheetRoute(page: CreateTaskScreen(editTask: task)))
        .then((_) => setState(() {}));
  }

  Future<void> _deleteTask(Task task) async {
    HapticFeedback.heavyImpact();
    await ref.read(taskRepositoryProvider).deleteTask(task.id);
    ref.invalidate(tasksProvider);
    setState(() {});
  }

  void _openActivity() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      IOSPushRoute(page: const InboxScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final members = ref.watch(teamMembersProvider);
    final user = ref.watch(currentUserProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    final now = DateTime.now();
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${monthNames[now.month - 1]} ${now.day}, ${now.year}';
    final greeting = _greeting();
    final overdueCount =
        activeTasks.where((t) => t.slaStatus == SLAStatus.overdue).length;
    final atRiskCount =
        activeTasks.where((t) => t.slaStatus == SLAStatus.atRisk).length;
    final onTrackCount =
        activeTasks.where((t) => t.slaStatus == SLAStatus.onTrack).length;
    final doneCount = completedTasks.length;

    final today = _todayTasks(activeTasks);
    final upNext = _upNextTasks(activeTasks);
    final later = _laterTasks(activeTasks);



    final commentRepo = ref.read(commentRepositoryProvider);
    int inboxCount = 0;
    int mentionCount = 0;
    for (final task in tasks) {
      final comments = commentRepo.getComments(task.id);
      inboxCount += comments.length;
      for (final comment in comments) {
        if (comment.mentions.contains(user?.id ?? 'current_user')) {
          mentionCount++;
        }
      }
    }

    // Completion percentage
    final totalTasks = tasks.length;
    final completionPct = totalTasks > 0 ? doneCount / totalTasks : 0.0;

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting${user != null ? ', ${user.name.split(' ').first}' : ''}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopIn(
                      delay: const Duration(milliseconds: 400),
                      child: PressableScale(
                        onTap: _openActivity,
                        pressedScale: 0.9,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceLight,
                            border: Border.all(
                              color: AppColors.divider.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (mentionCount > 0)
                                Positioned.fill(
                                  child: SonarRing(
                                    color: AppColors.overdue,
                                    size: 40,
                                    period: const Duration(milliseconds: 2500),
                                  ),
                                ),
                              Icon(
                                LucideIcons.bell,
                                size: 17,
                                color: AppColors.textSecondary,
                              ),
                              if (inboxCount > 0)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: mentionCount > 0 ? AppColors.overdue : AppColors.white,
                                      border: Border.all(
                                        color: AppColors.background,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        inboxCount > 9 ? '9+' : '$inboxCount',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 7,
                                          fontWeight: FontWeight.w700,
                                          color: mentionCount > 0 ? AppColors.white : AppColors.black,
                                          height: 1.0,
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
                  ],
                ),
              ),
            ),
          ),

          // ─── Briefing ───
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.05, 0.25),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: _DashboardBriefing(
                  todayCount: today.length,
                  overdueCount: overdueCount,
                  atRiskCount: atRiskCount,
                  onTrackCount: onTrackCount,
                  doneCount: doneCount,
                  totalActive: activeTasks.length,
                  mentionCount: mentionCount,
                  completionPct: completionPct,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 24)),

          if (activeTasks.isEmpty && completedTasks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else ...[
            // TODAY section — big date style
            ..._buildTodaySection(
              tasks: today,
              members: members,
              now: now,
            ),

            // Up Next date groups (no "UP NEXT" header)
            if (upNext.isNotEmpty)
              ..._buildDateGroups(
                tasks: upNext,
                members: members,
                startInterval: 0.25,
              ),

            // LATER section
            if (later.isNotEmpty)
              ..._buildFlatSection(
                label: 'LATER',
                tasks: later,
                members: members,
                startInterval: 0.38,
                showDueDay: true,
              ),

            // Completed
            if (completedTasks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  parentAnimation: _entranceCtrl,
                  interval: const Interval(0.55, 0.75),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 0.5,
                          color: AppColors.divider.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'COMPLETED',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: completedTasks.length,
                itemBuilder: (context, index) {
                  final task = completedTasks[index];
                  return SliverStaggerItem(
                    index: index,
                    child: _CompletedRow(
                      task: task,
                      onTap: () => _openTaskDetail(task),
                    ),
                  );
                },
              ),
            ],
          ],

          SliverToBoxAdapter(
            child: SizedBox(height: bottomPadding + 120),
          ),
        ],
      ),
    );
  }

  // _statDot removed — replaced by _StatChip spacing

  Widget _sectionHeader(String label, int count, double startInterval) {
    return FadeSlideIn(
      parentAnimation: _entranceCtrl,
      interval: Interval(startInterval, (startInterval + 0.2).clamp(0.0, 1.0)),
      slideFrom: const Offset(0, 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Row(
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceSubtle,
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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

  List<Widget> _buildFlatSection({
    required String label,
    required List<Task> tasks,
    required List<TeamMember> members,
    required double startInterval,
    String? emptyMessage,
    bool showDueDay = false,
  }) {
    return [
      SliverToBoxAdapter(child: _sectionHeader(label, tasks.length, startInterval)),
      if (tasks.isEmpty && emptyMessage != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              emptyMessage,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final assignees = task.assigneeIds
                .map((id) => members.where((m) => m.id == id).firstOrNull)
                .where((m) => m != null)
                .cast<TeamMember>()
                .toList();
            return SliverStaggerItem(
              index: index,
              child: _SwipeableTaskRow(
                task: task,
                assignees: assignees,
                onTap: () => _openTaskDetail(task),
                onComplete: () => _completeTask(task),
                onEdit: () => _editTask(task),
                onDelete: () => _deleteTask(task),
                showDueDay: showDueDay,
              ),
            );
          },
        ),
      SliverToBoxAdapter(child: const SizedBox(height: 8)),
    ];
  }

  List<Widget> _buildTodaySection({
    required List<Task> tasks,
    required List<TeamMember> members,
    required DateTime now,
  }) {
    final dayName = _dayNames[now.weekday - 1];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${now.day}',
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayName,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'TODAY',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (tasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (tasks.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              'Nothing due today',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final assignees = task.assigneeIds
                .map((id) => members.where((m) => m.id == id).firstOrNull)
                .where((m) => m != null)
                .cast<TeamMember>()
                .toList();
            return SliverStaggerItem(
              index: index,
              child: _SwipeableTaskRow(
                task: task,
                assignees: assignees,
                onTap: () => _openTaskDetail(task),
                onComplete: () => _completeTask(task),
                onEdit: () => _editTask(task),
                onDelete: () => _deleteTask(task),
              ),
            );
          },
        ),
      SliverToBoxAdapter(child: const SizedBox(height: 8)),
    ];
  }

  // ─── Date groups (no "UP NEXT" subtitle, just dates) ───
  List<Widget> _buildDateGroups({
    required List<Task> tasks,
    required List<TeamMember> members,
    required double startInterval,
  }) {
    final grouped = _groupByDate(tasks);
    final dateKeys = grouped.keys.toList();

    if (_expandedDates.isEmpty && dateKeys.isNotEmpty) {
      _expandedDates.add(dateKeys.first);
    }

    final widgets = <Widget>[];

    for (int gi = 0; gi < dateKeys.length; gi++) {
      final key = dateKeys[gi];
      final dateTasks = grouped[key]!;
      final sampleDate = dateTasks.first.deadline;
      final isExpanded = _expandedDates.contains(key);
      final dayName = _dayNames[sampleDate.weekday - 1];

      widgets.add(
        SliverToBoxAdapter(
          child: PressableScale(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) {
                  _expandedDates.remove(key);
                } else {
                  _expandedDates.add(key);
                }
              });
            },
            pressedScale: 0.99,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${sampleDate.day}',
                    style: AppTypography.displayLarge.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w200,
                      color: AppColors.textPrimary,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayName,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          _monthNamesUpper[sampleDate.month - 1],
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${dateTasks.length}',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (isExpanded) {
        widgets.add(
          SliverList.builder(
            itemCount: dateTasks.length,
            itemBuilder: (context, index) {
              final task = dateTasks[index];
              final assignees = task.assigneeIds
                  .map((id) => members.where((m) => m.id == id).firstOrNull)
                  .where((m) => m != null)
                  .cast<TeamMember>()
                  .toList();
              return SliverStaggerItem(
                index: index,
                child: _SwipeableTaskRow(
                  task: task,
                  assignees: assignees,
                  onTap: () => _openTaskDetail(task),
                  onComplete: () => _completeTask(task),
                  onEdit: () => _editTask(task),
                  onDelete: () => _deleteTask(task),
                ),
              );
            },
          ),
        );
      }
    }

    widgets.add(
      SliverToBoxAdapter(child: const SizedBox(height: 8)),
    );

    return widgets;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }
}

// ─────────────────────────────────────────────
// Stat Chip — colored pill with number + label
// ─────────────────────────────────────────────
class _DashboardBriefing extends StatelessWidget {
  final int todayCount;
  final int overdueCount;
  final int atRiskCount;
  final int onTrackCount;
  final int doneCount;
  final int totalActive;
  final int mentionCount;
  final double completionPct;

  const _DashboardBriefing({
    required this.todayCount,
    required this.overdueCount,
    required this.atRiskCount,
    required this.onTrackCount,
    required this.doneCount,
    required this.totalActive,
    required this.mentionCount,
    required this.completionPct,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];

    if (totalActive == 0 && doneCount == 0) {
      spans.add(TextSpan(
        text: 'No tasks yet.\n',
        style: _bold(AppColors.textPrimary),
      ));
      spans.add(TextSpan(
        text: 'Create one to get started.',
        style: _dim(),
      ));
    } else if (totalActive == 0 && doneCount > 0) {
      spans.add(TextSpan(text: 'All clear. ', style: _bold(AppColors.onTrack)));
      spans.add(TextSpan(
        text: 'You finished ',
        style: _dim(),
      ));
      spans.add(TextSpan(
        text: '$doneCount ${doneCount == 1 ? 'task' : 'tasks'}',
        style: _bold(AppColors.onTrack),
      ));
      spans.add(TextSpan(text: '.', style: _dim()));
    } else {
      // Main line — today's tasks
      if (todayCount > 0) {
        spans.add(TextSpan(
          text: 'You have ',
          style: _dim(),
        ));
        spans.add(TextSpan(
          text: '$todayCount ${todayCount == 1 ? 'task' : 'tasks'}',
          style: _bold(AppColors.textPrimary),
        ));
        spans.add(TextSpan(text: ' due today', style: _dim()));

        if (overdueCount > 0) {
          spans.add(TextSpan(text: ' — ', style: _dim()));
          spans.add(TextSpan(
            text: '$overdueCount ${overdueCount == 1 ? 'is' : 'are'} overdue',
            style: _bold(AppColors.overdue),
          ));
        } else if (atRiskCount > 0) {
          spans.add(TextSpan(text: ' and ', style: _dim()));
          spans.add(TextSpan(
            text: '$atRiskCount ${atRiskCount == 1 ? "is" : "are"} at risk',
            style: _bold(AppColors.atRisk),
          ));
        }
        spans.add(TextSpan(text: '.', style: _dim()));
      } else {
        spans.add(TextSpan(text: 'Nothing due today', style: _bold(AppColors.textPrimary)));
        if (totalActive > 0) {
          spans.add(TextSpan(text: ', but ', style: _dim()));
          spans.add(TextSpan(
            text: '$totalActive ${totalActive == 1 ? 'task' : 'tasks'}',
            style: _bold(AppColors.textPrimary),
          ));
          spans.add(TextSpan(text: ' still active.', style: _dim()));
        } else {
          spans.add(TextSpan(text: '.', style: _dim()));
        }
      }

      // Mentions line
      if (mentionCount > 0) {
        spans.add(TextSpan(text: '\n', style: _dim()));
        spans.add(TextSpan(
          text: 'You\'ve been tagged in ',
          style: _dim(),
        ));
        spans.add(TextSpan(
          text: '$mentionCount ${mentionCount == 1 ? 'comment' : 'comments'}',
          style: _bold(AppColors.white),
        ));
        spans.add(TextSpan(text: '.', style: _dim()));
      }

      // Completion nudge
      if (doneCount > 0 && totalActive > 0) {
        spans.add(TextSpan(text: '\n', style: _dim()));
        spans.add(TextSpan(
          text: '${(completionPct * 100).toInt()}% done',
          style: _bold(AppColors.onTrack),
        ));
        spans.add(TextSpan(text: ' so far.', style: _dim()));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      style: AppTypography.bodyLarge.copyWith(
        fontSize: 22,
        height: 1.3,
        letterSpacing: -0.8,
      ),
    );
  }

  TextStyle _bold(Color color) => AppTypography.bodyLarge.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
        letterSpacing: -0.8,
      );

  TextStyle _dim() => AppTypography.bodyLarge.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.3,
        letterSpacing: -0.8,
      );
}

// ─────────────────────────────────────────────
// Task Row — redesigned layout
// ─────────────────────────────────────────────
class _TaskRow extends ConsumerStatefulWidget {
  final Task task;
  final List<TeamMember> assignees;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final bool showDueDay;

  const _TaskRow({
    required this.task,
    required this.assignees,
    required this.onTap,
    required this.onComplete,
    this.showDueDay = false,
  });

  @override
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  void _onCheck() {
    if (_completing) return;
    _completing = true;
    _checkCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        widget.onComplete();
      });
    });
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dueLabel(Task task) {
    final d = task.deadline;
    return '${_monthNames[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final statusColor = taskStatusColor(task.status);
    final priorityColor = AppColors.priorityColor(task.priority);
    final timeLeft = task.deadline.difference(DateTime.now());
    final comments = ref.watch(commentsProvider(task.id));

    return AnimatedBuilder(
      animation: _checkCtrl,
      builder: (context, child) {
        return Opacity(
          opacity: (1.0 - _checkCtrl.value * 0.6).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1.0 - _checkCtrl.value * 0.03,
            child: child,
          ),
        );
      },
      child: TiltCard(
        child: PressableScale(
        onTap: widget.onTap,
        pressedScale: 0.98,
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
                // Checkbox
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: GestureDetector(
                    onTap: _onCheck,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          TickBurst(
                            trigger: _completing,
                            color: AppColors.onTrack,
                            size: 28,
                          ),
                          Crystallise(
                            trigger: _completing,
                            color: AppColors.onTrack,
                            size: 28,
                          ),
                          AnimatedBuilder(
                            animation: _checkCtrl,
                            builder: (context, _) {
                              final fillProgress = (_checkCtrl.value / 0.3).clamp(0.0, 1.0);
                              final checkScale = ((_checkCtrl.value - 0.3) / 0.4).clamp(0.0, 1.0);
                              final bounceScale = _checkCtrl.value > 0.3
                                  ? 1.0 + 0.2 * Sprung(20).transform(
                                      (1.0 - ((_checkCtrl.value - 0.3) / 0.7).clamp(0.0, 1.0)))
                                  : 1.0;
                              return Transform.scale(
                                scale: bounceScale,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color.lerp(
                                      Colors.transparent,
                                      AppColors.white,
                                      fillProgress,
                                    ),
                                    border: fillProgress < 1.0
                                        ? Border.all(
                                            color: Color.lerp(
                                              AppColors.divider.withValues(alpha: 0.5),
                                              AppColors.white,
                                              fillProgress,
                                            )!,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: checkScale > 0
                                      ? Opacity(
                                          opacity: checkScale.clamp(0.0, 1.0),
                                          child: Transform.scale(
                                            scale: 0.5 + 0.5 * checkScale,
                                            child: const Icon(LucideIcons.check,
                                                size: 10, color: AppColors.black),
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with status chip
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: AppTypography.bodyLarge.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _showStatusPicker(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    taskStatusLabel(task.status),
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 11,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(LucideIcons.chevronDown, size: 10,
                                      color: statusColor.withValues(alpha: 0.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Description
                      if (task.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            task.description,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // Tags
                      if (task.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: task.tags.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                tag,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )).toList(),
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Bottom row: priority · time · comments · assignees
                      Row(
                        children: [
                          // Priority
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              priorityLabel(task.priority),
                              style: AppTypography.caption.copyWith(
                                fontSize: 10,
                                color: priorityColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Time left
                          Text(
                            formatTimeLeft(timeLeft),
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              color: timeLeft.isNegative
                                  ? AppColors.overdue.withValues(alpha: 0.8)
                                  : AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          // Due day for Later
                          if (widget.showDueDay) ...[
                            const SizedBox(width: 4),
                            Text(
                              '· ${_dueLabel(task)}',
                              style: AppTypography.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          // Comments
                          if (comments.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(LucideIcons.messageCircle,
                                size: 10, color: AppColors.textTertiary),
                            const SizedBox(width: 2),
                            Text(
                              '${comments.length}',
                              style: AppTypography.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],

                          const Spacer(),

                          // Assignees
                          if (widget.assignees.isNotEmpty)
                            SizedBox(
                              width: widget.assignees.length == 1
                                  ? 20
                                  : 20 + (widget.assignees.length - 1) * 10.0,
                              height: 20,
                              child: Stack(
                                children: [
                                  for (int i = 0;
                                      i < widget.assignees.length && i < 3;
                                      i++)
                                    Positioned(
                                      left: i * 10.0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.surfaceLight,
                                          border: Border.all(
                                            color: AppColors.background,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            widget.assignees[i].avatarInitials,
                                            style: AppTypography.caption.copyWith(
                                              fontSize: 7,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                              letterSpacing: 0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
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

  void _showStatusPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    final task = widget.task;
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

}

// ─────────────────────────────────────────────
// Swipeable Task Row
// ─────────────────────────────────────────────
class _SwipeableTaskRow extends StatelessWidget {
  final Task task;
  final List<TeamMember> assignees;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDueDay;

  const _SwipeableTaskRow({
    required this.task,
    required this.assignees,
    required this.onTap,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
    this.showDueDay = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: Dismissible(
        key: ValueKey('dash_${task.id}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onEdit();
            return false;
          } else {
            onDelete();
            return false;
          }
        },
        background: const EditSwipeBackground(),
        secondaryBackground: const DeleteSwipeBackground(),
        child: _TaskRow(
          task: task,
          assignees: assignees,
          onTap: onTap,
          onComplete: onComplete,
          showDueDay: showDueDay,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Completed Row
// ─────────────────────────────────────────────
class _CompletedRow extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const _CompletedRow({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceSubtle,
                ),
                child: Icon(LucideIcons.check,
                    size: 10, color: AppColors.textTertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                    decorationColor:
                        AppColors.textTertiary.withValues(alpha: 0.3),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 120),
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
                child: Icon(LucideIcons.inbox,
                    size: 32, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No tasks yet',
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + New Task to get started',
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
