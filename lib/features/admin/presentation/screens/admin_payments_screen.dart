// ─────────────────────────────────────────────────────────────
//  admin_payments_screen.dart  –  Payments overview (structured)
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_top_bar.dart';

class AdminPaymentsScreen extends ConsumerWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary cards ──────────────────────────────
            statsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (stats) => Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 220,
                    child: AdminStatCard(
                      label: 'Total Enrollments',
                      value: '${stats.totalEnrollments}',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      subtitle: 'All paid + free',
                    ),
                  ),
                  const SizedBox(
                    width: 220,
                    child: AdminStatCard(
                      label: 'Revenue (Est.)',
                      value: '—',
                      icon: Icons.currency_rupee_rounded,
                      color: AppColors.success,
                      subtitle: 'Connect payment gateway',
                    ),
                  ),
                  const SizedBox(
                    width: 220,
                    child: AdminStatCard(
                      label: 'Pending Refunds',
                      value: '0',
                      icon: Icons.replay_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Integration notice ─────────────────────────
            AdminTableCard(
              title: 'Payment Gateway',
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.warning
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                            Icons.payments_rounded,
                            size: 36,
                            color: AppColors.warning),
                      ),
                      const SizedBox(height: 20),
                      Text('Payment Gateway Not Connected',
                          style: AppTextStyles.headlineMedium),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 420,
                        child: Text(
                          'Integrate Razorpay, Stripe, or PayU to start collecting payments. '
                          'Once connected, transaction history, invoices, and refund management will appear here.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary),
                            icon: const Icon(Icons.link_rounded,
                                size: 18),
                            label:
                                const Text('Connect Razorpay'),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18),
                            label: const Text('View Docs'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Recent transactions placeholder ────────────
            AdminTableCard(
              title: 'Recent Transactions',
              headerActions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: () {},
                ),
              ],
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    AppColors.surfaceVariant),
                columns: const [
                  DataColumn(label: Text('Order ID')),
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Course / Batch')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Date')),
                ],
                rows: const [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
