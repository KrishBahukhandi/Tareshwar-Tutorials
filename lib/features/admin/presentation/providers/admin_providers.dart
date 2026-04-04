// ─────────────────────────────────────────────────────────────
//  admin_providers.dart  –  Riverpod providers for Admin Panel
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/models.dart';
import '../../../../shared/services/admin_service.dart';

// ── Section enum ──────────────────────────────────────────────
enum AdminSection {
  dashboard,
  students,
  teachers,
  courses,
  liveClasses,
  payments,
  announcements,
  analytics,
  settings,
}

extension AdminSectionExt on AdminSection {
  String get label {
    switch (this) {
      case AdminSection.dashboard:      return 'Dashboard';
      case AdminSection.students:       return 'Students';
      case AdminSection.teachers:       return 'Teachers';
      case AdminSection.courses:        return 'Courses';
      case AdminSection.liveClasses:    return 'Live Classes';
      case AdminSection.payments:       return 'Payments';
      case AdminSection.announcements:  return 'Announcements';
      case AdminSection.analytics:      return 'Analytics';
      case AdminSection.settings:       return 'Settings';
    }
  }
}

// ── UI state ──────────────────────────────────────────────────
final adminSelectedSectionProvider =
    StateProvider<AdminSection>((ref) => AdminSection.dashboard);

final adminSidebarCollapsedProvider =
    StateProvider<bool>((ref) => false);

// ── Data providers ────────────────────────────────────────────

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
    (ref) => ref.watch(adminServiceProvider).fetchStats());

final adminAllUsersProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) =>
        ref.watch(adminServiceProvider).fetchUsers(limit: 200));

final adminStudentsProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) =>
        ref.watch(adminServiceProvider).fetchUsers(role: 'student', limit: 200));

final adminTeachersProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) =>
        ref.watch(adminServiceProvider).fetchUsers(role: 'teacher', limit: 200));

final adminCoursesProvider =
    FutureProvider.autoDispose<List<AdminCourseRow>>((ref) =>
        ref.watch(adminServiceProvider).fetchAllCourses());

final adminDoubtsProvider =
    FutureProvider.autoDispose<List<AdminDoubtRow>>((ref) =>
        ref.watch(adminServiceProvider).fetchDoubts(limit: 200));

final adminAnnouncementsProvider =
    FutureProvider.autoDispose<List<AnnouncementModel>>((ref) =>
        ref.watch(adminServiceProvider).fetchAnnouncements(limit: 100));

// ── Search / filter state ─────────────────────────────────────
final adminStudentSearchProvider = StateProvider<String>((ref) => '');
final adminTeacherSearchProvider = StateProvider<String>((ref) => '');
final adminCourseSearchProvider  = StateProvider<String>((ref) => '');
