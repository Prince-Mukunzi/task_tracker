import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/avatar_circle.dart';
import '../../core/components/bottom_sheet_handle.dart';
import '../../core/components/dismissible_backgrounds.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/task.dart';
import '../../models/team_member.dart';
import '../../providers/comment_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_member_provider.dart';
import '../create_task/create_task_screen.dart';
import '../task_detail/task_detail_screen.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Filter state (all inside the filter sheet)
  SLAStatus? _statusFilter;
  String? _personFilter;
  Priority? _priorityFilter;
  bool _deadlineThisWeek = false;

  bool get _hasActiveFilters =>
      _statusFilter != null ||
      _personFilter != null ||
      _priorityFilter != null ||
      _deadlineThisWeek;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Task> _filterTasks(List<Task> tasks) {
    var filtered = tasks.toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) =>
              t.title.toLowerCase().contains(_searchQuery) ||
              t.description.toLowerCase().contains(_searchQuery))
          .toList();
    }

    if (_statusFilter != null) {
      filtered = filtered.where((t) => t.slaStatus == _statusFilter).toList();
    }

    if (_personFilter != null) {
      filtered = filtered
          .where((t) => t.assigneeIds.contains(_personFilter))
          .toList();
    }

    if (_priorityFilter != null) {
      filtered = filtered.where((t) => t.priority == _priorityFilter).toList();
    }

    if (_deadlineThisWeek) {
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));
      filtered = filtered.where((t) =>
          t.deadline.isAfter(weekStart) && t.deadline.isBefore(weekEnd)).toList();
    }

    return filtered;
  }

  void _openTaskDetail(Task task) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(SheetRoute(page: TaskDetailScreen(taskId: task.id)))
        .then((_) => setState(() {}));
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

  void _showFilterSheet() {
    HapticFeedback.lightImpact();
    final members = ref.read(teamMembersProvider);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _FilterSheet(
        statusFilter: _statusFilter,
        personFilter: _personFilter,
        priorityFilter: _priorityFilter,
        deadlineThisWeek: _deadlineThisWeek,
        members: members,
        onApply: (status, person, priority, deadline) {
          setState(() {
            _statusFilter = status;
            _personFilter = person;
            _priorityFilter = priority;
            _deadlineThisWeek = deadline;
          });
          Navigator.of(ctx).pop();
        },
        onClear: () {
          setState(() {
            _statusFilter = null;
            _personFilter = null;
            _priorityFilter = null;
            _deadlineThisWeek = false;
          });
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final members = ref.watch(teamMembersProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final activeTasks = tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) {
        const order = {
          SLAStatus.overdue: 0,
          SLAStatus.atRisk: 1,
          SLAStatus.onTrack: 2,
        };
        return (order[a.slaStatus] ?? 3).compareTo(order[b.slaStatus] ?? 3);
      });
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    final filteredActive = _filterTasks(activeTasks);
    final filteredCompleted = _statusFilter == null
        ? (_searchQuery.isNotEmpty
            ? completedTasks
                .where((t) =>
                    t.title.toLowerCase().contains(_searchQuery) ||
                    t.description.toLowerCase().contains(_searchQuery))
                .toList()
            : completedTasks)
        : (_statusFilter == SLAStatus.completed ? completedTasks : <Task>[]);

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
                  'Tasks',
                  style: AppTypography.displayLarge.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Search bar + Filter icon
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.05, 0.25),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(LucideIcons.search,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                                cursorColor: AppColors.white,
                                decoration: InputDecoration(
                                  hintText: 'Search tasks...',
                                  hintStyle: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.5),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              PressableScale(
                                onTap: () {
                                  _searchCtrl.clear();
                                  FocusScope.of(context).unfocus();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(LucideIcons.x,
                                      size: 14, color: AppColors.textSecondary),
                                ),
                              ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Filter icon
                    PressableScale(
                      onTap: _showFilterSheet,
                      pressedScale: 0.9,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _hasActiveFilters
                              ? AppColors.white
                              : AppColors.surfaceSubtle,
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.slidersHorizontal,
                            size: 16,
                            color: _hasActiveFilters
                                ? AppColors.black
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 16)),

          // Divider
          SliverToBoxAdapter(
            child: FadeSlideIn(
              parentAnimation: _entranceCtrl,
              interval: const Interval(0.2, 0.4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Container(
                  height: 0.5,
                  color: AppColors.divider.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),

          // Results count + active filter indicator
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Row(
                children: [
                  Text(
                    '${filteredActive.length} active${filteredCompleted.isNotEmpty ? ', ${filteredCompleted.length} done' : ''}',
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    PressableScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _statusFilter = null;
                          _personFilter = null;
                          _priorityFilter = null;
                          _deadlineThisWeek = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Filtered',
                              style: AppTypography.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(LucideIcons.x, size: 10, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Active task list
          if (filteredActive.isEmpty && filteredCompleted.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: PopIn(
                    delay: const Duration(milliseconds: 100),
                    child: Column(
                      children: [
                        GlowPulse(
                          color: AppColors.white,
                          radius: 28,
                          period: const Duration(milliseconds: 3000),
                          child: Floating(
                            amplitude: 3,
                            period: const Duration(milliseconds: 3500),
                            child: Icon(LucideIcons.searchX,
                                size: 28, color: AppColors.textTertiary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tasks found',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else ...[
            SliverList.builder(
              itemCount: filteredActive.length,
              itemBuilder: (context, index) {
                final task = filteredActive[index];
                final assignees = task.assigneeIds
                    .map((id) =>
                        members.where((m) => m.id == id).firstOrNull)
                    .where((m) => m != null)
                    .cast<TeamMember>()
                    .toList();
                return SliverStaggerItem(
                  index: index,
                  child: ClipRRect(
                    child: Dismissible(
                      key: ValueKey('task_${task.id}'),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          _editTask(task);
                          return false;
                        } else {
                          _deleteTask(task);
                          return false;
                        }
                      },
                      background: const EditSwipeBackground(),
                      secondaryBackground: const DeleteSwipeBackground(),
                      child: _TaskRow(
                        task: task,
                        assignees: assignees,
                        onTap: () => _openTaskDetail(task),
                      ),
                    ),
                  ),
                );
              },
            ),

            if (filteredCompleted.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 0.5,
                        color: AppColors.divider.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Completed',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: filteredCompleted.length,
                itemBuilder: (context, index) {
                  final task = filteredCompleted[index];
                  return SliverStaggerItem(
                    index: index,
                    child: PressableScale(
                    onTap: () => _openTaskDetail(task),
                    pressedScale: 0.99,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  AppColors.divider.withValues(alpha: 0.06),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surfaceLight,
                              ),
                              child: const Icon(LucideIcons.check,
                                  size: 10, color: AppColors.textTertiary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                task.title,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: AppColors.textTertiary
                                      .withValues(alpha: 0.3),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
}

// ─────────────────────────────────────────────
// Filter Sheet
// ─────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final SLAStatus? statusFilter;
  final String? personFilter;
  final Priority? priorityFilter;
  final bool deadlineThisWeek;
  final List<TeamMember> members;
  final Function(SLAStatus?, String?, Priority?, bool) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.statusFilter,
    required this.personFilter,
    required this.priorityFilter,
    required this.deadlineThisWeek,
    required this.members,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SLAStatus? _status;
  late String? _person;
  late Priority? _priority;
  late bool _deadline;

  @override
  void initState() {
    super.initState();
    _status = widget.statusFilter;
    _person = widget.personFilter;
    _priority = widget.priorityFilter;
    _deadline = widget.deadlineThisWeek;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
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
                const BottomSheetHandle(title: 'Filters'),
                Row(
                  children: [
                    const Spacer(),
                    PressableScale(
                      onTap: widget.onClear,
                      child: Text(
                        'Clear',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Status
                Text('STATUS', style: _sectionLabel),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('All', _status == null, () => setState(() => _status = null)),
                    _buildChip('On Track', _status == SLAStatus.onTrack,
                        () => setState(() => _status = _status == SLAStatus.onTrack ? null : SLAStatus.onTrack),
                        dotColor: AppColors.onTrack),
                    _buildChip('At Risk', _status == SLAStatus.atRisk,
                        () => setState(() => _status = _status == SLAStatus.atRisk ? null : SLAStatus.atRisk),
                        dotColor: AppColors.atRisk),
                    _buildChip('Overdue', _status == SLAStatus.overdue,
                        () => setState(() => _status = _status == SLAStatus.overdue ? null : SLAStatus.overdue),
                        dotColor: AppColors.overdue),
                  ],
                ),

                const SizedBox(height: 20),

                // Assignee
                Text('ASSIGNEE', style: _sectionLabel),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('Everyone', _person == null, () => setState(() => _person = null)),
                    ...widget.members.map((m) => _buildChip(
                          m.id == 'current_user' ? 'Me' : m.name.split(' ').first,
                          _person == m.id,
                          () => setState(() => _person = _person == m.id ? null : m.id),
                        )),
                  ],
                ),

                const SizedBox(height: 20),

                // Priority
                Text('PRIORITY', style: _sectionLabel),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('All', _priority == null, () => setState(() => _priority = null)),
                    _buildChip('High', _priority == Priority.high,
                        () => setState(() => _priority = _priority == Priority.high ? null : Priority.high),
                        dotColor: AppColors.overdue),
                    _buildChip('Medium', _priority == Priority.medium,
                        () => setState(() => _priority = _priority == Priority.medium ? null : Priority.medium),
                        dotColor: AppColors.atRisk),
                    _buildChip('Low', _priority == Priority.low,
                        () => setState(() => _priority = _priority == Priority.low ? null : Priority.low),
                        dotColor: AppColors.onTrack),
                  ],
                ),

                const SizedBox(height: 20),

                // Deadline
                Text('DEADLINE', style: _sectionLabel),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('Any', !_deadline, () => setState(() => _deadline = false)),
                    _buildChip('This week', _deadline, () => setState(() => _deadline = !_deadline)),
                  ],
                ),

                const SizedBox(height: 24),

                PressableScale(
                  onTap: () => widget.onApply(_status, _person, _priority, _deadline),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(
                      child: Text(
                        'Apply',
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
    );
  }

  TextStyle get _sectionLabel => AppTypography.caption.copyWith(
        fontSize: 11,
        color: AppColors.textTertiary,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
      );

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap, {Color? dotColor}) {
    return _BounceChip(
      label: label,
      isSelected: isSelected,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      dotColor: dotColor,
    );
  }
}

class _BounceChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? dotColor;

  const _BounceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.dotColor,
  });

  @override
  State<_BounceChip> createState() => _BounceChipState();
}

class _BounceChipState extends State<_BounceChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_BounceChip old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.white : Colors.transparent,
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.white
                  : AppColors.divider.withValues(alpha: 0.4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.dotColor != null && !widget.isSelected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.dotColor!.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 13,
                  color: widget.isSelected ? AppColors.black : AppColors.textSecondary,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
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
// Task Row with due date and tags
// ─────────────────────────────────────────────
class _TaskRow extends ConsumerWidget {
  final Task task;
  final List<TeamMember> assignees;
  final VoidCallback onTap;

  const _TaskRow({
    required this.task,
    required this.assignees,
    required this.onTap,
  });

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDueDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(dt.year, dt.month, dt.day);
    final diff = taskDay.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return '${_monthNames[dt.month - 1]} ${dt.day}';
    if (diff <= 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    return '${_monthNames[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = AppColors.priorityColor(task.priority);
    final timeLeft = task.deadline.difference(DateTime.now());
    final comments = ref.watch(commentsProvider(task.id));

    return TiltCard(
      child: PressableScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Priority badge (colored)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.12),
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
                        // Time left badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            formatTimeLeft(timeLeft),
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Due date
                        Icon(LucideIcons.calendar, size: 10, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          _formatDueDate(task.deadline),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Comment count
                        if (comments.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(LucideIcons.messageCircle,
                              size: 11, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(
                            '${comments.length}',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Tags
                    if (task.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: task.tags.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 9,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Stacked assignee avatars
              if (assignees.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: SizedBox(
                    width: assignees.length == 1
                        ? 26
                        : 26 + (assignees.length - 1) * 16.0,
                    height: 26,
                    child: Stack(
                      children: [
                        for (int i = 0; i < assignees.length && i < 3; i++)
                          Positioned(
                            left: i * 16.0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.background,
                                  width: 2,
                                ),
                              ),
                              child: AvatarCircle(
                                initials: assignees[i].avatarInitials,
                                size: 22,
                              ),
                            ),
                          ),
                        if (assignees.length > 3)
                          Positioned(
                            left: 3 * 16.0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.background,
                                  width: 2,
                                ),
                              ),
                              child: AvatarCircle(
                                initials: '+${assignees.length - 3}',
                                size: 22,
                                backgroundColor: AppColors.surface,
                              ),
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
    );
  }

}
