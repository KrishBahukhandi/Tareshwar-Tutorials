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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Future<List<CourseModel>> fetchCourses({bool publishedOnly = false}) async {
    var q = _client.from('courses').select('*, users!teacher_id(name)');

    final List<Map<String, dynamic>> rows;
    if (publishedOnly) {
      rows = await q
          .eq('is_published', true)
          .order('created_at', ascending: false);
    } else {
      rows = await q.order('created_at', ascending: false);
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

  /// Courses the student is enrolled in (via any batch).
  /// Returns a deduplicated list of CourseModels.
  Future<List<CourseModel>> fetchEnrolledCourses(String studentId) async {
    final rows = await _client
        .from('enrollments')
        .select(
          'batch_id, batches!inner(course_id, courses!inner(*, users!teacher_id(name)))',
        )
        .eq('student_id', studentId);

    final seen = <String>{};
    final courses = <CourseModel>[];
    for (final r in rows) {
      final batchMap = r['batches'] as Map?;
      final courseMap = batchMap?['courses'] as Map?;
      if (courseMap == null) continue;
      final map = Map<String, dynamic>.from(courseMap);
      // Attach teacher name from nested users join if present
      final usersMap = map['users'] as Map?;
      map['teacher_name'] = usersMap?['name'];
      if (seen.add(map['id'] as String)) {
        courses.add(CourseModel.fromJson(map));
      }
    }
    return courses;
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

  /// Subjects for a course, optionally scoped to a batch, with nested data.
  Future<List<SubjectModel>> fetchSubjects(
    String courseId, {
    String? batchId,
  }) async {
    var q = _client
        .from('subjects')
        .select('*, chapters(*, lectures(*))')
        .eq('course_id', courseId);
    if (batchId != null) q = q.eq('batch_id', batchId);

    final rows = await q.order('sort_order');
    return rows
        .map((r) => SubjectModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Flat subjects list (no nested chapters/lectures).
  Future<List<SubjectModel>> fetchSubjectsFlat(
    String courseId, {
    String? batchId,
  }) async {
    var q = _client.from('subjects').select().eq('course_id', courseId);
    if (batchId != null) q = q.eq('batch_id', batchId);

    final rows = await q.order('sort_order');
    return rows
        .map(
          (r) => SubjectModel.fromJson({
            ...Map<String, dynamic>.from(r as Map),
            'chapters': <dynamic>[],
          }),
        )
        .toList();
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
      final rows = await _client
          .from('watch_progress')
          .select()
          .eq('student_id', studentId);
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
