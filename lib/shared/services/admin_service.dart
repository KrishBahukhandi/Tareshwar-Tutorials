// ─────────────────────────────────────────────────────────────
//  admin_service.dart
//  Full platform admin operations.
//  Only accessible to users with role = 'admin'.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_service.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.watch(supabaseClientProvider));
});

class AdminService {
  final SupabaseClient _db;
  AdminService(this._db);

  // ═══════════════════════════════════════════════════════
  //  PLATFORM STATS
  // ═══════════════════════════════════════════════════════

  Future<AdminStats> fetchStats() async {
    final results = await Future.wait([
      _db.from('users').select('id, role'),
      _db.from('courses').select('id, is_published'),
      _db.from('batches').select('id, is_active'),
      _db.from('enrollments').select('id'),
      _db.from('doubts').select('id, is_answered'),
      _db.from('test_attempts').select('id'),
    ]);

    final users       = results[0];
    final courses     = results[1];
    final batches     = results[2];
    final enrollments = results[3];
    final doubts      = results[4];
    final attempts    = results[5];

    return AdminStats(
      totalStudents:
          users.where((u) => u['role'] == 'student').length,
      totalTeachers:
          users.where((u) => u['role'] == 'teacher').length,
      totalAdmins:
          users.where((u) => u['role'] == 'admin').length,
      totalCourses: courses.length,
      publishedCourses:
          courses.where((c) => c['is_published'] == true).length,
      totalBatches: batches.length,
      activeBatches:
          batches.where((b) => b['is_active'] == true).length,
      totalEnrollments: enrollments.length,
      totalDoubts: doubts.length,
      resolvedDoubts:
          doubts.where((d) => d['is_answered'] == true).length,
      totalTestAttempts: attempts.length,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  USERS
  // ═══════════════════════════════════════════════════════

  Future<List<UserModel>> fetchUsers({
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    var q = _db.from('users').select();
    if (role != null) q = q.eq('role', role);
    final rows = await q
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    var models = rows
        .map((r) =>
            UserModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      models = models
          .where((u) =>
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q))
          .toList();
    }
    return models;
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    assert(
        ['student', 'teacher', 'admin'].contains(newRole),
        'Invalid role');
    await _db
        .from('users')
        .update({'role': newRole})
        .eq('id', userId);
  }

  Future<void> toggleUserActive(String userId, bool isActive) async {
    await _db
        .from('users')
        .update({'is_active': isActive})
        .eq('id', userId);
  }

  Future<void> deleteUser(String userId) async {
    // Deleting from users cascades to auth.users via the FK
    await _db.from('users').delete().eq('id', userId);
  }

  // ═══════════════════════════════════════════════════════
  //  COURSES (admin overview)
  // ═══════════════════════════════════════════════════════

  Future<List<AdminCourseRow>> fetchAllCourses() async {
    final rows = await _db
        .from('courses')
        .select('*, users!teacher_id(name)')
        .order('created_at', ascending: false);

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      return AdminCourseRow(
        id: map['id'] as String,
        title: map['title'] as String,
        teacherName:
            (map['users'] as Map?)?['name'] as String? ?? '—',
        isPublished: map['is_published'] as bool? ?? false,
        price: (map['price'] as num?)?.toDouble() ?? 0,
        totalLectures: map['total_lectures'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    }).toList();
  }

  Future<void> toggleCoursePublish(
      String courseId, bool publish) async {
    await _db
        .from('courses')
        .update({'is_published': publish})
        .eq('id', courseId);
  }

  Future<void> deleteCourse(String courseId) async {
    await _db.from('courses').delete().eq('id', courseId);
  }

  // ═══════════════════════════════════════════════════════
  //  BATCHES (admin CRUD)
  // ═══════════════════════════════════════════════════════

  Future<List<AdminBatchRow>> fetchAllBatches() async {
    final rows = await _db
        .from('batches')
        .select('*, courses!course_id(title)')
        .order('created_at', ascending: false);

    // Fetch enrollment counts
    final batchIds =
        rows.map((r) => r['id'] as String).toList();
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

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final bid = map['id'] as String;
      return AdminBatchRow(
        id: bid,
        batchName: map['batch_name'] as String,
        courseId: map['course_id'] as String,
        courseTitle:
            (map['courses'] as Map?)?['title'] as String? ?? '—',
        startDate:
            DateTime.parse(map['start_date'] as String),
        endDate: map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        maxStudents: map['max_students'] as int? ?? 50,
        enrolledCount: enrollCounts[bid] ?? 0,
        isActive: map['is_active'] as bool? ?? true,
        createdAt:
            DateTime.parse(map['created_at'] as String),
      );
    }).toList();
  }

  Future<AdminBatchRow> createBatch({
    required String courseId,
    required String batchName,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    int maxStudents = 50,
  }) async {
    final data = await _db
        .from('batches')
        .insert({
          'course_id': courseId,
          'batch_name': batchName,
          'description': description,
          'start_date':
              startDate.toIso8601String().substring(0, 10),
          'end_date': endDate?.toIso8601String().substring(0, 10),
          'max_students': maxStudents,
          'is_active': true,
        })
        .select('*, courses!course_id(title)')
        .single();

    final map = Map<String, dynamic>.from(data as Map);
    return AdminBatchRow(
      id: map['id'] as String,
      batchName: map['batch_name'] as String,
      courseId: map['course_id'] as String,
      courseTitle:
          (map['courses'] as Map?)?['title'] as String? ?? '—',
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      maxStudents: map['max_students'] as int? ?? 50,
      enrolledCount: 0,
      isActive: map['is_active'] as bool? ?? true,
      createdAt:
          DateTime.parse(map['created_at'] as String),
    );
  }

  Future<void> updateBatch({
    required String batchId,
    String? batchName,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? maxStudents,
    bool? isActive,
  }) async {
    final update = <String, dynamic>{};
    if (batchName != null) update['batch_name'] = batchName;
    if (description != null) update['description'] = description;
    if (startDate != null) {
      update['start_date'] =
          startDate.toIso8601String().substring(0, 10);
    }
    if (endDate != null) {
      update['end_date'] =
          endDate.toIso8601String().substring(0, 10);
    }
    if (maxStudents != null) update['max_students'] = maxStudents;
    if (isActive != null) update['is_active'] = isActive;
    if (update.isEmpty) return;
    await _db.from('batches').update(update).eq('id', batchId);
  }

  Future<void> deleteBatch(String batchId) async {
    await _db.from('batches').delete().eq('id', batchId);
  }

  // ═══════════════════════════════════════════════════════
  //  ENROLLMENTS
  // ═══════════════════════════════════════════════════════

  Future<List<AdminEnrollmentRow>> fetchBatchEnrollments(
      String batchId) async {
    final rows = await _db
        .from('enrollments')
        .select('*, users!student_id(name, email)')
        .eq('batch_id', batchId)
        .order('enrolled_at', ascending: false);

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final user = map['users'] as Map?;
      return AdminEnrollmentRow(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        studentName: user?['name'] as String? ?? '—',
        studentEmail: user?['email'] as String? ?? '—',
        batchId: map['batch_id'] as String,
        enrolledAt:
            DateTime.parse(map['enrolled_at'] as String),
        progressPercent:
            (map['progress_percent'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<void> enrollStudent({
    required String studentId,
    required String batchId,
  }) async {
    await _db.from('enrollments').insert({
      'student_id': studentId,
      'batch_id': batchId,
    });
  }

  Future<void> removeEnrollment(String enrollmentId) async {
    await _db
        .from('enrollments')
        .delete()
        .eq('id', enrollmentId);
  }

  // ═══════════════════════════════════════════════════════
  //  DOUBTS OVERVIEW
  // ═══════════════════════════════════════════════════════

  Future<List<AdminDoubtRow>> fetchDoubts({
    bool? answered,
    int limit = 50,
    int offset = 0,
  }) async {
    var q = _db
        .from('doubts')
        .select(
            '*, users!student_id(name), lectures!lecture_id(title)');
    if (answered != null) q = q.eq('is_answered', answered);
    final rows = await q
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      return AdminDoubtRow(
        id: map['id'] as String,
        studentName:
            (map['users'] as Map?)?['name'] as String? ?? '—',
        lectureTitle:
            (map['lectures'] as Map?)?['title'] as String? ??
                'General',
        question: map['question'] as String,
        isAnswered: map['is_answered'] as bool? ?? false,
        createdAt:
            DateTime.parse(map['created_at'] as String),
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════
  //  ANNOUNCEMENTS
  // ═══════════════════════════════════════════════════════

  Future<void> sendAnnouncement({
    required String authorId,
    required String title,
    required String body,
    String? batchId, // null = platform-wide
  }) async {
    await _db.from('announcements').insert({
      'author_id': authorId,
      'batch_id': batchId,
      'title': title,
      'body': body,
    });
  }

  /// Fetch recent announcements (admin view, newest first).
  Future<List<AnnouncementModel>> fetchAnnouncements({
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _db
        .from('announcements')
        .select(
            '*, users!author_id(name), batches!batch_id(batch_name)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows
        .map((r) => AnnouncementModel.fromJson(
            Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Delete an announcement.
  Future<void> deleteAnnouncement(String announcementId) async {
    await _db
        .from('announcements')
        .delete()
        .eq('id', announcementId);
  }
}

// ─────────────────────────────────────────────────────────────
//  Admin DTOs
// ─────────────────────────────────────────────────────────────

class AdminStats {
  final int totalStudents;
  final int totalTeachers;
  final int totalAdmins;
  final int totalCourses;
  final int publishedCourses;
  final int totalBatches;
  final int activeBatches;
  final int totalEnrollments;
  final int totalDoubts;
  final int resolvedDoubts;
  final int totalTestAttempts;

  const AdminStats({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalAdmins,
    required this.totalCourses,
    required this.publishedCourses,
    required this.totalBatches,
    required this.activeBatches,
    required this.totalEnrollments,
    required this.totalDoubts,
    required this.resolvedDoubts,
    required this.totalTestAttempts,
  });

  double get doubtResolutionRate =>
      totalDoubts == 0
          ? 0
          : resolvedDoubts / totalDoubts * 100;
}

class AdminCourseRow {
  final String id;
  final String title;
  final String teacherName;
  final bool isPublished;
  final double price;
  final int totalLectures;
  final DateTime createdAt;

  const AdminCourseRow({
    required this.id,
    required this.title,
    required this.teacherName,
    required this.isPublished,
    required this.price,
    required this.totalLectures,
    required this.createdAt,
  });
}

class AdminBatchRow {
  final String id;
  final String batchName;
  final String courseId;
  final String courseTitle;
  final DateTime startDate;
  final DateTime? endDate;
  final int maxStudents;
  final int enrolledCount;
  final bool isActive;
  final DateTime createdAt;

  const AdminBatchRow({
    required this.id,
    required this.batchName,
    required this.courseId,
    required this.courseTitle,
    required this.startDate,
    this.endDate,
    required this.maxStudents,
    required this.enrolledCount,
    required this.isActive,
    required this.createdAt,
  });

  double get fillPercent =>
      maxStudents == 0 ? 0 : enrolledCount / maxStudents;
}

class AdminEnrollmentRow {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String batchId;
  final DateTime enrolledAt;
  final double progressPercent;

  const AdminEnrollmentRow({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.batchId,
    required this.enrolledAt,
    required this.progressPercent,
  });
}

class AdminDoubtRow {
  final String id;
  final String studentName;
  final String lectureTitle;
  final String question;
  final bool isAnswered;
  final DateTime createdAt;

  const AdminDoubtRow({
    required this.id,
    required this.studentName,
    required this.lectureTitle,
    required this.question,
    required this.isAnswered,
    required this.createdAt,
  });
}
