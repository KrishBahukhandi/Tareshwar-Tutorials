// ─────────────────────────────────────────────────────────────
//  dashboard_remote_datasource.dart  –  Supabase data source
//  for the Student Dashboard.
// ─────────────────────────────────────────────────────────────
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/enrolled_course_entity.dart';
import '../../domain/entities/recommended_course_entity.dart';
import '../../domain/entities/announcement_entity.dart';

class DashboardRemoteDataSource {
  final SupabaseClient _client;
  DashboardRemoteDataSource(this._client);

  // ── Enrolled courses with progress ───────────────────────
  Future<List<EnrolledCourseEntity>> fetchEnrolledCourses(
      String studentId) async {
    // Join enrollments → courses directly (batches removed)
    final rows = await _client
        .from('enrollments')
        .select('''
          progress_percent,
          enrolled_at,
          courses!course_id(
            id, title, thumbnail_url, category_tag, total_lectures,
            users!teacher_id(name)
          )
        ''')
        .eq('student_id', studentId)
        .order('enrolled_at', ascending: false);

    return rows.map<EnrolledCourseEntity>((row) {
      final course =
          (row['courses'] as Map<String, dynamic>);
      final teacherName =
          (course['users'] as Map<String, dynamic>?)?['name'] as String?;
      return EnrolledCourseEntity(
        courseId: course['id'] as String,
        title: course['title'] as String,
        thumbnailUrl: course['thumbnail_url'] as String?,
        teacherName: teacherName,
        categoryTag: course['category_tag'] as String?,
        progressPercent:
            (row['progress_percent'] as num?)?.toDouble() ?? 0.0,
        totalLectures: (course['total_lectures'] as int?) ?? 0,
        enrolledAt: DateTime.parse(row['enrolled_at'] as String),
      );
    }).toList();
  }

  // ── Recommended courses (published, not enrolled) ────────
  Future<List<RecommendedCourseEntity>> fetchRecommended(
      String studentId) async {
    // Get enrolled course IDs directly from enrollments.course_id
    final enrolled = await _client
        .from('enrollments')
        .select('course_id')
        .eq('student_id', studentId);

    final enrolledIds = enrolled
        .map<String>((e) => e['course_id'] as String)
        .toSet();

    // Fetch all published courses
    final all = await _client
        .from('courses')
        .select('id, title, description, thumbnail_url, category_tag, '
            'price, rating, total_lectures, users!teacher_id(name)')
        .eq('is_published', true)
        .order('rating', ascending: false)
        .limit(20);

    return all
        .where((c) => !enrolledIds.contains(c['id']))
        .take(10)
        .map<RecommendedCourseEntity>((c) {
      final teacherName =
          (c['users'] as Map<String, dynamic>?)?['name'] as String?;
      return RecommendedCourseEntity(
        courseId: c['id'] as String,
        title: c['title'] as String,
        description: c['description'] as String? ?? '',
        thumbnailUrl: c['thumbnail_url'] as String?,
        teacherName: teacherName,
        categoryTag: c['category_tag'] as String?,
        price: (c['price'] as num).toDouble(),
        rating: (c['rating'] as num?)?.toDouble(),
        totalLectures: c['total_lectures'] as int?,
      );
    }).toList();
  }

  // ── Announcements ─────────────────────────────────────────
  Future<List<AnnouncementEntity>> fetchAnnouncements(String userId) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('type', 'announcement')
        .or('user_id.eq.$userId,user_id.is.null')
        .order('created_at', ascending: false)
        .limit(5);

    return rows
        .map<AnnouncementEntity>((r) => AnnouncementEntity(
              id: r['id'] as String,
              title: r['title'] as String,
              body: r['body'] as String,
              targetId: r['target_id'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();
  }

  // ── Unread notification count (realtime) ─────────────────
  Stream<int> unreadCountStream(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) =>
            list.where((n) => n['is_read'] == false).length);
  }
}
