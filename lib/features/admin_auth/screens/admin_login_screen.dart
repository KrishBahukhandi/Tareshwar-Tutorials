// ─────────────────────────────────────────────────────────────
//  admin_login_screen.dart
//  Secure admin portal login.
//
//  Features
//  ▸ Email + password with full inline validation
//  ▸ Driven by AdminAuthNotifier (dedicated provider)
//  ▸ Role-gate: accessDenied state → prominent locked-out banner
//  ▸ Password visibility toggle
//  ▸ Submit on Enter (web keyboard-friendly)
//  ▸ Centred card layout, max-width 460 px (desktop-optimised)
//  ▸ Dark admin colour palette distinct from student / teacher UIs
//  ▸ Animated error/access-denied banner with dismiss
//  ▸ Loading overlay on submit button
//  ▸ If a valid admin session already exists → skip to dashboard
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../providers/admin_auth_provider.dart'
    show adminAuthProvider, AdminAuthState;

// ─────────────────────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────────────────────
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() =>
      _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _emailFocus     = FocusNode();
  final _passwordFocus  = FocusNode();
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
    await ref.read(adminAuthProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  // ── Dismiss error / access-denied banner ─────────────────
  void _dismiss() =>
      ref.read(adminAuthProvider.notifier).clearError();

  @override
  Widget build(BuildContext context) {
    // Side-effect: navigate once successfully authenticated
    ref.listen<AdminAuthState>(adminAuthProvider, (_, next) {
      if (next.isAuthenticated) {
        context.go(AppRoutes.adminDashboard);
      }
    });

    final auth = ref.watch(adminAuthProvider);

    // Already authenticated on cold start → go straight to dashboard
    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.go(AppRoutes.adminDashboard));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C1A),
      body: Stack(
        children: [
          // ── Decorative background ──────────────────────
          const _BackgroundPattern(),

          // ── Scrollable centred card ────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / branding
                    const _AdminBrand(),
                    const SizedBox(height: 40),

                    // Login card
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: (auth.hasError || auth.isAccessDenied)
                          ? Padding(
                              key: const ValueKey('banner'),
                              padding: const EdgeInsets.only(top: 16),
                              child: _StatusBanner(
                                message: auth.errorMessage ??
                                    'An unexpected error occurred.',
                                isAccessDenied: auth.isAccessDenied,
                                onDismiss: _dismiss,
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('empty')),
                    ),

                    const SizedBox(height: 32),
                    _FooterNote(),
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
//  Background pattern
// ─────────────────────────────────────────────────────────────
class _BackgroundPattern extends StatelessWidget {
  const _BackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C63FF).withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Accent glow circles
    final glowPaint = Paint()
      ..color = const Color(0xFF6C63FF).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(
        Offset(size.width * 0.15, size.height * 0.2), 180, glowPaint);
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.75), 200, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
//  Brand / logo block
// ─────────────────────────────────────────────────────────────
class _AdminBrand extends StatelessWidget {
  const _AdminBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Shield icon badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4B44CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          'Admin Portal',
          style: AppTextStyles.displaySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tareshwar Tutorials',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1.2,
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
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final bool isLoading;

  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF13142A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            Text(
              'Sign in to continue',
              style: AppTextStyles.headlineMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your administrator credentials below.',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 28),

            // Email field
            _DarkField(
              controller: emailCtrl,
              focusNode: emailFocus,
              label: 'Email address',
              hint: 'admin@tareshwar.in',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onFieldSubmitted: () =>
                  FocusScope.of(context).requestFocus(passwordFocus),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required';
                }
                final emailRx = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!emailRx.hasMatch(v.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Password field
            _DarkField(
              controller: passwordCtrl,
              focusNode: passwordFocus,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: Colors.white38,
                ),
                onPressed: onToggleObscure,
                splashRadius: 18,
              ),
              onFieldSubmitted: onSubmit,
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
            const SizedBox(height: 28),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: AppTextStyles.labelLarge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded,
                              size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Sign in as Administrator',
                              style: TextStyle(color: Colors.white)),
                        ],
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
//  Dark-themed form field
// ─────────────────────────────────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final VoidCallback? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  const _DarkField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted:
              onFieldSubmitted != null ? (_) => onFieldSubmitted!() : null,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.2), fontSize: 14),
            prefixIcon: Icon(icon,
                color: Colors.white.withValues(alpha: 0.35), size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
            errorStyle: const TextStyle(
                color: AppColors.error, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Status banner (error / access-denied)
// ─────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isAccessDenied;
  final VoidCallback onDismiss;

  const _StatusBanner({
    required this.message,
    required this.isAccessDenied,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isAccessDenied ? AppColors.warning : AppColors.error;
    final icon = isAccessDenied
        ? Icons.block_rounded
        : Icons.error_outline_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAccessDenied ? 'Access Denied' : 'Sign-in Failed',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, color: color, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Footer note
// ─────────────────────────────────────────────────────────────
class _FooterNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_rounded,
            size: 13, color: Colors.white.withValues(alpha: 0.25)),
        const SizedBox(width: 6),
        Text(
          'Restricted access — administrators only',
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
