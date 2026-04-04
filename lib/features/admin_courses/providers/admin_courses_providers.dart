// ─────────────────────────────────────────────────────────────
//  admin_courses_providers.dart
//  Riverpod providers for admin course management.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_courses_service.dart';

// ── Search / filter state ─────────────────────────────────────
final adminCourseListSearchProvider = StateProvider<String>((ref) => '');
final adminCoursePublishedFilterProvider =
    StateProvider<bool?>((ref) => null); // null = all

// ── Course list ───────────────────────────────────────────────
final adminCourseListProvider =
    FutureProvider.autoDispose<List<AdminCourseListItem>>((ref) {
  final search  = ref.watch(adminCourseListSearchProvider);
  final filter  = ref.watch(adminCoursePublishedFilterProvider);
  return ref.watch(adminCoursesServiceProvider).fetchAllCourses(
        search: search,
        publishedFilter: filter,
      );
});

// ── Course detail (by courseId) ───────────────────────────────
final adminCourseDetailProvider =
    FutureProvider.autoDispose.family<AdminCourseDetail, String>(
  (ref, courseId) =>
      ref.watch(adminCoursesServiceProvider).fetchCourseDetail(courseId),
);

// ── Teacher options (for picker) ──────────────────────────────
final adminTeacherOptionsProvider =
    FutureProvider.autoDispose<List<AdminTeacherOption>>(
  (ref) => ref.watch(adminCoursesServiceProvider).fetchTeachers(),
);

// ── Course form notifier ──────────────────────────────────────
class AdminCourseFormState {
  final bool   isSubmitting;
  final String? error;
  final bool   success;

  const AdminCourseFormState({
    this.isSubmitting = false,
    this.error,
    this.success = false,
  });

  AdminCourseFormState copyWith({
    bool?   isSubmitting,
    String? error,
    bool?   success,
  }) =>
      AdminCourseFormState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error:        error,
        success:      success ?? this.success,
      );
}

class AdminCourseFormNotifier
    extends AutoDisposeNotifier<AdminCourseFormState> {
  @override
  AdminCourseFormState build() => const AdminCourseFormState();

  Future<void> create({
    required String teacherId,
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? classLevel,
    int maxStudents = 50,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subjectsOverview = const [],
    bool isPublished = false,
    bool isActive = true,
  }) async {
    state = state.copyWith(isSubmitting: true, success: false);
    try {
      await ref.read(adminCoursesServiceProvider).createCourse(
            teacherId:        teacherId,
            title:            title,
            description:      description,
            price:            price,
            thumbnailUrl:     thumbnailUrl,
            classLevel:       classLevel,
            maxStudents:      maxStudents,
            startDate:        startDate,
            endDate:          endDate,
            subjectsOverview: subjectsOverview,
            isPublished:      isPublished,
            isActive:         isActive,
          );
      ref.invalidate(adminCourseListProvider);
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> update({
    required String courseId,
    required String teacherId,
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? classLevel,
    int maxStudents = 50,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subjectsOverview = const [],
    required bool isPublished,
    required bool isActive,
  }) async {
    state = state.copyWith(isSubmitting: true, success: false);
    try {
      await ref.read(adminCoursesServiceProvider).updateCourse(
            courseId:         courseId,
            teacherId:        teacherId,
            title:            title,
            description:      description,
            price:            price,
            thumbnailUrl:     thumbnailUrl,
            classLevel:       classLevel,
            maxStudents:      maxStudents,
            startDate:        startDate,
            endDate:          endDate,
            subjectsOverview: subjectsOverview,
            isPublished:      isPublished,
            isActive:         isActive,
          );
      ref.invalidate(adminCourseListProvider);
      ref.invalidate(adminCourseDetailProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final adminCourseFormProvider = NotifierProvider.autoDispose<
    AdminCourseFormNotifier, AdminCourseFormState>(
  AdminCourseFormNotifier.new,
);
