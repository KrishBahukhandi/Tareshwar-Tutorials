// ─────────────────────────────────────────────────────────────
//  profile_screen.dart  –  Student profile + progress
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/app_providers.dart'
    show enrolledCoursesProvider, studentAttemptsProvider;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          final enrolledAsync = ref.watch(enrolledCoursesProvider);
          final attemptsAsync = ref.watch(studentAttemptsProvider);
          final enrolledCount = enrolledAsync.valueOrNull?.length ?? 0;
          final testsCount = attemptsAsync.valueOrNull?.length ?? 0;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          child: Text(
                            (user?.name ?? 'S')[0].toUpperCase(),
                            style: AppTextStyles.displayMedium
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.name ?? 'Student',
                          style: AppTextStyles.headlineLarge
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          user?.email ?? '',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Stats Row
                      Row(
                        children: [
                          _ProfileStat(
                              label: 'Courses',
                              value: enrolledCount.toString()),
                          _ProfileStat(
                              label: 'Tests',
                              value: testsCount.toString()),
                          const _ProfileStat(label: 'Rank', value: '-'),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Menu items
                      _ProfileMenuItem(
                        icon: Icons.book_outlined,
                        label: 'Enrolled Courses',
                        onTap: () => context.go(AppRoutes.myCourses),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.assignment_outlined,
                        label: 'Test History',
                        onTap: () => context.go(AppRoutes.testsTab),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.question_answer_outlined,
                        label: 'My Doubts',
                        onTap: () => context.go(AppRoutes.doubts),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () =>
                            context.push(AppRoutes.notifications),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Support',
                        onTap: () => launchUrl(
                          Uri.parse(
                              'https://wa.me/916280554348?text=Hi%2C%20I%20need%20help%20with%20the%20Tareshwar%20Tutorials%20app'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      _ProfileMenuItem(
                        icon: Icons.logout_rounded,
                        label: 'Sign Out',
                        color: AppColors.error,
                        onTap: () async {
                          await ref.read(authServiceProvider).signOut();
                          if (context.mounted) {
                            context.go(AppRoutes.login);
                          }
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.headlineLarge
                    .copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: c),
      ),
      title: Text(label,
          style: AppTextStyles.bodyMedium.copyWith(color: c)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint),
      onTap: onTap,
    );
  }
}
