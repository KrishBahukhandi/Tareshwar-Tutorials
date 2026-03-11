// ─────────────────────────────────────────────────────────────
//  dashboard_provider.dart  –  All Riverpod providers for the
//  Student Dashboard feature.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/supabase_service.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/announcement_entity.dart';
import '../../domain/entities/enrolled_course_entity.dart';
import '../../domain/entities/recommended_course_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';

// ── Dependency providers ──────────────────────────────────────

final _dashboardDsProvider =
    Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSource(ref.watch(supabaseClientProvider));
});

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(_dashboardDsProvider));
});

// ── Enrolled courses ──────────────────────────────────────────

final enrolledCoursesProvider =
    FutureProvider.autoDispose.family<List<EnrolledCourseEntity>, String>(
  (ref, studentId) =>
      ref.watch(dashboardRepositoryProvider).fetchEnrolledCourses(studentId),
);

// ── Recommended courses ───────────────────────────────────────

final recommendedCoursesProvider =
    FutureProvider.autoDispose.family<List<RecommendedCourseEntity>, String>(
  (ref, studentId) =>
      ref.watch(dashboardRepositoryProvider).fetchRecommended(studentId),
);

// ── Announcements ─────────────────────────────────────────────

final announcementsProvider =
    FutureProvider.autoDispose.family<List<AnnouncementEntity>, String>(
  (ref, userId) =>
      ref.watch(dashboardRepositoryProvider).fetchAnnouncements(userId),
);

// ── Unread notification count (realtime stream) ───────────────

final dashboardUnreadCountProvider =
    StreamProvider.autoDispose.family<int, String>(
  (ref, userId) =>
      ref.watch(dashboardRepositoryProvider).unreadCountStream(userId),
);
