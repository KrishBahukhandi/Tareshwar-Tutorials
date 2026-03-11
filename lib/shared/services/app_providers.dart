// ─────────────────────────────────────────────────────────────
//  app_providers.dart  –  Centralised Riverpod providers
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_service.dart' show currentUserProvider;
import 'batch_service.dart';
import 'course_service.dart';
import 'progress_service.dart';
import 'test_service.dart';
import 'doubt_service.dart';
import 'notification_service.dart';

export 'auth_service.dart' show currentUserProvider;

// ═══════════════════════════════════════════════════════════════
//  AUTH STATE
// ═══════════════════════════════════════════════════════════════

/// Whether the user has completed onboarding
final onboardingDoneProvider = StateProvider<bool>((ref) => false);

// ═══════════════════════════════════════════════════════════════
//  COURSE PROVIDERS
// ═══════════════════════════════════════════════════════════════

/// All published courses
final allCoursesProvider = FutureProvider.autoDispose<List<CourseModel>>((ref) {
  return ref.watch(courseServiceProvider).fetchCourses(publishedOnly: true);
});

/// Courses enrolled by current student
final enrolledCoursesProvider =
    FutureProvider.autoDispose<List<CourseModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Future.value([]);
  return ref.watch(courseServiceProvider).fetchEnrolledCourses(user.id);
});

/// Courses taught by current teacher
final teacherOwnCoursesProvider =
    FutureProvider.autoDispose<List<CourseModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Future.value([]);
  return ref.watch(courseServiceProvider).fetchTeacherCourses(user.id);
});

/// Single course detail by ID
final courseDetailProvider =
    FutureProvider.autoDispose.family<CourseModel?, String>((ref, courseId) {
  return ref.watch(courseServiceProvider).fetchCourseById(courseId);
});

/// Lectures for a course
final courseLecturesProvider =
    FutureProvider.autoDispose.family<List<LectureModel>, String>(
        (ref, courseId) {
  return ref.watch(courseServiceProvider).fetchLectures(courseId);
});

/// Subjects (flat) for a course — no nested chapters/lectures
final courseSubjectsProvider =
    FutureProvider.autoDispose.family<List<SubjectModel>, String>(
        (ref, courseId) {
  return ref.watch(courseServiceProvider).fetchSubjectsFlat(courseId);
});

/// Chapters for a subject
final subjectChaptersProvider =
    FutureProvider.autoDispose.family<List<ChapterModel>, String>(
        (ref, subjectId) {
  return ref.watch(courseServiceProvider).fetchChapters(subjectId);
});

/// Lectures for a chapter
final chapterLecturesProvider =
    FutureProvider.autoDispose.family<List<LectureModel>, String>(
        (ref, chapterId) {
  return ref.watch(courseServiceProvider).fetchLecturesByChapter(chapterId);
});

// ── Watch progress for a single lecture ──────────────────────
typedef _ProgressKey = ({String studentId, String lectureId});

final watchProgressProvider = FutureProvider.autoDispose
    .family<LectureProgressModel?, _ProgressKey>((ref, key) {
  return ref.watch(courseServiceProvider).fetchWatchProgress(
        studentId: key.studentId,
        lectureId: key.lectureId,
      );
});

// ── All progress for a student (Map<lectureId, progress>) ────
final studentProgressMapProvider = FutureProvider.autoDispose
    .family<Map<String, LectureProgressModel>, String>((ref, studentId) {
  return ref
      .watch(courseServiceProvider)
      .fetchStudentProgress(studentId: studentId);
});

// ═══════════════════════════════════════════════════════════════
//  PROGRESS PROVIDERS  (lecture / chapter / course completion)
// ═══════════════════════════════════════════════════════════════

/// Full map of all progress rows for the current student.
/// Re-exported key used across the app.
final currentStudentProgressProvider =
    FutureProvider.autoDispose<Map<String, LectureProgressModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Future.value({});
  return ref.watch(progressServiceProvider).fetchAllProgress(user.id);
});

/// Course-level progress for a given [courseId] scoped to current student.
typedef _CoursePrgKey = ({String studentId, String courseId});

final courseProgressProvider = FutureProvider.autoDispose
    .family<CourseProgress, _CoursePrgKey>((ref, key) {
  return ref.watch(progressServiceProvider).fetchCourseProgress(
        studentId: key.studentId,
        courseId: key.courseId,
      );
});

/// Chapter-level progress; lectureIds must be passed by the caller
/// (already available from chapterLecturesProvider).
typedef _ChapterPrgKey = ({
  String studentId,
  String chapterId,
  List<String> lectureIds
});

final chapterProgressProvider = FutureProvider.autoDispose
    .family<ChapterProgress, _ChapterPrgKey>((ref, key) {
  return ref.watch(progressServiceProvider).fetchChapterProgress(
        studentId: key.studentId,
        chapterId: key.chapterId,
        lectureIds: key.lectureIds,
      );
});

/// All course progresses for the current student's enrolled courses.
/// Returns a map keyed by courseId for O(1) lookup in UI.
final studentAllCourseProgressProvider =
    FutureProvider.autoDispose<Map<String, CourseProgress>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return {};
  final courses =
      await ref.watch(enrolledCoursesProvider.future);
  if (courses.isEmpty) return {};
  final progresses = await ref
      .watch(progressServiceProvider)
      .fetchAllCourseProgresses(
        studentId: user.id,
        courseIds: courses.map((c) => c.id).toList(),
      );
  return {for (int i = 0; i < courses.length; i++) courses[i].id: progresses[i]};
});

/// Count of courses the current student has completed (100%).
final completedCoursesCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final progressMap =
      await ref.watch(studentAllCourseProgressProvider.future);
  return progressMap.values.where((p) => p.isComplete).length;
});

/// Count of courses the current student has started (>0% progress).
final startedCoursesCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final progressMap =
      await ref.watch(studentAllCourseProgressProvider.future);
  return progressMap.values.where((p) => p.hasStarted).length;
});

// ═══════════════════════════════════════════════════════════════
//  TEST PROVIDERS
// ═══════════════════════════════════════════════════════════════

/// Tests for a course
final courseTestsProvider =
    FutureProvider.autoDispose.family<List<TestModel>, String>((ref, courseId) {
  return ref.watch(testServiceProvider).fetchTests(courseId: courseId);
});

/// Tests for a chapter
final chapterTestsProvider =
    FutureProvider.autoDispose.family<List<TestModel>, String>((ref, chapterId) {
  return ref.watch(testServiceProvider).fetchTestsByChapter(chapterId);
});

/// Attempts by current student
final studentAttemptsProvider =
    FutureProvider.autoDispose<List<TestAttemptModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Future.value([]);
  return ref.watch(testServiceProvider).fetchAttempts(studentId: user.id);
});

/// Aggregate stats for current student
final studentTestStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Future.value({'best': 0, 'avg': 0.0, 'total': 0});
  return ref.watch(testServiceProvider).fetchStudentStats(user.id);
});

/// Single test detail
final testDetailProvider =
    FutureProvider.autoDispose.family<TestModel, String>((ref, testId) {
  return ref.watch(testServiceProvider).fetchTest(testId);
});

/// Questions for a test
final testQuestionsProvider =
    FutureProvider.autoDispose.family<List<QuestionModel>, String>((ref, testId) {
  return ref.watch(testServiceProvider).fetchQuestions(testId);
});

/// Last attempt for a student on a test
typedef _AttemptKey = ({String testId, String studentId});

final lastAttemptProvider = FutureProvider.autoDispose
    .family<TestAttemptModel?, _AttemptKey>((ref, key) {
  return ref.watch(testServiceProvider).fetchLastAttempt(
        testId: key.testId,
        studentId: key.studentId,
      );
});

/// Leaderboard for a test
final testLeaderboardProvider =
    FutureProvider.autoDispose.family<List<TestAttemptModel>, String>((ref, testId) {
  return ref.watch(testServiceProvider).fetchLeaderboard(testId);
});

// ═══════════════════════════════════════════════════════════════
//  DOUBT PROVIDERS
// ═══════════════════════════════════════════════════════════════

/// All doubts (optionally filtered by lecture)
final doubtsProvider =
    FutureProvider.autoDispose.family<List<DoubtModel>, String?>(
        (ref, lectureId) {
  return ref.watch(doubtServiceProvider).fetchDoubts(lectureId: lectureId);
});

/// My doubts for the currently logged-in student
final myDoubtsProvider =
    FutureProvider.autoDispose<List<DoubtModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Future.value([]);
  return ref.watch(doubtServiceProvider).fetchDoubts(studentId: user.id);
});

/// Single doubt detail
final doubtDetailProvider =
    FutureProvider.autoDispose.family<DoubtModel, String>((ref, doubtId) {
  return ref.watch(doubtServiceProvider).fetchDoubt(doubtId);
});

/// Replies for a doubt (FutureProvider for initial load)
final doubtRepliesProvider =
    FutureProvider.autoDispose.family<List<DoubtReplyModel>, String>(
        (ref, doubtId) {
  return ref.watch(doubtServiceProvider).fetchReplies(doubtId);
});

/// Realtime replies stream for a doubt
final doubtRepliesStreamProvider =
    StreamProvider.autoDispose.family<List<DoubtReplyModel>, String>(
        (ref, doubtId) {
  return ref.watch(doubtServiceProvider).repliesStream(doubtId);
});

/// Realtime doubts stream for a lecture
final doubtsStreamProvider =
    StreamProvider.autoDispose.family<List<DoubtModel>, String>(
        (ref, lectureId) {
  return ref.watch(doubtServiceProvider).doubtsStream(lectureId);
});

// ═══════════════════════════════════════════════════════════════
//  NOTIFICATION PROVIDERS
// ═══════════════════════════════════════════════════════════════

/// All notifications for current user
final userNotificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Future.value([]);
  return ref.watch(notificationServiceProvider).fetchNotifications(user.id);
});

/// Unread notification count (realtime)
final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value(0);
  return ref.watch(notificationServiceProvider).unreadCountStream(user.id);
});

// ═══════════════════════════════════════════════════════════════
//  UI STATE PROVIDERS
// ═══════════════════════════════════════════════════════════════

/// Currently active bottom nav index for student shell
final studentNavIndexProvider = StateProvider<int>((ref) => 0);

/// Search query for courses screen
final courseSearchQueryProvider = StateProvider<String>((ref) => '');

/// Currently selected category filter
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Whether dark mode is forced (overrides system)
final forceDarkModeProvider = StateProvider<bool?>((ref) => null);

// ═══════════════════════════════════════════════════════════════
//  ACTIVE TEST SESSION STATE
// ═══════════════════════════════════════════════════════════════

class TestSessionState {
  final TestModel? test;
  final Map<int, int> answers; // questionIndex → selectedOption
  final int currentIndex;
  final DateTime? startTime;
  final bool isSubmitted;

  const TestSessionState({
    this.test,
    this.answers = const {},
    this.currentIndex = 0,
    this.startTime,
    this.isSubmitted = false,
  });

  TestSessionState copyWith({
    TestModel? test,
    Map<int, int>? answers,
    int? currentIndex,
    DateTime? startTime,
    bool? isSubmitted,
  }) =>
      TestSessionState(
        test: test ?? this.test,
        answers: answers ?? this.answers,
        currentIndex: currentIndex ?? this.currentIndex,
        startTime: startTime ?? this.startTime,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );

  int get answeredCount => answers.length;
  int get skippedCount {
    // We don't have questions count here — caller must pass it
    return 0;
  }
  int get elapsedSeconds =>
      startTime != null
          ? DateTime.now().difference(startTime!).inSeconds
          : 0;
}

class TestSessionNotifier extends StateNotifier<TestSessionState> {
  TestSessionNotifier() : super(const TestSessionState());

  void startTest(TestModel test) {
    state = TestSessionState(
      test: test,
      startTime: DateTime.now(),
    );
  }

  void selectAnswer(int questionIndex, int optionIndex) {
    final updated = Map<int, int>.from(state.answers);
    updated[questionIndex] = optionIndex;
    state = state.copyWith(answers: updated);
  }

  void goToQuestion(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void nextQuestion() {
    if (state.currentIndex < _totalQuestions - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  int get _totalQuestions => state.answers.length; // overestimate; caller tracks

  void previousQuestion() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  void submitTest() {
    state = state.copyWith(isSubmitted: true);
  }

  void reset() {
    state = const TestSessionState();
  }
}

final testSessionProvider =
    StateNotifierProvider<TestSessionNotifier, TestSessionState>(
        (ref) => TestSessionNotifier());

/// ──────────────────────────────────────────────────────────────
///  BATCH PROVIDERS
/// ──────────────────────────────────────────────────────────────

/// All batches (admin / teacher overview)
final allBatchesProvider =
    FutureProvider.autoDispose<List<BatchModel>>((ref) =>
        ref.watch(batchServiceProvider).fetchAllBatches());

/// Batches for a specific course
final courseBatchesProvider =
    FutureProvider.autoDispose.family<List<BatchModel>, String>(
        (ref, courseId) =>
            ref.watch(batchServiceProvider).fetchAllBatches(courseId: courseId));

/// Batches the current student is enrolled in
final studentBatchesProvider =
    FutureProvider.autoDispose.family<List<BatchModel>, String>(
        (ref, studentId) =>
            ref.watch(batchServiceProvider).fetchStudentBatches(studentId));

/// Batches assigned to a teacher (via course ownership)
final teacherBatchesProvider =
    FutureProvider.autoDispose.family<List<BatchModel>, String>(
        (ref, teacherId) =>
            ref.watch(batchServiceProvider).fetchTeacherBatches(teacherId));

/// Single batch by ID
final batchByIdProvider =
    FutureProvider.autoDispose.family<BatchModel?, String>(
        (ref, batchId) =>
            ref.watch(batchServiceProvider).fetchBatchById(batchId));

/// Enrollments for a batch (for teacher / admin)
final batchEnrollmentsProvider =
    FutureProvider.autoDispose.family<List<EnrollmentModel>, String>(
        (ref, batchId) =>
            ref.watch(batchServiceProvider).fetchBatchEnrollments(batchId));

/// All enrollments for a student
final studentEnrollmentsProvider =
    FutureProvider.autoDispose.family<List<EnrollmentModel>, String>(
        (ref, studentId) =>
            ref.watch(batchServiceProvider).fetchStudentEnrollments(studentId));

/// Check if student is enrolled in a specific batch
typedef _EnrollCheckKey = ({String studentId, String batchId});

final isEnrolledInBatchProvider =
    FutureProvider.autoDispose.family<bool, _EnrollCheckKey>(
        (ref, key) => ref.watch(batchServiceProvider).isStudentEnrolledInBatch(
              studentId: key.studentId,
              batchId: key.batchId,
            ));
