// ─────────────────────────────────────────────────────────────
//  admin_notifications_service.dart
//  Supabase data layer for the Admin Announcement / Notification module.
//
//  announcements table:
//    id, author_id, batch_id (null=platform-wide), title, body,
//    push_sent (bool), created_at
//
//  notifications table (per-user in-app inbox):
//    id, user_id, title, body, type, reference_id, is_read, created_at
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────
final adminNotificationsServiceProvider =
    Provider<AdminNotificationsService>((ref) {
  return AdminNotificationsService(ref.watch(supabaseClientProvider));
});

// ─────────────────────────────────────────────────────────────
//  DTOs
// ─────────────────────────────────────────────────────────────

/// Full announcement row returned by the service.
class AnnouncementRow {
  final String   id;
  final String   authorId;
  final String   authorName;
  final String?  batchId;
  final String?  batchName;
  final String   title;
  final String   body;
  final bool     pushSent;
  final DateTime createdAt;

  const AnnouncementRow({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.batchId,
    this.batchName,
    required this.title,
    required this.body,
    required this.pushSent,
    required this.createdAt,
  });

  bool get isPlatformWide => batchId == null;

  factory AnnouncementRow.fromJson(Map<String, dynamic> m) {
    final userMap  = m['users']   as Map?;
    final batchMap = m['batches'] as Map?;
    return AnnouncementRow(
      id:         m['id'] as String,
      authorId:   m['author_id'] as String,
      authorName: (m['author_name'] ?? userMap?['name']) as String? ?? '—',
      batchId:    m['batch_id'] as String?,
      batchName:  (m['batch_name'] ?? batchMap?['batch_name']) as String?,
      title:      m['title'] as String,
      body:       m['body'] as String,
      pushSent:   m['push_sent'] as bool? ?? false,
      createdAt:  DateTime.parse(m['created_at'] as String),
    );
  }
}

/// Lightweight batch row used for the batch picker.
class BatchPickerRow {
  final String id;
  final String batchName;
  final String courseTitle;
  final int    enrolledCount;

  const BatchPickerRow({
    required this.id,
    required this.batchName,
    required this.courseTitle,
    required this.enrolledCount,
  });

  factory BatchPickerRow.fromJson(Map<String, dynamic> m) {
    final courseMap = m['courses'] as Map?;
    return BatchPickerRow(
      id:            m['id'] as String,
      batchName:     m['batch_name'] as String? ?? m['name'] as String? ?? '—',
      courseTitle:   (m['course_title'] ?? courseMap?['title']) as String? ?? '—',
      enrolledCount: m['enrolled_count'] as int? ?? 0,
    );
  }
}

/// Summary stats for the dashboard header.
class AnnouncementStats {
  final int totalCount;
  final int platformWideCount;
  final int batchTargetedCount;
  final int pushSentCount;

  const AnnouncementStats({
    required this.totalCount,
    required this.platformWideCount,
    required this.batchTargetedCount,
    required this.pushSentCount,
  });
}

// ─────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────
class AdminNotificationsService {
  AdminNotificationsService(this._db);
  final SupabaseClient _db;

  // ── Fetch announcements list ───────────────────────────────
  Future<List<AnnouncementRow>> fetchAnnouncements({
    String? batchId,          // null = all
    String? search,
    bool?   platformWideOnly, // true = only null batch_id rows
    int     limit  = 100,
    int     offset = 0,
  }) async {
    var fb = _db
        .from('announcements')
        .select('*, users!author_id(name), batches!batch_id(batch_name)');

    if (batchId != null)           fb = fb.eq('batch_id', batchId);
    // platformWideOnly is handled client-side below (is_/isFilter not universally available)

    final rows = await fb
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1) as List;

    var result = rows
        .map((r) => AnnouncementRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    // Client-side filters
    if (platformWideOnly == true) {
      result = result.where((a) => a.batchId == null).toList();
    } else if (platformWideOnly == false) {
      result = result.where((a) => a.batchId != null).toList();
    }

    // Client-side search (title / body / batch)
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where((a) =>
              a.title.toLowerCase().contains(q) ||
              a.body.toLowerCase().contains(q)  ||
              (a.batchName?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return result;
  }

  // ── Single announcement ────────────────────────────────────
  Future<AnnouncementRow> fetchAnnouncement(String id) async {
    final row = await _db
        .from('announcements')
        .select('*, users!author_id(name), batches!batch_id(batch_name)')
        .eq('id', id)
        .single();
    return AnnouncementRow.fromJson(Map<String, dynamic>.from(row));
  }

  // ── Stats ──────────────────────────────────────────────────
  Future<AnnouncementStats> fetchStats() async {
    final rows = await _db
        .from('announcements')
        .select('batch_id, push_sent') as List;

    int total       = 0;
    int platformW   = 0;
    int batchTarget = 0;
    int pushSent    = 0;

    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      total++;
      if (m['batch_id'] == null) {
        platformW++;
      } else {
        batchTarget++;
      }
      if (m['push_sent'] == true) pushSent++;
    }

    return AnnouncementStats(
      totalCount:         total,
      platformWideCount:  platformW,
      batchTargetedCount: batchTarget,
      pushSentCount:      pushSent,
    );
  }

  // ── Create announcement ────────────────────────────────────
  /// Inserts the announcement and, if [sendPush] is true, fans out
  /// in-app notification rows to every target student.
  Future<AnnouncementRow> createAnnouncement({
    required String authorId,
    required String title,
    required String body,
    String?         batchId,   // null = platform-wide
    bool            sendPush = true,
  }) async {
    // 1. Insert announcement row
    final inserted = await _db
        .from('announcements')
        .insert({
          'author_id': authorId,
          'batch_id':  batchId,
          'title':     title,
          'body':      body,
          'push_sent': sendPush,
        })
        .select('*, users!author_id(name), batches!batch_id(batch_name)')
        .single();

    // 2. Fan out in-app notifications
    if (sendPush) {
      await _fanOutNotifications(
        announcementId: inserted['id'] as String,
        batchId:        batchId,
        title:          title,
        body:           body,
      );
    }

    return AnnouncementRow.fromJson(Map<String, dynamic>.from(inserted));
  }

  // ── Delete announcement ────────────────────────────────────
  Future<void> deleteAnnouncement(String id) async {
    await _db.from('announcements').delete().eq('id', id);
  }

  // ── Batch picker ───────────────────────────────────────────
  Future<List<BatchPickerRow>> fetchBatches() async {
    final rows = await _db
        .from('batches')
        .select('id, batch_name, enrolled_count, courses!course_id(title)')
        .eq('is_active', true)
        .order('batch_name') as List;
    return rows
        .map((r) => BatchPickerRow.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ── Enrolled student count for a batch ────────────────────
  Future<int> fetchEnrolledCount(String batchId) async {
    final rows = await _db
        .from('enrollments')
        .select('id')
        .eq('batch_id', batchId) as List;
    return rows.length;
  }

  // ── Re-send push for existing announcement ─────────────────
  Future<void> resendPush(AnnouncementRow announcement) async {
    await _fanOutNotifications(
      announcementId: announcement.id,
      batchId:        announcement.batchId,
      title:          announcement.title,
      body:           announcement.body,
    );
    await _db
        .from('announcements')
        .update({'push_sent': true})
        .eq('id', announcement.id);
  }

  // ── Private: fan-out notification rows ────────────────────
  Future<void> _fanOutNotifications({
    required String  announcementId,
    required String  title,
    required String  body,
    String?          batchId,
  }) async {
    List<String> userIds;

    if (batchId == null) {
      // Platform-wide → all active students
      final rows = await _db
          .from('users')
          .select('id')
          .eq('role', 'student')
          .eq('is_active', true) as List;
      userIds = rows.map((r) => r['id'] as String).toList();
    } else {
      // Batch-targeted → enrolled students only
      final rows = await _db
          .from('enrollments')
          .select('student_id')
          .eq('batch_id', batchId) as List;
      userIds = rows.map((r) => r['student_id'] as String).toList();
    }

    if (userIds.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final inserts = userIds
        .map((uid) => {
              'user_id':      uid,
              'title':        title,
              'body':         body,
              'type':         'announcement',
              'reference_id': announcementId,
              'is_read':      false,
              'created_at':   now,
            })
        .toList();

    // Insert in chunks of 200 to stay within Supabase row limits
    const chunk = 200;
    for (var i = 0; i < inserts.length; i += chunk) {
      final end = (i + chunk).clamp(0, inserts.length);
      await _db.from('notifications').insert(inserts.sublist(i, end));
    }
  }
}
