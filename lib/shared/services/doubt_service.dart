// ─────────────────────────────────────────────────────────────
//  doubt_service.dart  –  Doubts + Replies API layer
// ─────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'supabase_service.dart';
import '../../core/constants/app_constants.dart';

final doubtServiceProvider = Provider<DoubtService>((ref) {
  return DoubtService(ref.watch(supabaseClientProvider));
});

class DoubtService {
  final SupabaseClient _client;
  DoubtService(this._client);

  // ═══════════════════════════════════════════════════════
  //  DOUBTS
  // ═══════════════════════════════════════════════════════

  /// Fetch doubts — optionally scoped by lectureId or studentId.
  Future<List<DoubtModel>> fetchDoubts({
    String? lectureId,
    String? studentId,
  }) async {
    var query = _client
        .from('doubts')
        .select('*, users!student_id(name)');

    if (lectureId != null) {
      query = query.eq('lecture_id', lectureId) as dynamic;
    }
    if (studentId != null) {
      query = query.eq('student_id', studentId) as dynamic;
    }

    final List<Map<String, dynamic>> data =
        await (query as dynamic).order('created_at', ascending: false);

    // fetch reply counts in one batch
    final doubtIds = data.map((d) => d['id'] as String).toList();
    final replyCounts =
        doubtIds.isNotEmpty ? await _fetchReplyCounts(doubtIds) : <String, int>{};

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

  /// Post a new doubt with optional image.
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

  /// Mark a doubt as answered (legacy / teacher shortcut).
  Future<void> answerDoubt({
    required String doubtId,
    required String answer,
    required String teacherId,
  }) async {
    await _client.from('doubts').update({
      'answer': answer,
      'answered_by': teacherId,
      'is_answered': true,
    }).eq('id', doubtId);
  }

  Future<void> deleteDoubt(String doubtId) async {
    await _client.from('doubts').delete().eq('id', doubtId);
  }

  /// Mark a doubt resolved/unresolved by the teacher.
  Future<void> markResolved(String doubtId, {required bool resolved}) async {
    await _client.from('doubts').update({
      'is_answered': resolved,
    }).eq('id', doubtId);
  }

  // ═══════════════════════════════════════════════════════
  //  REPLIES
  // ═══════════════════════════════════════════════════════

  /// Fetch all replies for a doubt, oldest-first.
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

  /// Realtime stream of replies for a doubt.
  Stream<List<DoubtReplyModel>> repliesStream(String doubtId) {
    return _client
        .from('doubt_replies')
        .stream(primaryKey: ['id'])
        .eq('doubt_id', doubtId)
        .map((list) => list
            .map((r) => DoubtReplyModel.fromJson(
                Map<String, dynamic>.from(r as Map)))
            .toList());
  }

  /// Post a reply with optional image.
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

    // Teacher reply → mark doubt answered
    if (role == 'teacher') {
      await _client.from('doubts').update({
        'is_answered': true,
        'answered_by': authorId,
      }).eq('id', doubtId);
    }

    final map = Map<String, dynamic>.from(data);
    map['author_name'] = null; // populated by stream join
    return DoubtReplyModel.fromJson(map);
  }

  Future<void> deleteReply(String replyId) async {
    await _client.from('doubt_replies').delete().eq('id', replyId);
  }

  // ═══════════════════════════════════════════════════════
  //  LEGACY – Realtime doubts stream (lecture player)
  // ═══════════════════════════════════════════════════════
  Stream<List<DoubtModel>> doubtsStream(String lectureId) {
    return _client
        .from('doubts')
        .stream(primaryKey: ['id'])
        .eq('lecture_id', lectureId)
        .map((list) => list
            .map((d) => DoubtModel.fromJson(
                Map<String, dynamic>.from(d as Map)))
            .toList());
  }
}
