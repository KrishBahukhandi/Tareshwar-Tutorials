// ─────────────────────────────────────────────────────────────
//  transactions_screen.dart
//  Admin: Full paginated transaction list with filter/search,
//  inline status change, CSV export, and refund management tab.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../data/admin_payments_service.dart';
import '../providers/admin_payments_providers.dart';
import '../widgets/admin_payments_widgets.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  /// Pass 'refunds' to open directly on the Refunds tab.
  final String? initialTab;

  const TransactionsScreen({super.key, this.initialTab});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState
    extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'refunds' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── CSV export ─────────────────────────────────────────────
  void _exportCsv(List<PaymentRow> payments) {
    final csv = AdminPaymentsService.toCsv(payments);
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Transactions',
            style: AppTextStyles.headlineMedium),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'All Transactions'),
            Tab(text: 'Refund Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _TransactionsTab(
            searchCtrl: _searchCtrl,
            onExportCsv: _exportCsv,
          ),
          const _RefundsTab(),
        ],
      ),
    );
  }
}

// ── Transactions Tab ──────────────────────────────────────────
class _TransactionsTab extends ConsumerStatefulWidget {
  const _TransactionsTab({
    required this.searchCtrl,
    required this.onExportCsv,
  });

  final TextEditingController        searchCtrl;
  final ValueChanged<List<PaymentRow>> onExportCsv;

  @override
  ConsumerState<_TransactionsTab> createState() =>
      _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<_TransactionsTab> {
  @override
  Widget build(BuildContext context) {
    final filter       = ref.watch(paymentFilterProvider);
    final paymentsAsync = ref.watch(paymentsListProvider);

    return Column(
      children: [
        // ── Filter bar ──────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search
              SizedBox(
                width: 240,
                height: 36,
                child: TextField(
                  controller: widget.searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search student / course…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => ref
                      .read(paymentFilterProvider.notifier)
                      .state = filter.copyWith(search: v.trim()),
                ),
              ),
              // Status filter
              _StatusFilterChips(filter: filter),
              // Date range
              DateRangeRow(
                from: filter.from,
                to:   filter.to,
                onFromPicked: (d) => ref
                    .read(paymentFilterProvider.notifier)
                    .state = filter.copyWith(from: d),
                onToPicked: (d) => ref
                    .read(paymentFilterProvider.notifier)
                    .state = filter.copyWith(to: d),
                onClear: () => ref
                    .read(paymentFilterProvider.notifier)
                    .state = filter.copyWith(
                        clearFrom: true, clearTo: true),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // ── Column headers ──────────────────────────────────
        Container(
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                  flex: 3,
                  child: Text('Student',
                      style: AppTextStyles.labelMedium)),
              Expanded(
                  flex: 3,
                  child: Text('Course',
                      style: AppTextStyles.labelMedium)),
              SizedBox(
                  width: 90,
                  child: Text('Amount',
                      style: AppTextStyles.labelMedium,
                      textAlign: TextAlign.right)),
              const SizedBox(width: 16),
              SizedBox(
                  width: 96,
                  child: Text('Status',
                      style: AppTextStyles.labelMedium)),
              const SizedBox(width: 16),
              SizedBox(
                  width: 90,
                  child: Text('Date',
                      style: AppTextStyles.labelMedium,
                      textAlign: TextAlign.right)),
              // Sort + export
              const Spacer(),
              paymentsAsync.when(
                data: (payments) => Row(
                  children: [
                    Text('${payments.length} records',
                        style: AppTextStyles.caption),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      iconAlignment: IconAlignment.start,
                      icon: const Icon(Icons.download_rounded,
                          size: 14),
                      label: const Text('CSV',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () =>
                          widget.onExportCsv(payments),
                    ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // ── List ────────────────────────────────────────────
        Expanded(
          child: paymentsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 8),
                  Text('Failed to load transactions',
                      style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 4),
                  Text(e.toString(),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(paymentsListProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (payments) {
              if (payments.isEmpty) {
                return const PaymentEmptyState(
                  message: 'No transactions found',
                  subtitle:
                      'Try adjusting the filters or date range.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(paymentsListProvider),
                child: ListView.separated(
                  itemCount: payments.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, i) {
                    final p = payments[i];
                    return PaymentListTile(
                      payment: p,
                      onTap: () =>
                          _showPaymentDetail(context, p),
                      onStatusChange: (s) =>
                          _changeStatus(context, p.id, s),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Status change ─────────────────────────────────────────
  Future<void> _changeStatus(
      BuildContext context, String id, PaymentStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(updatePaymentProvider.notifier)
        .updateStatus(id, status);
    if (mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text('Status updated to ${status.label}'),
      ));
    }
  }

  // ── Payment detail bottom sheet ───────────────────────────
  void _showPaymentDetail(BuildContext context, PaymentRow p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PaymentDetailSheet(payment: p),
    );
  }
}

// ── Status filter chips ───────────────────────────────────────
class _StatusFilterChips extends ConsumerWidget {
  const _StatusFilterChips({required this.filter});

  final PaymentFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 6,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: filter.status == null,
          onSelected: (_) => ref
              .read(paymentFilterProvider.notifier)
              .state = filter.copyWith(clearStatus: true),
        ),
        ...PaymentStatus.values.map((s) => FilterChip(
              label: Text(s.label),
              selected: filter.status == s,
              onSelected: (_) => ref
                  .read(paymentFilterProvider.notifier)
                  .state = filter.copyWith(status: s),
            )),
      ],
    );
  }
}

// ── Payment detail sheet ──────────────────────────────────────
class _PaymentDetailSheet extends StatelessWidget {
  const _PaymentDetailSheet({required this.payment});

  final PaymentRow payment;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(24),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transaction Details',
                  style: AppTextStyles.headlineMedium,
                ),
              ),
              PaymentStatusBadge(status: payment.status),
            ],
          ),
          const SizedBox(height: 20),
          _DetailRow('Transaction ID', payment.transactionId ?? payment.id),
          _DetailRow('Student',        payment.studentName),
          _DetailRow('Email',          payment.studentEmail),
          _DetailRow('Course',         payment.courseTitle),
          _DetailRow('Amount',         fmtInr(payment.amount)),
          _DetailRow('Payment Method', payment.paymentMethod ?? '—'),
          _DetailRow('Date',
              DateFormat('dd MMMM yyyy, hh:mm a')
                  .format(payment.createdAt.toLocal())),
          if (payment.notes != null && payment.notes!.isNotEmpty)
            _DetailRow('Notes', payment.notes!),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: AppTextStyles.labelMedium),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Refunds Tab ───────────────────────────────────────────────
class _RefundsTab extends ConsumerWidget {
  const _RefundsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter  = ref.watch(refundFilterProvider);
    final refundsAsync  = ref.watch(refundRequestsProvider);

    return Column(
      children: [
        // Filter chips
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: statusFilter == null,
                onSelected: (_) => ref
                    .read(refundFilterProvider.notifier)
                    .state = null,
              ),
              for (final s in ['pending', 'approved', 'rejected'])
                FilterChip(
                  label: Text(
                      '${s[0].toUpperCase()}${s.substring(1)}'),
                  selected: statusFilter == s,
                  onSelected: (_) => ref
                      .read(refundFilterProvider.notifier)
                      .state = s,
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(
          child: refundsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Failed to load refunds: $e',
                  style: AppTextStyles.bodySmall),
            ),
            data: (refunds) {
              if (refunds.isEmpty) {
                return const PaymentEmptyState(
                  message: 'No refund requests',
                  subtitle: 'Refund requests will appear here.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(refundRequestsProvider),
                child: ListView.separated(
                  itemCount: refunds.length,
                  separatorBuilder: (_, _) => const Divider(
                      height: 1, color: AppColors.border),
                  itemBuilder: (ctx, i) =>
                      _RefundTile(refund: refunds[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Refund tile ───────────────────────────────────────────────
class _RefundTile extends ConsumerWidget {
  const _RefundTile({required this.refund});

  final RefundRequestRow refund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, label) = switch (refund.status) {
      'approved' => (AppColors.success, 'Approved'),
      'rejected' => (AppColors.error,   'Rejected'),
      _          => (AppColors.warning, 'Pending'),
    };

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(refund.studentName,
                    style: AppTextStyles.labelLarge),
                Text(refund.courseTitle,
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(refund.reason,
                style: AppTextStyles.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 90,
            child: Text(
              fmtInr(refund.amount),
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.error),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: color, fontSize: 11)),
          ),
          const SizedBox(width: 16),
          Text(
            DateFormat('dd MMM yy')
                .format(refund.createdAt.toLocal()),
            style: AppTextStyles.caption,
          ),
          if (refund.status == 'pending') ...[
            const SizedBox(width: 16),
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  onPressed: () =>
                      _update(ref, 'rejected', context),
                  child: const Text('Reject',
                      style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  onPressed: () =>
                      _update(ref, 'approved', context),
                  child: const Text('Approve',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _update(
      WidgetRef ref, String status, BuildContext context) async {
    await ref
        .read(updateRefundProvider.notifier)
        .updateStatus(refund.id, status);
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
