// ─────────────────────────────────────────────────────────────
//  dashboard_repository.dart  –  Abstract contract for all
//  data needed by the Student Dashboard screen.
// ─────────────────────────────────────────────────────────────
import '../entities/enrolled_course_entity.dart';
import '../entities/recommended_course_entity.dart';
import '../entities/announcement_entity.dart';

abstract class DashboardRepository {
  /// Enrolled courses with live progress for [studentId].
  Future<List<EnrolledCourseEntity>> fetchEnrolledCourses(String studentId);

  /// Published courses the student has NOT enrolled in (recommendations).
  Future<List<RecommendedCourseEntity>> fetchRecommended(String studentId);

  /// Latest announcements (notifications of type 'announcement').
  Future<List<AnnouncementEntity>> fetchAnnouncements(String userId);

  /// Count of unread notifications for [userId].
  Stream<int> unreadCountStream(String userId);
}
