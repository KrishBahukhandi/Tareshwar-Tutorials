// ─────────────────────────────────────────────────────────────
//  enrolled_course_entity.dart  –  Domain entity for an enrolled
//  course with progress information.
// ─────────────────────────────────────────────────────────────

class EnrolledCourseEntity {
  final String courseId;
  final String title;
  final String? thumbnailUrl;
  final String? teacherName;
  final String? categoryTag;
  final double progressPercent;   // 0–100
  final int totalLectures;
  final int completedLectures;
  final String? lastLectureId;
  final String? lastLectureTitle;
  final DateTime enrolledAt;

  const EnrolledCourseEntity({
    required this.courseId,
    required this.title,
    this.thumbnailUrl,
    this.teacherName,
    this.categoryTag,
    required this.progressPercent,
    this.totalLectures = 0,
    this.completedLectures = 0,
    this.lastLectureId,
    this.lastLectureTitle,
    required this.enrolledAt,
  });

  double get progressFraction => (progressPercent.clamp(0, 100)) / 100;
  bool get isCompleted => progressPercent >= 100;
  bool get isStarted   => progressPercent > 0;
}
