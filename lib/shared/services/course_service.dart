// ─────────────────────────────────────────────────────────────
//  course_service.dart  –  Course API service layer
//
//  Hierarchy: Course → Batch → Subject → Chapter → Lecture
//
//  Enrollment is ALWAYS done via a Batch (see batch_service.dart).
//  This service focuses on Course CRUD and content reads that are
//  not batch-specific (e.g. fetching a chapter's lectures for a
//  player screen once the student is already enrolled).
// ─────────────────────────────────────────────────────────────
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'storage_access_service.dart';
import 'supabase_service.dart';

final courseServiceProvider = Provider<CourseService>((ref) {
  return CourseService(ref.watch(supabaseClientProvider));
});

class CourseService {
  final SupabaseClient _client;
  CourseService(this._client);

  Future<LectureModel> _resolveLectureAssetUrls(LectureModel lecture) async {
    final storage = StorageAccessService(_client);
    final videoUrl = await storage.resolveAssetUrl(lecture.videoUrl);
    final notesUrl = await storage.resolveAssetUrl(lecture.notesUrl);
    return lecture.copyWith(videoUrl: videoUrl, notesUrl: notesUrl);
  }

  // ═══════════════════════════════════════════════════════════
  //  COURSES — Read
  // ═══════════════════════════════════════════════════════════

  /// Fetch all (optionally only published) courses with teacher name.
  /// Capped at 150 courses — prevents unbounded queries as the catalogue grows.
  Future<List<CourseModel>> fetchCourses({bool publishedOnly = false}) async {
    var q = _client.from('courses').select('*, users!teacher_id(name)');

    final List<Map<String, dynamic>> rows;
    if (publishedOnly) {
      rows = await q
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(150);
    } else {
      rows = await q.order('created_at', ascending: false).limit(150);
    }

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      map['teacher_name'] = (map['users'] as Map?)?['name'];
      return CourseModel.fromJson(map);
    }).toList();
  }

  /// Fetch a single course by ID.
  Future<CourseModel?> fetchCourseById(String courseId) async {
    try {
      final row = await _client
          .from('courses')
          .select('*, users!teacher_id(name)')
          .eq('id', courseId)
          .single();
      final map = Map<String, dynamic>.from(row);
      map['teacher_name'] = (map['users'] as Map?)?['name'];
      return CourseModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Courses owned by a specific teacher.
  Future<List<CourseModel>> fetchTeacherCourses(String teacherId) async {
    final rows = await _client
        .from('courses')
        .select()
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return rows
        .map((r) => CourseModel.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Courses the student is enrolled in (direct enrollment).
  Future<List<CourseModel>> fetchEnrolledCourses(String studentId) async {
    final rows = await _client
        .from('enrollments')
        .select('course_id, courses(*, users!teacher_id(name))')
        .eq('student_id', studentId);

    final courses = <CourseModel>[];
    for (final r in rows) {
      final courseMap = r['courses'] as Map?;
      if (courseMap == null) continue;
      final map = Map<String, dynamic>.from(courseMap);
      final usersMap = map['users'] as Map?;
      map['teacher_name'] = usersMap?['name'];
      courses.add(CourseModel.fromJson(map));
    }
    return courses;
  }

  // ═══════════════════════════════════════════════════════════
  //  ENROLLMENT
  // ═══════════════════════════════════════════════════════════

  /// Check if a student is enrolled in a course.
  Future<bool> isStudentEnrolled({
    required String studentId,
    required String courseId,
  }) async {
    final rows = await _client
        .from('enrollments')
        .select('id')
        .eq('student_id', studentId)
        .eq('course_id', courseId);
    return rows.isNotEmpty;
  }

  /// Enroll the current student into a free course via Next.js API.
  Future<EnrollmentModel> enrollStudent({
    required String studentId,
    required String courseId,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final dio = Dio();
    final response = await dio.post(
      '${AppConstants.webApiBaseUrl}/api/enroll-free',
      data: {'courseId': courseId},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        validateStatus: (status) => true,
      ),
    );

    if (response.statusCode != null && response.statusCode! >= 400) {
      final errorMsg = response.data is Map
          ? (response.data['error'] ?? 'Enrollment failed')
          : 'Enrollment failed';
      throw Exception(errorMsg);
    }

    final row = Map<String, dynamic>.from(response.data as Map);
    return EnrollmentModel.fromJson(row);
  }

  /// Remove an enrollment by ID.
  Future<void> removeEnrollment(String enrollmentId) async {
    await _client.from('enrollments').delete().eq('id', enrollmentId);
  }

  /// All enrollments for a course (admin/teacher).
  Future<List<EnrollmentModel>> fetchCourseEnrollments(String courseId) async {
    final rows = await _client
        .from('enrollments')
        .select('*, users(name, email)')
        .eq('course_id', courseId)
        .order('enrolled_at', ascending: false);
    return rows
        .map((r) => EnrollmentModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// All enrollments for a student.
  Future<List<EnrollmentModel>> fetchStudentEnrollments(String studentId) async {
    final rows = await _client
        .from('enrollments')
        .select('*, courses(title)')
        .eq('student_id', studentId)
        .order('enrolled_at', ascending: false);
    return rows
        .map((r) => EnrollmentModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Update progress percentage for an enrollment.
  Future<void> updateEnrollmentProgress({
    required String studentId,
    required String courseId,
    required double percent,
  }) async {
    await _client
        .from('enrollments')
        .update({'progress_percent': percent})
        .eq('student_id', studentId)
        .eq('course_id', courseId);
  }

  // ═══════════════════════════════════════════════════════════
  //  COURSES — Write (teacher / admin)
  // ═══════════════════════════════════════════════════════════

  Future<CourseModel> createCourse({
    required String title,
    required String description,
    required String teacherId,
    required double price,
    String? thumbnailUrl,
    String? categoryTag,
  }) async {
    final row = await _client
        .from('courses')
        .insert({
          'title': title,
          'description': description,
          'teacher_id': teacherId,
          'price': price,
          'thumbnail_url': thumbnailUrl,
          'category_tag': categoryTag,
          'is_published': false,
        })
        .select()
        .single();
    return CourseModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<CourseModel> updateCourse({
    required String courseId,
    String? title,
    String? description,
    double? price,
    String? thumbnailUrl,
    String? categoryTag,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (price != null) payload['price'] = price;
    if (thumbnailUrl != null) payload['thumbnail_url'] = thumbnailUrl;
    if (categoryTag != null) payload['category_tag'] = categoryTag;
    if (payload.isEmpty) throw ArgumentError('Nothing to update');

    final row = await _client
        .from('courses')
        .update(payload)
        .eq('id', courseId)
        .select()
        .single();
    return CourseModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> togglePublish(String courseId, bool publish) async {
    await _client
        .from('courses')
        .update({'is_published': publish})
        .eq('id', courseId);
  }

  Future<void> deleteCourse(String courseId) async {
    await _client.from('courses').delete().eq('id', courseId);
  }

  // ═══════════════════════════════════════════════════════════
  //  SUBJECTS (read-only convenience; writes via BatchService)
  // ═══════════════════════════════════════════════════════════

  /// Subjects for a course with nested chapters/lectures.
  Future<List<SubjectModel>> fetchSubjects(String courseId) async {
    final rows = await _client
        .from('subjects')
        .select('*, chapters(*, lectures(*))')
        .eq('course_id', courseId)
        .order('sort_order');
    return rows
        .map((r) => SubjectModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Flat subjects list (no nested chapters/lectures).
  Future<List<SubjectModel>> fetchSubjectsFlat(String courseId) async {
    final rows = await _client
        .from('subjects')
        .select()
        .eq('course_id', courseId)
        .order('sort_order');
    return rows
        .map(
          (r) => SubjectModel.fromJson({
            ...Map<String, dynamic>.from(r as Map),
            'chapters': <dynamic>[],
          }),
        )
        .toList();
  }

  // ── Subject / Chapter write methods (moved from batch_service) ──

  Future<SubjectModel> createSubject({
    required String courseId,
    required String name,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('subjects')
        .insert({'course_id': courseId, 'name': name, 'sort_order': sortOrder})
        .select()
        .single();
    return SubjectModel.fromJson({
      ...Map<String, dynamic>.from(row as Map),
      'chapters': <dynamic>[],
    });
  }

  Future<void> updateSubject({
    required String subjectId,
    String? name,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (payload.isEmpty) return;
    await _client.from('subjects').update(payload).eq('id', subjectId);
  }

  Future<void> deleteSubject(String subjectId) async {
    await _client.from('subjects').delete().eq('id', subjectId);
  }

  Future<ChapterModel> createChapter({
    required String subjectId,
    required String name,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('chapters')
        .insert({'subject_id': subjectId, 'name': name, 'sort_order': sortOrder})
        .select()
        .single();
    return ChapterModel.fromJson({
      ...Map<String, dynamic>.from(row as Map),
      'lectures': <dynamic>[],
    });
  }

  Future<void> updateChapter({
    required String chapterId,
    String? name,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (payload.isEmpty) return;
    await _client.from('chapters').update(payload).eq('id', chapterId);
  }

  Future<void> deleteChapter(String chapterId) async {
    await _client.from('chapters').delete().eq('id', chapterId);
  }

  // ═══════════════════════════════════════════════════════════
  //  CHAPTERS (read-only convenience; writes via BatchService)
  // ═══════════════════════════════════════════════════════════

  Future<List<ChapterModel>> fetchChapters(String subjectId) async {
    final rows = await _client
        .from('chapters')
        .select()
        .eq('subject_id', subjectId)
        .order('sort_order');
    return rows
        .map(
          (r) => ChapterModel.fromJson({
            ...Map<String, dynamic>.from(r as Map),
            'lectures': <dynamic>[],
          }),
        )
        .toList();
  }

  /// Fetch a single chapter by ID (used for courseId resolution in analytics).
  Future<ChapterModel?> fetchChapterById(String chapterId) async {
    try {
      final row = await _client
          .from('chapters')
          .select()
          .eq('id', chapterId)
          .single();
      return ChapterModel.fromJson({
        ...Map<String, dynamic>.from(row),
        'lectures': <dynamic>[],
      });
    } catch (_) {
      return null;
    }
  }

  /// Fetch a single subject by ID (used for courseId resolution in analytics).
  Future<SubjectModel?> fetchSubjectById(String subjectId) async {
    try {
      final row = await _client
          .from('subjects')
          .select()
          .eq('id', subjectId)
          .single();
      return SubjectModel.fromJson({
        ...Map<String, dynamic>.from(row),
        'chapters': <dynamic>[],
      });
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  LECTURES
  // ═══════════════════════════════════════════════════════════

  /// All lectures for a chapter ordered by sort_order.
  Future<List<LectureModel>> fetchLecturesByChapter(String chapterId) async {
    final rows = await _client
        .from('lectures')
        .select()
        .eq('chapter_id', chapterId)
        .order('sort_order');
    final lectures = rows
        .map((r) => LectureModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    return Future.wait(lectures.map(_resolveLectureAssetUrls));
  }

  /// Legacy: fetch lectures by course_id (flat, no hierarchy).
  /// Kept for backwards compatibility with older screens.
  Future<List<LectureModel>> fetchLectures(String courseId) async {
    // Lectures are now under chapters → subjects → course
    // We resolve them via a join path
    final subjects = await fetchSubjectsFlat(courseId);
    if (subjects.isEmpty) return [];

    final subjectIds = subjects.map((s) => s.id).toList();
    final chapters = await _client
        .from('chapters')
        .select('id')
        .inFilter('subject_id', subjectIds);

    if (chapters.isEmpty) return [];
    final chapterIds = chapters.map((c) => c['id'] as String).toList();

    final rows = await _client
        .from('lectures')
        .select()
        .inFilter('chapter_id', chapterIds)
        .order('sort_order');

    final lectures = rows
        .map((r) => LectureModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    return Future.wait(lectures.map(_resolveLectureAssetUrls));
  }

  /// Fetch a single lecture by ID.
  Future<LectureModel> fetchLecture(String lectureId) async {
    final row = await _client
        .from('lectures')
        .select()
        .eq('id', lectureId)
        .single();
    final lecture = LectureModel.fromJson(Map<String, dynamic>.from(row));
    return _resolveLectureAssetUrls(lecture);
  }

  // ═══════════════════════════════════════════════════════════
  //  LECTURES — Write (teacher / admin)
  // ═══════════════════════════════════════════════════════════

  Future<LectureModel> createLecture({
    required String chapterId,
    required String title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('lectures')
        .insert({
          'chapter_id': chapterId,
          'title': title,
          'description': description,
          'video_url': videoUrl,
          'notes_url': notesUrl,
          'duration_seconds': durationSeconds,
          'is_free': isFree,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return LectureModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<LectureModel> updateLecture({
    required String lectureId,
    String? title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool? isFree,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (videoUrl != null) payload['video_url'] = videoUrl;
    if (notesUrl != null) payload['notes_url'] = notesUrl;
    if (durationSeconds != null) payload['duration_seconds'] = durationSeconds;
    if (isFree != null) payload['is_free'] = isFree;
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (payload.isEmpty) throw ArgumentError('Nothing to update');

    final row = await _client
        .from('lectures')
        .update(payload)
        .eq('id', lectureId)
        .select()
        .single();
    return LectureModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteLecture(String lectureId) async {
    await _client.from('lectures').delete().eq('id', lectureId);
  }

  // ═══════════════════════════════════════════════════════════
  //  WATCH PROGRESS
  // ═══════════════════════════════════════════════════════════

  Future<void> updateWatchProgress({
    required String studentId,
    required String lectureId,
    required int watchedSeconds,
    bool completed = false,
  }) async {
    await _client.from('watch_progress').upsert({
      'student_id': studentId,
      'lecture_id': lectureId,
      'watched_seconds': watchedSeconds,
      'completed': completed,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<LectureProgressModel?> fetchWatchProgress({
    required String studentId,
    required String lectureId,
  }) async {
    try {
      final row = await _client
          .from('watch_progress')
          .select()
          .eq('student_id', studentId)
          .eq('lecture_id', lectureId)
          .maybeSingle();
      if (row == null) return null;
      return LectureProgressModel.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, LectureProgressModel>> fetchStudentProgress({
    required String studentId,
  }) async {
    try {
      // Limit to the 500 most-recently-updated rows.
      // A student who has watched hundreds of lectures across many
      // courses would otherwise return thousands of rows on every
      // home-screen load, exhausting memory and slowing the query.
      final rows = await _client
          .from('watch_progress')
          .select()
          .eq('student_id', studentId)
          .order('updated_at', ascending: false)
          .limit(500);
      return {
        for (final r in rows)
          (r['lecture_id'] as String): LectureProgressModel.fromJson(
            Map<String, dynamic>.from(r as Map),
          ),
      };
    } catch (_) {
      return {};
    }
  }
}
