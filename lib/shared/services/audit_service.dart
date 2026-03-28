import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_logger.dart';
import 'supabase_service.dart';

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService(ref.watch(supabaseClientProvider));
});

class AuditService {
  AuditService(this._db);

  final SupabaseClient _db;

  Future<void> logAdminAction({
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _db.from('audit_logs').insert({
        'actor_id': userId,
        'actor_role': 'admin',
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'details': details ?? <String, dynamic>{},
      });
    } catch (e, st) {
      AppLogger.warning(
        'Failed to write audit log for $action on $entityType',
        name: 'audit',
        error: e,
        stackTrace: st,
      );
    }
  }
}
