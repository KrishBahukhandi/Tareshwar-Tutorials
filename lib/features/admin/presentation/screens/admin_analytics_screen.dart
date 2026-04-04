// ─────────────────────────────────────────────────────────────
//  admin_analytics_screen.dart  –  Platform analytics & charts
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_top_bar.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync  = ref.watch(adminStatsProvider);
    final coursesAsync = ref.watch(adminCoursesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          ref.invalidate(adminCoursesProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Analytics',
                  style: AppTextStyles.displaySmall),
              const SizedBox(height: 4),
              Text(
                'Key performance indicators for the platform.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),

              // ── KPI Summary ────────────────────────────────
              statsAsync.when(
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => Text('Error: $e'),
                data: (stats) => Column(
                  children: [
                    // User breakdown
                    AdminTableCard(
                      title: 'User Distribution',
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _HorizontalBar(
                              label: 'Students',
                              count: stats.totalStudents,
                              total: stats.totalStudents +
                                  stats.totalTeachers +
                                  stats.totalAdmins,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            _HorizontalBar(
                              label: 'Teachers',
                              count: stats.totalTeachers,
                              total: stats.totalStudents +
                                  stats.totalTeachers +
                                  stats.totalAdmins,
                              color: AppColors.info,
                            ),
                            const SizedBox(height: 12),
                            _HorizontalBar(
                              label: 'Admins',
                              count: stats.totalAdmins,
                              total: stats.totalStudents +
                                  stats.totalTeachers +
                                  stats.totalAdmins,
                              color: AppColors.error,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Engagement
                    AdminTableCard(
                      title: 'Engagement Metrics',
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _HorizontalBar(
                              label: 'Published Courses',
                              count: stats.publishedCourses,
                              total: stats.totalCourses,
                              color: AppColors.success,
                            ),
                            const SizedBox(height: 12),
                            _HorizontalBar(
                              label: 'Resolved Doubts',
                              count: stats.resolvedDoubts,
                              total: stats.totalDoubts,
                              color: AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Top courses by lectures ────────────────────
              coursesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (courses) {
                  final sorted = [...courses]
                    ..sort((a, b) =>
                        b.totalLectures.compareTo(a.totalLectures));
                  final top = sorted.take(8).toList();
                  return AdminTableCard(
                    title: 'Top Courses by Lecture Count',
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: top.asMap().entries.map((e) {
                          final c = e.value;
                          final max = top.first.totalLectures;
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 10),
                            child: _HorizontalBar(
                              label: c.title,
                              count: c.totalLectures,
                              total:
                                  max == 0 ? 1 : max,
                              color: _rankColor(e.key),
                              suffix: '${c.totalLectures} lectures',
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Course fill rates ──────────────────────────
              coursesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (courses) {
                  final withCapacity = courses
                      .where((c) => c.maxStudents > 0 && c.isPublished)
                      .toList();
                  if (withCapacity.isEmpty) return const SizedBox.shrink();
                  return AdminTableCard(
                    title: 'Course Fill Rates',
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: withCapacity.take(8).map((c) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 10),
                            child: _HorizontalBar(
                              label: c.title,
                              count: c.enrolledCount,
                              total: c.maxStudents,
                              color: c.fillPercent >= 1.0
                                  ? AppColors.error
                                  : c.fillPercent >= 0.8
                                      ? AppColors.warning
                                      : AppColors.success,
                              suffix:
                                  '${c.enrolledCount}/${c.maxStudents}',
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _rankColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      AppColors.accent,
      AppColors.warning,
      AppColors.secondary,
      AppColors.primaryDark,
      AppColors.error,
    ];
    return colors[index % colors.length];
  }
}

// ── Horizontal bar chart row ──────────────────────────────────
class _HorizontalBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final String? suffix;

  const _HorizontalBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    final displayPct = (pct * 100).toStringAsFixed(1);

    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            suffix ?? '$count ($displayPct%)',
            style: AppTextStyles.labelMedium.copyWith(color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
