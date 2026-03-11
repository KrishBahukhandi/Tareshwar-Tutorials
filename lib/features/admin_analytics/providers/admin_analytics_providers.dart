// ─────────────────────────────────────────────────────────────
//  admin_analytics_providers.dart
//  Riverpod state layer for the Admin Analytics Dashboard.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_analytics_service.dart';

export '../data/admin_analytics_service.dart'
    show
        AnalyticsDashboardStats,
        MonthlyDataPoint,
        AdminAnalyticsService;

// ─────────────────────────────────────────────────────────────
//  Dashboard KPI stats
// ─────────────────────────────────────────────────────────────
final analyticsDashboardStatsProvider =
    FutureProvider.autoDispose<AnalyticsDashboardStats>((ref) {
  return ref
      .watch(adminAnalyticsServiceProvider)
      .fetchDashboardStats();
});

// ─────────────────────────────────────────────────────────────
//  Monthly revenue (last 12 months)
// ─────────────────────────────────────────────────────────────
final analyticsMonthlyRevenueProvider =
    FutureProvider.autoDispose<List<MonthlyDataPoint>>((ref) {
  return ref
      .watch(adminAnalyticsServiceProvider)
      .fetchMonthlyRevenue();
});

// ─────────────────────────────────────────────────────────────
//  Monthly student growth (last 12 months)
// ─────────────────────────────────────────────────────────────
final analyticsStudentGrowthProvider =
    FutureProvider.autoDispose<List<MonthlyDataPoint>>((ref) {
  return ref
      .watch(adminAnalyticsServiceProvider)
      .fetchStudentGrowth();
});
