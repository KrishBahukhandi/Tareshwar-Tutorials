// ─────────────────────────────────────────────────────────────
//  splash_screen.dart  –  Animated launch screen
//
//  Checks existing Supabase session via authProvider and
//  navigates to the correct home based on user role.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_router.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.elasticOut),
    ));

    _controller.forward();

    // Give authProvider time to restore session, then navigate
    Future.delayed(const Duration(milliseconds: 2200), _navigate);
  }

  void _navigate() {
    if (!mounted || _navigated) return;

    final authState = ref.read(authProvider);

    if (authState.isAuthenticated && authState.user != null) {
      _navigated = true;
      final role = authState.user!.role;
      if (role == AppConstants.roleTeacher) {
        context.go(AppRoutes.teacherDashboard);
      } else if (role == AppConstants.roleAdmin) {
        context.go(AppRoutes.adminDashboard);
      } else {
        context.go(AppRoutes.homeTab);
      }
    } else if (authState.isInitial) {
      // Still initialising – wait a little more then force login
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _navigated) return;
        _navigated = true;
        _goToLogin();
      });
    } else {
      _navigated = true;
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, child) => FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(scale: _scaleAnim, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── App icon ───────────────────────────────
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── App name ───────────────────────────────
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Tagline ────────────────────────────────
                Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 48),

                // ── Loading indicator ──────────────────────
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.70)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
