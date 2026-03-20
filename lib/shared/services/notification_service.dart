// ─────────────────────────────────────────────────────────────
//  notification_service.dart  –  Push & in-app notifications
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'supabase_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(supabaseClientProvider));
});

/// Provider that streams unread notification count
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final svc = ref.watch(notificationServiceProvider);
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return Stream.value(0);
  return svc.unreadCountStream(userId);
});

/// Provider that fetches all notifications for current user
final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) {
  final svc = ref.watch(notificationServiceProvider);
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return Future.value([]);
  return svc.fetchNotifications(userId);
});

class NotificationService {
  final SupabaseClient _client;
  NotificationService(this._client);

  // ── Fetch all notifications for user ─────────────────────
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return data.map((n) => NotificationModel.fromJson(n)).toList();
  }

  // ── Mark a notification as read ──────────────────────────
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // ── Mark all as read for user ─────────────────────────────
  Future<void> markAllAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // ── Send notification to user(s) ─────────────────────────
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    String? referenceId,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'reference_id': referenceId,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Send announcement to all students in a batch ─────────
  Future<void> sendBatchAnnouncement({
    required String batchId,
    required String title,
    required String body,
  }) async {
    // Fetch all student IDs in this batch
    final members = await _client
        .from('enrollments')
        .select('student_id')
        .eq('batch_id', batchId);

    final inserts = members
        .map(
          (m) => {
            'user_id': m['student_id'],
            'title': title,
            'body': body,
            'type': 'announcement',
            'reference_id': batchId,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          },
        )
        .toList();

    if (inserts.isNotEmpty) {
      await _client.from('notifications').insert(inserts);
    }
  }

  // ── Realtime: unread count stream ─────────────────────────
  Stream<int> unreadCountStream(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) => list.where((n) => n['is_read'] == false).length);
  }
}
