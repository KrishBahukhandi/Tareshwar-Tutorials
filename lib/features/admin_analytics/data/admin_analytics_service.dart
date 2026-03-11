// ─────────────────────────────────────────────────────────────
//  admin_analytics_service.dart
//  Supabase data layer for the Admin Analytics Dashboard.
//
//  Provides:
//    • fetchDashboardStats()   – totals: students, teachers, courses, revenue, completion
//    • fetchMonthlyRevenue()   – last 12 months of revenue (completed payments)
//    • fetchStudentGrowth()    – monthly new-student registrations (last 12 months)
//    • fetchCourseCompletionRate() – platform-wide completion %
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────
//  Service provider
// ─────────────────────────────────────────────────────────────
final adminAnalyticsServiceProvider =
    Provider<AdminAnalyticsService>((ref) {
  return AdminAnalyticsService(ref.watch(supabaseClientProvider));
});

// ─────────────────────────────────────────────────────────────
//  Value objects (DTOs)
// ─────────────────────────────────────────────────────────────

/// One aggregated data point per calendar month.
class MonthlyDataPoint {
  final int    year;
  final int    month;      // 1 – 12
  final String label;      // e.g. 'Jan', 'Feb'
  final double value;

  const MonthlyDataPoint({
    required this.year,
    required this.month,
    required this.label,
    required this.value,
  });
}

/// Top-level platform KPIs shown in stat-cards.
class AnalyticsDashboardStats {
  final int    totalStudents;
  final int    totalTeachers;
  final int    activeCourses;      // is_published = true
  final double totalRevenue;       // completed payments sum
  final double monthRevenue;       // this month completed payments
  final double courseCompletionRate; // % of enrollments with progress ≥ 100
  final int    totalEnrollments;
  final int    completedEnrollments;

  const AnalyticsDashboardStats({
    required this.totalStudents,
    required this.totalTeachers,
    required this.activeCourses,
    required this.totalRevenue,
    required this.monthRevenue,
    required this.courseCompletionRate,
    required this.totalEnrollments,
    required this.completedEnrollments,
  });
}

// ─────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────
class AdminAnalyticsService {
  AdminAnalyticsService(this._db);
  final SupabaseClient _db;

  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // ── Dashboard KPIs ────────────────────────────────────────

  Future<AnalyticsDashboardStats> fetchDashboardStats() async {
    final now  = DateTime.now();
    final m1st = DateTime(now.year, now.month, 1);

    final results = await Future.wait([
      _db.from('users').select('role'),
      _db.from('courses').select('is_published'),
      _db.from('payments').select('amount, payment_status, created_at'),
      _db.from('enrollments').select('progress_percent'),
    ]);

    // ── users ────────────────────────────────────────────────
    final users = results[0] as List;
    int students = 0, teachers = 0;
    for (final u in users) {
      final r = (u as Map)['role'] as String? ?? '';
      if (r == 'student') students++;
      if (r == 'teacher') teachers++;
    }

    // ── courses ──────────────────────────────────────────────
    final courses = results[1] as List;
    int activeCourses = 0;
    for (final c in courses) {
      if ((c as Map)['is_published'] == true) activeCourses++;
    }

    // ── payments ─────────────────────────────────────────────
    final payments = results[2] as List;
    double totalRevenue = 0, monthRevenue = 0;
    for (final p in payments) {
      final m   = p as Map;
      final st  = m['payment_status'] as String? ?? '';
      if (st != 'completed') continue;
      final amt  = (m['amount'] as num).toDouble();
      final date = DateTime.parse(m['created_at'] as String);
      totalRevenue += amt;
      if (!date.isBefore(m1st)) monthRevenue += amt;
    }

    // ── enrollments / completion ──────────────────────────────
    final enrollments = results[3] as List;
    final total     = enrollments.length;
    int completed   = 0;
    for (final e in enrollments) {
      final pct = ((e as Map)['progress_percent'] as num?)?.toDouble() ?? 0;
      if (pct >= 100) completed++;
    }
    final completionRate =
        total == 0 ? 0.0 : (completed / total) * 100;

    return AnalyticsDashboardStats(
      totalStudents:        students,
      totalTeachers:        teachers,
      activeCourses:        activeCourses,
      totalRevenue:         totalRevenue,
      monthRevenue:         monthRevenue,
      courseCompletionRate: completionRate,
      totalEnrollments:     total,
      completedEnrollments: completed,
    );
  }

  // ── Monthly revenue (last 12 months) ──────────────────────

  Future<List<MonthlyDataPoint>> fetchMonthlyRevenue() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final rows   = await _db
        .from('payments')
        .select('amount, created_at')
        .eq('payment_status', 'completed')
        .gte('created_at', cutoff.toIso8601String())
        .order('created_at');

    return _aggregateByMonth(rows as List, (m) {
      return (m['amount'] as num).toDouble();
    });
  }

  // ── Monthly new-student registrations (last 12 months) ────

  Future<List<MonthlyDataPoint>> fetchStudentGrowth() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final rows   = await _db
        .from('users')
        .select('created_at')
        .eq('role', 'student')
        .gte('created_at', cutoff.toIso8601String())
        .order('created_at');

    return _aggregateByMonth(rows as List, (_) => 1.0);
  }

  // ── Course completion rate per course (top N) ─────────────

  Future<double> fetchCourseCompletionRate() async {
    final rows = await _db
        .from('enrollments')
        .select('progress_percent');

    final list = rows as List;
    if (list.isEmpty) return 0.0;

    int completed = 0;
    for (final e in list) {
      final pct = ((e as Map)['progress_percent'] as num?)?.toDouble() ?? 0;
      if (pct >= 100) completed++;
    }
    return (completed / list.length) * 100;
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Groups [rows] by year-month and sums [valueFn] per group.
  /// Returns a chronologically-sorted list covering every month
  /// in the range (filling zeros for months with no data).
  List<MonthlyDataPoint> _aggregateByMonth(
    List rows,
    double Function(Map<String, dynamic>) valueFn,
  ) {
    final Map<String, double> agg = {};
    for (final r in rows) {
      final m    = Map<String, dynamic>.from(r as Map);
      final date = DateTime.parse(m['created_at'] as String);
      final key  = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      agg[key]   = (agg[key] ?? 0) + valueFn(m);
    }

    // Build sorted list for the last 12 months
    final now    = DateTime.now();
    final result = <MonthlyDataPoint>[];
    for (int i = 11; i >= 0; i--) {
      final d   = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      result.add(MonthlyDataPoint(
        year:  d.year,
        month: d.month,
        label: _monthNames[d.month],
        value: agg[key] ?? 0.0,
      ));
    }
    return result;
  }
}
