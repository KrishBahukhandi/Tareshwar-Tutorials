// ─────────────────────────────────────────────────────────────
//  student_growth_chart_screen.dart
//  Standalone full-screen Student Growth chart page.
//  Shows: monthly new-student line chart + cumulative stats.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/admin_analytics_providers.dart';
import '../widgets/admin_analytics_widgets.dart';

class StudentGrowthChartScreen extends ConsumerWidget {
  const StudentGrowthChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync  = ref.watch(analyticsDashboardStatsProvider);
    final growthAsync = ref.watch(analyticsStudentGrowthProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Student Growth', style: AppTextStyles.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(analyticsDashboardStatsProvider);
              ref.invalidate(analyticsStudentGrowthProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsDashboardStatsProvider);
          ref.invalidate(analyticsStudentGrowthProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── KPI tiles ─────────────────────────────────
              statsAsync.when(
                loading: () => _KpiSkeleton(),
                error: (e, _) => _ErrorBanner(e.toString()),
                data: (s) {
                  final newThisMonth = growthAsync.valueOrNull
                          ?.lastOrNull?.value.toInt() ??
                      0;
                  return LayoutBuilder(
                    builder: (ctx, c) {
                      final cols = c.maxWidth > 600 ? 3 : 2;
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: c.maxWidth > 600 ? 2.0 : 1.6,
                        children: [
                          AnalyticsStatCard(
                            label: 'Total Students',
                            value: '${s.totalStudents}',
                            icon: Icons.people_alt_rounded,
                            color: AppColors.primary,
                            subtitle: 'All time registrations',
                          ),
                          AnalyticsStatCard(
                            label: 'New This Month',
                            value: '$newThisMonth',
                            icon: Icons.person_add_rounded,
                            color: AppColors.accent,
                            subtitle: 'Students joined this month',
                          ),
                          AnalyticsStatCard(
                            label: 'Total Teachers',
                            value: '${s.totalTeachers}',
                            icon: Icons.co_present_rounded,
                            color: AppColors.info,
                            subtitle: 'Active educators',
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Student growth line chart ─────────────────
              AnalyticsChartCard(
                title: 'New Student Registrations',
                subtitle: 'Last 12 months',
                trailing: growthAsync.whenData((data) {
                  if (data.isEmpty) return const SizedBox.shrink();
                  final total = data.fold<double>(0, (s, d) => s + d.value);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${total.toInt()} total',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.accent),
                    ),
                  );
                }).valueOrNull ??
                    const SizedBox.shrink(),
                child: growthAsync.when(
                  loading: () => const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => _ErrorBanner(e.toString()),
                  data: (data) => StudentGrowthChart(data: data),
                ),
              ),
              const SizedBox(height: 24),

              // ── Monthly breakdown table ───────────────────
              growthAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) {
                  if (data.isEmpty) return const SizedBox.shrink();
                  return AnalyticsChartCard(
                    title: 'Monthly Breakdown',
                    subtitle: 'New students by month',
                    child: _GrowthTable(
                        data: data.reversed.toList()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Monthly growth table ──────────────────────────────────────
class _GrowthTable extends StatelessWidget {
  const _GrowthTable({required this.data});
  final List<MonthlyDataPoint> data;

  @override
  Widget build(BuildContext context) {
    final maxVal =
        data.map((d) => d.value).fold(0.0, (a, b) => a > b ? a : b);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final d = data[i];
        final pct = maxVal == 0 ? 0.0 : d.value / maxVal;
        return Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  d.label,
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 4),
              Text('${d.year}',
                  style: AppTextStyles.bodySmall),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(
                        AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Text(
                  '${d.value.toInt()} new',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.accent),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────
class _KpiSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
          3,
          (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.shimmerBase,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              )),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
