// ─────────────────────────────────────────────────────────────
//  admin_payments_service.dart
//  Supabase data layer for the Admin Payment Management module.
//
//  Table schema assumed:
//    payments(id, student_id, course_id, amount,
//             payment_status, payment_method, transaction_id,
//             notes, created_at, updated_at)
//
//  payment_status values: 'completed' | 'pending' | 'failed' | 'refunded'
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────
//  Service provider
// ─────────────────────────────────────────────────────────────
final adminPaymentsServiceProvider = Provider<AdminPaymentsService>((ref) {
  return AdminPaymentsService(ref.watch(supabaseClientProvider));
});

// ─────────────────────────────────────────────────────────────
//  Value objects
// ─────────────────────────────────────────────────────────────

enum PaymentStatus {
  completed,
  pending,
  failed,
  refunded;

  static PaymentStatus fromString(String s) {
    switch (s) {
      case 'pending':   return PaymentStatus.pending;
      case 'failed':    return PaymentStatus.failed;
      case 'refunded':  return PaymentStatus.refunded;
      default:          return PaymentStatus.completed;
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.completed: return 'Completed';
      case PaymentStatus.pending:   return 'Pending';
      case PaymentStatus.failed:    return 'Failed';
      case PaymentStatus.refunded:  return 'Refunded';
    }
  }

  String get value {
    switch (this) {
      case PaymentStatus.completed: return 'completed';
      case PaymentStatus.pending:   return 'pending';
      case PaymentStatus.failed:    return 'failed';
      case PaymentStatus.refunded:  return 'refunded';
    }
  }
}

// ── Payment row DTO ───────────────────────────────────────────
class PaymentRow {
  final String          id;
  final String          studentId;
  final String          studentName;
  final String          studentEmail;
  final String          courseId;
  final String          courseTitle;
  final double          amount;
  final PaymentStatus   status;
  final String?         paymentMethod;
  final String?         transactionId;
  final String?         notes;
  final DateTime        createdAt;

  const PaymentRow({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.courseId,
    required this.courseTitle,
    required this.amount,
    required this.status,
    this.paymentMethod,
    this.transactionId,
    this.notes,
    required this.createdAt,
  });

  factory PaymentRow.fromJson(Map<String, dynamic> m) {
    final userMap   = m['users']   as Map?;
    final courseMap = m['courses'] as Map?;
    return PaymentRow(
      id:              m['id'] as String,
      studentId:       m['student_id'] as String,
      studentName:     (m['student_name'] ?? userMap?['name'])   as String? ?? '—',
      studentEmail:    (m['student_email'] ?? userMap?['email']) as String? ?? '—',
      courseId:        m['course_id'] as String,
      courseTitle:     (m['course_title'] ?? courseMap?['title']) as String? ?? '—',
      amount:          (m['amount'] as num).toDouble(),
      status:          PaymentStatus.fromString(m['payment_status'] as String? ?? 'completed'),
      paymentMethod:   m['payment_method'] as String?,
      transactionId:   m['transaction_id'] as String?,
      notes:           m['notes'] as String?,
      createdAt:       DateTime.parse(m['created_at'] as String),
    );
  }
}

// ── Refund request DTO ────────────────────────────────────────
class RefundRequestRow {
  final String    id;
  final String    paymentId;
  final String    studentId;
  final String    studentName;
  final String    courseTitle;
  final double    amount;
  final String    reason;
  final String    status;   // 'pending' | 'approved' | 'rejected'
  final DateTime  createdAt;

  const RefundRequestRow({
    required this.id,
    required this.paymentId,
    required this.studentId,
    required this.studentName,
    required this.courseTitle,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory RefundRequestRow.fromJson(Map<String, dynamic> m) {
    final paymentMap = m['payments'] as Map?;
    final userMap    = m['users']    as Map?;
    final courseMap  = paymentMap?['courses'] as Map?;
    return RefundRequestRow(
      id:          m['id'] as String,
      paymentId:   m['payment_id'] as String,
      studentId:   m['student_id'] as String,
      studentName: (m['student_name'] ?? userMap?['name']) as String? ?? '—',
      courseTitle: (m['course_title'] ?? courseMap?['title']) as String? ?? '—',
      amount:      (m['amount'] ?? paymentMap?['amount'] as num? ?? 0).toDouble(),
      reason:      m['reason'] as String? ?? '',
      status:      m['status'] as String? ?? 'pending',
      createdAt:   DateTime.parse(m['created_at'] as String),
    );
  }
}

// ── Revenue summary ───────────────────────────────────────────
class PaymentSummary {
  final double totalRevenue;
  final double monthRevenue;
  final int    totalTransactions;
  final int    pendingCount;
  final int    refundedCount;
  final int    failedCount;

  const PaymentSummary({
    required this.totalRevenue,
    required this.monthRevenue,
    required this.totalTransactions,
    required this.pendingCount,
    required this.refundedCount,
    required this.failedCount,
  });
}

// ── Monthly revenue data point ────────────────────────────────
class MonthlyRevenue {
  final String month;   // 'Jan', 'Feb' …
  final int    year;
  final double amount;

  const MonthlyRevenue({
    required this.month,
    required this.year,
    required this.amount,
  });
}

// ── Course revenue breakdown ──────────────────────────────────
class CourseRevenue {
  final String courseId;
  final String courseTitle;
  final int    salesCount;
  final double totalRevenue;

  const CourseRevenue({
    required this.courseId,
    required this.courseTitle,
    required this.salesCount,
    required this.totalRevenue,
  });
}

// ─────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────
class AdminPaymentsService {
  AdminPaymentsService(this._db);
  final SupabaseClient _db;

  // ── Payments list ──────────────────────────────────────────

  Future<List<PaymentRow>> fetchPayments({
    PaymentStatus?  status,
    String?         courseId,
    String?         search,
    DateTime?       from,
    DateTime?       to,
    String          sortBy    = 'created_at',
    bool            ascending = false,
    int             limit     = 50,
    int             offset    = 0,
  }) async {
    // Filters must be applied on PostgrestFilterBuilder (before order/range).
    var fb = _db
        .from('payments')
        .select('*, users!student_id(name, email), courses!course_id(title)');

    if (status != null)   fb = fb.eq('payment_status', status.value);
    if (courseId != null) fb = fb.eq('course_id', courseId);
    if (from != null)     fb = fb.gte('created_at', from.toIso8601String());
    if (to != null)       fb = fb.lte('created_at', to.toIso8601String());

    final rows = await fb
        .order(sortBy, ascending: ascending)
        .range(offset, offset + limit - 1) as List;
    var result = rows
        .map((r) => PaymentRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    // Client-side search (name / email / transaction ID)
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where((p) =>
              p.studentName.toLowerCase().contains(q)  ||
              p.studentEmail.toLowerCase().contains(q) ||
              p.courseTitle.toLowerCase().contains(q)  ||
              (p.transactionId?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return result;
  }

  // ── Single payment ─────────────────────────────────────────

  Future<PaymentRow> fetchPayment(String id) async {
    final row = await _db
        .from('payments')
        .select('*, users!student_id(name, email), courses!course_id(title)')
        .eq('id', id)
        .single();
    return PaymentRow.fromJson(Map<String, dynamic>.from(row));
  }

  // ── Update payment status ──────────────────────────────────

  Future<void> updatePaymentStatus(String id, PaymentStatus status) async {
    await _db
        .from('payments')
        .update({'payment_status': status.value})
        .eq('id', id);
  }

  // ── Summary stats ──────────────────────────────────────────

  Future<PaymentSummary> fetchSummary() async {
    final now  = DateTime.now();
    final m1st = DateTime(now.year, now.month, 1);

    final rows = await _db
        .from('payments')
        .select('amount, payment_status, created_at');

    double totalRevenue  = 0;
    double monthRevenue  = 0;
    int    total         = 0;
    int    pending       = 0;
    int    refunded      = 0;
    int    failed        = 0;

    for (final r in rows as List) {
      final m    = Map<String, dynamic>.from(r as Map);
      final amt  = (m['amount'] as num).toDouble();
      final st   = m['payment_status'] as String? ?? 'completed';
      final date = DateTime.parse(m['created_at'] as String);

      total++;
      switch (st) {
        case 'pending':  pending++;
        case 'failed':   failed++;
        case 'refunded': refunded++;
        default:
          totalRevenue += amt;
          if (!date.isBefore(m1st)) monthRevenue += amt;
      }
    }

    return PaymentSummary(
      totalRevenue:       totalRevenue,
      monthRevenue:       monthRevenue,
      totalTransactions:  total,
      pendingCount:       pending,
      refundedCount:      refunded,
      failedCount:        failed,
    );
  }

  // ── Monthly revenue (last 12 months) ──────────────────────

  Future<List<MonthlyRevenue>> fetchMonthlyRevenue() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final rows   = await _db
        .from('payments')
        .select('amount, created_at')
        .eq('payment_status', 'completed')
        .gte('created_at', cutoff.toIso8601String())
        .order('created_at');

    // Aggregate by year-month
    final Map<String, double> agg = {};
    for (final r in rows as List) {
      final m    = Map<String, dynamic>.from(r as Map);
      final date = DateTime.parse(m['created_at'] as String);
      final key  = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      agg[key]   = (agg[key] ?? 0) + (m['amount'] as num).toDouble();
    }

    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return agg.entries.map((e) {
      final parts = e.key.split('-');
      final year  = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return MonthlyRevenue(
        month:  monthNames[month],
        year:   year,
        amount: e.value,
      );
    }).toList()
      ..sort((a, b) => '${a.year}${a.month}'.compareTo('${b.year}${b.month}'));
  }

  // ── Course revenue breakdown ───────────────────────────────

  Future<List<CourseRevenue>> fetchCourseRevenue() async {
    final rows = await _db
        .from('payments')
        .select('course_id, amount, courses!course_id(title)')
        .eq('payment_status', 'completed');

    final Map<String, _CourseAgg> agg = {};
    for (final r in rows as List) {
      final m    = Map<String, dynamic>.from(r as Map);
      final cid  = m['course_id'] as String;
      final amt  = (m['amount'] as num).toDouble();
      final title = (m['courses'] as Map?)?['title'] as String? ?? '—';

      if (!agg.containsKey(cid)) {
        agg[cid] = _CourseAgg(title: title);
      }
      agg[cid]!.total += amt;
      agg[cid]!.count++;
    }

    final result = agg.entries
        .map((e) => CourseRevenue(
              courseId:     e.key,
              courseTitle:  e.value.title,
              salesCount:   e.value.count,
              totalRevenue: e.value.total,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return result;
  }

  // ── Refund requests ────────────────────────────────────────

  Future<List<RefundRequestRow>> fetchRefundRequests({
    String? status,   // 'pending' | 'approved' | 'rejected' | null = all
  }) async {
    var fb = _db
        .from('refund_requests')
        .select(
            '*, users!student_id(name), '
            'payments!payment_id(amount, courses!course_id(title))');

    if (status != null) fb = fb.eq('status', status);

    final rows = await fb.order('created_at', ascending: false) as List;
    return rows
        .map((r) => RefundRequestRow.fromJson(
            Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> updateRefundStatus(
      String refundId, String status) async {
    await _db
        .from('refund_requests')
        .update({'status': status})
        .eq('id', refundId);

    // If approved → also mark the payment as refunded
    if (status == 'approved') {
      final row = await _db
          .from('refund_requests')
          .select('payment_id')
          .eq('id', refundId)
          .single();
      final paymentId = (row as Map)['payment_id'] as String;
      await updatePaymentStatus(paymentId, PaymentStatus.refunded);
    }
  }

  // ── CSV export helper ──────────────────────────────────────
  /// Returns CSV string for the given payments list.
  static String toCsv(List<PaymentRow> payments) {
    final header =
        'ID,Student,Email,Course,Amount,Status,Method,Transaction ID,Date';
    final lines = payments.map((p) {
      return [
        p.id,
        '"${p.studentName}"',
        p.studentEmail,
        '"${p.courseTitle}"',
        p.amount.toStringAsFixed(2),
        p.status.label,
        p.paymentMethod ?? '',
        p.transactionId ?? '',
        p.createdAt.toLocal().toString().substring(0, 10),
      ].join(',');
    });
    return [header, ...lines].join('\n');
  }
}

// internal aggregator
class _CourseAgg {
  final String title;
  double total = 0;
  int    count = 0;
  _CourseAgg({required this.title});
}
