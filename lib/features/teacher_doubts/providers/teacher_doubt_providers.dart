// ─────────────────────────────────────────────────────────────
//  teacher_doubt_providers.dart
//  Riverpod providers for the Teacher Doubt Management module.
//  Reuses DoubtService from shared services layer.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/doubt_service.dart';

// ═════════════════════════════════════════════════════════════
//  FILTER ENUM
// ═════════════════════════════════════════════════════════════

enum TeacherDoubtFilter { all, pending, resolved }

extension TeacherDoubtFilterExt on TeacherDoubtFilter {
  String get label {
    switch (this) {
      case TeacherDoubtFilter.all:
        return 'All';
      case TeacherDoubtFilter.pending:
        return 'Pending';
      case TeacherDoubtFilter.resolved:
        return 'Resolved';
    }
  }
}

// ═════════════════════════════════════════════════════════════
//  LIST PROVIDERS
// ═════════════════════════════════════════════════════════════

/// All doubts across all lectures (teacher view).
final teacherAllDoubtsProvider =
    FutureProvider.autoDispose<List<DoubtModel>>((ref) async {
  return ref.read(doubtServiceProvider).fetchDoubts();
});

/// Doubts filtered to a specific course's lectures (optional).
/// Pass null to fetch all doubts.
final teacherDoubtsProvider = FutureProvider.autoDispose
    .family<List<DoubtModel>, String?>((ref, lectureId) async {
  return ref.read(doubtServiceProvider).fetchDoubts(lectureId: lectureId);
});

/// Single doubt detail — invalidated after teacher actions.
final teacherDoubtDetailProvider = FutureProvider.autoDispose
    .family<DoubtModel, String>((ref, doubtId) async {
  return ref.read(doubtServiceProvider).fetchDoubt(doubtId);
});

/// Realtime reply stream for a doubt (teacher view).
final teacherRepliesStreamProvider = StreamProvider.autoDispose
    .family<List<DoubtReplyModel>, String>((ref, doubtId) {
  return ref.read(doubtServiceProvider).repliesStream(doubtId);
});

// ═════════════════════════════════════════════════════════════
//  UI STATE PROVIDERS
// ═════════════════════════════════════════════════════════════

/// Active filter on the teacher doubt list.
final teacherDoubtFilterProvider =
    StateProvider.autoDispose<TeacherDoubtFilter>(
        (_) => TeacherDoubtFilter.all);

/// Search query on the teacher doubt list.
final teacherDoubtSearchProvider =
    StateProvider.autoDispose<String>((_) => '');

// ═════════════════════════════════════════════════════════════
//  TEACHER REPLY NOTIFIER
// ═════════════════════════════════════════════════════════════

class TeacherReplyState {
  final bool isSending;
  final bool success;
  final String? error;

  const TeacherReplyState({
    this.isSending = false,
    this.success = false,
    this.error,
  });

  TeacherReplyState copyWith({
    bool? isSending,
    bool? success,
    String? error,
  }) =>
      TeacherReplyState(
        isSending: isSending ?? this.isSending,
        success: success ?? this.success,
        error: error,
      );
}

class TeacherReplyNotifier
    extends AutoDisposeNotifier<TeacherReplyState> {
  @override
  TeacherReplyState build() => const TeacherReplyState();

  Future<void> postReply({
    required String doubtId,
    required String teacherId,
    required String body,
  }) async {
    if (body.trim().isEmpty) return;
    state = const TeacherReplyState(isSending: true);
    try {
      await ref.read(doubtServiceProvider).postReply(
            doubtId: doubtId,
            authorId: teacherId,
            body: body.trim(),
            role: 'teacher',
          );
      // Refresh the doubt header (isAnswered flag updated by service).
      ref.invalidate(teacherDoubtDetailProvider(doubtId));
      ref.invalidate(teacherAllDoubtsProvider);
      state = const TeacherReplyState(success: true);
    } catch (e) {
      state = TeacherReplyState(error: e.toString());
    }
  }

  void reset() => state = const TeacherReplyState();
}

final teacherReplyProvider =
    AutoDisposeNotifierProvider<TeacherReplyNotifier, TeacherReplyState>(
        TeacherReplyNotifier.new);

// ═════════════════════════════════════════════════════════════
//  RESOLVE NOTIFIER
// ═════════════════════════════════════════════════════════════

class ResolveNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> toggle(
    String doubtId, {
    required bool resolved,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(doubtServiceProvider)
          .markResolved(doubtId, resolved: resolved);
      ref.invalidate(teacherDoubtDetailProvider(doubtId));
      ref.invalidate(teacherAllDoubtsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final resolveDoubtProvider =
    AutoDisposeNotifierProvider<ResolveNotifier, AsyncValue<void>>(
        ResolveNotifier.new);
