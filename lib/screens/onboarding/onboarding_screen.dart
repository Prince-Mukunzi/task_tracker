import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sprung/sprung.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/animated_background.dart';
import '../../core/components/painters/crystallise_painter.dart';
import '../../core/components/painters/sonar_painter.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/components/wordmark.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/team_member.dart';
import '../../providers/team_member_provider.dart';
import '../shell/app_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _roleFocus = FocusNode();

  bool _nameCommitted = false;
  bool _roleCommitted = false;
  bool _isCrystallising = false;

  String _selectedRole = '';

  late AnimationController _entranceCtrl;
  late Animation<double> _wordmarkFade;
  late Animation<Offset> _wordmarkSlide;
  late Animation<double> _headlineFade;
  late Animation<Offset> _headlineSlide;
  late Animation<double> _nameFieldFade;
  late Animation<Offset> _nameFieldSlide;

  late AnimationController _roleAnimCtrl;
  late Animation<double> _roleFade;
  late Animation<Offset> _roleSlide;

  late AnimationController _confirmCtrl;
  late Animation<double> _confirmScale;
  late Animation<double> _confirmFade;

  late AnimationController _crystalliseCtrl;
  late AnimationController _sonarCtrl;
  late AnimationController _exitCtrl;

  static const _rolePresets = [
    'Product Lead',
    'Frontend Dev',
    'Backend Dev',
    'Designer',
    'QA',
    'Manager',
  ];

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _wordmarkFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _wordmarkSlide =
        Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: Interval(0.0, 0.30, curve: Sprung(18)),
          ),
        );

    _headlineFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
    );
    _headlineSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: Interval(0.15, 0.48, curve: Sprung(20)),
          ),
        );

    _nameFieldFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.40, 0.70, curve: Curves.easeOut),
    );
    _nameFieldSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: Interval(0.40, 0.72, curve: Sprung(16)),
          ),
        );

    _roleAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _roleFade = CurvedAnimation(parent: _roleAnimCtrl, curve: Curves.easeOut);
    _roleSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _roleAnimCtrl, curve: Sprung(16)));

    _confirmCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _confirmScale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _confirmCtrl, curve: Sprung(14)));
    _confirmFade = CurvedAnimation(parent: _confirmCtrl, curve: Curves.easeOut);

    _crystalliseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _sonarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _nameCtrl.addListener(_onNameChanged);
    _roleCtrl.addListener(_onRoleChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _nameFocus.requestFocus();
      });
    });
  }

  List<String> get _matchedRoles {
    final typed = _roleCtrl.text.trim().toLowerCase();
    if (typed.isEmpty) return _rolePresets;
    return _rolePresets.where((r) => r.toLowerCase().contains(typed)).toList();
  }

  void _onNameChanged() {
    final hasName = _nameCtrl.text.trim().length >= 3;
    if (hasName && !_nameCommitted) {
      setState(() => _nameCommitted = true);
      _roleAnimCtrl.forward();
    } else if (!hasName && _nameCommitted) {
      setState(() {
        _nameCommitted = false;
        _roleCommitted = false;
        _selectedRole = '';
      });
      _roleAnimCtrl.reverse();
      _confirmCtrl.reverse();
    }
  }

  void _onRoleChanged() {
    if (_selectedRole.isNotEmpty && _roleCtrl.text.trim() != _selectedRole) {
      setState(() => _selectedRole = '');
    }
    setState(() {});
    _checkConfirmReady();
  }

  void _onRolePresetTap(String role) {
    HapticFeedback.selectionClick();
    setState(() => _selectedRole = role);
    _roleCtrl.text = role;
    _checkConfirmReady();
    FocusScope.of(context).unfocus();
  }

  void _checkConfirmReady() {
    final typedRole = _roleCtrl.text.trim();
    final typedMatchesPreset = _rolePresets.any(
      (r) => r.toLowerCase() == typedRole.toLowerCase(),
    );
    final hasValidRole = _selectedRole.isNotEmpty || typedMatchesPreset;
    final ready = _nameCtrl.text.trim().length >= 3 && hasValidRole;

    if (ready && !_roleCommitted) {
      setState(() => _roleCommitted = true);
      _confirmCtrl.forward();
    } else if (!ready && _roleCommitted) {
      setState(() => _roleCommitted = false);
      _confirmCtrl.reverse();
    }
  }

  Future<void> _onConfirm() async {
    if (_isCrystallising) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _isCrystallising = true);

    _sonarCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _crystalliseCtrl.forward(from: 0);
    if (!mounted) return;

    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final name = _nameCtrl.text.trim();
    String role;
    if (_selectedRole.isNotEmpty) {
      role = _selectedRole;
    } else {
      final typed = _roleCtrl.text.trim();
      role = _rolePresets.firstWhere(
        (r) => r.toLowerCase() == typed.toLowerCase(),
        orElse: () => typed,
      );
    }
    final initials = initialsFrom(name);

    final member = TeamMember(
      id: 'current_user',
      name: name,
      role: role,
      avatarInitials: initials,
    );

    await ref.read(teamMemberRepositoryProvider).saveMember(member);
    ref.read(currentUserProvider.notifier).state = member;

    await _exitCtrl.forward();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: const AppShell(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _roleCtrl.removeListener(_onRoleChanged);
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _nameFocus.dispose();
    _roleFocus.dispose();
    _entranceCtrl.dispose();
    _roleAnimCtrl.dispose();
    _confirmCtrl.dispose();
    _crystalliseCtrl.dispose();
    _sonarCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final centerScreen = Offset(size.width / 2, size.height / 2);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AnimatedBuilder(
        animation: _exitCtrl,
        builder: (context, child) {
          return Opacity(opacity: 1.0 - _exitCtrl.value, child: child);
        },
        child: Material(
          color: AppColors.background,
          child: Stack(
            children: [
              const Positioned.fill(
                child: AnimatedBackground(child: SizedBox.expand()),
              ),

              // Crystallise overlay
              AnimatedBuilder(
                animation: _crystalliseCtrl,
                builder: (context, _) {
                  if (!_isCrystallising || _crystalliseCtrl.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: CustomPaint(
                      painter: CrystallisePainter(
                        center: centerScreen,
                        progress: _crystalliseCtrl.value,
                        initials: initialsFrom(_nameCtrl.text.trim()),
                        color: AppColors.accent,
                      ),
                    ),
                  );
                },
              ),

              // Sonar rings
              AnimatedBuilder(
                animation: _sonarCtrl,
                builder: (context, _) {
                  if (!_isCrystallising || _sonarCtrl.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: CustomPaint(
                      painter: SonarPainter(
                        origin: centerScreen,
                        progress: _sonarCtrl.value,
                        color: AppColors.accent,
                      ),
                    ),
                  );
                },
              ),

              // Main UI
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.xl),

                          FadeTransition(
                            opacity: _wordmarkFade,
                            child: SlideTransition(
                              position: _wordmarkSlide,
                              child: const Wordmark(),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xxl),

                          FadeTransition(
                            opacity: _headlineFade,
                            child: SlideTransition(
                              position: _headlineSlide,
                              child: _buildHeadline(),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xxl),

                          FadeTransition(
                            opacity: _nameFieldFade,
                            child: SlideTransition(
                              position: _nameFieldSlide,
                              child: _FieldBlock(
                                label: 'Your name',
                                controller: _nameCtrl,
                                focusNode: _nameFocus,
                                hint: 'e.g. Mukunzi',
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => _roleFocus.requestFocus(),
                              ),
                            ),
                          ),

                          // Role field
                          FadeTransition(
                            opacity: _roleFade,
                            child: SlideTransition(
                              position: _roleSlide,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.xl),
                                  _FieldBlock(
                                    label: 'Your role',
                                    controller: _roleCtrl,
                                    focusNode: _roleFocus,
                                    hint: 'or pick one below',
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) =>
                                        FocusScope.of(context).unfocus(),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                    alignment: Alignment.topLeft,
                                    child: Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.sm,
                                      children: _matchedRoles.map((role) {
                                        final isSelected = _selectedRole == role;
                                        return _RoleChip(
                                          label: role,
                                          isSelected: isSelected,
                                          onTap: () => _onRolePresetTap(role),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  if (_roleCtrl.text.trim().isNotEmpty &&
                                      _matchedRoles.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppSpacing.sm,
                                      ),
                                      child: Text(
                                        'No matching role found',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.atRisk,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xxl),

                          // Confirm button with breathing glow when ready
                          AnimatedBuilder(
                            animation: _confirmCtrl,
                            builder: (context, _) {
                              final isVisible = _confirmCtrl.value > 0;
                              return FadeTransition(
                                opacity: _confirmFade,
                                child: Transform.scale(
                                  scale: _confirmScale.value,
                                  child: isVisible
                                      ? Breathing(
                                          intensity: _isCrystallising ? 0 : 0.015,
                                          period: const Duration(milliseconds: 2500),
                                          child: _ConfirmButton(
                                            onTap: _roleCommitted ? _onConfirm : null,
                                            isCrystallising: _isCrystallising,
                                          ),
                                        )
                                      : _ConfirmButton(
                                          onTap: _roleCommitted ? _onConfirm : null,
                                          isCrystallising: _isCrystallising,
                                        ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline() {
    if (_isCrystallising) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Welcome,\n',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 44,
                height: 1.05,
                letterSpacing: -1.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w300,
              ),
            ),
            TextSpan(
              text: '${_nameCtrl.text.trim()}.',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 44,
                height: 1.05,
                letterSpacing: -1.5,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 350),
      crossFadeState: _nameCommitted
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Let\'s get\n',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 44,
                height: 1.05,
                letterSpacing: -1.5,
              ),
            ),
            TextSpan(
              text: 'you set up.',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 44,
                height: 1.05,
                letterSpacing: -1.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
      secondChild: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'And your\n',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 44,
                height: 1.05,
                letterSpacing: -1.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w300,
              ),
            ),
            TextSpan(
              text: 'role?',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 44,
                height: 1.05,
                letterSpacing: -1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FieldBlock extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _FieldBlock({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: AppTypography.headingLarge.copyWith(
            color: AppColors.textPrimary,
          ),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.headingLarge.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.35),
            ),
            border: InputBorder.none,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider, width: 1),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          ),
        ),
      ],
    );
  }
}


class _RoleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.93,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.white
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.white : AppColors.divider,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? AppColors.black : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}


class _ConfirmButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isCrystallising;

  const _ConfirmButton({required this.onTap, required this.isCrystallising});

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 350),
    );
    _pressScale = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Sprung(14)));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) =>
            Transform.scale(scale: _pressScale.value, child: child),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: widget.isCrystallising
                ? const CupertinoActivityIndicator(
                    color: AppColors.onAccent,
                  )
                : Text(
                    'That\'s me',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}


