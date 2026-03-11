// ─────────────────────────────────────────────────────────────
//  recommended_course_entity.dart  –  Domain entity for a
//  recommended (unenrolled) course shown on the dashboard.
// ─────────────────────────────────────────────────────────────

class RecommendedCourseEntity {
  final String courseId;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String? teacherName;
  final String? categoryTag;
  final double price;
  final double? rating;
  final int? totalStudents;
  final int? totalLectures;

  const RecommendedCourseEntity({
    required this.courseId,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    this.teacherName,
    this.categoryTag,
    required this.price,
    this.rating,
    this.totalStudents,
    this.totalLectures,
  });

  bool get isFree => price == 0;
  String get formattedPrice =>
      isFree ? 'Free' : '₹${price.toStringAsFixed(0)}';
  String get formattedRating =>
      rating != null ? rating!.toStringAsFixed(1) : '–';
}
