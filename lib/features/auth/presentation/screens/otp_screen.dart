// ─────────────────────────────────────────────────────────────
//  otp_screen.dart  –  Phone OTP verification
//
//  Features:
//  ▸ 6-box PIN entry with auto-advance & backspace handling
//  ▸ Paste support (auto-splits pasted 6-digit code)
//  ▸ 60-second resend countdown with timer
//  ▸ Animated error banner
//  ▸ Loading state on verify button
//  ▸ Role-based navigation after verification
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

// ─────────────────────────────────────────────────────────────
class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _otpLength     = 6;
  static const _resendSeconds = 60;

  final _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  int    _countdown = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes.first.requestFocus(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────
  void _startCountdown() {
    _timer?.cancel();
    if (mounted) setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── OTP value ─────────────────────────────────────────────
  String get _otp => _controllers.map((c) => c.text).join();

  // ── Paste a 6-digit code ──────────────────────────────────
  void _handlePaste(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == _otpLength) {
      for (var i = 0; i < _otpLength; i++) {
        _controllers[i].text = digits[i];
      }
      _focusNodes.last.unfocus();
      _verify();
    }
  }

  // ── Verify ────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_otp.length != _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter all 6 digits'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final phone = widget.phone.isNotEmpty
        ? widget.phone
        : (ref.read(authProvider).pendingPhone ?? '');

    await ref.read(authProvider.notifier).verifyPhoneOtp(
          phone: phone,
          token: _otp,
        );
  }

  // ── Resend OTP ────────────────────────────────────────────
  Future<void> _resend() async {
    _clearBoxes();
    final phone = widget.phone.isNotEmpty
        ? widget.phone
        : (ref.read(authProvider).pendingPhone ?? '');
    await ref.read(authProvider.notifier).sendPhoneOtp(phone);
    _startCountdown();
  }

  void _clearBoxes() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes.first.requestFocus();
    ref.read(authProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    // ── Side-effects ─────────────────────────────────────────
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.authenticated && next.user != null) {
        final role = next.user!.role;
        if (role == AppConstants.roleTeacher) {
          context.go(AppRoutes.teacherDashboard);
        } else if (role == AppConstants.roleAdmin) {
          context.go(AppRoutes.adminDashboard);
        } else {
          context.go(AppRoutes.homeTab);
        }
      }
    });

    final auth  = ref.watch(authProvider);
    final phone = widget.phone.isNotEmpty
        ? widget.phone
        : (auth.pendingPhone ?? '');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Verify Phone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.login),
          tooltip: 'Back',
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Icon ───────────────────────────────────────
              _OtpIcon(),
              const SizedBox(height: 28),

              // ── Heading ────────────────────────────────────
              Text(
                'Enter Verification Code',
                style: AppTextStyles.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to\n'),
                    TextSpan(
                      text: phone,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ── 6-box PIN input ────────────────────────────
              _PinRow(
                controllers: _controllers,
                focusNodes: _focusNodes,
                onComplete: _verify,
                onPaste: _handlePaste,
              ),

              // ── Error banner ───────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => SizeTransition(
                  sizeFactor: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: (auth.hasError && auth.errorMessage != null)
                    ? Padding(
                        key: const ValueKey('err'),
                        padding: const EdgeInsets.only(top: 20),
                        child: AuthErrorBanner(
                          message: auth.errorMessage!,
                          onDismiss: () {
                            ref.read(authProvider.notifier).clearError();
                            _clearBoxes();
                          },
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
              const SizedBox(height: 36),

              // ── Verify button ──────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _verify,
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text('Verify & Continue',
                            style: AppTextStyles.button),
                ),
              ),
              const SizedBox(height: 24),

              // ── Resend ─────────────────────────────────────
              _ResendRow(
                countdown: _countdown,
                isLoading: auth.isLoading,
                onResend: _resend,
              ),
              const SizedBox(height: 24),

              // ── Change number ──────────────────────────────
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.login),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Change phone number'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  OTP icon decoration
// ─────────────────────────────────────────────────────────────
class _OtpIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
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
            color: AppColors.primary.withValues(alpha: 0.20), width: 1.5),
      ),
      child: const Icon(
        Icons.sms_rounded,
        color: AppColors.primary,
        size: 38,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  6-box PIN row
// ─────────────────────────────────────────────────────────────
class _PinRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onComplete;
  final ValueChanged<String> onPaste;

  const _PinRow({
    required this.controllers,
    required this.focusNodes,
    required this.onComplete,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(controllers.length, (i) {
        return SizedBox(
          width: 48,
          height: 60,
          child: TextField(
            controller: controllers[i],
            focusNode: focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: AppTextStyles.headlineLarge.copyWith(
              fontSize: 24,
              color: AppColors.textPrimary,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              // Handle paste
              if (val.length > 1) {
                onPaste(val);
                return;
              }
              if (val.isNotEmpty) {
                if (i < controllers.length - 1) {
                  focusNodes[i + 1].requestFocus();
                } else {
                  focusNodes[i].unfocus();
                  onComplete();
                }
              } else {
                // Backspace: move to previous box
                if (i > 0) focusNodes[i - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Resend row
// ─────────────────────────────────────────────────────────────
class _ResendRow extends StatelessWidget {
  final int countdown;
  final bool isLoading;
  final VoidCallback onResend;

  const _ResendRow({
    required this.countdown,
    required this.isLoading,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final canResend = countdown == 0 && !isLoading;

    return Column(
      children: [
        Text(
          "Didn't receive the code?",
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        if (canResend)
          TextButton(
            onPressed: onResend,
            child: Text(
              'Resend OTP',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.primary),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 6),
                Text(
                  'Resend in ${countdown}s',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
