// ─────────────────────────────────────────────────────────────
//  admin_payments_providers.dart
//  Riverpod state layer for Admin Payment Management.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_payments_service.dart';

export '../data/admin_payments_service.dart'
    show
        PaymentRow,
        PaymentStatus,
        RefundRequestRow,
        PaymentSummary,
        MonthlyRevenue,
        CourseRevenue;

// ─────────────────────────────────────────────────────────────
//  Filter state
// ─────────────────────────────────────────────────────────────
class PaymentFilterState {
  const PaymentFilterState({
    this.status,
    this.courseId,
    this.search = '',
    this.from,
    this.to,
    this.sortBy    = 'created_at',
    this.ascending = false,
  });

  final PaymentStatus? status;
  final String?        courseId;
  final String         search;
  final DateTime?      from;
  final DateTime?      to;
  final String         sortBy;
  final bool           ascending;

  PaymentFilterState copyWith({
    PaymentStatus?  status,
    bool            clearStatus  = false,
    String?         courseId,
    bool            clearCourse  = false,
    String?         search,
    DateTime?       from,
    bool            clearFrom    = false,
    DateTime?       to,
    bool            clearTo      = false,
    String?         sortBy,
    bool?           ascending,
  }) =>
      PaymentFilterState(
        status:    clearStatus ? null  : status    ?? this.status,
        courseId:  clearCourse ? null  : courseId  ?? this.courseId,
        search:    search    ?? this.search,
        from:      clearFrom  ? null  : from       ?? this.from,
        to:        clearTo    ? null  : to         ?? this.to,
        sortBy:    sortBy    ?? this.sortBy,
        ascending: ascending ?? this.ascending,
      );
}

final paymentFilterProvider =
    StateProvider<PaymentFilterState>((ref) => const PaymentFilterState());

// ─────────────────────────────────────────────────────────────
//  Payments list
// ─────────────────────────────────────────────────────────────
final paymentsListProvider =
    FutureProvider.autoDispose<List<PaymentRow>>((ref) async {
  final svc    = ref.watch(adminPaymentsServiceProvider);
  final filter = ref.watch(paymentFilterProvider);

  return svc.fetchPayments(
    status:    filter.status,
    courseId:  filter.courseId,
    search:    filter.search.isEmpty ? null : filter.search,
    from:      filter.from,
    to:        filter.to,
    sortBy:    filter.sortBy,
    ascending: filter.ascending,
  );
});

// ─────────────────────────────────────────────────────────────
//  Payment summary / stats
// ─────────────────────────────────────────────────────────────
final paymentSummaryProvider =
    FutureProvider.autoDispose<PaymentSummary>((ref) {
  return ref.watch(adminPaymentsServiceProvider).fetchSummary();
});

// ─────────────────────────────────────────────────────────────
//  Monthly revenue chart data
// ─────────────────────────────────────────────────────────────
final monthlyRevenueProvider =
    FutureProvider.autoDispose<List<MonthlyRevenue>>((ref) {
  return ref.watch(adminPaymentsServiceProvider).fetchMonthlyRevenue();
});

// ─────────────────────────────────────────────────────────────
//  Course revenue breakdown
// ─────────────────────────────────────────────────────────────
final courseRevenueProvider =
    FutureProvider.autoDispose<List<CourseRevenue>>((ref) {
  return ref.watch(adminPaymentsServiceProvider).fetchCourseRevenue();
});

// ─────────────────────────────────────────────────────────────
//  Refund requests
// ─────────────────────────────────────────────────────────────
final refundFilterProvider = StateProvider<String?>((ref) => null); // null = all

final refundRequestsProvider =
    FutureProvider.autoDispose<List<RefundRequestRow>>((ref) {
  final svc    = ref.watch(adminPaymentsServiceProvider);
  final status = ref.watch(refundFilterProvider);
  return svc.fetchRefundRequests(status: status);
});

// ─────────────────────────────────────────────────────────────
//  Update payment status notifier
// ─────────────────────────────────────────────────────────────
class UpdatePaymentNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateStatus(String id, PaymentStatus status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(adminPaymentsServiceProvider)
          .updatePaymentStatus(id, status);
      ref.invalidate(paymentsListProvider);
      ref.invalidate(paymentSummaryProvider);
    });
  }
}

final updatePaymentProvider =
    AsyncNotifierProvider.autoDispose<UpdatePaymentNotifier, void>(
        UpdatePaymentNotifier.new);

// ─────────────────────────────────────────────────────────────
//  Update refund status notifier
// ─────────────────────────────────────────────────────────────
class UpdateRefundNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateStatus(String refundId, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(adminPaymentsServiceProvider)
          .updateRefundStatus(refundId, status);
      ref.invalidate(refundRequestsProvider);
      ref.invalidate(paymentsListProvider);
      ref.invalidate(paymentSummaryProvider);
    });
  }
}

final updateRefundProvider =
    AsyncNotifierProvider.autoDispose<UpdateRefundNotifier, void>(
        UpdateRefundNotifier.new);
