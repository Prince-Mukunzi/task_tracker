import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sprung/sprung.dart';

import 'core/animations/animation_helpers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'providers/team_member_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/shell/app_shell.dart';

class SlaTrackerApp extends StatelessWidget {
  const SlaTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AppGate(),
    );
  }
}

class _AppGate extends ConsumerStatefulWidget {
  const _AppGate();

  @override
  ConsumerState<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<_AppGate>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _hasUser = false;
  late AnimationController _splashCtrl;

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _splashCtrl.forward();
      _checkUser();
    });
  }

  @override
  void dispose() {
    _splashCtrl.dispose();
    super.dispose();
  }

  void _checkUser() async {
    final repo = ref.read(teamMemberRepositoryProvider);
    final existingUser = repo.getMemberById('current_user');

    if (existingUser != null) {
      ref.read(currentUserProvider.notifier).state = existingUser;
      _hasUser = true;
    } else {
      _hasUser = false;
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: AnimatedBuilder(
            animation: _splashCtrl,
            builder: (context, child) {
              final t = _splashCtrl.value;
              final scale = 0.9 + 0.1 * Sprung(18).transform(t);
              final opacity = Curves.easeOut.transform(t);
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'pulse',
                  style: AppTypography.displayLarge.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                StatusOrb(color: AppColors.white, size: 5),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      child: _hasUser ? const AppShell() : const AuthScreen(),
    );
  }
}
