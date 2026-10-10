import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/components/app_button.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/team_member.dart';
import '../../providers/team_member_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();

  String? _errorMessage;
  bool _isSaving = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _nameController.addListener(() {
      setState(() {});
    });

    _roleController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    setState(() => _errorMessage = null);

    final name = _nameController.text.trim();
    final role = _roleController.text.trim();

    if (name.length < 3) {
      setState(() => _errorMessage = 'Name must be at least 3 characters.');
      return;
    }

    if (role.isEmpty) {
      setState(() => _errorMessage = 'Please enter your role.');
      return;
    }

    setState(() => _isSaving = true);

    final parts = name.split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_role', role);
    await prefs.setString('user_initials', initials);

    final repo = ref.read(teamMemberRepositoryProvider);
    await repo.saveMember(
      TeamMember(
        id: 'current_user',
        name: name,
        role: role,
        avatarInitials: initials,
      ),
    );

    if (!mounted) return;

    debugPrint('Account created: $name');
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final showRoleField = _nameController.text.trim().length >= 3;
    final showButton = showRoleField && _roleController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),

                Text(
                  'Who do we have \nToday?',
                  style: AppTypography.displayLarge,
                ),

                const SizedBox(height: AppSpacing.xxl),

                Text('Your name', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                _AppTextField(
                  controller: _nameController,
                  hint: 'e.g. John Doe',
                  keyboardType: TextInputType.name,
                  autofocus: true,
                ),

                AnimatedOpacity(
                  opacity: showRoleField ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    child: SizedBox(
                      height: showRoleField ? null : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          Text('Your role', style: AppTypography.labelLarge),
                          const SizedBox(height: AppSpacing.sm),
                          _AppTextField(
                            controller: _roleController,
                            hint: 'e.g. Frontend Dev',
                            keyboardType: TextInputType.text,
                            autofocus: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                AnimatedOpacity(
                  opacity: showButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    child: SizedBox(
                      height: showButton ? null : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),

                          if (_errorMessage != null) ...[
                            Text(
                              _errorMessage!,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.overdue,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          AppButton(
                            label: _isSaving ? 'Saving...' : 'Get started',
                            isFullWidth: true,
                            onTap: _isSaving ? null : _onGetStarted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool autofocus;

  const _AppTextField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      style: AppTypography.bodyLarge,
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.textDisabled,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}
