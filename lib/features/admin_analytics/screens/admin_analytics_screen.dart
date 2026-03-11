// ─────────────────────────────────────────────────────────────
//  admin_analytics_screen.dart  (features/admin_analytics)
//
//  Main Admin Analytics Dashboard. Shows two tabs:
//    Tab 1 – Overview:
//      • 5 KPI stat-cards: students, teachers, active courses,
//        revenue, course-completion rate
//      • Monthly Revenue BarChart   (RevenueChart widget)
//      • Student Growth LineChart   (StudentGrowthChart widget)
//      • Course Completion Donut    (CompletionRingChart widget)
//    Tab 2 – Event Activity:
//      • Real-time engagement KPIs from analytics_events table
//      • Daily activity chart, top lectures, top tests, recent feed
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/admin_analytics_providers.dart';
import '../widgets/admin_analytics_widgets.dart';
import 'event_analytics_screen.dart';
import 'revenue_chart_screen.dart';
import 'student_growth_chart_screen.dart';

// ─────────────────────────────────────────────────────────────
final _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _fmtInr(double v) => _inr.format(v);

// ─────────────────────────────────────────────────────────────
class AdminAnalyticsDashboardScreen extends ConsumerWidget {
  const AdminAnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tab bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analytics', style: AppTextStyles.displaySmall),
                      const SizedBox(height: 4),
                      Text(
                        'Platform-wide metrics and engagement data.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              isScrollable: false,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.labelLarge,
              dividerColor: AppColors.border,
              tabs: const [
                Tab(
                  icon: Icon(Icons.bar_chart_rounded, size: 18),
                  text: 'Overview',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.bolt_rounded, size: 18),
                  text: 'Event Activity',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(),
                EventAnalyticsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Overview Tab (original content)
// ─────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync   = ref.watch(analyticsDashboardStatsProvider);
    final revenueAsync = ref.watch(analyticsMonthlyRevenueProvider);
    final growthAsync  = ref.watch(analyticsStudentGrowthProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsDashboardStatsProvider);
          ref.invalidate(analyticsMonthlyRevenueProvider);
          ref.invalidate(analyticsStudentGrowthProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Refresh button ─────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  onPressed: () {
                    ref.invalidate(analyticsDashboardStatsProvider);
                    ref.invalidate(analyticsMonthlyRevenueProvider);
                    ref.invalidate(analyticsStudentGrowthProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh',
                ),
              ),
              const SizedBox(height: 8),

              // ── KPI stat cards ────────────────────────────
              statsAsync.when(
                loading: () => const AnalyticsSkeletonLoader(),
                error: (e, _) => _ErrorBanner(e.toString()),
                data: (s) => Column(
                  children: [
                    // Row 1: 3 cards
                    LayoutBuilder(
                      builder: (ctx, c) {
                        final cols = c.maxWidth > 700 ? 3 : 2;
                        return GridView.count(
                          crossAxisCount: cols,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio:
                              c.maxWidth > 700 ? 2.0 : 1.55,
                          children: [
                            AnalyticsStatCard(
                              label: 'Total Students',
                              value: '${s.totalStudents}',
                              icon: Icons.school_rounded,
                              color: AppColors.primary,
                              subtitle:
                                  '${s.totalEnrollments} enrollments',
                            ),
                            AnalyticsStatCard(
                              label: 'Total Teachers',
                              value: '${s.totalTeachers}',
                              icon: Icons.co_present_rounded,
                              color: AppColors.info,
                              subtitle: 'Active educators',
                            ),
                            AnalyticsStatCard(
                              label: 'Active Courses',
                              value: '${s.activeCourses}',
                              icon: Icons.play_circle_rounded,
                              color: AppColors.accent,
                              subtitle: 'Published & live',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    // Row 2: 2 wider cards
                    LayoutBuilder(
                      builder: (ctx, c) {
                        final cols = c.maxWidth > 600 ? 2 : 1;
                        return GridView.count(
                          crossAxisCount: cols,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio:
                              c.maxWidth > 600 ? 3.2 : 2.4,
                          children: [
                            AnalyticsStatCard(
                              label: 'Total Revenue',
                              value: _fmtInr(s.totalRevenue),
                              icon: Icons.currency_rupee_rounded,
                              color: AppColors.success,
                              subtitle:
                                  'This month: ${_fmtInr(s.monthRevenue)}',
                              trend: 'Month ↑',
                            ),
                            AnalyticsStatCard(
                              label: 'Course Completion Rate',
                              value:
                                  '${s.courseCompletionRate.toStringAsFixed(1)}%',
                              icon: Icons.verified_rounded,
                              color: AppColors.warning,
                              subtitle:
                                  '${s.completedEnrollments} of ${s.totalEnrollments} completed',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Revenue Bar Chart ─────────────────────────
              AnalyticsChartCard(
                title: 'Monthly Revenue',
                subtitle: 'Last 12 months — completed payments',
                trailing: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const RevenueChartScreen()),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Full View'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: AppTextStyles.labelSmall,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                  ),
                ),
                child: revenueAsync.when(
                  loading: () => const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => _ErrorBanner(e.toString()),
                  data: (data) => RevenueChart(data: data),
                ),
              ),
              const SizedBox(height: 20),

              // ── Student Growth + Completion (side by side on wide) ──
              LayoutBuilder(
                builder: (ctx, c) {
                  final isWide = c.maxWidth > 800;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _StudentGrowthCard(
                              growthAsync: growthAsync,
                              context: context),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _CompletionCard(
                              statsAsync: statsAsync),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _StudentGrowthCard(
                          growthAsync: growthAsync,
                          context: context),
                      const SizedBox(height: 20),
                      _CompletionCard(statsAsync: statsAsync),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Student growth section widget ─────────────────────────────
class _StudentGrowthCard extends StatelessWidget {
  const _StudentGrowthCard({
    required this.growthAsync,
    required this.context,
  });

  final AsyncValue<List<MonthlyDataPoint>> growthAsync;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return AnalyticsChartCard(
      title: 'Student Growth',
      subtitle: 'New registrations — last 12 months',
      trailing: TextButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const StudentGrowthChartScreen()),
        ),
        icon: const Icon(Icons.open_in_new_rounded, size: 14),
        label: const Text('Full View'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppTextStyles.labelSmall,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
      ),
      child: growthAsync.when(
        loading: () => const SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => _ErrorBanner(e.toString()),
        data: (data) => StudentGrowthChart(data: data),
      ),
    );
  }
}

// ── Completion donut section widget ──────────────────────────
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.statsAsync});
  final AsyncValue<AnalyticsDashboardStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Course Completion',
      subtitle: 'Platform-wide completion rate',
      child: statsAsync.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => _ErrorBanner(e.toString()),
        data: (s) => CompletionRingChart(
          completionRate: s.courseCompletionRate,
          total: s.totalEnrollments,
          completed: s.completedEnrollments,
        ),
      ),
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
            color: AppColors.error.withValues(alpha: 0.30)),
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
