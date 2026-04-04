// ─────────────────────────────────────────────────────────────
//  admin_courses_service.dart
//  Supabase data layer for admin course management.
//
//  Courses now carry capacity, timeline, class level and
//  subjects overview directly (batches removed).
//  Students enroll into courses via enrollments.course_id.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────
final adminCoursesServiceProvider =
    Provider<AdminCoursesService>((ref) {
  return AdminCoursesService(ref.watch(supabaseClientProvider));
});

// ─────────────────────────────────────────────────────────────
//  DTOs
// ─────────────────────────────────────────────────────────────

/// Flat row used in the course list table.
class AdminCourseListItem {
  final String        id;
  final String        title;
  final String        description;
  final String        teacherId;
  final String        teacherName;
  final double        price;
  final String?       thumbnailUrl;
  final bool          isPublished;
  final bool          isActive;
  final String?       categoryTag;
  final String?       classLevel;
  final int           maxStudents;
  final DateTime?     startDate;
  final DateTime?     endDate;
  final List<String>  subjectsOverview;
  final int           enrolledCount;
  final int           totalLectures;
  final DateTime      createdAt;

  const AdminCourseListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.teacherId,
    required this.teacherName,
    required this.price,
    this.thumbnailUrl,
    required this.isPublished,
    required this.isActive,
    this.categoryTag,
    this.classLevel,
    required this.maxStudents,
    this.startDate,
    this.endDate,
    required this.subjectsOverview,
    required this.enrolledCount,
    required this.totalLectures,
    required this.createdAt,
  });

  double get fillPercent =>
      maxStudents > 0 ? (enrolledCount / maxStudents).clamp(0.0, 1.0) : 0.0;

  bool get isFull => enrolledCount >= maxStudents;
}

/// Enrollment record inside a course detail view.
class AdminCourseEnrollment {
  final String   id;
  final String   studentId;
  final String   studentName;
  final String   studentEmail;
  final DateTime enrolledAt;
  final double   progressPercent;

  const AdminCourseEnrollment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.enrolledAt,
    required this.progressPercent,
  });
}

/// Rich course detail.
class AdminCourseDetail {
  final AdminCourseListItem      course;
  final List<AdminCourseEnrollment> enrollments;

  const AdminCourseDetail({
    required this.course,
    required this.enrollments,
  });
}

/// Minimal teacher info for the teacher picker.
class AdminTeacherOption {
  final String id;
  final String name;
  final String email;

  const AdminTeacherOption({
    required this.id,
    required this.name,
    required this.email,
  });
}

// ─────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────
class AdminCoursesService {
  final SupabaseClient _db;
  AdminCoursesService(this._db);

  // ── Fetch all courses ─────────────────────────────────────
  Future<List<AdminCourseListItem>> fetchAllCourses({
    String search = '',
    bool? publishedFilter,
  }) async {
    var query = _db.from('courses').select(
      '*, users!teacher_id(id, name)',
    );

    if (publishedFilter != null) {
      query = query.eq('is_published', publishedFilter);
    }

    final rows = await query.order('created_at', ascending: false);

    // Fetch lecture counts via subjects → chapters → lectures
    final courseIds = rows.map((r) => r['id'] as String).toList();
    Map<String, int> lectureCounts = {};

    if (courseIds.isNotEmpty) {
      final subjectRows = await _db
          .from('subjects')
          .select('id, course_id')
          .inFilter('course_id', courseIds);

      final subjectIds =
          (subjectRows as List).map((s) => s['id'] as String).toList();

      if (subjectIds.isNotEmpty) {
        final chapterRows = await _db
            .from('chapters')
            .select('id, subject_id')
            .inFilter('subject_id', subjectIds);

        final chapterIds =
            (chapterRows as List).map((c) => c['id'] as String).toList();

        if (chapterIds.isNotEmpty) {
          final lectureRows = await _db
              .from('lectures')
              .select('id, chapter_id, chapters!chapter_id(subject_id, subjects!subject_id(course_id))')
              .inFilter('chapter_id', chapterIds);

          for (final l in lectureRows) {
            final cid =
                ((l['chapters'] as Map?)?['subjects'] as Map?)?['course_id']
                    as String?;
            if (cid != null) {
              lectureCounts[cid] = (lectureCounts[cid] ?? 0) + 1;
            }
          }
        }
      }
    }

    List<AdminCourseListItem> items = rows.map((r) {
      final map        = Map<String, dynamic>.from(r as Map);
      final teacherMap = map['users'] as Map?;
      final id         = map['id'] as String;
      return AdminCourseListItem(
        id:               id,
        title:            map['title'] as String,
        description:      map['description'] as String? ?? '',
        teacherId:        map['teacher_id'] as String,
        teacherName:      teacherMap?['name'] as String? ?? '—',
        price:            (map['price'] as num?)?.toDouble() ?? 0,
        thumbnailUrl:     map['thumbnail_url'] as String?,
        isPublished:      map['is_published'] as bool? ?? false,
        isActive:         map['is_active'] as bool? ?? true,
        categoryTag:      map['category_tag'] as String?,
        classLevel:       map['class_level'] as String?,
        maxStudents:      map['max_students'] as int? ?? 50,
        startDate:        map['start_date'] != null
            ? DateTime.tryParse(map['start_date'] as String)
            : null,
        endDate:          map['end_date'] != null
            ? DateTime.tryParse(map['end_date'] as String)
            : null,
        subjectsOverview: (map['subjects_overview'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        enrolledCount:    (map['enrolled_count'] ?? map['total_students']) as int? ?? 0,
        totalLectures:    lectureCounts[id] ?? (map['total_lectures'] as int? ?? 0),
        createdAt:        DateTime.parse(map['created_at'] as String),
      );
    }).toList();

    // Client-side search
    if (search.isNotEmpty) {
      final lq = search.toLowerCase();
      items = items
          .where((c) =>
              c.title.toLowerCase().contains(lq) ||
              c.teacherName.toLowerCase().contains(lq) ||
              (c.classLevel ?? '').toLowerCase().contains(lq))
          .toList();
    }
    return items;
  }

  // ── Fetch single course detail ────────────────────────────
  Future<AdminCourseDetail> fetchCourseDetail(String courseId) async {
    final results = await Future.wait([
      _db
          .from('courses')
          .select('*, users!teacher_id(id, name)')
          .eq('id', courseId)
          .single(),
      _db
          .from('enrollments')
          .select('*, users!student_id(name, email)')
          .eq('course_id', courseId)
          .order('enrolled_at', ascending: false),
    ]);

    final courseMap    = Map<String, dynamic>.from(results[0] as Map);
    final enrollRows   = results[1] as List;
    final teacherMap   = courseMap['users'] as Map?;

    final enrollments = enrollRows.map((r) {
      final em  = Map<String, dynamic>.from(r as Map);
      final um  = em['users'] as Map?;
      return AdminCourseEnrollment(
        id:              em['id'] as String,
        studentId:       em['student_id'] as String,
        studentName:     um?['name'] as String? ?? '—',
        studentEmail:    um?['email'] as String? ?? '—',
        enrolledAt:      DateTime.parse(em['enrolled_at'] as String),
        progressPercent: (em['progress_percent'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    final cid  = courseMap['id'] as String;
    final item = AdminCourseListItem(
      id:               cid,
      title:            courseMap['title'] as String,
      description:      courseMap['description'] as String? ?? '',
      teacherId:        courseMap['teacher_id'] as String,
      teacherName:      teacherMap?['name'] as String? ?? '—',
      price:            (courseMap['price'] as num?)?.toDouble() ?? 0,
      thumbnailUrl:     courseMap['thumbnail_url'] as String?,
      isPublished:      courseMap['is_published'] as bool? ?? false,
      isActive:         courseMap['is_active'] as bool? ?? true,
      categoryTag:      courseMap['category_tag'] as String?,
      classLevel:       courseMap['class_level'] as String?,
      maxStudents:      courseMap['max_students'] as int? ?? 50,
      startDate:        courseMap['start_date'] != null
          ? DateTime.tryParse(courseMap['start_date'] as String)
          : null,
      endDate:          courseMap['end_date'] != null
          ? DateTime.tryParse(courseMap['end_date'] as String)
          : null,
      subjectsOverview: (courseMap['subjects_overview'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      enrolledCount:    enrollments.length,
      totalLectures:    courseMap['total_lectures'] as int? ?? 0,
      createdAt:        DateTime.parse(courseMap['created_at'] as String),
    );

    return AdminCourseDetail(course: item, enrollments: enrollments);
  }

  // ── Fetch teachers (for picker) ───────────────────────────
  Future<List<AdminTeacherOption>> fetchTeachers() async {
    final rows = await _db
        .from('users')
        .select('id, name, email')
        .eq('role', 'teacher')
        .order('name');
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return AdminTeacherOption(
        id:    m['id']    as String,
        name:  m['name']  as String,
        email: m['email'] as String,
      );
    }).toList();
  }

  // ── Enroll a student into a course ───────────────────────
  Future<void> enrollStudent({
    required String studentId,
    required String courseId,
  }) async {
    // Guard: capacity
    final course = await _db
        .from('courses')
        .select('max_students, enrolled_count')
        .eq('id', courseId)
        .single();
    final max     = course['max_students'] as int? ?? 50;
    final current = course['enrolled_count'] as int? ?? 0;
    if (current >= max) {
      throw StateError('Course is full ($max max students)');
    }

    await _db.from('enrollments').insert({
      'student_id': studentId,
      'course_id':  courseId,
    });
  }

  // ── Remove a student from a course ───────────────────────
  Future<void> removeEnrollment(String enrollmentId) async {
    await _db.from('enrollments').delete().eq('id', enrollmentId);
  }

  // ── Create course ─────────────────────────────────────────
  Future<CourseModel> createCourse({
    required String  teacherId,
    required String  title,
    required String  description,
    required double  price,
    String?          thumbnailUrl,
    String?          classLevel,
    int              maxStudents      = 50,
    DateTime?        startDate,
    DateTime?        endDate,
    List<String>     subjectsOverview = const [],
    bool             isPublished      = false,
    bool             isActive         = true,
  }) async {
    final data = await _db
        .from('courses')
        .insert({
          'teacher_id':        teacherId,
          'title':             title,
          'description':       description,
          'price':             price,
          'thumbnail_url':     thumbnailUrl,
          'class_level':       classLevel,
          'max_students':      maxStudents,
          'start_date':        startDate?.toIso8601String().substring(0, 10),
          'end_date':          endDate?.toIso8601String().substring(0, 10),
          'subjects_overview': subjectsOverview,
          'is_published':      isPublished,
          'is_active':         isActive,
        })
        .select()
        .single();
    return CourseModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Update course ─────────────────────────────────────────
  Future<CourseModel> updateCourse({
    required String  courseId,
    required String  teacherId,
    required String  title,
    required String  description,
    required double  price,
    String?          thumbnailUrl,
    String?          classLevel,
    int              maxStudents      = 50,
    DateTime?        startDate,
    DateTime?        endDate,
    List<String>     subjectsOverview = const [],
    required bool    isPublished,
    required bool    isActive,
  }) async {
    final data = await _db
        .from('courses')
        .update({
          'teacher_id':        teacherId,
          'title':             title,
          'description':       description,
          'price':             price,
          'thumbnail_url':     thumbnailUrl,
          'class_level':       classLevel,
          'max_students':      maxStudents,
          'start_date':        startDate?.toIso8601String().substring(0, 10),
          'end_date':          endDate?.toIso8601String().substring(0, 10),
          'subjects_overview': subjectsOverview,
          'is_published':      isPublished,
          'is_active':         isActive,
        })
        .eq('id', courseId)
        .select()
        .single();
    return CourseModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Toggle published ──────────────────────────────────────
  Future<void> togglePublished(String courseId, {required bool publish}) async {
    await _db.from('courses').update({'is_published': publish}).eq('id', courseId);
  }

  // ── Delete course ─────────────────────────────────────────
  Future<void> deleteCourse(String courseId) async {
    await _db.from('courses').delete().eq('id', courseId);
  }
}
