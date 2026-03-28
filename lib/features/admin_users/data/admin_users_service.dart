// ─────────────────────────────────────────────────────────────
//  admin_users_service.dart
//  Supabase data layer for the admin user-management module.
//
//  Provides:
//    • Paginated user lists with search (students / teachers)
//    • Full user-detail profile including enrolled courses,
//      batch memberships and test-attempt counts
//    • Suspend / unsuspend (toggle is_active)
//    • Role promotion / demotion
//    • Permanent user deletion
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────
//  DTO: full user profile for the detail view
// ─────────────────────────────────────────────────────────────
class AdminUserDetail {
  final UserModel user;
  final List<AdminUserCourse>  enrolledCourses;
  final List<AdminUserBatch>   batchMemberships;
  final int                    testAttemptCount;

  const AdminUserDetail({
    required this.user,
    required this.enrolledCourses,
    required this.batchMemberships,
    required this.testAttemptCount,
  });
}

class AdminUserCourse {
  final String courseId;
  final String courseTitle;
  final String? teacherName;
  final double  progressPercent;
  final DateTime enrolledAt;

  const AdminUserCourse({
    required this.courseId,
    required this.courseTitle,
    this.teacherName,
    required this.progressPercent,
    required this.enrolledAt,
  });
}

class AdminUserBatch {
  final String   batchId;
  final String   batchName;
  final String   courseTitle;
  final bool     isActive;
  final DateTime enrolledAt;

  const AdminUserBatch({
    required this.batchId,
    required this.batchName,
    required this.courseTitle,
    required this.isActive,
    required this.enrolledAt,
  });
}

// ─────────────────────────────────────────────────────────────
//  DTO: teacher detail (courses taught)
// ─────────────────────────────────────────────────────────────
class AdminTeacherDetail {
  final UserModel            user;
  final List<AdminUserCourse> coursesTaught;
  final int                   totalBatches;
  final int                   totalStudents;

  const AdminTeacherDetail({
    required this.user,
    required this.coursesTaught,
    required this.totalBatches,
    required this.totalStudents,
  });
}

class AdminTeacherInviteResult {
  final String userId;
  final String email;

  const AdminTeacherInviteResult({
    required this.userId,
    required this.email,
  });
}

// ─────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────
final adminUsersServiceProvider = Provider<AdminUsersService>((ref) {
  return AdminUsersService(ref.watch(supabaseClientProvider));
});

class AdminUsersService {
  final SupabaseClient _db;
  AdminUsersService(this._db);

  // ── Fetch paginated user list ─────────────────────────────
  Future<List<UserModel>> fetchUsers({
    required String role,
    String  search = '',
    int     limit  = 50,
    int     offset = 0,
  }) async {
    var q = _db.from('users').select().eq('role', role);
    final rows = await q
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    List<UserModel> models = rows
        .map((r) => UserModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (search.isNotEmpty) {
      final lq = search.toLowerCase();
      models = models
          .where((u) =>
              u.name.toLowerCase().contains(lq) ||
              u.email.toLowerCase().contains(lq) ||
              (u.phone ?? '').contains(lq))
          .toList();
    }
    return models;
  }

  // ── Full student detail ───────────────────────────────────
  Future<AdminUserDetail> fetchStudentDetail(String userId) async {
    final results = await Future.wait([
      // Base user
      _db.from('users').select().eq('id', userId).single(),
      // Enrollments → batch → course → teacher
      _db
          .from('enrollments')
          .select(
              'id, enrolled_at, progress_percent, '
              'batches!batch_id(id, batch_name, is_active, '
              'courses!course_id(id, title, users!teacher_id(name)))')
          .eq('student_id', userId)
          .order('enrolled_at', ascending: false),
      // Test attempt count
      _db
          .from('test_attempts')
          .select('id')
          .eq('student_id', userId),
    ]);

    final user = UserModel.fromJson(
        Map<String, dynamic>.from(results[0] as Map));
    final enrollRows = results[1] as List;
    final attemptRows = results[2] as List;

    final courses  = <AdminUserCourse>[];
    final batches  = <AdminUserBatch>[];

    for (final r in enrollRows) {
      final map       = Map<String, dynamic>.from(r as Map);
      final batchMap  = map['batches'] as Map?;
      final courseMap = batchMap?['courses'] as Map?;
      final teacherMap = courseMap?['users'] as Map?;

      final batchId    = batchMap?['id']         as String? ?? '';
      final batchName  = batchMap?['batch_name'] as String? ?? '—';
      final batchActive= batchMap?['is_active']  as bool?   ?? true;
      final courseId   = courseMap?['id']        as String? ?? '';
      final courseTitle= courseMap?['title']     as String? ?? '—';
      final teacherName= teacherMap?['name']     as String?;
      final progress   = (map['progress_percent'] as num?)?.toDouble() ?? 0.0;
      final enrolledAt = DateTime.parse(
          map['enrolled_at'] as String? ?? DateTime.now().toIso8601String());

      courses.add(AdminUserCourse(
        courseId:        courseId,
        courseTitle:     courseTitle,
        teacherName:     teacherName,
        progressPercent: progress,
        enrolledAt:      enrolledAt,
      ));

      batches.add(AdminUserBatch(
        batchId:    batchId,
        batchName:  batchName,
        courseTitle:courseTitle,
        isActive:   batchActive,
        enrolledAt: enrolledAt,
      ));
    }

    return AdminUserDetail(
      user:             user,
      enrolledCourses:  courses,
      batchMemberships: batches,
      testAttemptCount: attemptRows.length,
    );
  }

  // ── Full teacher detail ───────────────────────────────────
  Future<AdminTeacherDetail> fetchTeacherDetail(String userId) async {
    final results = await Future.wait([
      // Base user
      _db.from('users').select().eq('id', userId).single(),
      // Courses the teacher owns
      _db
          .from('courses')
          .select('id, title, created_at, is_published')
          .eq('teacher_id', userId)
          .order('created_at', ascending: false),
    ]);

    final user = UserModel.fromJson(
        Map<String, dynamic>.from(results[0] as Map));
    final courseRows = results[1] as List;

    final courseIds = courseRows.map((r) => r['id'] as String).toList();

    int totalBatches  = 0;
    int totalStudents = 0;

    if (courseIds.isNotEmpty) {
      final [batchRows, enrollRows] = await Future.wait([
        _db
            .from('batches')
            .select('id')
            .inFilter('course_id', courseIds),
        _db
            .from('enrollments')
            .select('id, batches!batch_id(course_id)')
            .inFilter(
                'batches.course_id', courseIds),
      ]);
      totalBatches  = (batchRows as List).length;
      totalStudents = (enrollRows as List).length;
    }

    final courses = courseRows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      return AdminUserCourse(
        courseId:        map['id']    as String,
        courseTitle:     map['title'] as String,
        progressPercent: 0,
        enrolledAt:      DateTime.parse(map['created_at'] as String),
      );
    }).toList();

    return AdminTeacherDetail(
      user:          user,
      coursesTaught: courses,
      totalBatches:  totalBatches,
      totalStudents: totalStudents,
    );
  }

  // ── Suspend / Unsuspend ───────────────────────────────────
  Future<void> setUserActive(String userId, {required bool active}) async {
    await _db
        .from('users')
        .update({'is_active': active})
        .eq('id', userId);
  }

  // ── Role change ───────────────────────────────────────────
  Future<void> updateUserRole(String userId, String newRole) async {
    assert(['student', 'teacher', 'admin'].contains(newRole));
    await _db
        .from('users')
        .update({'role': newRole})
        .eq('id', userId);
  }

  Future<AdminTeacherInviteResult> createTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    final accessToken = _db.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception(
        'Your admin session has expired. Please sign out and sign in again.',
      );
    }

    final response = await _db.functions.invoke(
      'admin-create-teacher',
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
      body: {
        'name': name,
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    return AdminTeacherInviteResult(
      userId: data['user_id'] as String,
      email: data['email'] as String,
    );
  }

  // ── Delete user ───────────────────────────────────────────
  Future<void> deleteUser(String userId) async {
    await _db.from('users').delete().eq('id', userId);
  }
}
