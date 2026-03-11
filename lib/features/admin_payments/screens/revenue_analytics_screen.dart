// ─────────────────────────────────────────────────────────────
//  revenue_analytics_screen.dart
//  Admin: Deep-dive revenue analytics — bar chart, pie chart,
//  top-courses table, and monthly growth stats.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/admin_payments_providers.dart';
import '../widgets/admin_payments_widgets.dart';

class RevenueAnalyticsScreen extends ConsumerWidget {
  const RevenueAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync  = ref.watch(paymentSummaryProvider);
    final monthlyAsync  = ref.watch(monthlyRevenueProvider);
    final courseAsync   = ref.watch(courseRevenueProvider);

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
              ref.invalidate(paymentSummaryProvider);
              ref.invalidate(monthlyRevenueProvider);
              ref.invalidate(courseRevenueProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paymentSummaryProvider);
          ref.invalidate(monthlyRevenueProvider);
          ref.invalidate(courseRevenueProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary KPIs ────────────────────────────────
              summaryAsync.when(
                loading: () => const _SkeletonRow(count: 4, height: 110),
                error: (e, _) => _ErrorBanner(e.toString()),
                data: (s) => _SummaryCards(summary: s),
              ),
              const SizedBox(height: 24),

              // ── Monthly revenue chart ────────────────────────
              PaymentTableCard(
                title: 'Monthly Revenue Trend',
                headerActions: [
                  monthlyAsync.whenData((data) {
                    if (data.isEmpty) return const SizedBox.shrink();
                    final total = data.fold<double>(0, (s, m) => s + m.amount);
                    return Text(
                      'YTD: ${fmtInr(total)}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    );
                  }).valueOrNull ?? const SizedBox.shrink(),
                ],
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: SizedBox(
                    height: 260,
                    child: monthlyAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text('Failed: $e',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.error)),
                      ),
                      data: (data) => data.isEmpty
                          ? const _NoDataWidget(
                              label: 'No monthly revenue data yet')
                          : MonthlyRevenueChart(data: data),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Dual-panel: pie + table ──────────────────────
              courseAsync.when(
                loading: () =>
                    const _SkeletonRow(count: 1, height: 300),
                error: (e, _) => _ErrorBanner(e.toString()),
                data: (courses) {
                  return LayoutBuilder(builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth >= 800;
                    final piePanel = PaymentTableCard(
                      title: 'Revenue by Course',
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: 240,
                          child: courses.isEmpty
                              ? const _NoDataWidget(
                                  label: 'No course revenue yet')
                              : CourseRevenuePieChart(data: courses),
                        ),
                      ),
                    );

                    final tablePanel = PaymentTableCard(
                      title: 'Top Performing Courses',
                      child: _CourseRevenueTable(courses: courses),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: piePanel),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: tablePanel),
                        ],
                      );
                    }
                    return Column(children: [
                      piePanel,
                      const SizedBox(height: 16),
                      tablePanel,
                    ]);
                  });
                },
              ),
              const SizedBox(height: 24),

              // ── Monthly growth table ─────────────────────────
              monthlyAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (data) => _MonthlyGrowthTable(data: data),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Summary cards ─────────────────────────────────────────────
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final PaymentSummary summary;

  @override
  Widget build(BuildContext context) {
    final successRate = summary.totalTransactions == 0
        ? 0.0
        : (summary.totalTransactions -
                summary.failedCount -
                summary.refundedCount -
                summary.pendingCount) /
            summary.totalTransactions *
            100;

    final cards = [
      RevenueStatCard(
        label:    'Total Revenue',
        value:    fmtInr(summary.totalRevenue),
        icon:     Icons.currency_rupee_rounded,
        color:    AppColors.success,
        subtitle: '${summary.totalTransactions} total payments',
      ),
      RevenueStatCard(
        label:    'This Month',
        value:    fmtInr(summary.monthRevenue),
        icon:     Icons.calendar_month_rounded,
        color:    AppColors.primary,
        subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
      ),
      RevenueStatCard(
        label:    'Success Rate',
        value:    '${successRate.toStringAsFixed(1)}%',
        icon:     Icons.check_circle_outline_rounded,
        color:    AppColors.accent,
        subtitle: '${summary.failedCount} failed',
      ),
      RevenueStatCard(
        label:    'Refund Rate',
        value:    summary.totalTransactions == 0
            ? '0%'
            : '${(summary.refundedCount / summary.totalTransactions * 100).toStringAsFixed(1)}%',
        icon:     Icons.replay_rounded,
        color:    AppColors.info,
        subtitle: '${summary.refundedCount} refunded',
      ),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      final isWide = c.maxWidth >= 800;
      if (isWide) {
        return Row(
          children: cards
              .expand((w) => [
                    Expanded(child: w),
                    if (w != cards.last) const SizedBox(width: 16),
                  ])
              .toList(),
        );
      }
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: cards,
      );
    });
  }
}

// ── Course revenue table ──────────────────────────────────────
class _CourseRevenueTable extends StatelessWidget {
  const _CourseRevenueTable({required this.courses});

  final List<CourseRevenue> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: _NoDataWidget(label: 'No course revenue yet'),
      );
    }

    final maxRev = courses.first.totalRevenue;

    return Column(
      children: [
        // Header
        Container(
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                  flex: 4,
                  child: Text('Course',
                      style: AppTextStyles.labelMedium)),
              SizedBox(
                  width: 70,
                  child: Text('Sales',
                      style: AppTextStyles.labelMedium,
                      textAlign: TextAlign.right)),
              const SizedBox(width: 12),
              SizedBox(
                  width: 100,
                  child: Text('Revenue',
                      style: AppTextStyles.labelMedium,
                      textAlign: TextAlign.right)),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: Text('Share',
                    style: AppTextStyles.labelMedium),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        ...courses.take(10).map((c) {
          final pct = maxRev > 0 ? c.totalRevenue / maxRev : 0.0;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(c.courseTitle,
                        style: AppTextStyles.labelLarge,
                        overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('${c.salesCount}',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.right),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: Text(
                      fmtInr(c.totalRevenue),
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.success),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
          ]);
        }),
      ],
    );
  }
}

// ── Monthly growth table ──────────────────────────────────────
class _MonthlyGrowthTable extends StatelessWidget {
  const _MonthlyGrowthTable({required this.data});

  final List<MonthlyRevenue> data;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();

    // Calculate MoM growth
    final rows = <_GrowthRow>[];
    for (var i = 0; i < data.length; i++) {
      final current = data[i].amount;
      final prev    = i > 0 ? data[i - 1].amount : null;
      final growth  = prev != null && prev > 0
          ? (current - prev) / prev * 100
          : null;
      rows.add(_GrowthRow(
        month:   '${data[i].month} ${data[i].year}',
        revenue: current,
        growth:  growth,
      ));
    }

    return PaymentTableCard(
      title: 'Month-over-Month Growth',
      child: Column(
        children: [
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                    child: Text('Month',
                        style: AppTextStyles.labelMedium)),
                SizedBox(
                    width: 120,
                    child: Text('Revenue',
                        style: AppTextStyles.labelMedium,
                        textAlign: TextAlign.right)),
                const SizedBox(width: 16),
                SizedBox(
                    width: 100,
                    child: Text('Growth',
                        style: AppTextStyles.labelMedium,
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...rows.reversed.take(12).map((r) {
            final growthColor = (r.growth ?? 0) >= 0
                ? AppColors.success
                : AppColors.error;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(r.month,
                          style: AppTextStyles.labelLarge),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(fmtInr(r.revenue),
                          style: AppTextStyles.bodySmall
                              .copyWith(
                                  color: AppColors.textPrimary),
                          textAlign: TextAlign.right),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 100,
                      child: r.growth == null
                          ? Text('—',
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.right)
                          : Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                Icon(
                                  r.growth! >= 0
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 14,
                                  color: growthColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${r.growth!.abs().toStringAsFixed(1)}%',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(
                                          color: growthColor),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
            ]);
          }),
        ],
      ),
    );
  }
}

class _GrowthRow {
  final String month;
  final double revenue;
  final double? growth;
  const _GrowthRow(
      {required this.month, required this.revenue, this.growth});
}

// ── Utility widgets ───────────────────────────────────────────
class _NoDataWidget extends StatelessWidget {
  const _NoDataWidget({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 40, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.count, required this.height});

  final int    count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(right: i < count - 1 ? 16 : 0),
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
