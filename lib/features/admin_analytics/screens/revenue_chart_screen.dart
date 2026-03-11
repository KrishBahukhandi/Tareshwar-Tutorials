// ─────────────────────────────────────────────────────────────
//  revenue_chart_screen.dart
//  Standalone full-screen Revenue Analytics chart page.
//  Shows: monthly revenue bar chart + summary KPIs.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/admin_analytics_providers.dart';
import '../widgets/admin_analytics_widgets.dart';

final _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _fmt(double v) => _inr.format(v);

class RevenueChartScreen extends ConsumerWidget {
  const RevenueChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync   = ref.watch(analyticsDashboardStatsProvider);
    final monthlyAsync = ref.watch(analyticsMonthlyRevenueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Revenue Analytics',
            style: AppTextStyles.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(analyticsDashboardStatsProvider);
              ref.invalidate(analyticsMonthlyRevenueProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsDashboardStatsProvider);
          ref.invalidate(analyticsMonthlyRevenueProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Revenue KPI cards ─────────────────────────
              statsAsync.when(
                loading: () => const _RevenueKpiSkeleton(),
                error: (e, _) => _ErrorBanner(e.toString()),
                data: (s) => LayoutBuilder(
                  builder: (ctx, c) {
                    final cols = c.maxWidth > 600 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: c.maxWidth > 600 ? 1.8 : 1.6,
                      children: [
                        AnalyticsStatCard(
                          label: 'Total Revenue',
                          value: _fmt(s.totalRevenue),
                          icon: Icons.currency_rupee_rounded,
                          color: AppColors.success,
                          subtitle: 'All completed payments',
                        ),
                        AnalyticsStatCard(
                          label: 'This Month',
                          value: _fmt(s.monthRevenue),
                          icon: Icons.calendar_month_rounded,
                          color: AppColors.primary,
                          subtitle: 'Current month revenue',
                        ),
                        AnalyticsStatCard(
                          label: 'Total Students',
                          value: '${s.totalStudents}',
                          icon: Icons.school_rounded,
                          color: AppColors.info,
                          subtitle: 'Registered on platform',
                        ),
                        AnalyticsStatCard(
                          label: 'Active Courses',
                          value: '${s.activeCourses}',
                          icon: Icons.play_circle_rounded,
                          color: AppColors.accent,
                          subtitle: 'Published courses',
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // ── Monthly Revenue Bar Chart ─────────────────
              AnalyticsChartCard(
                title: 'Monthly Revenue',
                subtitle: 'Last 12 months — completed payments',
                trailing: monthlyAsync.whenData((data) {
                  if (data.isEmpty) return const SizedBox.shrink();
                  final ytd = data.fold<double>(0, (s, d) => s + d.value);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'YTD ${_fmt(ytd)}',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.success),
                    ),
                  );
                }).valueOrNull ??
                    const SizedBox.shrink(),
                child: monthlyAsync.when(
                  loading: () => const SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => _ErrorBanner(e.toString()),
                  data: (data) => RevenueChart(data: data),
                ),
              ),
              const SizedBox(height: 24),

              // ── Monthly breakdown table ───────────────────
              monthlyAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) {
                  if (data.isEmpty) return const SizedBox.shrink();
                  final reversed = data.reversed.toList();
                  return AnalyticsChartCard(
                    title: 'Monthly Breakdown',
                    subtitle: 'Revenue by month',
                    child: _MonthlyTable(data: reversed),
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

// ── Monthly breakdown table ───────────────────────────────────
class _MonthlyTable extends StatelessWidget {
  const _MonthlyTable({required this.data});
  final List<MonthlyDataPoint> data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final d = data[i];
        final maxVal =
            data.map((x) => x.value).fold(0.0, (a, b) => a > b ? a : b);
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
              Text(
                '${d.year}',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: Text(
                  _fmt(d.value),
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.primary),
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
class _RevenueKpiSkeleton extends StatelessWidget {
  const _RevenueKpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
          4,
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
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
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
