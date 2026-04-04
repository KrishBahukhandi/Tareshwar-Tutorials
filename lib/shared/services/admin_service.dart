// ─────────────────────────────────────────────────────────────
//  admin_service.dart
//  Full platform admin operations.
//  Only accessible to users with role = 'admin'.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'audit_service.dart';
import 'supabase_service.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(
    ref.watch(supabaseClientProvider),
    ref.watch(auditServiceProvider),
  );
});

class AdminService {
  final SupabaseClient _db;
  final AuditService _audit;
  AdminService(this._db, this._audit);

  // ═══════════════════════════════════════════════════════
  //  PLATFORM STATS
  // ═══════════════════════════════════════════════════════

  Future<AdminStats> fetchStats() async {
    final results = await Future.wait([
      _db.from('users').select('id, role'),
      _db.from('courses').select('id, is_published'),
      _db.from('enrollments').select('id'),
      _db.from('doubts').select('id, is_answered'),
      _db.from('test_attempts').select('id'),
    ]);

    final users       = results[0];
    final courses     = results[1];
    final enrollments = results[2];
    final doubts      = results[3];
    final attempts    = results[4];

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
    await _audit.logAdminAction(
      action: 'user.role_updated',
      entityType: 'user',
      entityId: userId,
      details: {'role': newRole},
    );
  }

  Future<void> toggleUserActive(String userId, bool isActive) async {
    await _db
        .from('users')
        .update({'is_active': isActive})
        .eq('id', userId);
    await _audit.logAdminAction(
      action: isActive ? 'user.activated' : 'user.suspended',
      entityType: 'user',
      entityId: userId,
    );
  }

  Future<void> deleteUser(String userId) async {
    await _db.from('users').delete().eq('id', userId);
    await _audit.logAdminAction(
      action: 'user.deleted',
      entityType: 'user',
      entityId: userId,
    );
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
    await _audit.logAdminAction(
      action: publish ? 'course.published' : 'course.unpublished',
      entityType: 'course',
      entityId: courseId,
    );
  }

  Future<void> deleteCourse(String courseId) async {
    await _db.from('courses').delete().eq('id', courseId);
    await _audit.logAdminAction(
      action: 'course.deleted',
      entityType: 'course',
      entityId: courseId,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  ENROLLMENTS
  // ═══════════════════════════════════════════════════════

  Future<List<AdminEnrollmentRow>> fetchCourseEnrollments(
      String courseId) async {
    final rows = await _db
        .from('enrollments')
        .select('*, users!student_id(name, email)')
        .eq('course_id', courseId)
        .order('enrolled_at', ascending: false);

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final user = map['users'] as Map?;
      return AdminEnrollmentRow(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        studentName: user?['name'] as String? ?? '—',
        studentEmail: user?['email'] as String? ?? '—',
        courseId: map['course_id'] as String,
        enrolledAt:
            DateTime.parse(map['enrolled_at'] as String),
        progressPercent:
            (map['progress_percent'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<void> enrollStudent({
    required String studentId,
    required String courseId,
  }) async {
    await _db.from('enrollments').insert({
      'student_id': studentId,
      'course_id': courseId,
    });
    await _audit.logAdminAction(
      action: 'enrollment.created',
      entityType: 'enrollment',
      details: {'student_id': studentId, 'course_id': courseId},
    );
  }

  Future<void> removeEnrollment(String enrollmentId) async {
    await _db
        .from('enrollments')
        .delete()
        .eq('id', enrollmentId);
    await _audit.logAdminAction(
      action: 'enrollment.deleted',
      entityType: 'enrollment',
      entityId: enrollmentId,
    );
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
    String? courseId, // null = platform-wide
  }) async {
    await _db.from('announcements').insert({
      'author_id': authorId,
      'course_id': courseId,
      'title': title,
      'body': body,
    });
    await _audit.logAdminAction(
      action: 'announcement.created',
      entityType: 'announcement',
      details: {'course_id': courseId, 'title': title},
    );
  }

  /// Fetch recent announcements (admin view, newest first).
  Future<List<AnnouncementModel>> fetchAnnouncements({
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _db
        .from('announcements')
        .select('*, users!author_id(name), courses!course_id(title)')
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
    await _audit.logAdminAction(
      action: 'announcement.deleted',
      entityType: 'announcement',
      entityId: announcementId,
    );
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

class AdminEnrollmentRow {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String courseId;
  final DateTime enrolledAt;
  final double progressPercent;

  const AdminEnrollmentRow({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.courseId,
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
