// ─────────────────────────────────────────────────────────────
//  admin_batches_service.dart
//  Supabase data layer for admin batch management.
//
//  Provides:
//    • Full batch list (all courses) with search + filter
//    • Rich batch detail: enrolled students, capacity stats
//    • Create batch  (admin sets course, dates, capacity)
//    • Update batch  (name, description, dates, capacity,
//                     active state)
//    • Delete batch  (cascades enrollments)
//    • Enrollment management: enroll / remove students
//    • Fetch courses (for assign-course picker)
//    • Fetch students (for enroll picker)
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────
final adminBatchesServiceProvider =
    Provider<AdminBatchesService>((ref) {
  return AdminBatchesService(ref.watch(supabaseClientProvider));
});

// ─────────────────────────────────────────────────────────────
//  DTOs
// ─────────────────────────────────────────────────────────────

/// Flat row used in the batch list table.
class AdminBatchListItem {
  final String   id;
  final String   batchName;
  final String?  description;
  final String   courseId;
  final String   courseTitle;
  final String   teacherName;
  final DateTime startDate;
  final DateTime? endDate;
  final int      maxStudents;
  final int      enrolledCount;
  final bool     isActive;
  final DateTime createdAt;

  const AdminBatchListItem({
    required this.id,
    required this.batchName,
    this.description,
    required this.courseId,
    required this.courseTitle,
    required this.teacherName,
    required this.startDate,
    this.endDate,
    required this.maxStudents,
    required this.enrolledCount,
    required this.isActive,
    required this.createdAt,
  });

  double get fillPercent =>
      maxStudents > 0
          ? (enrolledCount / maxStudents).clamp(0.0, 1.0)
          : 0.0;

  bool get isFull => enrolledCount >= maxStudents;

  int get availableSeats =>
      (maxStudents - enrolledCount).clamp(0, maxStudents);
}

/// Rich batch detail including enrolled students.
class AdminBatchDetail {
  final AdminBatchListItem batch;
  final List<AdminBatchEnrollment> enrollments;

  const AdminBatchDetail({
    required this.batch,
    required this.enrollments,
  });
}

/// Enrollment row inside a batch detail.
class AdminBatchEnrollment {
  final String   id;
  final String   studentId;
  final String   studentName;
  final String   studentEmail;
  final String?  studentPhone;
  final String?  avatarUrl;
  final DateTime enrolledAt;
  final double   progressPercent;

  const AdminBatchEnrollment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.studentPhone,
    this.avatarUrl,
    required this.enrolledAt,
    required this.progressPercent,
  });
}

/// Course option for the assign-course picker.
class AdminBatchCourseOption {
  final String id;
  final String title;
  final String teacherName;
  final String? categoryTag;
  final bool   isPublished;

  const AdminBatchCourseOption({
    required this.id,
    required this.title,
    required this.teacherName,
    this.categoryTag,
    required this.isPublished,
  });
}

// ─────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────
class AdminBatchesService {
  final SupabaseClient _db;
  AdminBatchesService(this._db);

  // ═══════════════════════════════════════════════════════
  //  BATCH LIST
  // ═══════════════════════════════════════════════════════

  /// Fetch all batches with course and teacher info.
  /// Optionally filter by [search], [courseId], [activeOnly].
  Future<List<AdminBatchListItem>> fetchAllBatches({
    String? search,
    String? courseId,
    bool?   activeOnly,
  }) async {
    var q = _db.from('batches').select(
        '*, courses!course_id(title, users!teacher_id(name))');

    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    if (activeOnly == true) {
      q = q.eq('is_active', true);
    }

    final rows = await q.order('created_at', ascending: false);

    // Resolve enrollment counts in a single query
    final ids = rows.map((r) => r['id'] as String).toList();
    final enrollCounts = await _resolveEnrollmentCounts(ids);

    List<AdminBatchListItem> items = rows.map((r) {
      final map      = Map<String, dynamic>.from(r as Map);
      final courseMap = map['courses'] as Map?;
      final teacherMap = courseMap?['users'] as Map?;
      final bid      = map['id'] as String;
      return AdminBatchListItem(
        id:             bid,
        batchName:      map['batch_name'] as String,
        description:    map['description'] as String?,
        courseId:       map['course_id'] as String,
        courseTitle:    courseMap?['title'] as String? ?? '—',
        teacherName:    teacherMap?['name'] as String? ?? '—',
        startDate:      DateTime.parse(map['start_date'] as String),
        endDate:        map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        maxStudents:    map['max_students'] as int? ?? 50,
        enrolledCount:  enrollCounts[bid] ?? 0,
        isActive:       map['is_active'] as bool? ?? true,
        createdAt:      DateTime.parse(map['created_at'] as String),
      );
    }).toList();

    // Client-side search filter (name, course, teacher)
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      items = items
          .where((b) =>
              b.batchName.toLowerCase().contains(q) ||
              b.courseTitle.toLowerCase().contains(q) ||
              b.teacherName.toLowerCase().contains(q))
          .toList();
    }

    return items;
  }

  // ═══════════════════════════════════════════════════════
  //  BATCH DETAIL
  // ═══════════════════════════════════════════════════════

  Future<AdminBatchDetail> fetchBatchDetail(String batchId) async {
    // Fetch batch with course + teacher join
    final row = await _db
        .from('batches')
        .select(
            '*, courses!course_id(title, users!teacher_id(name))')
        .eq('id', batchId)
        .single();

    final map       = Map<String, dynamic>.from(row as Map);
    final courseMap  = map['courses'] as Map?;
    final teacherMap = courseMap?['users'] as Map?;

    // Fetch enrollments for this batch
    final enrollRows = await _db
        .from('enrollments')
        .select('*, users!student_id(name, email, phone, avatar_url)')
        .eq('batch_id', batchId)
        .order('enrolled_at', ascending: false);

    final enrollments = enrollRows.map((r) {
      final em    = Map<String, dynamic>.from(r as Map);
      final userM = em['users'] as Map?;
      return AdminBatchEnrollment(
        id:              em['id'] as String,
        studentId:       em['student_id'] as String,
        studentName:     userM?['name'] as String? ?? '—',
        studentEmail:    userM?['email'] as String? ?? '—',
        studentPhone:    userM?['phone'] as String?,
        avatarUrl:       userM?['avatar_url'] as String?,
        enrolledAt:      DateTime.parse(em['enrolled_at'] as String),
        progressPercent:
            (em['progress_percent'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    final batch = AdminBatchListItem(
      id:            map['id'] as String,
      batchName:     map['batch_name'] as String,
      description:   map['description'] as String?,
      courseId:      map['course_id'] as String,
      courseTitle:   courseMap?['title'] as String? ?? '—',
      teacherName:   teacherMap?['name'] as String? ?? '—',
      startDate:     DateTime.parse(map['start_date'] as String),
      endDate:       map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      maxStudents:   map['max_students'] as int? ?? 50,
      enrolledCount: enrollments.length,
      isActive:      map['is_active'] as bool? ?? true,
      createdAt:     DateTime.parse(map['created_at'] as String),
    );

    return AdminBatchDetail(batch: batch, enrollments: enrollments);
  }

  // ═══════════════════════════════════════════════════════
  //  BATCH WRITE
  // ═══════════════════════════════════════════════════════

  Future<AdminBatchListItem> createBatch({
    required String   courseId,
    required String   batchName,
    String?           description,
    required DateTime startDate,
    DateTime?         endDate,
    int               maxStudents = 50,
  }) async {
    final data = await _db
        .from('batches')
        .insert({
          'course_id':   courseId,
          'batch_name':  batchName,
          'description': description,
          'start_date':
              startDate.toIso8601String().substring(0, 10),
          'end_date':
              endDate?.toIso8601String().substring(0, 10),
          'max_students': maxStudents,
          'is_active':    true,
        })
        .select(
            '*, courses!course_id(title, users!teacher_id(name))')
        .single();

    final map        = Map<String, dynamic>.from(data as Map);
    final courseMap   = map['courses'] as Map?;
    final teacherMap  = courseMap?['users'] as Map?;

    return AdminBatchListItem(
      id:            map['id'] as String,
      batchName:     map['batch_name'] as String,
      description:   map['description'] as String?,
      courseId:      map['course_id'] as String,
      courseTitle:   courseMap?['title'] as String? ?? '—',
      teacherName:   teacherMap?['name'] as String? ?? '—',
      startDate:     DateTime.parse(map['start_date'] as String),
      endDate:       map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      maxStudents:   map['max_students'] as int? ?? 50,
      enrolledCount: 0,
      isActive:      true,
      createdAt:     DateTime.parse(map['created_at'] as String),
    );
  }

  Future<void> updateBatch({
    required String   batchId,
    String?           batchName,
    String?           description,
    String?           courseId,
    DateTime?         startDate,
    DateTime?         endDate,
    int?              maxStudents,
    bool?             isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (batchName != null)   payload['batch_name']   = batchName;
    if (description != null) payload['description']  = description;
    if (courseId != null)    payload['course_id']    = courseId;
    if (startDate != null) {
      payload['start_date'] =
          startDate.toIso8601String().substring(0, 10);
    }
    if (endDate != null) {
      payload['end_date'] =
          endDate.toIso8601String().substring(0, 10);
    }
    if (maxStudents != null) payload['max_students'] = maxStudents;
    if (isActive != null)    payload['is_active']    = isActive;
    if (payload.isEmpty) return;
    await _db.from('batches').update(payload).eq('id', batchId);
  }

  Future<void> deleteBatch(String batchId) async {
    await _db.from('batches').delete().eq('id', batchId);
  }

  Future<void> toggleBatchActive(
      String batchId, bool isActive) async {
    await _db
        .from('batches')
        .update({'is_active': isActive})
        .eq('id', batchId);
  }

  // ═══════════════════════════════════════════════════════
  //  ENROLLMENTS
  // ═══════════════════════════════════════════════════════

  Future<void> enrollStudent({
    required String studentId,
    required String batchId,
  }) async {
    await _db.from('enrollments').insert({
      'student_id': studentId,
      'batch_id':   batchId,
    });
  }

  Future<void> removeEnrollment(String enrollmentId) async {
    await _db
        .from('enrollments')
        .delete()
        .eq('id', enrollmentId);
  }

  // ═══════════════════════════════════════════════════════
  //  COURSE PICKER
  // ═══════════════════════════════════════════════════════

  Future<List<AdminBatchCourseOption>> fetchCourseOptions() async {
    final rows = await _db
        .from('courses')
        .select('id, title, category_tag, is_published, '
            'users!teacher_id(name)')
        .order('title');

    return rows.map((r) {
      final map      = Map<String, dynamic>.from(r as Map);
      final userMap   = map['users'] as Map?;
      return AdminBatchCourseOption(
        id:          map['id'] as String,
        title:       map['title'] as String,
        teacherName: userMap?['name'] as String? ?? '—',
        categoryTag: map['category_tag'] as String?,
        isPublished: map['is_published'] as bool? ?? false,
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════
  //  STUDENT PICKER
  // ═══════════════════════════════════════════════════════

  /// Fetch all students (for enrollment picker).
  /// Already-enrolled student IDs should be filtered client-side.
  Future<List<UserModel>> fetchStudents({
    String? search,
    int limit = 200,
  }) async {
    var q = _db
        .from('users')
        .select()
        .eq('role', 'student')
        .eq('is_active', true);

    final rows = await q
        .order('name')
        .limit(limit);

    var models = rows
        .map((r) =>
            UserModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      models = models
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.email.toLowerCase().contains(q))
          .toList();
    }
    return models;
  }

  // ═══════════════════════════════════════════════════════
  //  STATS
  // ═══════════════════════════════════════════════════════

  Future<Map<String, int>> fetchBatchStats() async {
    final results = await Future.wait([
      _db.from('batches').select('id'),
      _db.from('batches').select('id').eq('is_active', true),
      _db.from('enrollments').select('id'),
    ]);
    return {
      'total':       results[0].length,
      'active':      results[1].length,
      'enrollments': results[2].length,
    };
  }

  // ═══════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════

  Future<Map<String, int>> _resolveEnrollmentCounts(
      List<String> batchIds) async {
    if (batchIds.isEmpty) return {};
    final rows = await _db
        .from('enrollments')
        .select('batch_id')
        .inFilter('batch_id', batchIds);
    final counts = <String, int>{};
    for (final r in rows) {
      final bid = r['batch_id'] as String;
      counts[bid] = (counts[bid] ?? 0) + 1;
    }
    return counts;
  }
}
