import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprung/sprung.dart';

import '../../core/components/animated_background.dart';
import '../../core/components/pressable_scale.dart';
import '../../core/components/wordmark.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/team_member.dart';
import '../../providers/team_member_provider.dart';
import '../shell/app_shell.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  AuthMode _mode = AuthMode.signIn;

  // Sign In
  final _signInEmailCtrl = TextEditingController();
  final _signInPasswordCtrl = TextEditingController();
  final _signInEmailFocus = FocusNode();
  final _signInPasswordFocus = FocusNode();
  bool _signInShowPassword = false;

  // Sign Up — all fields on one page, progressively revealed
  final _signUpEmailCtrl = TextEditingController();
  final _signUpNameCtrl = TextEditingController();
  final _signUpPasswordCtrl = TextEditingController();
  final _signUpConfirmCtrl = TextEditingController();
  final _signUpRoleCtrl = TextEditingController();
  final _signUpEmailFocus = FocusNode();
  final _signUpNameFocus = FocusNode();
  final _signUpPasswordFocus = FocusNode();
  final _signUpConfirmFocus = FocusNode();
  final _signUpRoleFocus = FocusNode();

  String _selectedRole = '';
  bool _signUpShowPassword = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _canUseBiometrics = false;

  late AnimationController _entranceCtrl;
  late Animation<double> _wordmarkFade;
  late Animation<Offset> _wordmarkSlide;
  late Animation<double> _headlineFade;
  late Animation<Offset> _headlineSlide;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;


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

    _formFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );
    _formSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(0.35, 0.68, curve: Sprung(16)),
      ),
    );

    // Add listeners for progressive reveal
    _signInEmailCtrl.addListener(_onFieldChanged);
    _signUpEmailCtrl.addListener(_onFieldChanged);
    _signUpNameCtrl.addListener(_onFieldChanged);
    _signUpPasswordCtrl.addListener(_onFieldChanged);
    _signUpConfirmCtrl.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
      _checkBiometrics();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _signInEmailFocus.requestFocus();
      });
    });
  }

  void _onFieldChanged() {
    setState(() => _errorMessage = null);
  }

  Future<void> _checkBiometrics() async {
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      if (mounted) {
        setState(() => _canUseBiometrics = canCheck && isSupported);
      }
    } catch (_) {}
  }

  Future<void> _signInWithBiometrics() async {
    final auth = LocalAuthentication();
    try {
      final didAuth = await auth.authenticate(
        localizedReason: 'Sign in to Pulse',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!didAuth || !mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('auth_email');
      if (savedEmail == null) {
        setState(
            () => _errorMessage = 'No account found. Please sign up first.');
        return;
      }

      _loadUser();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Biometric authentication failed');
      }
    }
  }

  Future<void> _signIn() async {
    final email = _signInEmailCtrl.text.trim();
    final password = _signInPasswordCtrl.text;

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _errorMessage = 'Enter a valid email address');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Check if user exists locally — if so, verify; if not, create
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('auth_email');
    final savedHash = prefs.getString('auth_password_hash');

    if (savedEmail != null &&
        savedEmail.toLowerCase() == email.toLowerCase() &&
        savedHash != null &&
        savedHash != _hashPassword(password)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid password';
      });
      return;
    }

    // Save credentials locally (works as both sign in and first-time sign in)
    await prefs.setString('auth_email', email);
    await prefs.setString('auth_password_hash', _hashPassword(password));

    // Load or create user
    final repo = ref.read(teamMemberRepositoryProvider);
    final existingUser = repo.getMemberById('current_user');
    if (existingUser != null) {
      ref.read(currentUserProvider.notifier).state = existingUser;
    } else {
      final initials = initialsFrom(email.split('@').first);
      final member = TeamMember(
        id: 'current_user',
        name: email.split('@').first,
        role: 'Member',
        avatarInitials: initials,
        email: email,
      );
      await repo.saveMember(member);
      ref.read(currentUserProvider.notifier).state = member;
    }

    await _crystalliseAndEnter();
  }

  Future<void> _signUp() async {
    final email = _signUpEmailCtrl.text.trim();
    final name = _signUpNameCtrl.text.trim();
    final password = _signUpPasswordCtrl.text;
    final confirm = _signUpConfirmCtrl.text;
    final role = _selectedRole.isNotEmpty
        ? _selectedRole
        : _signUpRoleCtrl.text.trim();

    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Enter a valid email address');
      return;
    }
    if (name.length < 2) {
      setState(() => _errorMessage = 'Name must be at least 2 characters');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords don\'t match');
      return;
    }
    if (role.isEmpty) {
      setState(() => _errorMessage = 'Choose or type a role');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_email', email);
    await prefs.setString('auth_password_hash', _hashPassword(password));

    final initials = initialsFrom(name);
    final member = TeamMember(
      id: 'current_user',
      name: name,
      role: role,
      avatarInitials: initials,
      email: email,
    );

    await ref.read(teamMemberRepositoryProvider).saveMember(member);
    ref.read(currentUserProvider.notifier).state = member;

    await _crystalliseAndEnter();
  }

  void _loadUser() {
    final repo = ref.read(teamMemberRepositoryProvider);
    final existingUser = repo.getMemberById('current_user');
    if (existingUser != null) {
      ref.read(currentUserProvider.notifier).state = existingUser;
      _crystalliseAndEnter();
    }
  }

  Future<void> _crystalliseAndEnter() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    HapticFeedback.heavyImpact();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (_, __, ___) => const AppShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Sprung(18),
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _switchMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = _mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn;
      _errorMessage = null;
      _selectedRole = '';
    });
    _entranceCtrl.forward(from: 0.3);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        if (_mode == AuthMode.signIn) {
          _signInEmailFocus.requestFocus();
        } else {
          _signUpEmailFocus.requestFocus();
        }
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-.+]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(email);
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'pulse_salt_2024');
    var hash = 0;
    for (final b in bytes) {
      hash = ((hash << 5) - hash) + b;
      hash &= 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  List<String> get _matchedRoles {
    final typed = _signUpRoleCtrl.text.trim().toLowerCase();
    if (typed.isEmpty) return _rolePresets;
    return _rolePresets.where((r) => r.toLowerCase().contains(typed)).toList();
  }

  // Progressive reveal checks
  bool get _signInEmailValid =>
      _isValidEmail(_signInEmailCtrl.text.trim());

  bool get _signUpEmailValid =>
      _isValidEmail(_signUpEmailCtrl.text.trim());

  bool get _signUpNameValid =>
      _signUpNameCtrl.text.trim().length >= 2;

  bool get _signUpPasswordValid =>
      _signUpPasswordCtrl.text.length >= 6;

  bool get _signUpConfirmValid =>
      _signUpConfirmCtrl.text.isNotEmpty &&
      _signUpConfirmCtrl.text == _signUpPasswordCtrl.text;

  bool get _signUpRoleValid =>
      _selectedRole.isNotEmpty || _signUpRoleCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _signInEmailCtrl.dispose();
    _signInPasswordCtrl.dispose();
    _signInEmailFocus.dispose();
    _signInPasswordFocus.dispose();
    _signUpEmailCtrl.dispose();
    _signUpNameCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _signUpConfirmCtrl.dispose();
    _signUpRoleCtrl.dispose();
    _signUpEmailFocus.dispose();
    _signUpNameFocus.dispose();
    _signUpPasswordFocus.dispose();
    _signUpConfirmFocus.dispose();
    _signUpRoleFocus.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: AppColors.background,
        child: Stack(
          children: [
            const Positioned.fill(
              child: AnimatedBackground(child: SizedBox.expand()),
            ),

            SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: size.height -
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

                          const SizedBox(height: AppSpacing.xl),

                          FadeTransition(
                            opacity: _formFade,
                            child: SlideTransition(
                              position: _formSlide,
                              child: _mode == AuthMode.signIn
                                  ? _buildSignIn()
                                  : _buildSignUp(),
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _errorMessage!,
                                key: ValueKey(_errorMessage),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.overdue,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSpacing.xxl),

                          // Switch mode link — centered
                          Center(
                            child: PressableScale(
                              onTap: _switchMode,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _mode == AuthMode.signIn
                                            ? 'Don\'t have an account? '
                                            : 'Already have an account? ',
                                      ),
                                      TextSpan(
                                        text: _mode == AuthMode.signIn
                                            ? 'Sign up'
                                            : 'Sign in',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
    );
  }

  Widget _buildHeadline() {
    if (_mode == AuthMode.signIn) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Welcome\n',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 44,
                height: 1.05,
                letterSpacing: -1.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w300,
              ),
            ),
            TextSpan(
              text: 'back.',
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

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Let\'s get\n',
            style: AppTypography.displayLarge.copyWith(
              fontSize: 44,
              height: 1.05,
              letterSpacing: -1.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w300,
            ),
          ),
          TextSpan(
            text: 'started.',
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

  Widget _buildSignIn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AuthField(
          label: 'Email',
          controller: _signInEmailCtrl,
          focusNode: _signInEmailFocus,
          hint: 'your@email.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (_signInEmailValid) _signInPasswordFocus.requestFocus();
          },
        ),

        // Password — only when email is valid
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _signInEmailValid
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _signInEmailValid ? 1.0 : 0.0,
                    child: _AuthField(
                      label: 'Password',
                      controller: _signInPasswordCtrl,
                      focusNode: _signInPasswordFocus,
                      hint: '••••••••',
                      obscureText: !_signInShowPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signIn(),
                      suffix: PressableScale(
                        onTap: () => setState(
                            () => _signInShowPassword = !_signInShowPassword),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _signInShowPassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Sign in button — visible when password field is shown
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _signInEmailValid
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: 1.0,
                    child: PressableScale(
                      onTap: _isLoading ? null : _signIn,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CupertinoActivityIndicator(
                                  color: AppColors.black)
                              : Text(
                                  'Sign In',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Face ID
        if (_canUseBiometrics) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: PressableScale(
              onTap: _signInWithBiometrics,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.scanFace,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Sign in with Face ID',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignUp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Email — always visible
        _AuthField(
          label: 'Email',
          controller: _signUpEmailCtrl,
          focusNode: _signUpEmailFocus,
          hint: 'your@email.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (_signUpEmailValid) _signUpNameFocus.requestFocus();
          },
        ),

        // 2. Name — appears when email is valid
        _RevealField(
          visible: _signUpEmailValid,
          child: _AuthField(
            label: 'Full name',
            controller: _signUpNameCtrl,
            focusNode: _signUpNameFocus,
            hint: 'e.g. Prince Mukunzi',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              if (_signUpNameValid) _signUpPasswordFocus.requestFocus();
            },
          ),
        ),

        // 3. Password — appears when name >= 2 chars
        _RevealField(
          visible: _signUpNameValid,
          child: _AuthField(
            label: 'Password',
            controller: _signUpPasswordCtrl,
            focusNode: _signUpPasswordFocus,
            hint: 'At least 6 characters',
            obscureText: !_signUpShowPassword,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              if (_signUpPasswordValid) _signUpConfirmFocus.requestFocus();
            },
            suffix: PressableScale(
              onTap: () =>
                  setState(() => _signUpShowPassword = !_signUpShowPassword),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  _signUpShowPassword
                      ? LucideIcons.eyeOff
                      : LucideIcons.eye,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ),

        // 4. Confirm password — appears when password > 6 chars
        _RevealField(
          visible: _signUpPasswordValid,
          child: _AuthField(
            label: 'Confirm password',
            controller: _signUpConfirmCtrl,
            focusNode: _signUpConfirmFocus,
            hint: 'Re-enter password',
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (_signUpConfirmValid) {
                FocusScope.of(context).unfocus();
              }
            },
          ),
        ),

        // 5. Role — appears when confirm matches password
        _RevealField(
          visible: _signUpConfirmValid,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthField(
                label: 'Your role',
                controller: _signUpRoleCtrl,
                focusNode: _signUpRoleFocus,
                hint: 'or pick one below',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signUp(),
                onChanged: (_) => setState(() {
                  if (_selectedRole.isNotEmpty &&
                      _signUpRoleCtrl.text.trim() != _selectedRole) {
                    _selectedRole = '';
                  }
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _matchedRoles.map((role) {
                  final isSelected = _selectedRole == role;
                  return PressableScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedRole = role);
                      _signUpRoleCtrl.text = role;
                      FocusScope.of(context).unfocus();
                    },
                    pressedScale: 0.93,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs + 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.white : Colors.transparent,
                        border: Border.all(
                          color:
                              isSelected ? AppColors.white : AppColors.divider,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        role,
                        style: AppTypography.labelSmall.copyWith(
                          color: isSelected
                              ? AppColors.black
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Create Account button — appears when role is selected
        _RevealField(
          visible: _signUpRoleValid && _signUpConfirmValid,
          child: PressableScale(
            onTap: _isLoading ? null : _signUp,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: _isLoading
                    ? const CupertinoActivityIndicator(
                        color: AppColors.black)
                    : Text(
                        'Create Account',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealField extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _RevealField({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: visible
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: visible ? 1.0 : 0.0,
                child: child,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  const _AuthField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
                onChanged: onChanged,
                autocorrect: false,
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
                    borderSide:
                        BorderSide(color: AppColors.divider, width: 1),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
              ),
            ),
            if (suffix != null) suffix!,
          ],
        ),
      ],
    );
  }
}

