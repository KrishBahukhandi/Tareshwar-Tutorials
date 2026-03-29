// ─────────────────────────────────────────────────────────────
//  email_verification_screen.dart
//
//  Shown after successful sign-up.
//  ▸ Clearly displays which email the link was sent to
//  ▸ Resend button (calls Supabase auth.resend)
//  ▸ Back to Sign In navigation
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────
class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  bool _resending = false;
  bool _resentSuccess = false;

  late final AnimationController _iconController;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScale = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );
    _iconController.forward();
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _resentSuccess = false;
    });
    try {
      await ref.read(supabaseClientProvider).auth.resend(
            type: OtpType.email,
            email: widget.email,
          );
      if (mounted) setState(() => _resentSuccess = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not resend. Please try again later.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Animated envelope icon ────────────────────
              ScaleTransition(
                scale: _iconScale,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 54,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ── Heading ───────────────────────────────────
              Text(
                'Check your inbox!',
                style: AppTextStyles.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // ── Body copy ─────────────────────────────────
              Text(
                'We\'ve sent a verification link to',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  widget.email,
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap the link in the email to activate your account.\nDon\'t forget to check your spam / junk folder.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 44),

              // ── Back to Sign In ───────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.login),
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: Text('Back to Sign In', style: AppTextStyles.button),
                ),
              ),

              const SizedBox(height: 16),

              // ── Resend ────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _resentSuccess
                    ? Container(
                        key: const ValueKey('success'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  AppColors.success.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Verification email resent!',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.success),
                            ),
                          ],
                        ),
                      )
                    : TextButton(
                        key: const ValueKey('resend'),
                        onPressed: _resending ? null : _resend,
                        child: _resending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              )
                            : Text(
                                'Didn\'t receive it? Resend email',
                                style: AppTextStyles.labelLarge.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
