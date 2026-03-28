// ─────────────────────────────────────────────────────────────
//  live_class_service.dart  –  Supabase data layer for live classes
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase_service.dart';
import 'live_class_model.dart';

final liveClassServiceProvider = Provider<LiveClassService>((ref) {
  return LiveClassService(ref.watch(supabaseClientProvider));
});

class LiveClassService {
  final SupabaseClient _client;
  LiveClassService(this._client);

  // ── Select with joins ─────────────────────────────────────
  static const _select =
      '*, batches(batch_name, courses(title)), users!teacher_id(name)';

  Future<String?> _currentRole() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final profile = await _client
        .from('users')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return profile?['role'] as String?;
  }

  Future<void> _requireTeacherOwnsBatch(String batchId, String teacherId) async {
    final role = await _currentRole();
    if (role == 'admin') return;

    final batch = await _client
        .from('batches')
        .select('id, courses!inner(teacher_id)')
        .eq('id', batchId)
        .maybeSingle();

    if (batch == null) {
      throw StateError('Batch not found.');
    }

    final course = batch['courses'] as Map?;
    if (course?['teacher_id'] != teacherId) {
      throw StateError(
        'You can only schedule live classes for your own batches.',
      );
    }
  }

  Future<void> _requireCanManageLiveClass(String liveClassId) async {
    final uid = _client.auth.currentUser?.id;
    final role = await _currentRole();
    if (uid == null) {
      throw StateError('You must be signed in to manage live classes.');
    }
    if (role == 'admin') return;

    final row = await _client
        .from('live_classes')
        .select('teacher_id')
        .eq('id', liveClassId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Live class not found.');
    }
    if (row['teacher_id'] != uid) {
      throw StateError('You do not have permission to manage this live class.');
    }
  }

  // ─────────────────────────────────────────────────────────
  //  STUDENT: live classes for their enrolled batches
  // ─────────────────────────────────────────────────────────
  Future<List<LiveClassModel>> fetchStudentLiveClasses(
      String studentId) async {
    // 1. Fetch batch IDs the student is enrolled in
    final enrollments = await _client
        .from('enrollments')
        .select('batch_id')
        .eq('student_id', studentId);

    if (enrollments.isEmpty) return [];

    final batchIds =
        enrollments.map((e) => e['batch_id'] as String).toList();

    // 2. Fetch live classes for those batches
    final data = await _client
        .from('live_classes')
        .select(_select)
        .inFilter('batch_id', batchIds)
        .order('start_time', ascending: true);

    return data.map((e) => LiveClassModel.fromJson(e)).toList();
  }

  // ─────────────────────────────────────────────────────────
  //  STUDENT: upcoming only
  // ─────────────────────────────────────────────────────────
  Future<List<LiveClassModel>> fetchUpcomingForStudent(
      String studentId) async {
    final all = await fetchStudentLiveClasses(studentId);
    final now = DateTime.now();
    return all
        .where((lc) => lc.endTime.isAfter(now))
        .toList();
  }

  // ─────────────────────────────────────────────────────────
  //  TEACHER: their own scheduled classes
  // ─────────────────────────────────────────────────────────
  Future<List<LiveClassModel>> fetchTeacherLiveClasses(
      String teacherId) async {
    final data = await _client
        .from('live_classes')
        .select(_select)
        .eq('teacher_id', teacherId)
        .order('start_time', ascending: true);

    return data.map((e) => LiveClassModel.fromJson(e)).toList();
  }

  // ─────────────────────────────────────────────────────────
  //  ADMIN: all live classes
  // ─────────────────────────────────────────────────────────
  Future<List<LiveClassModel>> fetchAllLiveClasses() async {
    final data = await _client
        .from('live_classes')
        .select(_select)
        .order('start_time', ascending: true);

    return data.map((e) => LiveClassModel.fromJson(e)).toList();
  }

  // ─────────────────────────────────────────────────────────
  //  Single live class
  // ─────────────────────────────────────────────────────────
  Future<LiveClassModel?> fetchById(String id) async {
    final data = await _client
        .from('live_classes')
        .select(_select)
        .eq('id', id)
        .maybeSingle();

    return data == null ? null : LiveClassModel.fromJson(data);
  }

  // ─────────────────────────────────────────────────────────
  //  TEACHER: schedule a new live class
  // ─────────────────────────────────────────────────────────
  Future<LiveClassModel> scheduleLiveClass({
    required String batchId,
    required String teacherId,
    required String title,
    String? description,
    required String meetingLink,
    required DateTime startTime,
    required int durationMinutes,
  }) async {
    await _requireTeacherOwnsBatch(batchId, teacherId);

    final row = await _client
        .from('live_classes')
        .insert({
          'batch_id': batchId,
          'teacher_id': teacherId,
          'title': title,
          'description': description,
          'meeting_link': meetingLink,
          'start_time': startTime.toIso8601String(),
          'duration_minutes': durationMinutes,
        })
        .select(_select)
        .single();

    return LiveClassModel.fromJson(row);
  }

  // ─────────────────────────────────────────────────────────
  //  TEACHER: update a live class
  // ─────────────────────────────────────────────────────────
  Future<void> updateLiveClass({
    required String id,
    String? title,
    String? description,
    String? meetingLink,
    DateTime? startTime,
    int? durationMinutes,
  }) async {
    await _requireCanManageLiveClass(id);

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (meetingLink != null) updates['meeting_link'] = meetingLink;
    if (startTime != null) updates['start_time'] = startTime.toIso8601String();
    if (durationMinutes != null) updates['duration_minutes'] = durationMinutes;

    if (updates.isEmpty) return;
    await _client.from('live_classes').update(updates).eq('id', id);
  }

  // ─────────────────────────────────────────────────────────
  //  TEACHER: delete a live class
  // ─────────────────────────────────────────────────────────
  Future<void> deleteLiveClass(String id) async {
    await _requireCanManageLiveClass(id);
    await _client.from('live_classes').delete().eq('id', id);
  }

  // ─────────────────────────────────────────────────────────
  //  TEACHER: send notification to all students in a batch
  // ─────────────────────────────────────────────────────────
  Future<void> sendLiveClassNotification({
    required String liveClassId,
    required String batchId,
    required String title,
    required DateTime startTime,
  }) async {
    await _requireCanManageLiveClass(liveClassId);

    // Get all student IDs in this batch
    final enrollments = await _client
        .from('enrollments')
        .select('student_id')
        .eq('batch_id', batchId);

    if (enrollments.isEmpty) return;

    final notifBody = 'Live class "$title" starts at ${_formatTime(startTime)}';

    final inserts = enrollments
        .map((e) => {
              'user_id': e['student_id'] as String,
              'title': '🔴 Live Class: $title',
              'body': notifBody,
              'type': 'announcement',
              'reference_id': liveClassId,
              'is_read': false,
            })
        .toList();

    if (inserts.isNotEmpty) {
      await _client.from('notifications').insert(inserts);
    }

    // Mark notification as sent on live class
    await _client
        .from('live_classes')
        .update({'notification_sent': true})
        .eq('id', liveClassId);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}
