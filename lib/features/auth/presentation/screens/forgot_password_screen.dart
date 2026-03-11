// ─────────────────────────────────────────────────────────────
//  forgot_password_screen.dart  –  Password reset via email
//
//  Features:
//  ▸ Email field with validation
//  ▸ Loading state on send button
//  ▸ Animated success view with spring-scale icon
//  ▸ Animated error banner with dismiss
//  ▸ Clear instructions for the user
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_text_field.dart';

// ─────────────────────────────────────────────────────────────
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .resetPassword(_emailCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final sent = auth.status == AuthStatus.emailSent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.login),
          tooltip: 'Back to Login',
        ),
        title: const Text('Forgot Password'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.08), end: Offset.zero)
                    .animate(anim),
                child: child,
              ),
            ),
            child: sent
                ? _SuccessView(
                    key: const ValueKey('success'),
                    email: _emailCtrl.text,
                    onBack: () => context.go(AppRoutes.login),
                  )
                : _FormView(
                    key: const ValueKey('form'),
                    formKey: _formKey,
                    emailCtrl: _emailCtrl,
                    auth: auth,
                    onSend: _send,
                    onClearError: () =>
                        ref.read(authProvider.notifier).clearError(),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Form view
// ─────────────────────────────────────────────────────────────
class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final AuthState auth;
  final VoidCallback onSend;
  final VoidCallback onClearError;

  const _FormView({
    super.key,
    required this.formKey,
    required this.emailCtrl,
    required this.auth,
    required this.onSend,
    required this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Icon ──────────────────────────────────────────────
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  width: 1.5),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 28),

        Text('Reset your password', style: AppTextStyles.displaySmall),
        const SizedBox(height: 10),
        Text(
          "Enter the email linked to your account and we'll send a secure password reset link.",
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),

        // ── Email field ────────────────────────────────────────
        Form(
          key: formKey,
          child: AuthTextField(
            controller: emailCtrl,
            label: 'Email Address',
            hint: 'you@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: onSend,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
        ),

        // ── Error banner ───────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => SizeTransition(
            sizeFactor: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: (auth.hasError && auth.errorMessage != null)
              ? Padding(
                  key: const ValueKey('err'),
                  padding: const EdgeInsets.only(top: 16),
                  child: AuthErrorBanner(
                    message: auth.errorMessage!,
                    onDismiss: onClearError,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('none')),
        ),
        const SizedBox(height: 28),

        // ── Send button ────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : onSend,
            child: auth.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text('Send Reset Link', style: AppTextStyles.button),
          ),
        ),
        const SizedBox(height: 16),

        // ── Back to login ──────────────────────────────────────
        Center(
          child: TextButton.icon(
            onPressed: () => context.go(AppRoutes.login),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back to Login'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Success view
// ─────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final String email;
  final VoidCallback onBack;

  const _SuccessView({super.key, required this.email, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),

        // Spring-scale animated checkmark
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.30),
                  width: 2),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 52,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(height: 28),

        Text(
          'Check your inbox!',
          style: AppTextStyles.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(
          'A password reset link has been sent to',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            email,
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.textHint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Didn't get it? Check your spam folder or wait a few minutes before trying again.",
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: onBack,
            child: Text('Back to Login', style: AppTextStyles.button),
          ),
        ),
      ],
    );
  }
}
