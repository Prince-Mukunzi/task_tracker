import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/animations/animation_helpers.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../create_task/create_task_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../tasks/tasks_screen.dart';
import '../team/team_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navEntranceCtrl;
  late AnimationController _tabFadeCtrl;
  bool _isSwitching = false;

  final _screens = const [
    DashboardScreen(),
    TasksScreen(),
    TeamScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _navEntranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _tabFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navEntranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _navEntranceCtrl.dispose();
    _tabFadeCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index != _currentIndex && !_isSwitching) {
      _isSwitching = true;
      HapticFeedback.selectionClick();
      _tabFadeCtrl.animateTo(0.0, duration: const Duration(milliseconds: 100),
          curve: Curves.easeIn).then((_) {
        if (mounted) {
          setState(() => _currentIndex = index);
          _tabFadeCtrl.animateTo(1.0, duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut).then((_) {
            _isSwitching = false;
          });
        }
      });
    }
  }

  void _openCreateTask() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      SheetRoute(page: const CreateTaskScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnimatedBuilder(
          animation: _tabFadeCtrl,
          builder: (context, child) {
            return Opacity(
              opacity: _tabFadeCtrl.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.98 + 0.02 * _tabFadeCtrl.value,
                child: child,
              ),
            );
          },
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
        bottomNavigationBar: FadeSlideIn(
          parentAnimation: _navEntranceCtrl,
          interval: const Interval(0.35, 0.85),
          slideFrom: const Offset(0, 48),
          child: Container(
            padding: EdgeInsets.only(
              bottom: bottomPadding + 8,
              top: 16,
              left: 20,
              right: 20,
            ),
            color: AppColors.background,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left pair: Home, Tasks
                _NavCircle(
                  icon: LucideIcons.house,
                  isActive: _currentIndex == 0,
                  onTap: () => _switchTab(0),
                ),
                const SizedBox(width: 10),
                _NavCircle(
                  icon: LucideIcons.clipboardList,
                  isActive: _currentIndex == 1,
                  onTap: () => _switchTab(1),
                ),

                const SizedBox(width: 14),

                // Center: + New Task pill (secondary with shimmer)
                PopIn(
                  delay: const Duration(milliseconds: 600),
                  child: PressableScale(
                    onTap: _openCreateTask,
                    pressedScale: 0.9,
                    child: _ShimmerNewTask(),
                  ),
                ),

                const SizedBox(width: 14),

                // Right pair: Workspace, Settings
                _NavCircle(
                  icon: LucideIcons.users,
                  isActive: _currentIndex == 2,
                  onTap: () => _switchTab(2),
                ),
                const SizedBox(width: 10),
                _NavCircle(
                  icon: LucideIcons.settings,
                  isActive: _currentIndex == 3,
                  onTap: () => _switchTab(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCircle extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavCircle({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavCircle> createState() => _NavCircleState();
}

class _NavCircleState extends State<_NavCircle>
    with TickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late AnimationController _selectCtrl;
  late Animation<double> _selectScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 350),
    );
    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _selectScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 65),
    ]).animate(CurvedAnimation(parent: _selectCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_NavCircle old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _selectCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _selectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressCtrl, _selectCtrl]),
        builder: (context, child) {
          return Transform.scale(
            scale: (1.0 - _pressCtrl.value * 0.12) * _selectScale.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isActive ? AppColors.white : AppColors.surfaceLight,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: AppColors.white.withValues(alpha: 0.1),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 19,
              color:
                  widget.isActive ? AppColors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerNewTask extends StatefulWidget {
  const _ShimmerNewTask();

  @override
  State<_ShimmerNewTask> createState() => _ShimmerNewTaskState();
}

class _ShimmerNewTaskState extends State<_ShimmerNewTask>
    with TickerProviderStateMixin {
  late AnimationController _textCtrl;
  late AnimationController _borderCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _borderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _borderCtrl.repeat();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _borderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_textCtrl, _borderCtrl]),
      builder: (context, _) {
        final borderAlpha =
            (0.3 + 0.25 * _shimmerWave(_borderCtrl.value)).clamp(0.0, 1.0);

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppColors.divider.withValues(alpha: borderAlpha),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _textCtrl.value, 0),
                    end: Alignment(-0.5 + 2.0 * _textCtrl.value, 0),
                    colors: [
                      Colors.white.withValues(alpha: 0.6),
                      Colors.white,
                      Colors.white.withValues(alpha: 0.6),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.modulate,
                child: Text(
                  'New Task',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _shimmerWave(double t) {
    final x = (t * 2 - 1).abs();
    return 1.0 - x;
  }
}
