// ─────────────────────────────────────────────────────────────
//  payments_dashboard_screen.dart
//  Admin: Payment overview with KPI cards and quick nav.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../providers/admin_payments_providers.dart';
import '../widgets/admin_payments_widgets.dart';

class PaymentsDashboardScreen extends ConsumerWidget {
  const PaymentsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync  = ref.watch(paymentSummaryProvider);
    final monthlyAsync  = ref.watch(monthlyRevenueProvider);
    final courseAsync   = ref.watch(courseRevenueProvider);
    final recentAsync   = ref.watch(paymentsListProvider);  // uses default filter

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paymentSummaryProvider);
          ref.invalidate(monthlyRevenueProvider);
          ref.invalidate(courseRevenueProvider);
          ref.invalidate(paymentsListProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Management',
                            style: AppTextStyles.headlineLarge
                                .copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          'Revenue overview, transactions & refunds',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('All Transactions'),
                    onPressed: () =>
                        context.push(AppRoutes.adminTransactions),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.analytics_rounded, size: 16),
                    label: const Text('Revenue Analytics'),
                    onPressed: () =>
                        context.push(AppRoutes.adminRevenueAnalytics),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── KPI stat cards ────────────────────────────
              summaryAsync.when(
                loading: () => const _StatCardSkeleton(),
                error: (e, _) => _ErrorTile(message: e.toString(),
                    onRetry: () => ref.invalidate(paymentSummaryProvider)),
                data: (s) => _StatCardRow(summary: s),
              ),
              const SizedBox(height: 24),

              // ── Charts row ────────────────────────────────
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final charts = [
                  // Monthly revenue bar chart
                  PaymentTableCard(
                    title: 'Monthly Revenue (Last 12 Months)',
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      child: SizedBox(
                        height: 220,
                        child: monthlyAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) => Center(
                              child: Text('Failed to load chart',
                                  style: AppTextStyles.bodySmall)),
                          data: (data) =>
                              MonthlyRevenueChart(data: data),
                        ),
                      ),
                    ),
                  ),
                  // Course revenue pie
                  PaymentTableCard(
                    title: 'Revenue by Course',
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      child: SizedBox(
                        height: 220,
                        child: courseAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) => Center(
                              child: Text('Failed to load chart',
                                  style: AppTextStyles.bodySmall)),
                          data: (data) =>
                              CourseRevenuePieChart(data: data),
                        ),
                      ),
                    ),
                  ),
                ];

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: charts[0]),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: charts[1]),
                    ],
                  );
                }
                return Column(children: [
                  charts[0],
                  const SizedBox(height: 16),
                  charts[1],
                ]);
              }),
              const SizedBox(height: 24),

              // ── Recent transactions ────────────────────────
              PaymentTableCard(
                title: 'Recent Transactions',
                headerActions: [
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('View all'),
                    onPressed: () =>
                        context.push(AppRoutes.adminTransactions),
                  ),
                ],
                child: recentAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: $e',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error)),
                  ),
                  data: (payments) {
                    final recent = payments.take(8).toList();
                    if (recent.isEmpty) {
                      return const PaymentEmptyState(
                        message: 'No transactions yet',
                        subtitle: 'Payments will appear here once students purchase courses.',
                      );
                    }
                    return _TransactionMiniTable(payments: recent);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // ── Pending refunds quick view ─────────────────
              _PendingRefundsCard(ref: ref),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat card row ─────────────────────────────────────────────
class _StatCardRow extends StatelessWidget {
  const _StatCardRow({required this.summary});

  final PaymentSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cards = [
        RevenueStatCard(
          label:    'Total Revenue',
          value:    fmtInr(summary.totalRevenue),
          icon:     Icons.currency_rupee_rounded,
          color:    AppColors.success,
          subtitle: '${summary.totalTransactions} transactions',
        ),
        RevenueStatCard(
          label:    'This Month',
          value:    fmtInr(summary.monthRevenue),
          icon:     Icons.calendar_month_rounded,
          color:    AppColors.primary,
          subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
        ),
        RevenueStatCard(
          label:    'Pending',
          value:    '${summary.pendingCount}',
          icon:     Icons.pending_actions_rounded,
          color:    AppColors.warning,
          subtitle: 'Awaiting confirmation',
        ),
        RevenueStatCard(
          label:    'Refunds',
          value:    '${summary.refundedCount}',
          icon:     Icons.replay_rounded,
          color:    AppColors.info,
          subtitle: '${summary.failedCount} failed',
        ),
      ];

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

// ── Skeleton for loading ──────────────────────────────────────
class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Container(
            height: 110,
            margin: EdgeInsets.only(right: i < 3 ? 16 : 0),
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

// ── Compact transaction table ─────────────────────────────────
class _TransactionMiniTable extends StatelessWidget {
  const _TransactionMiniTable({required this.payments});

  final List<PaymentRow> payments;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Student', style: AppTextStyles.labelMedium)),
              Expanded(flex: 3, child: Text('Course',  style: AppTextStyles.labelMedium)),
              SizedBox(width: 90, child: Text('Amount', style: AppTextStyles.labelMedium, textAlign: TextAlign.right)),
              const SizedBox(width: 16),
              SizedBox(width: 96, child: Text('Status', style: AppTextStyles.labelMedium)),
              const SizedBox(width: 16),
              SizedBox(width: 90, child: Text('Date', style: AppTextStyles.labelMedium, textAlign: TextAlign.right)),
              const SizedBox(width: 36),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        ...payments.map((p) => Column(
          children: [
            PaymentListTile(payment: p),
            const Divider(height: 1, color: AppColors.border),
          ],
        )),
      ],
    );
  }
}

// ── Pending refunds summary ───────────────────────────────────
class _PendingRefundsCard extends ConsumerWidget {
  const _PendingRefundsCard({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refundsAsync = ref.watch(refundRequestsProvider);

    return refundsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (refunds) {
        final pending = refunds.where((r) => r.status == 'pending').toList();
        if (pending.isEmpty) return const SizedBox.shrink();

        return PaymentTableCard(
          title: 'Pending Refund Requests (${pending.length})',
          headerActions: [
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Manage all'),
              onPressed: () => context.push(AppRoutes.adminTransactions,
                  extra: 'refunds'),
            ),
          ],
          child: Column(
            children: pending.take(5).map((r) {
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.studentName,
                                style: AppTextStyles.labelLarge),
                            Text(r.courseTitle,
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Text(fmtInr(r.amount),
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.error)),
                      const SizedBox(width: 16),
                      _RefundActionButtons(refund: r),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

class _RefundActionButtons extends ConsumerWidget {
  const _RefundActionButtons({required this.refund});

  final RefundRequestRow refund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => _updateRefund(ref, refund.id, 'rejected', context),
          child: const Text('Reject', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => _updateRefund(ref, refund.id, 'approved', context),
          child: const Text('Approve', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _updateRefund(
      WidgetRef ref, String id, String status, BuildContext context) async {
    await ref
        .read(updateRefundProvider.notifier)
        .updateStatus(id, status);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Refund ${status == 'approved' ? 'approved' : 'rejected'}'),
        backgroundColor:
            status == 'approved' ? AppColors.success : AppColors.error,
      ));
    }
  }
}

// ── Error tile ────────────────────────────────────────────────
class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message, required this.onRetry});

  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message, style: AppTextStyles.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
