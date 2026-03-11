// ─────────────────────────────────────────────────────────────
//  dashboard_repository_impl.dart  –  Concrete implementation
// ─────────────────────────────────────────────────────────────
import '../../domain/entities/enrolled_course_entity.dart';
import '../../domain/entities/recommended_course_entity.dart';
import '../../domain/entities/announcement_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remote;
  DashboardRepositoryImpl(this._remote);

  @override
  Future<List<EnrolledCourseEntity>> fetchEnrolledCourses(
          String studentId) =>
      _remote.fetchEnrolledCourses(studentId);

  @override
  Future<List<RecommendedCourseEntity>> fetchRecommended(
          String studentId) =>
      _remote.fetchRecommended(studentId);

  @override
  Future<List<AnnouncementEntity>> fetchAnnouncements(String userId) =>
      _remote.fetchAnnouncements(userId);

  @override
  Stream<int> unreadCountStream(String userId) =>
      _remote.unreadCountStream(userId);
}
