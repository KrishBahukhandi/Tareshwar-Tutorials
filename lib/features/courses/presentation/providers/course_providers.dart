// ─────────────────────────────────────────────────────────────
//  course_providers.dart  –  Riverpod providers for the
//  full Course module (CourseList → Subject → Chapter → Lecture)
// ─────────────────────────────────────────────────────────────
export '../../../../shared/services/app_providers.dart'
    show
        allCoursesProvider,
        enrolledCoursesProvider,
        courseDetailProvider,
        courseSubjectsProvider,
        subjectChaptersProvider,
        chapterLecturesProvider,
        courseLecturesProvider,
        courseProgressProvider,
        chapterProgressProvider,
        studentAllCourseProgressProvider,
        completedCoursesCountProvider,
        currentStudentProgressProvider;

export '../../../../shared/services/progress_service.dart'
    show CourseProgress, ChapterProgress;
