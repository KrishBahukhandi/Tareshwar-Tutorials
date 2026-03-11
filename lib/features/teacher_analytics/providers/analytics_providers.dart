// ─────────────────────────────────────────────────────────────
//  analytics_providers.dart
//  Riverpod providers for the Teacher Analytics module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/auth_service.dart';
import '../../../shared/services/course_service.dart';
import '../data/analytics_repository.dart';
import '../models/analytics_models.dart';

// ─────────────────────────────────────────────────────────────
//  Teacher's course IDs (base dependency)
// ─────────────────────────────────────────────────────────────
final teacherCourseIdsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final uid = ref.watch(authServiceProvider).currentAuthUser?.id;
  if (uid == null) return [];
  final courses =
      await ref.read(courseServiceProvider).fetchTeacherCourses(uid);
  return courses.map((c) => c.id).toList();
});

// ─────────────────────────────────────────────────────────────
//  Overall summary
// ─────────────────────────────────────────────────────────────
final analyticsSummaryProvider =
    FutureProvider.autoDispose<TeacherAnalyticsSummary>((ref) async {
  final ids = await ref.watch(teacherCourseIdsProvider.future);
  return ref.read(analyticsRepositoryProvider).fetchSummary(ids);
});

// ─────────────────────────────────────────────────────────────
//  Enrollment trend (last 6 months)
// ─────────────────────────────────────────────────────────────
final enrollmentTrendProvider =
    FutureProvider.autoDispose<List<EnrollmentPoint>>((ref) async {
  final ids = await ref.watch(teacherCourseIdsProvider.future);
  return ref
      .read(analyticsRepositoryProvider)
      .fetchEnrollmentTrend(ids);
});

// ─────────────────────────────────────────────────────────────
//  Student leaderboard
// ─────────────────────────────────────────────────────────────
final studentLeaderboardProvider =
    FutureProvider.autoDispose<List<StudentRankEntry>>((ref) async {
  final ids = await ref.watch(teacherCourseIdsProvider.future);
  return ref
      .read(analyticsRepositoryProvider)
      .fetchStudentLeaderboard(ids);
});

// ─────────────────────────────────────────────────────────────
//  Per-course analytics
// ─────────────────────────────────────────────────────────────
final courseAnalyticsProvider = FutureProvider.autoDispose
    .family<CourseAnalyticsData, _CourseArg>((ref, arg) async {
  return ref
      .read(analyticsRepositoryProvider)
      .fetchCourseAnalytics(arg.courseId, arg.courseTitle);
});

/// Argument wrapper for courseAnalyticsProvider.
class _CourseArg {
  final String courseId;
  final String courseTitle;
  const _CourseArg(this.courseId, this.courseTitle);

  @override
  bool operator ==(Object other) =>
      other is _CourseArg && other.courseId == courseId;

  @override
  int get hashCode => courseId.hashCode;
}

// Helper to create the arg from outside the module
CourseAnalyticsArg courseAnalyticsArg(
        String courseId, String courseTitle) =>
    CourseAnalyticsArg(courseId, courseTitle);

class CourseAnalyticsArg extends _CourseArg {
  const CourseAnalyticsArg(super.courseId, super.courseTitle);
}

// ─────────────────────────────────────────────────────────────
//  Per-student analytics
// ─────────────────────────────────────────────────────────────
final studentAnalyticsProvider = FutureProvider.autoDispose
    .family<StudentAnalyticsData, _StudentArg>((ref, arg) async {
  final ids = await ref.watch(teacherCourseIdsProvider.future);
  return ref.read(analyticsRepositoryProvider).fetchStudentAnalytics(
        arg.studentId,
        arg.studentName,
        ids,
      );
});

/// Argument wrapper for studentAnalyticsProvider.
class _StudentArg {
  final String studentId;
  final String studentName;
  const _StudentArg(this.studentId, this.studentName);

  @override
  bool operator ==(Object other) =>
      other is _StudentArg && other.studentId == studentId;

  @override
  int get hashCode => studentId.hashCode;
}

// Helper to create the arg from outside the module
StudentAnalyticsArg studentAnalyticsArg(
        String studentId, String studentName) =>
    StudentAnalyticsArg(studentId, studentName);

class StudentAnalyticsArg extends _StudentArg {
  const StudentAnalyticsArg(super.studentId, super.studentName);
}
