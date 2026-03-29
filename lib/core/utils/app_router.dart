// app_router.dart – GoRouter with role-based routing + 5-tab student shell
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/courses/presentation/screens/my_courses_screen.dart';
import '../../features/courses/presentation/screens/course_list_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/subject_list_screen.dart';
import '../../features/courses/presentation/screens/chapter_list_screen.dart';
import '../../features/courses/presentation/screens/lecture_list_screen.dart';
import '../../features/lectures/presentation/screens/lecture_player_screen.dart';
import '../../features/lectures/presentation/screens/lecture_notes_screen.dart';
import '../../features/tests/presentation/screens/tests_tab_screen.dart';
import '../../features/tests/presentation/screens/test_screen.dart';
import '../../features/tests/presentation/screens/test_list_screen.dart';
import '../../features/tests/presentation/screens/test_instruction_screen.dart';
import '../../features/tests/presentation/screens/test_attempt_screen.dart';
import '../../features/tests/presentation/screens/test_result_screen.dart';
import '../../features/tests/presentation/screens/performance_analysis_screen.dart';
import '../../features/doubts/presentation/screens/doubts_screen.dart';
import '../../features/doubts/presentation/screens/doubt_list_screen.dart';
import '../../features/doubts/presentation/screens/doubt_detail_screen.dart';
import '../../features/doubts/presentation/screens/ask_doubt_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/teacher/presentation/screens/content_upload_screen.dart';
import '../../features/content_upload/screens/create_subject_screen.dart';
import '../../features/content_upload/screens/create_chapter_screen.dart';
import '../../features/content_upload/screens/upload_lecture_screen.dart';
import '../../features/teacher_tests/screens/create_test_screen.dart';
import '../../features/teacher_tests/screens/question_form_screen.dart';
import '../../features/teacher_tests/screens/test_preview_screen.dart';
import '../../features/teacher_doubts/screens/teacher_doubt_list_screen.dart';
import '../../features/teacher_doubts/screens/teacher_doubt_detail_screen.dart';
import '../../features/teacher_doubts/screens/reply_doubt_screen.dart';
import '../../features/teacher_analytics/screens/teacher_analytics_screen.dart';
import '../../features/teacher_analytics/screens/course_analytics_screen.dart';
import '../../features/teacher_analytics/screens/student_performance_screen.dart';
import '../../features/teacher_auth/screens/teacher_login_screen.dart';
import '../../features/teacher_auth/providers/teacher_auth_provider.dart'
    show teacherAuthProvider, TeacherAuthStatus;
import '../../features/teacher_dashboard/screens/teacher_dashboard_screen.dart'
    show TeacherDashboardShell;
import '../../features/teacher_courses/screens/teacher_course_list_screen.dart';
import '../../features/teacher_courses/screens/create_course_screen.dart';
import '../../features/teacher_courses/screens/edit_course_screen.dart';
import '../../features/teacher_courses/screens/course_students_screen.dart';
import '../../features/admin/presentation/screens/admin_shell.dart';
import '../../features/admin/presentation/providers/admin_providers.dart'
    show AdminSection, adminSelectedSectionProvider;
import '../../features/admin_auth/screens/admin_login_screen.dart';
import '../../features/admin_auth/providers/admin_auth_provider.dart'
    show adminAuthProvider, AdminAuthStatus;
import '../../features/admin_users/screens/student_detail_screen.dart';
import '../../features/admin_users/screens/teacher_detail_screen.dart';
import '../../features/admin_courses/screens/admin_course_list_screen.dart';
import '../../features/admin_courses/screens/admin_create_course_screen.dart';
import '../../features/admin_courses/screens/admin_edit_course_screen.dart';
import '../../features/admin_courses/screens/admin_course_detail_screen.dart';
import '../../features/admin_courses/data/admin_courses_service.dart'
    show AdminCourseListItem;
import '../../features/admin_batches/screens/create_batch_screen.dart';
import '../../features/admin_batches/screens/edit_batch_screen.dart';
import '../../features/admin_batches/screens/batch_detail_screen.dart';
import '../../features/admin_batches/screens/batch_students_screen.dart';
import '../../features/admin_batches/data/admin_batches_service.dart'
    show AdminBatchListItem;
import '../../features/admin_notifications/screens/create_announcement_screen.dart';
import '../../features/courses/presentation/screens/student_batches_screen.dart';
import '../../features/teacher_dashboard/screens/teacher_batches_screen.dart';
import '../../features/live_classes/screens/live_class_list_screen.dart';
import '../../features/live_classes/screens/live_class_detail_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/downloads/presentation/screens/downloaded_lecture_player.dart';
import '../../features/downloads/data/download_model.dart'
    show DownloadedLecture;
import '../constants/app_constants.dart';
import 'app_scaffold.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/models.dart';

// ─────────────────────────────────────────────────────────────
//  Route name constants
// ─────────────────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  // ── Auth ──────────────────────────────────────────────────
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String otp = '/otp';
  static const String emailVerification = '/email-verification';
  static String emailVerificationPath(String email) =>
      '/email-verification?email=${Uri.encodeComponent(email)}';

  // ── Student shell root ────────────────────────────────────
  static const String studentDashboard = '/student';

  // ── Student tab roots ─────────────────────────────────────
  static const String homeTab = '/student/home';
  static const String search = '/student/search';
  static const String myCourses = '/student/my-courses';
  static const String allCourses = '/student/courses';
  static const String testsTab = '/student/tests';
  static const String profile = '/student/profile';

  // ── Student sub-routes ────────────────────────────────────
  static const String courseDetail = '/student/course/:courseId';
  static const String subjectDetail =
      '/student/course/:courseId/subject/:subjectId';
  static const String chapterDetail =
      '/student/course/:courseId/subject/:subjectId/chapter/:chapterId';
  static const String lectureList = '/student/course/:courseId/lectures';
  static const String lecturePlayer = '/student/lecture/:lectureId';
  static const String lectureNotes = '/student/lecture/:lectureId/notes';
  static const String testList = '/student/test-list';
  static const String testInstruction = '/student/test-instruction/:testId';
  static const String testAttempt = '/student/test-attempt/:testId';
  static const String test = '/student/test/:testId';
  static const String testResult = '/student/test-result/:testId';
  static const String performanceAnalysis = '/student/performance-analysis';
  static const String doubts = '/student/doubts';
  static const String doubtDetail = '/student/doubt/:doubtId';
  static const String askDoubt = '/student/ask-doubt';
  static const String notifications = '/student/notifications';

  // ── Teacher ───────────────────────────────────────────────
  static const String teacherLogin = '/teacher/login';
  static const String teacherDashboard = '/teacher';
  static const String contentUpload = '/teacher/upload/:courseId';

  // ── Teacher: Content Upload ───────────────────────────────
  static const String createSubject =
      '/teacher/courses/:courseId/subjects/create';
  static const String createChapter =
      '/teacher/subjects/:subjectId/chapters/create';
  static const String uploadLecture =
      '/teacher/chapters/:chapterId/lectures/upload';

  // ── Teacher: Course Management ────────────────────────────
  static const String teacherCourseList = '/teacher/courses';
  static const String teacherCreateCourse = '/teacher/courses/create';
  static const String teacherEditCourse = '/teacher/courses/:courseId/edit';
  static const String teacherCourseStudents =
      '/teacher/courses/:courseId/students';

  static String teacherEditCoursePath(String id) => '/teacher/courses/$id/edit';
  static String teacherCourseStudentsPath(String id) =>
      '/teacher/courses/$id/students';

  // ── Teacher: Tests ────────────────────────────────────────
  static const String createTest = '/teacher/chapters/:chapterId/tests/create';
  static const String addQuestion = '/teacher/tests/:testId/questions/add';
  static const String testPreview = '/teacher/tests/:testId/preview';

  static String createTestPath(String chapterId) =>
      '/teacher/chapters/$chapterId/tests/create';
  static String addQuestionPath(String testId) =>
      '/teacher/tests/$testId/questions/add';
  static String testPreviewPath(String testId) =>
      '/teacher/tests/$testId/preview';

  // ── Teacher: Doubts ───────────────────────────────────────
  static const String teacherDoubtList = '/teacher/doubts';
  static const String teacherDoubtDetail = '/teacher/doubts/:doubtId';
  static const String replyDoubt = '/teacher/doubts/:doubtId/reply';

  static String teacherDoubtListPath() => '/teacher/doubts';
  static String teacherDoubtDetailPath(String id) => '/teacher/doubts/$id';
  static String replyDoubtPath(String id) => '/teacher/doubts/$id/reply';

  // ── Teacher: Analytics ────────────────────────────────────
  static const String teacherAnalytics = '/teacher/analytics';
  static const String courseAnalytics = '/teacher/analytics/course/:courseId';
  static const String studentPerformance =
      '/teacher/analytics/student/:studentId';

  static String teacherAnalyticsPath() => '/teacher/analytics';
  static String courseAnalyticsPath(String id) =>
      '/teacher/analytics/course/$id';
  static String studentPerformancePath(String id) =>
      '/teacher/analytics/student/$id';

  // ── Admin ─────────────────────────────────────────────────
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin';
  static const String adminStudents = '/admin/students';
  static const String adminTeachers = '/admin/teachers';
  static const String adminCourses = '/admin/courses';
  static const String batchManagement = '/admin/batches';
  static const String adminBatchEnrollments =
      '/admin/batches/:batchId/enrollments';
  static const String adminPayments = '/admin/payments';
  static const String adminTransactions = '/admin/payments/transactions';
  static const String adminRevenueAnalytics = '/admin/payments/analytics';
  static const String adminAnnouncements = '/admin/announcements';
  static const String adminCreateAnnouncement = '/admin/announcements/create';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminSettings = '/admin/settings';

  // ── Admin: User detail pages ──────────────────────────────
  static const String adminUserStudentDetail = '/admin/students/:userId';
  static const String adminUserTeacherDetail = '/admin/teachers/:userId';

  static String adminStudentDetailPath(String userId) =>
      '/admin/students/$userId';
  static String adminTeacherDetailPath(String userId) =>
      '/admin/teachers/$userId';

  // ── Admin: Course management ──────────────────────────────
  static const String adminCourseDetail = '/admin/courses/:courseId';
  static const String adminCreateCourse = '/admin/courses/create';
  static const String adminEditCourse = '/admin/courses/:courseId/edit';

  static String adminCourseDetailPath(String courseId) =>
      '/admin/courses/$courseId';
  static String adminEditCoursePath(String courseId) =>
      '/admin/courses/$courseId/edit';

  // ── Admin: Batch management (new modular screens) ─────────
  static const String adminCreateBatch = '/admin/batches/create';
  static const String adminBatchDetail = '/admin/batches/:batchId';
  static const String adminEditBatch = '/admin/batches/:batchId/edit';
  static const String adminBatchStudents = '/admin/batches/:batchId/students';

  static String adminCreateBatchPath({String? courseId}) =>
      '/admin/batches/create${courseId != null ? '?courseId=${Uri.encodeComponent(courseId)}' : ''}';
  static String adminBatchDetailPath(String batchId) =>
      '/admin/batches/$batchId';
  static String adminEditBatchPath(String batchId) =>
      '/admin/batches/$batchId/edit';
  static String adminBatchStudentsPath(String batchId) =>
      '/admin/batches/$batchId/students';

  static String adminBatchEnrollmentsPath(String batchId) =>
      '/admin/batches/$batchId/enrollments';
  static String adminPaymentsPath() => '/admin/payments';
  static String adminTransactionsPath() => '/admin/payments/transactions';
  static String adminRevenueAnalyticsPath() => '/admin/payments/analytics';
  static String adminAnnouncementsPath() => '/admin/announcements';
  static String adminCreateAnnouncementPath() => '/admin/announcements/create';
  static String adminLoginPath() => '/admin/login';

  // ── Downloads ─────────────────────────────────────────────
  static const String downloads = '/student/downloads';
  static const String downloadedPlayer = '/student/downloads/:lectureId/play';

  static String downloadsPath() => '/student/downloads';
  static String downloadedPlayerPath(String id) =>
      '/student/downloads/$id/play';

  // ── Student batches ───────────────────────────────────────
  static const String studentBatches = '/student/my-batches';
  static String studentBatchesPath() => '/student/my-batches';

  // ── Live Classes ──────────────────────────────────────────
  static const String liveClasses = '/student/live-classes';
  static const String liveClassDetail = '/student/live-classes/:liveClassId';

  static String liveClassesPath() => '/student/live-classes';
  static String liveClassDetailPath(String id) => '/student/live-classes/$id';

  // ── Teacher batches ───────────────────────────────────────
  static const String teacherBatches = '/teacher/batches';
  static String teacherBatchesPath() => '/teacher/batches';

  // ── Path helpers ──────────────────────────────────────────
  static String courseDetailPath(String id) => '/student/course/$id';
  static String subjectDetailPath(String courseId, String subjectId) =>
      '/student/course/$courseId/subject/$subjectId';
  static String chapterDetailPath(
    String courseId,
    String subjectId,
    String chapterId,
  ) => '/student/course/$courseId/subject/$subjectId/chapter/$chapterId';
  static String lectureListPath(String courseId) =>
      '/student/course/$courseId/lectures';
  static String lecturePlayerPath(String id) => '/student/lecture/$id';
  static String lectureNotesPath(
    String lectureId, {
    required String notesUrl,
    required String title,
  }) =>
      '/student/lecture/$lectureId/notes'
      '?url=${Uri.encodeComponent(notesUrl)}'
      '&title=${Uri.encodeComponent(title)}';
  static String testListPath() => '/student/test-list';
  static String testInstructionPath(String id) =>
      '/student/test-instruction/$id';
  static String testAttemptPath(String id) => '/student/test-attempt/$id';
  static String testPath(String id) => '/student/test/$id';
  static String testResultPath(String id) => '/student/test-result/$id';
  static String performanceAnalysisPath() => '/student/performance-analysis';
  static String doubtsPath() => '/student/doubts';
  static String doubtDetailPath(String id) => '/student/doubt/$id';
  static String askDoubtPath({String? lectureId}) =>
      '/student/ask-doubt${lectureId != null ? '?lectureId=${Uri.encodeComponent(lectureId)}' : ''}';
  static String teacherLoginPath() => '/teacher/login';
  static String contentUploadPath(String courseId) =>
      '/teacher/upload/$courseId';
  static String createSubjectPath(String courseId) =>
      '/teacher/courses/$courseId/subjects/create';
  static String createChapterPath(String subjectId) =>
      '/teacher/subjects/$subjectId/chapters/create';
  static String uploadLecturePath(String chapterId) =>
      '/teacher/chapters/$chapterId/lectures/upload';
}

// ─────────────────────────────────────────────────────────────
//  Router provider
// ─────────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final adminAuth = ref.watch(adminAuthProvider);
  final teacherAuth = ref.watch(teacherAuthProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,

    // ── Global redirect ───────────────────────────────────
    redirect: (context, state) {
      final isLoggedIn = authService.isLoggedIn;
      final role = authService.currentRole;
      final loc = state.matchedLocation;

      final isAuthRoute = [
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.otp,
        AppRoutes.forgotPassword,
        AppRoutes.onboarding,
        AppRoutes.splash,
        AppRoutes.emailVerification,
      ].contains(loc);

      final isTeacherAuthRoute = loc == AppRoutes.teacherLogin;
      final isAdminLoginRoute = loc == AppRoutes.adminLogin;
      final isTeacherArea = loc.startsWith('/teacher');
      // Admin-area excludes the login page itself
      final isAdminArea = loc.startsWith('/admin') && !isAdminLoginRoute;

      // ── Admin-area guard ───────────────────────────────
      // Unauthenticated → admin login page
      if (isAdminArea && adminAuth.status != AdminAuthStatus.authenticated) {
        return AppRoutes.adminLogin;
      }
      // Already authenticated admin hitting login → skip to dashboard
      if (isAdminLoginRoute &&
          adminAuth.status == AdminAuthStatus.authenticated) {
        return AppRoutes.adminDashboard;
      }

      // ── Teacher-area guard ─────────────────────────────
      if (isTeacherArea) {
        if (teacherAuth.status == TeacherAuthStatus.initial ||
            teacherAuth.status == TeacherAuthStatus.loading) {
          return null;
        }

        if (!isTeacherAuthRoute &&
            teacherAuth.status != TeacherAuthStatus.authenticated) {
          return AppRoutes.teacherLogin;
        }

        if (isTeacherAuthRoute &&
            teacherAuth.status == TeacherAuthStatus.authenticated) {
          return AppRoutes.teacherDashboard;
        }
      }

      // ── Student / general routes ───────────────────────
      if (!isLoggedIn &&
          !isAuthRoute &&
          !isTeacherArea &&
          !isAdminArea &&
          !isAdminLoginRoute) {
        return AppRoutes.login;
      }
      if (isLoggedIn && isAuthRoute && loc == AppRoutes.login) {
        if (role == AppConstants.roleTeacher) {
          return AppRoutes.teacherDashboard;
        }
        // Admins have their own login; don't redirect here
        return AppRoutes.homeTab;
      }

      if (loc == AppRoutes.studentDashboard) {
        return AppRoutes.homeTab;
      }

      return null;
    },

    routes: [
      // ── Auth ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) =>
            OtpScreen(phone: state.uri.queryParameters['phone'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) => EmailVerificationScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),

      // ── Student shell (6-tab StatefulShellRoute) ──────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppScaffold(child: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.homeTab,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myCourses,
                builder: (context, state) => const MyCoursesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.testsTab,
                builder: (context, state) => const TestsTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.downloads,
                builder: (context, state) => const DownloadsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Student full-screen routes ─────────────────────────
      GoRoute(
        path: AppRoutes.courseDetail,
        builder: (context, state) =>
            CourseDetailScreen(courseId: state.pathParameters['courseId']!),
      ),
      GoRoute(
        path: AppRoutes.subjectDetail,
        builder: (context, state) => SubjectListScreen(
          courseId: state.pathParameters['courseId']!,
          subjectId: state.pathParameters['subjectId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.chapterDetail,
        builder: (context, state) => ChapterListScreen(
          courseId: state.pathParameters['courseId']!,
          subjectId: state.pathParameters['subjectId']!,
          chapterId: state.pathParameters['chapterId']!,
          chapterName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: AppRoutes.lectureList,
        builder: (context, state) => LectureListScreen(
          courseId: state.pathParameters['courseId']!,
          courseTitle: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: AppRoutes.allCourses,
        builder: (context, state) => const CourseListScreen(),
      ),
      GoRoute(
        path: AppRoutes.lecturePlayer,
        builder: (context, state) =>
            LecturePlayerScreen(lectureId: state.pathParameters['lectureId']!),
      ),
      GoRoute(
        path: AppRoutes.lectureNotes,
        builder: (context, state) => LectureNotesScreen(
          notesUrl: Uri.decodeComponent(state.uri.queryParameters['url'] ?? ''),
          lectureTitle: Uri.decodeComponent(
            state.uri.queryParameters['title'] ?? 'Lecture Notes',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.test,
        builder: (context, state) =>
            TestScreen(testId: state.pathParameters['testId']!),
      ),
      GoRoute(
        path: AppRoutes.testList,
        builder: (context, state) => const TestListScreen(),
      ),
      GoRoute(
        path: AppRoutes.testInstruction,
        builder: (context, state) =>
            TestInstructionScreen(testId: state.pathParameters['testId']!),
      ),
      GoRoute(
        path: AppRoutes.testAttempt,
        builder: (context, state) =>
            TestAttemptScreen(testId: state.pathParameters['testId']!),
      ),
      GoRoute(
        path: AppRoutes.testResult,
        builder: (context, state) =>
            TestResultScreen(testId: state.pathParameters['testId']!),
      ),
      GoRoute(
        path: AppRoutes.performanceAnalysis,
        builder: (context, state) => const PerformanceAnalysisScreen(),
      ),
      GoRoute(
        path: AppRoutes.doubts,
        builder: (context, state) => const DoubtListScreen(),
      ),
      GoRoute(
        path: AppRoutes.doubtDetail,
        builder: (context, state) =>
            DoubtDetailScreen(doubtId: state.pathParameters['doubtId']!),
      ),
      GoRoute(
        path: AppRoutes.askDoubt,
        builder: (context, state) =>
            AskDoubtScreen(lectureId: state.uri.queryParameters['lectureId']),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ── Teacher ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.teacherLogin,
        builder: (context, state) => const TeacherLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherDashboard,
        builder: (context, state) => const TeacherDashboardShell(),
        routes: [
          GoRoute(
            path: 'upload/:courseId',
            builder: (context, state) => ContentUploadScreen(
              courseId: state.pathParameters['courseId']!,
              teacherId: state.uri.queryParameters['teacherId'] ?? '',
            ),
          ),
        ],
      ),

      // ── Teacher: Course Management ─────────────────────────
      GoRoute(
        path: AppRoutes.teacherCourseList,
        builder: (context, state) => const TeacherCourseListScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherCreateCourse,
        builder: (context, state) => const CreateCourseScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherEditCourse,
        builder: (context, state) {
          final course = state.extra as CourseModel?;
          if (course == null) {
            return const Scaffold(
              body: Center(child: Text('Course not found')),
            );
          }
          return EditCourseScreen(course: course);
        },
      ),
      GoRoute(
        path: AppRoutes.teacherCourseStudents,
        builder: (context, state) => CourseStudentsScreen(
          courseId: state.pathParameters['courseId']!,
          courseTitle: state.extra as String? ?? 'Course',
        ),
      ),

      // ── Teacher: Content Upload ────────────────────────────
      GoRoute(
        path: AppRoutes.createSubject,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return CreateSubjectScreen(
            courseId: state.pathParameters['courseId']!,
            courseTitle: extra?['courseTitle'] ?? 'Course',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.createChapter,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return CreateChapterScreen(
            subjectId: state.pathParameters['subjectId']!,
            subjectName: extra?['subjectName'] ?? 'Subject',
            courseTitle: extra?['courseTitle'] ?? 'Course',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.uploadLecture,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return UploadLectureScreen(
            chapterId: state.pathParameters['chapterId']!,
            courseId: extra?['courseId'] ?? '',
            chapterName: extra?['chapterName'] ?? 'Chapter',
            courseTitle: extra?['courseTitle'] ?? 'Course',
          );
        },
      ),

      // ── Teacher: Tests ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.createTest,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return CreateTestScreen(
            chapterId: state.pathParameters['chapterId']!,
            courseId: extra?['courseId'],
            chapterName: extra?['chapterName'] ?? 'Chapter',
            courseTitle: extra?['courseTitle'] ?? 'Course',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.addQuestion,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return AddQuestionScreen(
            testId: state.pathParameters['testId']!,
            testTitle: extra?['testTitle'] ?? 'Test',
            chapterId: extra?['chapterId'] ?? '',
            chapterName: extra?['chapterName'] ?? 'Chapter',
            courseTitle: extra?['courseTitle'] ?? 'Course',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.testPreview,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return TestPreviewScreen(
            testId: state.pathParameters['testId']!,
            chapterId: extra?['chapterId'] ?? '',
            chapterName: extra?['chapterName'] ?? 'Chapter',
            courseTitle: extra?['courseTitle'] ?? 'Course',
          );
        },
      ),

      // ── Teacher: Doubts ────────────────────────────────────
      GoRoute(
        path: AppRoutes.teacherDoubtList,
        builder: (context, state) => const TeacherDoubtListScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherDoubtDetail,
        builder: (context, state) =>
            TeacherDoubtDetailScreen(doubtId: state.pathParameters['doubtId']!),
      ),
      GoRoute(
        path: AppRoutes.replyDoubt,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return ReplyDoubtScreen(
            doubtId: state.pathParameters['doubtId']!,
            studentName: extra?['studentName'] ?? 'Student',
            questionPreview: extra?['questionPreview'] ?? '',
          );
        },
      ),

      // ── Teacher: Analytics ─────────────────────────────────
      GoRoute(
        path: AppRoutes.teacherAnalytics,
        builder: (context, state) => const TeacherAnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.courseAnalytics,
        builder: (context, state) => CourseAnalyticsScreen(
          courseId: state.pathParameters['courseId']!,
          courseTitle: state.extra as String? ?? 'Course',
        ),
      ),
      GoRoute(
        path: AppRoutes.studentPerformance,
        builder: (context, state) => StudentPerformanceScreen(
          studentId: state.pathParameters['studentId']!,
          studentName: state.extra as String? ?? 'Student',
        ),
      ),

      // ── Admin (Sidebar-Shell) ──────────────────────────────
      GoRoute(
        path: AppRoutes.adminLogin,
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminShell(),
      ),
      GoRoute(
        path: AppRoutes.adminStudents,
        builder: (context, state) {
          // Navigate into the shell and switch to Students section
          return _AdminShellSection(section: AdminSection.students);
        },
      ),
      GoRoute(
        path: AppRoutes.adminTeachers,
        builder: (context, state) =>
            _AdminShellSection(section: AdminSection.teachers),
      ),
      GoRoute(
        path: AppRoutes.adminCourses,
        builder: (context, state) =>
            _AdminShellSection(section: AdminSection.courses),
      ),

      // ── Admin: Course management (full-page routes) ────────
      GoRoute(
        path: AppRoutes.adminCreateCourse,
        builder: (context, state) => const AdminCreateCourseScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminCourseDetail,
        builder: (context, state) => AdminCourseDetailScreen(
          courseId: state.pathParameters['courseId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.adminEditCourse,
        builder: (context, state) {
          final course = state.extra as AdminCourseListItem?;
          if (course == null) {
            // Fallback: redirect to list if no extra provided
            return const AdminCourseListScreen();
          }
          return AdminEditCourseScreen(course: course);
        },
      ),
      GoRoute(
        path: AppRoutes.batchManagement,
        builder: (context, state) =>
            _AdminShellSection(section: AdminSection.batches),
      ),

      // ── Admin: Batch management (full-page screens) ────────
      GoRoute(
        path: AppRoutes.adminCreateBatch,
        builder: (context, state) => CreateBatchScreen(
          preselectedCourseId: state.uri.queryParameters['courseId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.adminBatchDetail,
        builder: (context, state) =>
            BatchDetailScreen(batchId: state.pathParameters['batchId']!),
      ),
      GoRoute(
        path: AppRoutes.adminEditBatch,
        builder: (context, state) => EditBatchScreen(
          batchId: state.pathParameters['batchId']!,
          existing: state.extra as AdminBatchListItem?,
        ),
      ),
      GoRoute(
        path: AppRoutes.adminBatchStudents,
        builder: (context, state) =>
            BatchStudentsScreen(batchId: state.pathParameters['batchId']!),
      ),
      GoRoute(
        path: AppRoutes.adminPayments,
        redirect: (context, state) => AppRoutes.adminDashboard,
      ),

      // ── Admin: Payment management (full-page screens) ──────
      GoRoute(
        path: AppRoutes.adminTransactions,
        redirect: (context, state) => AppRoutes.adminDashboard,
      ),
      GoRoute(
        path: AppRoutes.adminRevenueAnalytics,
        redirect: (context, state) => AppRoutes.adminDashboard,
      ),
      GoRoute(
        path: AppRoutes.adminAnnouncements,
        builder: (context, state) =>
            _AdminShellSection(section: AdminSection.announcements),
      ),
      GoRoute(
        path: AppRoutes.adminCreateAnnouncement,
        builder: (context, state) => const CreateAnnouncementScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAnalytics,
        builder: (context, state) =>
            _AdminShellSection(section: AdminSection.analytics),
      ),
      GoRoute(
        path: AppRoutes.adminSettings,
        builder: (context, state) =>
            _AdminShellSection(section: AdminSection.settings),
      ),

      // ── Admin: User detail pages ───────────────────────────
      GoRoute(
        path: AppRoutes.adminUserStudentDetail,
        builder: (context, state) =>
            StudentDetailScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: AppRoutes.adminUserTeacherDetail,
        builder: (context, state) =>
            TeacherDetailScreen(userId: state.pathParameters['userId']!),
      ),

      // ── Student: My Batches ────────────────────────────────
      GoRoute(
        path: AppRoutes.studentBatches,
        builder: (context, state) => const StudentBatchesScreen(),
      ),

      // ── Student: Live Classes ──────────────────────────────
      GoRoute(
        path: AppRoutes.liveClasses,
        builder: (context, state) => const LiveClassListScreen(),
      ),
      GoRoute(
        path: AppRoutes.liveClassDetail,
        builder: (context, state) => LiveClassDetailScreen(
          liveClassId: state.pathParameters['liveClassId']!,
        ),
      ),

      // ── Student: Downloads (player only – screen is in shell) ─
      GoRoute(
        path: AppRoutes.downloadedPlayer,
        builder: (context, state) => DownloadedLecturePlayer(
          lectureId: state.pathParameters['lectureId']!,
          download: state.extra as DownloadedLecture?,
        ),
      ),

      // ── Teacher: Batch Management ──────────────────────────
      GoRoute(
        path: AppRoutes.teacherBatches,
        builder: (context, state) => const TeacherBatchesScreen(),
      ),
    ],

    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
  );
});

// ─────────────────────────────────────────────────────────────
//  Helper widget: opens AdminShell pre-seeded to a given section.
//  Used by deep-link routes like /admin/students, /admin/analytics…
// ─────────────────────────────────────────────────────────────
class _AdminShellSection extends ConsumerWidget {
  final AdminSection section;
  const _AdminShellSection({required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set the section before the shell renders so the correct
    // screen is shown immediately (no flash to dashboard).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminSelectedSectionProvider.notifier).state = section;
    });
    return const AdminShell();
  }
}
