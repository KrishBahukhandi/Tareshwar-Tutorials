// ─────────────────────────────────────────────────────────────
//  doubt_service.dart  –  Doubts + Replies API layer
// ─────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'supabase_service.dart';

final doubtServiceProvider = Provider<DoubtService>((ref) {
  return DoubtService(ref.watch(supabaseClientProvider));
});

class DoubtService {
  final SupabaseClient _client;
  DoubtService(this._client);

  Future<List<String>> _fetchTeacherLectureIds(String teacherId) async {
    final courses = await _client
        .from('courses')
        .select('id')
        .eq('teacher_id', teacherId);
    final courseIds = courses.map((row) => row['id'] as String).toList();
    if (courseIds.isEmpty) return const [];

    final subjects = await _client
        .from('subjects')
        .select('id')
        .inFilter('course_id', courseIds);
    final subjectIds = subjects.map((row) => row['id'] as String).toList();
    if (subjectIds.isEmpty) return const [];

    final chapters = await _client
        .from('chapters')
        .select('id')
        .inFilter('subject_id', subjectIds);
    final chapterIds = chapters.map((row) => row['id'] as String).toList();
    if (chapterIds.isEmpty) return const [];

    final lectures = await _client
        .from('lectures')
        .select('id')
        .inFilter('chapter_id', chapterIds);
    return lectures.map((row) => row['id'] as String).toList();
  }

  Future<void> _requireTeacherOwnsDoubt(
    String doubtId,
    String teacherId,
  ) async {
    final doubt = await _client
        .from('doubts')
        .select('lecture_id')
        .eq('id', doubtId)
        .maybeSingle();
    if (doubt == null) {
      throw StateError('Doubt not found.');
    }

    final lectureId = doubt['lecture_id'] as String?;
    if (lectureId == null) {
      throw StateError(
        'This doubt is not linked to a lecture and cannot be managed from the teacher panel.',
      );
    }

    final lectureIds = await _fetchTeacherLectureIds(teacherId);
    if (!lectureIds.contains(lectureId)) {
      throw StateError('You do not have permission to manage this doubt.');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  DOUBTS
  // ═══════════════════════════════════════════════════════

  Future<List<DoubtModel>> fetchDoubts({
    String? lectureId,
    String? studentId,
  }) async {
    var query = _client.from('doubts').select('*, users!student_id(name)');

    if (lectureId != null) {
      query = query.eq('lecture_id', lectureId) as dynamic;
    }
    if (studentId != null) {
      query = query.eq('student_id', studentId) as dynamic;
    }

    final List<Map<String, dynamic>> data = await (query as dynamic).order(
      'created_at',
      ascending: false,
    );

    final doubtIds = data.map((d) => d['id'] as String).toList();
    final replyCounts = doubtIds.isNotEmpty
        ? await _fetchReplyCounts(doubtIds)
        : <String, int>{};

    return data.map((d) {
      final map = Map<String, dynamic>.from(d);
      map['student_name'] = (map['users'] as Map?)?['name'];
      map['reply_count'] = replyCounts[map['id']] ?? 0;
      return DoubtModel.fromJson(map);
    }).toList();
  }

  Future<List<DoubtModel>> fetchTeacherDoubts(String teacherId) async {
    final lectureIds = await _fetchTeacherLectureIds(teacherId);
    if (lectureIds.isEmpty) return const [];
    return fetchDoubtsByLectureIds(lectureIds);
  }

  Future<List<DoubtModel>> fetchDoubtsByLectureIds(
    List<String> lectureIds,
  ) async {
    final data = await _client
        .from('doubts')
        .select('*, users!student_id(name)')
        .inFilter('lecture_id', lectureIds)
        .order('created_at', ascending: false);

    final doubtIds = data.map((d) => d['id'] as String).toList();
    final replyCounts = doubtIds.isNotEmpty
        ? await _fetchReplyCounts(doubtIds)
        : <String, int>{};

    return data.map((d) {
      final map = Map<String, dynamic>.from(d);
      map['student_name'] = (map['users'] as Map?)?['name'];
      map['reply_count'] = replyCounts[map['id']] ?? 0;
      return DoubtModel.fromJson(map);
    }).toList();
  }

  Future<DoubtModel> fetchDoubt(String doubtId) async {
    final data = await _client
        .from('doubts')
        .select('*, users!student_id(name)')
        .eq('id', doubtId)
        .single();
    final map = Map<String, dynamic>.from(data);
    map['student_name'] = (map['users'] as Map?)?['name'];
    final counts = await _fetchReplyCounts([doubtId]);
    map['reply_count'] = counts[doubtId] ?? 0;
    return DoubtModel.fromJson(map);
  }

  Future<DoubtModel> fetchTeacherDoubt(String doubtId, String teacherId) async {
    await _requireTeacherOwnsDoubt(doubtId, teacherId);
    return fetchDoubt(doubtId);
  }

  Future<Map<String, int>> _fetchReplyCounts(List<String> doubtIds) async {
    try {
      final rows = await _client
          .from('doubt_replies')
          .select('doubt_id')
          .inFilter('doubt_id', doubtIds);
      final counts = <String, int>{};
      for (final r in rows) {
        final id = r['doubt_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<DoubtModel> postDoubt({
    required String studentId,
    required String question,
    String? lectureId,
    File? image,
  }) async {
    String? imageUrl;
    if (image != null) {
      final fileName =
          '${studentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage
          .from(AppConstants.doubtImagesBucket)
          .upload(fileName, image);
      imageUrl = _client.storage
          .from(AppConstants.doubtImagesBucket)
          .getPublicUrl(fileName);
    }

    final data = await _client
        .from('doubts')
        .insert({
          'student_id': studentId,
          'lecture_id': lectureId,
          'question': question,
          'image_url': imageUrl,
          'is_answered': false,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return DoubtModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> answerDoubt({
    required String doubtId,
    required String answer,
    required String teacherId,
  }) async {
    await _requireTeacherOwnsDoubt(doubtId, teacherId);
    await _client
        .from('doubts')
        .update({
          'answer': answer,
          'answered_by': teacherId,
          'is_answered': true,
        })
        .eq('id', doubtId);
  }

  Future<void> deleteDoubt(String doubtId) async {
    await _client.from('doubts').delete().eq('id', doubtId);
  }

  Future<void> markResolved(String doubtId, {required bool resolved}) async {
    await _client
        .from('doubts')
        .update({'is_answered': resolved})
        .eq('id', doubtId);
  }

  Future<void> markResolvedForTeacher(
    String doubtId, {
    required String teacherId,
    required bool resolved,
  }) async {
    await _requireTeacherOwnsDoubt(doubtId, teacherId);
    await markResolved(doubtId, resolved: resolved);
  }

  // ═══════════════════════════════════════════════════════
  //  REPLIES
  // ═══════════════════════════════════════════════════════

  Future<List<DoubtReplyModel>> fetchReplies(String doubtId) async {
    final data = await _client
        .from('doubt_replies')
        .select('*, users!author_id(name, role)')
        .eq('doubt_id', doubtId)
        .order('created_at', ascending: true);

    return data.map((r) {
      final map = Map<String, dynamic>.from(r);
      final user = map['users'] as Map?;
      map['author_name'] = user?['name'];
      map['role'] = user?['role'] ?? 'student';
      return DoubtReplyModel.fromJson(map);
    }).toList();
  }

  Stream<List<DoubtReplyModel>> repliesStream(String doubtId) {
    return _client
        .from('doubt_replies')
        .stream(primaryKey: ['id'])
        .eq('doubt_id', doubtId)
        .map(
          (list) => list
              .map(
                (r) => DoubtReplyModel.fromJson(
                  Map<String, dynamic>.from(r as Map),
                ),
              )
              .toList(),
        );
  }

  Future<DoubtReplyModel> postReply({
    required String doubtId,
    required String authorId,
    required String body,
    required String role,
    File? image,
  }) async {
    String? imageUrl;
    if (image != null) {
      final fileName =
          '${authorId}_reply_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage
          .from(AppConstants.doubtImagesBucket)
          .upload(fileName, image);
      imageUrl = _client.storage
          .from(AppConstants.doubtImagesBucket)
          .getPublicUrl(fileName);
    }

    final data = await _client
        .from('doubt_replies')
        .insert({
          'doubt_id': doubtId,
          'author_id': authorId,
          'body': body,
          'role': role,
          'image_url': imageUrl,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    if (role == 'teacher') {
      await _client
          .from('doubts')
          .update({'is_answered': true, 'answered_by': authorId})
          .eq('id', doubtId);
    }

    final map = Map<String, dynamic>.from(data);
    map['author_name'] = null;
    return DoubtReplyModel.fromJson(map);
  }

  Future<DoubtReplyModel> postTeacherReply({
    required String doubtId,
    required String teacherId,
    required String body,
    File? image,
  }) async {
    await _requireTeacherOwnsDoubt(doubtId, teacherId);
    return postReply(
      doubtId: doubtId,
      authorId: teacherId,
      body: body,
      role: 'teacher',
      image: image,
    );
  }

  Future<void> deleteReply(String replyId) async {
    await _client.from('doubt_replies').delete().eq('id', replyId);
  }

  Stream<List<DoubtModel>> doubtsStream(String lectureId) {
    return _client
        .from('doubts')
        .stream(primaryKey: ['id'])
        .eq('lecture_id', lectureId)
        .map(
          (list) => list
              .map(
                (d) => DoubtModel.fromJson(Map<String, dynamic>.from(d as Map)),
              )
              .toList(),
        );
  }
}
