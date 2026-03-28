// ─────────────────────────────────────────────────────────────
//  batch_service.dart  –  Batch / Enrollment / Subject CRUD
//
//  Hierarchy enforced here:
//    Course → Batch → Subject → Chapter → Lecture
//
//  Students enroll in batches, not courses directly.
//  Role-based permissions are enforced via Supabase RLS.
//  Flutter-side guards are provided via helper getters.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_service.dart';

final batchServiceProvider = Provider<BatchService>((ref) {
  return BatchService(ref.watch(supabaseClientProvider));
});

class BatchService {
  final SupabaseClient _db;
  BatchService(this._db);

  Future<String?> _currentRole() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;

    final profile = await _db
        .from('users')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return profile?['role'] as String?;
  }

  Future<void> _requireEnrollmentManager() async {
    final role = await _currentRole();
    if (role != 'admin' && role != 'teacher') {
      throw StateError(
        'Students cannot self-enroll into batches. Please contact your institute administrator.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BATCHES — Read
  // ═══════════════════════════════════════════════════════════

  /// All batches (admin / teacher use).
  /// Joins course title + teacher name. Resolves enrolled count.
  Future<List<BatchModel>> fetchAllBatches({
    String? courseId,
    bool activeOnly = false,
  }) async {
    var q = _db
        .from('batches')
        .select('*, courses!course_id(title, users!teacher_id(name))');

    if (courseId != null) q = q.eq('course_id', courseId);
    if (activeOnly) q = q.eq('is_active', true);

    final rows = await q.order('created_at', ascending: false);

    // Resolve enrollment counts in one query
    final ids = rows.map((r) => r['id'] as String).toList();
    final counts = await _resolveEnrollmentCounts(ids);

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      map['enrolled_count'] = counts[map['id']] ?? 0;
      return BatchModel.fromJson(map);
    }).toList();
  }

  /// Batches the current student is enrolled in.
  Future<List<BatchModel>> fetchStudentBatches(String studentId) async {
    final rows = await _db
        .from('enrollments')
        .select(
            'batch_id, batches!inner(*, courses!course_id(title, users!teacher_id(name)))')
        .eq('student_id', studentId);

    return rows.map((r) {
      final batchMap = Map<String, dynamic>.from(r['batches'] as Map);
      return BatchModel.fromJson(batchMap);
    }).toList();
  }

  /// Batches assigned to a teacher (via course ownership).
  Future<List<BatchModel>> fetchTeacherBatches(String teacherId) async {
    final rows = await _db
        .from('batches')
        .select('*, courses!course_id(title, teacher_id)')
        .eq('courses.teacher_id', teacherId)
        .order('created_at', ascending: false);

    final ids = rows.map((r) => r['id'] as String).toList();
    final counts = await _resolveEnrollmentCounts(ids);

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      map['enrolled_count'] = counts[map['id']] ?? 0;
      return BatchModel.fromJson(map);
    }).toList();
  }

  /// Single batch by ID.
  Future<BatchModel?> fetchBatchById(String batchId) async {
    try {
      final row = await _db
          .from('batches')
          .select('*, courses!course_id(title, users!teacher_id(name))')
          .eq('id', batchId)
          .single();
      final map = Map<String, dynamic>.from(row as Map);
      final counts = await _resolveEnrollmentCounts([batchId]);
      map['enrolled_count'] = counts[batchId] ?? 0;
      return BatchModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BATCHES — Write (admin / teacher)
  // ═══════════════════════════════════════════════════════════

  Future<BatchModel> createBatch({
    required String courseId,
    required String batchName,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    int maxStudents = 50,
  }) async {
    final row = await _db
        .from('batches')
        .insert({
          'course_id': courseId,
          'batch_name': batchName,
          'description': description,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate?.toIso8601String().substring(0, 10),
          'max_students': maxStudents,
          'is_active': true,
        })
        .select('*, courses!course_id(title, users!teacher_id(name))')
        .single();
    final map = Map<String, dynamic>.from(row as Map);
    map['enrolled_count'] = 0;
    return BatchModel.fromJson(map);
  }

  Future<BatchModel> updateBatch({
    required String batchId,
    String? batchName,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? maxStudents,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (batchName != null) payload['batch_name'] = batchName;
    if (description != null) payload['description'] = description;
    if (startDate != null) {
      payload['start_date'] = startDate.toIso8601String().substring(0, 10);
    }
    if (endDate != null) {
      payload['end_date'] = endDate.toIso8601String().substring(0, 10);
    }
    if (maxStudents != null) payload['max_students'] = maxStudents;
    if (isActive != null) payload['is_active'] = isActive;
    if (payload.isEmpty) throw ArgumentError('Nothing to update');

    final row = await _db
        .from('batches')
        .update(payload)
        .eq('id', batchId)
        .select('*, courses!course_id(title, users!teacher_id(name))')
        .single();
    final map = Map<String, dynamic>.from(row as Map);
    final counts = await _resolveEnrollmentCounts([batchId]);
    map['enrolled_count'] = counts[batchId] ?? 0;
    return BatchModel.fromJson(map);
  }

  Future<void> deleteBatch(String batchId) async {
    await _db.from('batches').delete().eq('id', batchId);
  }

  // ═══════════════════════════════════════════════════════════
  //  ENROLLMENTS
  // ═══════════════════════════════════════════════════════════

  /// Check whether a student is enrolled in any batch of a course.
  Future<bool> isStudentEnrolled({
    required String studentId,
    required String courseId,
  }) async {
    final rows = await _db
        .from('enrollments')
        .select('id, batches!inner(course_id)')
        .eq('student_id', studentId)
        .eq('batches.course_id', courseId);
    return rows.isNotEmpty;
  }

  /// Check whether a student is enrolled in a specific batch.
  Future<bool> isStudentEnrolledInBatch({
    required String studentId,
    required String batchId,
  }) async {
    final rows = await _db
        .from('enrollments')
        .select('id')
        .eq('student_id', studentId)
        .eq('batch_id', batchId);
    return rows.isNotEmpty;
  }

  /// Fetch enrollments for a batch (admin / teacher).
  Future<List<EnrollmentModel>> fetchBatchEnrollments(
      String batchId) async {
    final rows = await _db
        .from('enrollments')
        .select('*, users!student_id(name, email)')
        .eq('batch_id', batchId)
        .order('enrolled_at', ascending: false);
    return rows
        .map((r) =>
            EnrollmentModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Fetch all enrollments for a student (includes batch + course info).
  Future<List<EnrollmentModel>> fetchStudentEnrollments(
      String studentId) async {
    final rows = await _db
        .from('enrollments')
        .select(
            '*, batches!inner(batch_name, courses!course_id(title))')
        .eq('student_id', studentId)
        .order('enrolled_at', ascending: false);
    return rows
        .map((r) =>
            EnrollmentModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Enroll a student into a batch.
  /// Returns the new EnrollmentModel.
  Future<EnrollmentModel> enrollStudent({
    required String studentId,
    required String batchId,
  }) async {
    await _requireEnrollmentManager();

    // Guard: prevent duplicate enrollment
    final already = await isStudentEnrolledInBatch(
        studentId: studentId, batchId: batchId);
    if (already) {
      throw StateError('Student is already enrolled in this batch');
    }

    // Guard: check capacity
    final batch = await fetchBatchById(batchId);
    if (batch != null && batch.isFull) {
      throw StateError('Batch is full (${batch.maxStudents} max)');
    }

    final row = await _db
        .from('enrollments')
        .insert({
          'student_id': studentId,
          'batch_id': batchId,
        })
        .select(
            '*, batches!inner(batch_name, courses!course_id(title))')
        .single();
    return EnrollmentModel.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Remove a student from a batch.
  Future<void> removeEnrollment(String enrollmentId) async {
    await _requireEnrollmentManager();
    await _db.from('enrollments').delete().eq('id', enrollmentId);
  }

  /// Remove a student from a batch by student + batch id.
  Future<void> unenrollStudent({
    required String studentId,
    required String batchId,
  }) async {
    await _requireEnrollmentManager();
    await _db
        .from('enrollments')
        .delete()
        .eq('student_id', studentId)
        .eq('batch_id', batchId);
  }

  /// Update progress percentage for a student's enrollment.
  Future<void> updateProgress({
    required String studentId,
    required String batchId,
    required double percent,
  }) async {
    await _db
        .from('enrollments')
        .update({'progress_percent': percent})
        .eq('student_id', studentId)
        .eq('batch_id', batchId);
  }

  // ═══════════════════════════════════════════════════════════
  //  SUBJECTS  (scoped to a course; batch_id is optional)
  // ═══════════════════════════════════════════════════════════

  /// Fetch subjects for a course, optionally scoped to a batch.
  Future<List<SubjectModel>> fetchSubjects({
    required String courseId,
    String? batchId,
    bool nested = false, // if true, includes chapters → lectures
  }) async {
    final selectExpr = nested
        ? '*, chapters(*, lectures(*))'
        : '*';

    var q = _db
        .from('subjects')
        .select(selectExpr)
        .eq('course_id', courseId);

    if (batchId != null) q = q.eq('batch_id', batchId);

    final rows = await q.order('sort_order');

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      if (!nested) map['chapters'] = <dynamic>[];
      return SubjectModel.fromJson(map);
    }).toList();
  }

  Future<SubjectModel> createSubject({
    required String courseId,
    String? batchId,
    required String name,
    int sortOrder = 0,
  }) async {
    final row = await _db
        .from('subjects')
        .insert({
          'course_id': courseId,
          'batch_id': batchId,
          'name': name,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    final map = Map<String, dynamic>.from(row as Map);
    map['chapters'] = <dynamic>[];
    return SubjectModel.fromJson(map);
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
    await _db.from('subjects').update(payload).eq('id', subjectId);
  }

  Future<void> deleteSubject(String subjectId) async {
    await _db.from('subjects').delete().eq('id', subjectId);
  }

  // ═══════════════════════════════════════════════════════════
  //  CHAPTERS
  // ═══════════════════════════════════════════════════════════

  Future<List<ChapterModel>> fetchChapters(String subjectId) async {
    final rows = await _db
        .from('chapters')
        .select()
        .eq('subject_id', subjectId)
        .order('sort_order');
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      map['lectures'] = <dynamic>[];
      return ChapterModel.fromJson(map);
    }).toList();
  }

  Future<ChapterModel> createChapter({
    required String subjectId,
    required String name,
    int sortOrder = 0,
  }) async {
    final row = await _db
        .from('chapters')
        .insert({
          'subject_id': subjectId,
          'name': name,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    final map = Map<String, dynamic>.from(row as Map);
    map['lectures'] = <dynamic>[];
    return ChapterModel.fromJson(map);
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
    await _db.from('chapters').update(payload).eq('id', chapterId);
  }

  Future<void> deleteChapter(String chapterId) async {
    await _db.from('chapters').delete().eq('id', chapterId);
  }

  // ═══════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════

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
