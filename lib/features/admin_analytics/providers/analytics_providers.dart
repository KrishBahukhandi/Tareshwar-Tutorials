// ─────────────────────────────────────────────────────────────
//  analytics_providers.dart  –  Riverpod providers for the
//  analytics_events table.  Used by admin dashboards.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/analytics_service.dart';
export '../../../shared/services/analytics_service.dart'
    show
        AnalyticsService,
        AnalyticsEvent,
        AnalyticsEventModel,
        PlatformAnalyticsStats,
        DailyEventPoint,
        TopLecture,
        TopTest;

// ── Platform-wide aggregate KPIs ─────────────────────────────
final platformAnalyticsStatsProvider =
    FutureProvider.autoDispose<PlatformAnalyticsStats>((ref) {
  return ref.watch(analyticsServiceProvider).fetchPlatformStats();
});

// ── Daily activity points (last 30 days) ─────────────────────
final dailyActivityProvider =
    FutureProvider.autoDispose<List<DailyEventPoint>>((ref) {
  return ref
      .watch(analyticsServiceProvider)
      .fetchDailyActivity(days: 30);
});

// ── Top lectures by start count ───────────────────────────────
final topLecturesProvider =
    FutureProvider.autoDispose<List<TopLecture>>((ref) {
  return ref.watch(analyticsServiceProvider).fetchTopLectures();
});

// ── Top tests by attempt count ────────────────────────────────
final topTestsProvider =
    FutureProvider.autoDispose<List<TopTest>>((ref) {
  return ref.watch(analyticsServiceProvider).fetchTopTests();
});

// ── Recent activity feed ──────────────────────────────────────
final recentAnalyticsEventsProvider =
    FutureProvider.autoDispose<List<AnalyticsEventModel>>((ref) {
  return ref
      .watch(analyticsServiceProvider)
      .fetchRecentEvents(limit: 50);
});
