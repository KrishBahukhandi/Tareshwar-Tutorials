// ─────────────────────────────────────────────────────────────
//  teacher_course_providers.dart
//  All Riverpod state for Teacher Course Management module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/auth_service.dart';
import '../data/teacher_course_repository.dart';

// ═════════════════════════════════════════════════════════════
//  MY COURSES  (auto-refresh family)
// ═════════════════════════════════════════════════════════════

/// Watches the current teacher's course list. Invalidate to refresh.
final myCoursesProvider =
    FutureProvider.autoDispose<List<CourseModel>>((ref) async {
  final uid = ref.watch(authServiceProvider).currentAuthUser?.id;
  if (uid == null) return [];
  return ref.read(teacherCourseRepoProvider).fetchMyCourses(uid);
});

// ═════════════════════════════════════════════════════════════
//  COURSE OUTLINE  (subjects → chapters → lectures)
// ═════════════════════════════════════════════════════════════

final courseOutlineProvider = FutureProvider.autoDispose
    .family<List<SubjectModel>, String>((ref, courseId) async {
  return ref
      .read(teacherCourseRepoProvider)
      .fetchCourseOutline(courseId);
});

// ═════════════════════════════════════════════════════════════
//  SUBJECTS for a course
// ═════════════════════════════════════════════════════════════

final subjectsProvider = FutureProvider.autoDispose
    .family<List<SubjectModel>, String>((ref, courseId) async {
  return ref
      .read(teacherCourseRepoProvider)
      .fetchSubjects(courseId);
});

// ═════════════════════════════════════════════════════════════
//  CHAPTERS for a subject
// ═════════════════════════════════════════════════════════════

final chaptersProvider = FutureProvider.autoDispose
    .family<List<ChapterModel>, String>((ref, subjectId) async {
  return ref
      .read(teacherCourseRepoProvider)
      .fetchChapters(subjectId);
});

// ═════════════════════════════════════════════════════════════
//  LECTURES for a chapter
// ═════════════════════════════════════════════════════════════

final lecturesProvider = FutureProvider.autoDispose
    .family<List<LectureModel>, String>((ref, chapterId) async {
  return ref
      .read(teacherCourseRepoProvider)
      .fetchLectures(chapterId);
});

// ═════════════════════════════════════════════════════════════
//  ENROLLED STUDENTS for a course
// ═════════════════════════════════════════════════════════════

final enrolledStudentsProvider = FutureProvider.autoDispose
    .family<List<EnrolledStudentInfo>, String>((ref, courseId) async {
  return ref
      .read(teacherCourseRepoProvider)
      .fetchEnrolledStudents(courseId);
});

// ═════════════════════════════════════════════════════════════
//  COURSE FORM NOTIFIER  (create / edit)
// ═════════════════════════════════════════════════════════════

class CourseFormState {
  final bool isSubmitting;
  final String? error;
  final bool success;

  const CourseFormState({
    this.isSubmitting = false,
    this.error,
    this.success = false,
  });

  CourseFormState copyWith({
    bool? isSubmitting,
    String? error,
    bool? success,
  }) =>
      CourseFormState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
        success: success ?? this.success,
      );
}

class CourseFormNotifier extends AutoDisposeNotifier<CourseFormState> {
  @override
  CourseFormState build() => const CourseFormState();

  Future<void> create({
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? categoryTag,
  }) async {
    final uid = ref.read(authServiceProvider).currentAuthUser?.id;
    if (uid == null) {
      state = state.copyWith(error: 'Not authenticated');
      return;
    }
    state = state.copyWith(isSubmitting: true, success: false);
    try {
      await ref.read(teacherCourseRepoProvider).createCourse(
            teacherId: uid,
            title: title,
            description: description,
            price: price,
            thumbnailUrl: thumbnailUrl,
            categoryTag: categoryTag,
          );
      ref.invalidate(myCoursesProvider);
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> update({
    required String courseId,
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? categoryTag,
  }) async {
    state = state.copyWith(isSubmitting: true, success: false);
    try {
      await ref.read(teacherCourseRepoProvider).updateCourse(
            courseId: courseId,
            title: title,
            description: description,
            price: price,
            thumbnailUrl: thumbnailUrl,
            categoryTag: categoryTag,
          );
      ref.invalidate(myCoursesProvider);
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> delete(String courseId) async {
    state = state.copyWith(isSubmitting: true, success: false);
    try {
      await ref.read(teacherCourseRepoProvider).deleteCourse(courseId);
      ref.invalidate(myCoursesProvider);
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> togglePublish(String courseId,
      {required bool publish}) async {
    try {
      await ref
          .read(teacherCourseRepoProvider)
          .togglePublish(courseId, publish: publish);
      ref.invalidate(myCoursesProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final courseFormProvider =
    AutoDisposeNotifierProvider<CourseFormNotifier, CourseFormState>(
        CourseFormNotifier.new);

// ═════════════════════════════════════════════════════════════
//  SUBJECT FORM NOTIFIER
// ═════════════════════════════════════════════════════════════

class SubjectFormState {
  final bool isSubmitting;
  final String? error;
  final bool success;
  const SubjectFormState(
      {this.isSubmitting = false, this.error, this.success = false});
  SubjectFormState copyWith(
          {bool? isSubmitting, String? error, bool? success}) =>
      SubjectFormState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
        success: success ?? this.success,
      );
}

class SubjectFormNotifier
    extends AutoDisposeNotifier<SubjectFormState> {
  @override
  SubjectFormState build() => const SubjectFormState();

  Future<void> create(
      {required String courseId,
      required String name,
      required int sortOrder}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(teacherCourseRepoProvider)
          .createSubject(
              courseId: courseId, name: name, sortOrder: sortOrder);
      ref.invalidate(subjectsProvider(courseId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> update(
      {required String subjectId,
      required String courseId,
      required String name,
      required int sortOrder}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref.read(teacherCourseRepoProvider).updateSubject(
          subjectId: subjectId, name: name, sortOrder: sortOrder);
      ref.invalidate(subjectsProvider(courseId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> delete(
      {required String subjectId, required String courseId}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(teacherCourseRepoProvider)
          .deleteSubject(subjectId);
      ref.invalidate(subjectsProvider(courseId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final subjectFormProvider =
    AutoDisposeNotifierProvider<SubjectFormNotifier, SubjectFormState>(
        SubjectFormNotifier.new);

// ═════════════════════════════════════════════════════════════
//  CHAPTER FORM NOTIFIER
// ═════════════════════════════════════════════════════════════

class ChapterFormState {
  final bool isSubmitting;
  final String? error;
  final bool success;
  const ChapterFormState(
      {this.isSubmitting = false, this.error, this.success = false});
  ChapterFormState copyWith(
          {bool? isSubmitting, String? error, bool? success}) =>
      ChapterFormState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
        success: success ?? this.success,
      );
}

class ChapterFormNotifier
    extends AutoDisposeNotifier<ChapterFormState> {
  @override
  ChapterFormState build() => const ChapterFormState();

  Future<void> create(
      {required String subjectId,
      required String courseId,
      required String name,
      required int sortOrder}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref.read(teacherCourseRepoProvider).createChapter(
          subjectId: subjectId, name: name, sortOrder: sortOrder);
      ref.invalidate(chaptersProvider(subjectId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> update(
      {required String chapterId,
      required String subjectId,
      required String courseId,
      required String name,
      required int sortOrder}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref.read(teacherCourseRepoProvider).updateChapter(
          chapterId: chapterId, name: name, sortOrder: sortOrder);
      ref.invalidate(chaptersProvider(subjectId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> delete(
      {required String chapterId,
      required String subjectId,
      required String courseId}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(teacherCourseRepoProvider)
          .deleteChapter(chapterId);
      ref.invalidate(chaptersProvider(subjectId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final chapterFormProvider =
    AutoDisposeNotifierProvider<ChapterFormNotifier, ChapterFormState>(
        ChapterFormNotifier.new);

// ═════════════════════════════════════════════════════════════
//  LECTURE FORM NOTIFIER
// ═════════════════════════════════════════════════════════════

class LectureFormState {
  final bool isSubmitting;
  final String? error;
  final bool success;
  const LectureFormState(
      {this.isSubmitting = false, this.error, this.success = false});
  LectureFormState copyWith(
          {bool? isSubmitting, String? error, bool? success}) =>
      LectureFormState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
        success: success ?? this.success,
      );
}

class LectureFormNotifier
    extends AutoDisposeNotifier<LectureFormState> {
  @override
  LectureFormState build() => const LectureFormState();

  Future<void> create({
    required String chapterId,
    required String courseId,
    required String title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref.read(teacherCourseRepoProvider).createLecture(
            chapterId: chapterId,
            title: title,
            description: description,
            videoUrl: videoUrl,
            notesUrl: notesUrl,
            durationSeconds: durationSeconds,
            isFree: isFree,
            sortOrder: sortOrder,
          );
      ref.invalidate(lecturesProvider(chapterId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> update({
    required String lectureId,
    required String chapterId,
    required String courseId,
    required String title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref.read(teacherCourseRepoProvider).updateLecture(
            lectureId: lectureId,
            title: title,
            description: description,
            videoUrl: videoUrl,
            notesUrl: notesUrl,
            durationSeconds: durationSeconds,
            isFree: isFree,
            sortOrder: sortOrder,
          );
      ref.invalidate(lecturesProvider(chapterId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> delete({
    required String lectureId,
    required String chapterId,
    required String courseId,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(teacherCourseRepoProvider)
          .deleteLecture(lectureId);
      ref.invalidate(lecturesProvider(chapterId));
      ref.invalidate(courseOutlineProvider(courseId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}

final lectureFormProvider =
    AutoDisposeNotifierProvider<LectureFormNotifier, LectureFormState>(
        LectureFormNotifier.new);
