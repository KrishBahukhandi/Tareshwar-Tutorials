// ─────────────────────────────────────────────────────────────
//  teacher_dashboard_providers.dart
//  Riverpod providers for the Teacher Dashboard module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/course_service.dart';
import '../../../shared/services/doubt_service.dart';

// ─────────────────────────────────────────────────────────────
//  Sidebar section enum
// ─────────────────────────────────────────────────────────────
enum TeacherSection {
  overview,
  myCourses,
  liveClasses,
  uploadContent,
  createTest,
  studentDoubts,
  analytics,
  settings,
}

extension TeacherSectionExt on TeacherSection {
  String get label {
    switch (this) {
      case TeacherSection.overview:       return 'Dashboard';
      case TeacherSection.myCourses:      return 'My Courses';
      case TeacherSection.liveClasses:    return 'Live Classes';
      case TeacherSection.uploadContent:  return 'Upload Content';
      case TeacherSection.createTest:     return 'Create Test';
      case TeacherSection.studentDoubts:  return 'Student Doubts';
      case TeacherSection.analytics:      return 'Analytics';
      case TeacherSection.settings:       return 'Settings';
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Active sidebar section
// ─────────────────────────────────────────────────────────────
final teacherSelectedSectionProvider =
    StateProvider<TeacherSection>((ref) => TeacherSection.overview);

// ─────────────────────────────────────────────────────────────
//  Stats model
// ─────────────────────────────────────────────────────────────
class TeacherDashboardStats {
  final int totalCourses;
  final int totalStudents;
  final int pendingDoubts;
  final int totalLectures;

  const TeacherDashboardStats({
    required this.totalCourses,
    required this.totalStudents,
    required this.pendingDoubts,
    required this.totalLectures,
  });
}

// ─────────────────────────────────────────────────────────────
//  Activity event model
// ─────────────────────────────────────────────────────────────
enum ActivityEventType { doubt, enrollment, upload, test }

class TeacherActivityEvent {
  final String title;
  final String subtitle;
  final DateTime time;
  final ActivityEventType type;

  const TeacherActivityEvent({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
  });
}

// ─────────────────────────────────────────────────────────────
//  Teacher's courses
// ─────────────────────────────────────────────────────────────
final teacherCoursesListProvider =
    FutureProvider.autoDispose<List<CourseModel>>((ref) async {
  final uid = ref.watch(authServiceProvider).currentAuthUser?.id;
  if (uid == null) return [];
  return ref.watch(courseServiceProvider).fetchTeacherCourses(uid);
});

// ─────────────────────────────────────────────────────────────
//  Pending doubts
// ─────────────────────────────────────────────────────────────
final teacherPendingDoubtsProvider =
    FutureProvider.autoDispose<List<DoubtModel>>((ref) async {
  final all = await ref.watch(doubtServiceProvider).fetchDoubts();
  return all.where((d) => !d.isAnswered).toList();
});

// ─────────────────────────────────────────────────────────────
//  All doubts (for doubts screen)
// ─────────────────────────────────────────────────────────────
final teacherAllDoubtsProvider =
    FutureProvider.autoDispose<List<DoubtModel>>((ref) async {
  return ref.watch(doubtServiceProvider).fetchDoubts();
});

// ─────────────────────────────────────────────────────────────
//  Aggregate stats
// ─────────────────────────────────────────────────────────────
final teacherDashboardStatsProvider =
    FutureProvider.autoDispose<TeacherDashboardStats>((ref) async {
  final courses =
      await ref.watch(teacherCoursesListProvider.future);
  final doubts =
      await ref.watch(teacherPendingDoubtsProvider.future);

  return TeacherDashboardStats(
    totalCourses: courses.length,
    totalStudents: courses.fold(
        0, (s, c) => s + (c.totalStudents ?? 0)),
    pendingDoubts: doubts.length,
    totalLectures: courses.fold(
        0, (s, c) => s + (c.totalLectures ?? 0)),
  );
});

// ─────────────────────────────────────────────────────────────
//  Recent activity (derived – no extra table needed)
// ─────────────────────────────────────────────────────────────
final teacherRecentActivityProvider =
    FutureProvider.autoDispose<List<TeacherActivityEvent>>((ref) async {
  final doubts  = await ref.watch(teacherAllDoubtsProvider.future);
  final courses = await ref.watch(teacherCoursesListProvider.future);

  final events = <TeacherActivityEvent>[];

  for (final d in doubts.take(5)) {
    events.add(TeacherActivityEvent(
      title: 'New doubt from ${d.studentName ?? "a student"}',
      subtitle: d.question.length > 60
          ? '${d.question.substring(0, 60)}…'
          : d.question,
      time: d.createdAt,
      type: ActivityEventType.doubt,
    ));
  }

  for (final c in courses.take(5)) {
    events.add(TeacherActivityEvent(
      title: 'Course: ${c.title}',
      subtitle: c.isPublished ? 'Published' : 'Draft',
      time: c.createdAt,
      type: ActivityEventType.upload,
    ));
  }

  events.sort((a, b) => b.time.compareTo(a.time));
  return events.take(10).toList();
});
