// ─────────────────────────────────────────────────────────────
//  admin_courses_service.dart
//  Supabase data layer for admin course management.
//
//  Provides:
//    • Full course list (all teachers) with search + filter
//    • Rich course detail: batches, enrollments, teacher info
//    • Create course  (admin assigns teacher)
//    • Update course  (title, description, price, thumbnail,
//                      category, teacher, published state)
//    • Delete course  (cascades batches / enrollments)
//    • Toggle published state
//    • Fetch teacher list (for assign-teacher picker)
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
  final String   id;
  final String   title;
  final String   description;
  final String   teacherId;
  final String   teacherName;
  final double   price;
  final String?  thumbnailUrl;
  final String?  categoryTag;
  final bool     isPublished;
  final int      totalBatches;
  final int      totalEnrollments;
  final int      totalLectures;
  final DateTime createdAt;

  const AdminCourseListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.teacherId,
    required this.teacherName,
    required this.price,
    this.thumbnailUrl,
    this.categoryTag,
    required this.isPublished,
    required this.totalBatches,
    required this.totalEnrollments,
    required this.totalLectures,
    required this.createdAt,
  });
}

/// Rich course detail including batches.
class AdminCourseDetail {
  final AdminCourseListItem course;
  final List<AdminCourseBatch> batches;

  const AdminCourseDetail({
    required this.course,
    required this.batches,
  });
}

/// Batch summary inside a course detail.
class AdminCourseBatch {
  final String   id;
  final String   batchName;
  final String?  description;
  final DateTime startDate;
  final DateTime? endDate;
  final int      maxStudents;
  final int      enrolledCount;
  final bool     isActive;
  final DateTime createdAt;

  const AdminCourseBatch({
    required this.id,
    required this.batchName,
    this.description,
    required this.startDate,
    this.endDate,
    required this.maxStudents,
    required this.enrolledCount,
    required this.isActive,
    required this.createdAt,
  });

  double get fillPercent =>
      maxStudents > 0 ? (enrolledCount / maxStudents).clamp(0.0, 1.0) : 0.0;
  bool get isFull => enrolledCount >= maxStudents;
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
    // Fetch courses joined with teacher name
    var query = _db
        .from('courses')
        .select('*, users!teacher_id(id, name)');

    if (publishedFilter != null) {
      query = query.eq('is_published', publishedFilter);
    }

    final rows = await query.order('created_at', ascending: false);

    // Fetch batch counts per course
    final courseIds =
        rows.map((r) => r['id'] as String).toList();

    Map<String, int> batchCounts    = {};
    Map<String, int> enrollCounts   = {};
    Map<String, int> lectureCounts  = {};

    if (courseIds.isNotEmpty) {
      final [batchRows, subjectRows] = await Future.wait([
        _db
            .from('batches')
            .select('id, course_id')
            .inFilter('course_id', courseIds),
        _db
            .from('subjects')
            .select('id, course_id')
            .inFilter('course_id', courseIds),
      ]);

      for (final b in batchRows as List) {
        final cid = b['course_id'] as String;
        batchCounts[cid] = (batchCounts[cid] ?? 0) + 1;
      }

      // Enrollments via batches
      final batchIds = (batchRows as List)
          .map((b) => b['id'] as String)
          .toList();
      if (batchIds.isNotEmpty) {
        final eRows = await _db
            .from('enrollments')
            .select('batch_id, batches!batch_id(course_id)')
            .inFilter('batch_id', batchIds);
        for (final e in eRows) {
          final cid = (e['batches'] as Map?)?['course_id'] as String?;
          if (cid != null) {
            enrollCounts[cid] = (enrollCounts[cid] ?? 0) + 1;
          }
        }
      }

      // Lecture count via subjects → chapters → lectures
      final subjectIds = (subjectRows as List)
          .map((s) => s['id'] as String)
          .toList();
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
            final cid = ((l['chapters'] as Map?)?['subjects'] as Map?)?['course_id'] as String?;
            if (cid != null) {
              lectureCounts[cid] = (lectureCounts[cid] ?? 0) + 1;
            }
          }
        }
      }
    }

    List<AdminCourseListItem> items = rows.map((r) {
      final map         = Map<String, dynamic>.from(r as Map);
      final teacherMap  = map['users'] as Map?;
      final id          = map['id'] as String;
      return AdminCourseListItem(
        id:               id,
        title:            map['title'] as String,
        description:      map['description'] as String? ?? '',
        teacherId:        map['teacher_id'] as String,
        teacherName:      teacherMap?['name'] as String? ?? '—',
        price:            (map['price'] as num?)?.toDouble() ?? 0,
        thumbnailUrl:     map['thumbnail_url'] as String?,
        categoryTag:      map['category_tag'] as String?,
        isPublished:      map['is_published'] as bool? ?? false,
        totalBatches:     batchCounts[id]   ?? 0,
        totalEnrollments: enrollCounts[id]  ?? 0,
        totalLectures:    lectureCounts[id] ?? 0,
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
              (c.categoryTag ?? '').toLowerCase().contains(lq))
          .toList();
    }
    return items;
  }

  // ── Fetch single course detail ────────────────────────────
  Future<AdminCourseDetail> fetchCourseDetail(String courseId) async {
    final results = await Future.wait([
      // Course + teacher
      _db
          .from('courses')
          .select('*, users!teacher_id(id, name)')
          .eq('id', courseId)
          .single(),
      // Batches for this course
      _db
          .from('batches')
          .select('*')
          .eq('course_id', courseId)
          .order('created_at', ascending: false),
    ]);

    final courseMap  = Map<String, dynamic>.from(results[0] as Map);
    final batchRows  = results[1] as List;
    final teacherMap = courseMap['users'] as Map?;

    // Enrollment counts per batch
    final batchIds =
        batchRows.map((b) => b['id'] as String).toList();
    Map<String, int> enrollCounts = {};
    if (batchIds.isNotEmpty) {
      final eRows = await _db
          .from('enrollments')
          .select('batch_id')
          .inFilter('batch_id', batchIds);
      for (final e in eRows) {
        final bid = e['batch_id'] as String;
        enrollCounts[bid] = (enrollCounts[bid] ?? 0) + 1;
      }
    }

    final batches = batchRows.map((r) {
      final bm  = Map<String, dynamic>.from(r as Map);
      final bid = bm['id'] as String;
      return AdminCourseBatch(
        id:           bid,
        batchName:    bm['batch_name'] as String,
        description:  bm['description'] as String?,
        startDate:    DateTime.parse(bm['start_date'] as String),
        endDate:      bm['end_date'] != null
            ? DateTime.parse(bm['end_date'] as String)
            : null,
        maxStudents:  bm['max_students'] as int? ?? 50,
        enrolledCount: enrollCounts[bid] ?? 0,
        isActive:     bm['is_active'] as bool? ?? true,
        createdAt:    DateTime.parse(bm['created_at'] as String),
      );
    }).toList();

    final cid = courseMap['id'] as String;
    final item = AdminCourseListItem(
      id:               cid,
      title:            courseMap['title'] as String,
      description:      courseMap['description'] as String? ?? '',
      teacherId:        courseMap['teacher_id'] as String,
      teacherName:      teacherMap?['name'] as String? ?? '—',
      price:            (courseMap['price'] as num?)?.toDouble() ?? 0,
      thumbnailUrl:     courseMap['thumbnail_url'] as String?,
      categoryTag:      courseMap['category_tag'] as String?,
      isPublished:      courseMap['is_published'] as bool? ?? false,
      totalBatches:     batches.length,
      totalEnrollments: enrollCounts.values.fold(0, (a, b) => a + b),
      totalLectures:    courseMap['total_lectures'] as int? ?? 0,
      createdAt:        DateTime.parse(courseMap['created_at'] as String),
    );

    return AdminCourseDetail(course: item, batches: batches);
  }

  // ── Fetch all teachers (for picker) ──────────────────────
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

  // ── Create course ─────────────────────────────────────────
  Future<CourseModel> createCourse({
    required String teacherId,
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? categoryTag,
    bool isPublished = false,
  }) async {
    final data = await _db
        .from('courses')
        .insert({
          'teacher_id':    teacherId,
          'title':         title,
          'description':   description,
          'price':         price,
          'thumbnail_url': thumbnailUrl,
          'category_tag':  categoryTag,
          'is_published':  isPublished,
        })
        .select()
        .single();
    return CourseModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Update course ─────────────────────────────────────────
  Future<CourseModel> updateCourse({
    required String courseId,
    required String teacherId,
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? categoryTag,
    required bool isPublished,
  }) async {
    final data = await _db
        .from('courses')
        .update({
          'teacher_id':    teacherId,
          'title':         title,
          'description':   description,
          'price':         price,
          'thumbnail_url': thumbnailUrl,
          'category_tag':  categoryTag,
          'is_published':  isPublished,
        })
        .eq('id', courseId)
        .select()
        .single();
    return CourseModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Toggle published ──────────────────────────────────────
  Future<void> togglePublished(String courseId,
      {required bool publish}) async {
    await _db
        .from('courses')
        .update({'is_published': publish})
        .eq('id', courseId);
  }

  // ── Delete course ─────────────────────────────────────────
  Future<void> deleteCourse(String courseId) async {
    await _db.from('courses').delete().eq('id', courseId);
  }
}
