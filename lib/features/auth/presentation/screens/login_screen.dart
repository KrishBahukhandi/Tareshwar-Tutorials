// ─────────────────────────────────────────────────────────────
//  login_screen.dart  –  Email + Phone OTP login
//
//  Features:
//  ▸ Segmented tab: Email login / Phone OTP
//  ▸ Full form validation with inline field errors
//  ▸ Animated error banner with dismiss
//  ▸ Loading state on submit button
//  ▸ Role-based navigation after successful login
//  ▸ Forgot password + Sign-up navigation
// ─────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_text_field.dart';

// ─────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Form state ────────────────────────────────────────────
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  bool _obscurePassword = true;
  Timer? _errorDismissTimer;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
      ref.read(authProvider.notifier).clearError();
      _errorDismissTimer?.cancel();
    });
  }

  void _scheduleErrorDismiss() {
    _errorDismissTimer?.cancel();
    _errorDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _errorDismissTimer?.cancel();
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _isEmailTab => _tabController.index == 0;

  // ── Role-based navigation ─────────────────────────────────
  void _navigateByRole(String role) {
    switch (role) {
      case AppConstants.roleTeacher:
        context.go(AppRoutes.teacherDashboard);
      case AppConstants.roleAdmin:
        context.go(AppRoutes.adminDashboard);
      default:
        context.go(AppRoutes.homeTab);
    }
  }

  // ── Submit handler ────────────────────────────────────────
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authProvider.notifier);
    if (_isEmailTab) {
      await notifier.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } else {
      await notifier.sendPhoneOtp(_phoneCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Side-effects: listen for state transitions ─────────
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && next.user != null) {
        _navigateByRole(next.user!.role);
      }
      if (next.status == AuthStatus.otpSent) {
        context.push(
          '${AppRoutes.otp}?phone=${Uri.encodeComponent(next.pendingPhone ?? '')}',
        );
      }
      if (next.hasError && !(prev?.hasError ?? false)) {
        _scheduleErrorDismiss();
      }
    });

    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // ── Hero section ───────────────────────────
                _HeroHeader(),
                const SizedBox(height: 36),

                // ── Tab switcher ───────────────────────────
                _LoginTabBar(controller: _tabController),
                const SizedBox(height: 28),

                // ── Fields ─────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: _isEmailTab
                      ? _EmailFields(
                          key: const ValueKey('email'),
                          emailCtrl: _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          obscure: _obscurePassword,
                          onToggle: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          onSubmit: _submit,
                        )
                      : _PhoneField(
                          key: const ValueKey('phone'),
                          controller: _phoneCtrl,
                          onSubmit: _submit,
                        ),
                ),

                // ── Error banner ───────────────────────────
                _AnimatedErrorBanner(
                  visible: auth.hasError && auth.errorMessage != null,
                  message: auth.errorMessage ?? '',
                  onDismiss: () =>
                      ref.read(authProvider.notifier).clearError(),
                ),
                const SizedBox(height: 24),

                // ── Submit ─────────────────────────────────
                _PrimaryButton(
                  label: _isEmailTab ? 'Sign In' : 'Send OTP',
                  isLoading: auth.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),

                // ── Forgot password (email tab only) ───────
                if (_isEmailTab)
                  Center(
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: Text(
                        'Forgot Password?',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // ── Sign-up link ───────────────────────────
                Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.signup),
                        child: Text(
                          'Sign Up',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Hero header widget
// ─────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App logo
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Welcome Back!', style: AppTextStyles.displayMedium),
        const SizedBox(height: 6),
        Text(
          'Sign in to continue your learning journey',
          style: AppTextStyles.bodyLarge
              .copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Segmented tab bar
// ─────────────────────────────────────────────────────────────
class _LoginTabBar extends StatelessWidget {
  final TabController controller;
  const _LoginTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(10),
        labelStyle: AppTextStyles.labelLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Email'),
          Tab(text: 'Phone OTP'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Email fields
// ─────────────────────────────────────────────────────────────
class _EmailFields extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback onSubmit;

  const _EmailFields({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AuthTextField(
          controller: emailCtrl,
          label: 'Email Address',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: passwordCtrl,
          label: 'Password',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: onSubmit,
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textHint,
              size: 20,
            ),
            onPressed: onToggle,
            tooltip: obscure ? 'Show password' : 'Hide password',
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 6) return 'Minimum 6 characters';
            return null;
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Phone field
// ─────────────────────────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _PhoneField({super.key, required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthTextField(
          controller: controller,
          label: 'Phone Number',
          hint: '+91 98765 43210',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
          onFieldSubmitted: onSubmit,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Phone number is required';
            final digits = v.replaceAll(RegExp(r'\D'), '');
            if (digits.length < 10) return 'Enter a valid phone number';
            return null;
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.info.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.info, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Include country code (e.g. +91 for India)',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Animated error banner
// ─────────────────────────────────────────────────────────────
class _AnimatedErrorBanner extends StatelessWidget {
  final bool visible;
  final String message;
  final VoidCallback onDismiss;

  const _AnimatedErrorBanner({
    required this.visible,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: visible
          ? Padding(
              key: const ValueKey('error'),
              padding: const EdgeInsets.only(top: 16),
              child: AuthErrorBanner(
                message: message,
                onDismiss: onDismiss,
              ),
            )
          : const SizedBox.shrink(key: ValueKey('none')),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Primary action button
// ─────────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(label, style: AppTextStyles.button),
      ),
    );
  }
}
