// ─────────────────────────────────────────────────────────────
//  admin_overview_screen.dart  –  Dashboard KPI overview
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../../../shared/services/admin_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_top_bar.dart';

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final adminName = ref.watch(currentUserProvider).valueOrNull?.name.split(' ').first ?? 'Admin';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminStatsProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting ──────────────────────────────────
              Text('Welcome back, $adminName 👋',
                  style: AppTextStyles.displaySmall),
              const SizedBox(height: 4),
              Text('Here\'s what\'s happening on the platform today.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 28),

              // ── KPI Cards ──────────────────────────────────
              statsAsync.when(
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => _ErrorBanner(message: e.toString()),
                data: (stats) => Column(
                  children: [
                    // Row 1
                    _ResponsiveGrid(children: [
                      AppKpiCard(
                        label: 'Total Students',
                        value: '${stats.totalStudents}',
                        icon: Icons.people_alt_rounded,
                        color: AppColors.primary,
                        subtitle: 'Registered accounts',
                      ),
                      AppKpiCard(
                        label: 'Teachers',
                        value: '${stats.totalTeachers}',
                        icon: Icons.school_rounded,
                        color: AppColors.info,
                        subtitle: 'Active instructors',
                      ),
                      AppKpiCard(
                        label: 'Courses',
                        value: '${stats.totalCourses}',
                        icon: Icons.menu_book_rounded,
                        color: AppColors.accent,
                        subtitle: '${stats.publishedCourses} published',
                      ),
                      AppKpiCard(
                        label: 'Batches',
                        value: '${stats.totalBatches}',
                        icon: Icons.group_work_rounded,
                        color: AppColors.secondary,
                        subtitle: '${stats.activeBatches} active',
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    // Row 2
                    _ResponsiveGrid(children: [
                      AppKpiCard(
                        label: 'Enrollments',
                        value: '${stats.totalEnrollments}',
                        icon: Icons.assignment_turned_in_rounded,
                        color: AppColors.success,
                        subtitle: 'All time',
                      ),
                      AppKpiCard(
                        label: 'Doubts Raised',
                        value: '${stats.totalDoubts}',
                        icon: Icons.help_outline_rounded,
                        color: AppColors.warning,
                        subtitle:
                            '${stats.resolvedDoubts} resolved (${stats.doubtResolutionRate.toStringAsFixed(0)}%)',
                      ),
                      AppKpiCard(
                        label: 'Test Attempts',
                        value: '${stats.totalTestAttempts}',
                        icon: Icons.quiz_rounded,
                        color: AppColors.primaryDark,
                        subtitle: 'All tests, all students',
                      ),
                      AppKpiCard(
                        label: 'Admins',
                        value: '${stats.totalAdmins}',
                        icon: Icons.admin_panel_settings_rounded,
                        color: AppColors.error,
                        subtitle: 'Super users',
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Progress metrics ─────────────────────
                    _MetricsRow(stats: stats),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Quick Actions ─────────────────────────────
              Text('Quick Actions', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 16),
              _QuickActions(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Responsive grid ───────────────────────────────────────────
class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1200 ? 4 : w >= 800 ? 2 : 1;
    return LayoutBuilder(
      builder: (_, constraints) {
        final cardW =
            (constraints.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((c) => SizedBox(width: cardW, child: c))
              .toList(),
        );
      },
    );
  }
}

// ── Metrics row ───────────────────────────────────────────────
class _MetricsRow extends StatelessWidget {
  final AdminStats stats;
  const _MetricsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return AdminTableCard(
      title: 'Platform Health',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _ProgressMetric(
              label: 'Course Publish Rate',
              value: stats.totalCourses == 0
                  ? 0
                  : stats.publishedCourses / stats.totalCourses,
              color: AppColors.success,
            ),
            const SizedBox(height: 14),
            _ProgressMetric(
              label: 'Batch Activation Rate',
              value: stats.totalBatches == 0
                  ? 0
                  : stats.activeBatches / stats.totalBatches,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            _ProgressMetric(
              label: 'Doubt Resolution Rate',
              value: stats.totalDoubts == 0
                  ? 0
                  : stats.resolvedDoubts / stats.totalDoubts,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProgressMetric(
      {required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toStringAsFixed(1);
    return Row(
      children: [
        SizedBox(
            width: 200,
            child: Text(label, style: AppTextStyles.bodyMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Text('$pct%',
              style: AppTextStyles.labelMedium
                  .copyWith(color: color),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────
class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const actions = [
      (
        label: 'Add Student',
        icon: Icons.person_add_rounded,
        color: AppColors.primary,
        section: AdminSection.students
      ),
      (
        label: 'Add Teacher',
        icon: Icons.school_rounded,
        color: AppColors.info,
        section: AdminSection.teachers
      ),
      (
        label: 'New Batch',
        icon: Icons.group_work_rounded,
        color: AppColors.secondary,
        section: AdminSection.batches
      ),
      (
        label: 'Announce',
        icon: Icons.campaign_rounded,
        color: AppColors.warning,
        section: AdminSection.announcements
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions.map((a) {
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ref
              .read(adminSelectedSectionProvider.notifier)
              .state = a.section,
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.icon, color: a.color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(a.label,
                    style: AppTextStyles.labelMedium,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.error))),
        ],
      ),
    );
  }
}
