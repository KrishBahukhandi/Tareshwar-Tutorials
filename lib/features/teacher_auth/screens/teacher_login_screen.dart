// ─────────────────────────────────────────────────────────────
//  teacher_login_screen.dart  –  Teacher web portal login
//
//  Features
//  ▸ Email + password with inline validation
//  ▸ Driven by TeacherAuthNotifier (dedicated provider)
//  ▸ Role gate: accessDenied state shows prominent banner
//  ▸ Password visibility toggle
//  ▸ "Forgot password" link (reuses shared reset flow)
//  ▸ Submit on Enter key (web-friendly)
//  ▸ Web-optimised centred card layout (max-width 440 px)
//  ▸ Loading overlay on the submit button
//  ▸ Session already active → skips straight to dashboard
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../providers/teacher_auth_provider.dart';

// ─────────────────────────────────────────────────────────────
class TeacherLoginScreen extends ConsumerStatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  ConsumerState<TeacherLoginScreen> createState() =>
      _TeacherLoginScreenState();
}

class _TeacherLoginScreenState
    extends ConsumerState<TeacherLoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus   = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref.read(teacherAuthProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  // ── Sign out (when access-denied) ────────────────────────
  void _dismiss() => ref.read(teacherAuthProvider.notifier).clearError();

  @override
  Widget build(BuildContext context) {
    // Side-effect: navigate once authenticated
    ref.listen<TeacherAuthState>(teacherAuthProvider, (_, next) {
      if (next.isAuthenticated) {
        context.go(AppRoutes.teacherDashboard);
      }
    });

    final auth = ref.watch(teacherAuthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: Stack(
        children: [
          // ── Background decoration ──────────────────────
          _BackgroundDecoration(),

          // ── Centred card ───────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo + title
                    _Logo(),
                    const SizedBox(height: 36),

                    // Card
                    _LoginCard(
                      formKey: _formKey,
                      emailCtrl: _emailCtrl,
                      passwordCtrl: _passwordCtrl,
                      emailFocus: _emailFocus,
                      passwordFocus: _passwordFocus,
                      obscurePassword: _obscurePassword,
                      onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      onSubmit: _submit,
                      isLoading: auth.isLoading,
                    ),

                    // Error / access-denied banner
                    if (auth.hasError || auth.isAccessDenied) ...[
                      const SizedBox(height: 16),
                      _ErrorCard(
                        message: auth.errorMessage ??
                            'An unexpected error occurred.',
                        isAccessDenied: auth.isAccessDenied,
                        onDismiss: _dismiss,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Forgot password
                    _ForgotPasswordLink(),

                    const SizedBox(height: 32),

                    // Footer
                    Text(
                      '© ${DateTime.now().year} ${AppConstants.appName}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Background decoration
// ─────────────────────────────────────────────────────────────
class _BackgroundDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-left blob
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
        // Bottom-right blob
        Positioned(
          bottom: -60,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.10),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Logo / brand header
// ─────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          AppConstants.appName,
          style: AppTextStyles.displaySmall,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Teacher Portal',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Login card
// ─────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back 👋',
                style: AppTextStyles.headlineLarge),
            const SizedBox(height: 4),
            Text(
              'Sign in with your teacher credentials',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),

            const SizedBox(height: 28),

            // Email field
            _FieldLabel(label: 'Email Address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: emailCtrl,
              focusNode: emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: AppTextStyles.bodyMedium,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(passwordFocus),
              decoration: InputDecoration(
                hintText: 'teacher@school.edu',
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.textHint, size: 20),
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textHint),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required';
                }
                final emailRx = RegExp(
                    r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
                if (!emailRx.hasMatch(v.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Password field
            _FieldLabel(label: 'Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: passwordCtrl,
              focusNode: passwordFocus,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              style: AppTextStyles.bodyMedium,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.textHint, size: 20),
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textHint),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                  tooltip: obscurePassword
                      ? 'Show password'
                      : 'Hide password',
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Password is required';
                }
                if (v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: isLoading ? null : onSubmit,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Sign In',
                          key: const ValueKey('label'),
                          style: AppTextStyles.button,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Error / access-denied card
// ─────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  final bool isAccessDenied;
  final VoidCallback onDismiss;

  const _ErrorCard({
    required this.message,
    required this.isAccessDenied,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isAccessDenied ? AppColors.warning : AppColors.error;
    final icon = isAccessDenied
        ? Icons.no_accounts_rounded
        : Icons.error_outline_rounded;
    final title = isAccessDenied ? 'Access Denied' : 'Login Failed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLarge
                      .copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: color, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, color: color, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Forgot password link
// ─────────────────────────────────────────────────────────────
class _ForgotPasswordLink extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.forgotPassword),
      child: Text(
        'Forgot your password?',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tiny helpers
// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTextStyles.labelLarge);
}
