import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/avatar_circle.dart';
import '../../core/components/bottom_sheet_handle.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/task.dart';
import '../../models/team_member.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_member_provider.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  final Task? editTask;

  const CreateTaskScreen({super.key, this.editTask});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen>
    with TickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _titleFocus = FocusNode();

  Priority _selectedPriority = Priority.medium;
  final Set<String> _selectedMemberIds = {};
  DateTime? _selectedDeadline;
  List<String> _tags = [];
  bool _isSaving = false;
  bool _saved = false;

  bool get _isEditing => widget.editTask != null;

  late AnimationController _entranceCtrl;
  late AnimationController _optionsCtrl;

  bool _showOptions = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _optionsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    if (_isEditing) {
      final task = widget.editTask!;
      _titleCtrl.text = task.title;
      _descCtrl.text = task.description;
      _selectedPriority = task.priority;
      _selectedDeadline = task.deadline;
      _selectedMemberIds.addAll(task.assigneeIds);
      _tags = List.from(task.tags);
      _showOptions = true;
    }

    _titleCtrl.addListener(_onTitleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
      if (_isEditing) {
        _optionsCtrl.forward();
      } else {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _titleFocus.requestFocus();
        });
      }
    });
  }

  void _onTitleChanged() {
    final hasTitle = _titleCtrl.text.trim().length >= 2;
    if (hasTitle && !_showOptions) {
      setState(() => _showOptions = true);
      _optionsCtrl.forward();
    }
    setState(() {});
  }

  bool get _canSave =>
      _titleCtrl.text.trim().length >= 2 && _selectedDeadline != null;

  Future<void> _pickDeadline() async {
    HapticFeedback.selectionClick();
    DateTime tempDate =
        _selectedDeadline ?? DateTime.now().add(const Duration(days: 1));

    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        padding: const EdgeInsets.only(top: 6),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: BottomSheetHandle(),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: tempDate.isBefore(DateTime.now())
                    ? DateTime.now().add(const Duration(minutes: 1))
                    : tempDate,
                minimumDate: DateTime.now(),
                use24hFormat: false,
                onDateTimeChanged: (dt) => tempDate = dt,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: PressableScale(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDeadline = tempDate);
                    Navigator.of(ctx).pop();
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
                        'Set Deadline',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w600,
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
    );
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _onSave() async {
    if (_isSaving || !_canSave) return;
    HapticFeedback.heavyImpact();
    setState(() => _isSaving = true);

    final assignedTo = _selectedMemberIds.isNotEmpty
        ? _selectedMemberIds.join(',')
        : 'current_user';

    if (_isEditing) {
      final updated = widget.editTask!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        deadline: _selectedDeadline,
        assignedTo: assignedTo,
        priority: _selectedPriority,
        tags: _tags,
      );
      await ref.read(taskRepositoryProvider).updateTask(updated);
    } else {
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      final task = Task(
        id: taskId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        createdAt: DateTime.now(),
        deadline: _selectedDeadline!,
        assignedTo: assignedTo,
        priority: _selectedPriority,
        isCompleted: false,
        tags: _tags,
      );
      await ref.read(taskRepositoryProvider).saveTask(task);
    }

    ref.invalidate(tasksProvider);
    if (!mounted) return;
    setState(() => _saved = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    _titleFocus.dispose();
    _entranceCtrl.dispose();
    _optionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);

    return Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 24),

                  // Title input
                  FadeSlideIn(
                    parentAnimation: _entranceCtrl,
                    interval: const Interval(0.0, 0.4),
                    child: TextField(
                      controller: _titleCtrl,
                      focusNode: _titleFocus,
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -1,
                        height: 1.15,
                      ),
                      cursorColor: AppColors.white,
                      cursorHeight: 28,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Task name',
                        hintStyle: AppTypography.displayLarge.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1,
                          color:
                              AppColors.textTertiary.withValues(alpha: 0.6),
                          height: 1.15,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Description
                  FadeSlideIn(
                    parentAnimation: _entranceCtrl,
                    interval: const Interval(0.1, 0.5),
                    child: TextField(
                      controller: _descCtrl,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      cursorColor: AppColors.white,
                      maxLines: null,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Notes',
                        hintStyle: AppTypography.bodyLarge.copyWith(
                          color:
                              AppColors.textTertiary.withValues(alpha: 0.4),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Options
                  AnimatedBuilder(
                    animation: _optionsCtrl,
                    builder: (context, child) {
                      if (_optionsCtrl.value < 0.01) {
                        return const SizedBox.shrink();
                      }
                      return Opacity(
                        opacity: _optionsCtrl.value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - _optionsCtrl.value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Deadline
                        _OptionRow(
                          icon: LucideIcons.calendar,
                          label: _selectedDeadline != null
                              ? formatDate(_selectedDeadline!)
                              : 'Deadline',
                          isSet: _selectedDeadline != null,
                          valueColor: _selectedDeadline != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                          onTap: _pickDeadline,
                        ),

                        // Priority inline picker
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Icon(LucideIcons.flag,
                                  size: 16, color: AppColors.textTertiary),
                              const SizedBox(width: 14),
                              ...Priority.values.map((p) {
                                final isSelected = _selectedPriority == p;
                                final color = AppColors.priorityColor(p);
                                final label = p.name[0].toUpperCase() +
                                    p.name.substring(1);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: PressableScale(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(
                                          () => _selectedPriority = p);
                                    },
                                    pressedScale: 0.92,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? color.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? color.withValues(alpha: 0.4)
                                              : AppColors.divider
                                                  .withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        label,
                                        style:
                                            AppTypography.labelSmall.copyWith(
                                          fontSize: 13,
                                          color: isSelected
                                              ? color
                                              : AppColors.textSecondary,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Assign label
                        Row(
                          children: [
                            Icon(LucideIcons.users,
                                size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 10),
                            Text(
                              'Assign to',
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_selectedMemberIds.length > 1) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_selectedMemberIds.length}',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Member badges (multi-select)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: members.map((member) {
                            final isSelected =
                                _selectedMemberIds.contains(member.id);
                            return _MemberBadge(
                              member: member,
                              isSelected: isSelected,
                              isYou: member.id == 'current_user',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (isSelected) {
                                    _selectedMemberIds.remove(member.id);
                                  } else {
                                    _selectedMemberIds.add(member.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // Tags / Categories
                        Row(
                          children: [
                            Icon(LucideIcons.tag,
                                size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 10),
                            Text(
                              'Tags',
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _tags.map((tag) => PressableScale(
                                  onTap: () => _removeTag(tag),
                                  pressedScale: 0.92,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tag,
                                          style: AppTypography.caption.copyWith(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(LucideIcons.x,
                                            size: 10, color: AppColors.textTertiary),
                                      ],
                                    ),
                                  ),
                                )).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: TextField(
                                  controller: _tagCtrl,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                  cursorColor: AppColors.white,
                                  decoration: InputDecoration(
                                    hintText: 'Add tag...',
                                    hintStyle: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textTertiary
                                          .withValues(alpha: 0.5),
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onSubmitted: (_) => _addTag(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PressableScale(
                              onTap: _addTag,
                              pressedScale: 0.9,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surfaceLight,
                                ),
                                child: Center(
                                  child: Icon(LucideIcons.plus,
                                      size: 14, color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Save button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              child: _canSave
                  ? Padding(
                      key: const ValueKey('save'),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        8,
                        24,
                        MediaQuery.of(context).padding.bottom + 12,
                      ),
                      child: PressableScale(
                        onTap: _isSaving ? null : _onSave,
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _saved
                                ? TweenAnimationBuilder<double>(
                                    key: const ValueKey('done'),
                                    tween: Tween(begin: 0.6, end: 1.0),
                                    duration: const Duration(milliseconds: 350),
                                    curve: Anim.spring,
                                    builder: (context, value, child) =>
                                        Transform.scale(scale: value, child: child),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.check,
                                            size: 16, color: AppColors.black),
                                        const SizedBox(width: 6),
                                        Text(
                                          _isEditing ? 'Saved' : 'Created',
                                          style: AppTypography.labelLarge.copyWith(
                                            color: AppColors.black,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _isSaving
                                    ? const CupertinoActivityIndicator(
                                        key: ValueKey('loading'),
                                        color: AppColors.black)
                                    : Text(
                                        key: const ValueKey('label'),
                                        _isEditing ? 'Save Changes' : 'Create Task',
                                        style: AppTypography.labelLarge.copyWith(
                                          color: AppColors.black,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('empty'),
                      height: MediaQuery.of(context).padding.bottom + 20,
                    ),
            ),
          ],
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────
// Option Row
// ─────────────────────────────────────────────
class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSet;
  final Color valueColor;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.isSet,
    required this.valueColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: valueColor,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 14,
                color: AppColors.textTertiary.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Member Badge (multi-select)
// ─────────────────────────────────────────────
class _MemberBadge extends StatelessWidget {
  final TeamMember member;
  final bool isSelected;
  final bool isYou;
  final VoidCallback onTap;

  const _MemberBadge({
    required this.member,
    required this.isSelected,
    required this.isYou,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.white
                : AppColors.divider.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(LucideIcons.check,
                    size: 12, color: AppColors.black),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AvatarCircle(
                  initials: member.avatarInitials,
                  size: 20,
                  fontSize: 8,
                ),
              ),
            Text(
              isYou
                  ? '${member.name.split(' ').first} (You)'
                  : member.name.split(' ').first,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 13,
                color: isSelected ? AppColors.black : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
