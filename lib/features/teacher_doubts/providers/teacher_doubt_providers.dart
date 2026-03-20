// ─────────────────────────────────────────────────────────────
//  teacher_doubt_providers.dart
//  Riverpod providers for the Teacher Doubt Management module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/doubt_service.dart';

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

final teacherAllDoubtsProvider = FutureProvider.autoDispose<List<DoubtModel>>((
  ref,
) async {
  final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
  if (teacherId == null) return [];
  return ref.read(doubtServiceProvider).fetchTeacherDoubts(teacherId);
});

final teacherDoubtsProvider = FutureProvider.autoDispose
    .family<List<DoubtModel>, String?>((ref, lectureId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) return [];
      final doubts = await ref
          .read(doubtServiceProvider)
          .fetchTeacherDoubts(teacherId);
      if (lectureId == null) return doubts;
      return doubts.where((d) => d.lectureId == lectureId).toList();
    });

final teacherDoubtDetailProvider = FutureProvider.autoDispose
    .family<DoubtModel, String>((ref, doubtId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) {
        throw StateError('You must be signed in as a teacher.');
      }
      return ref
          .read(doubtServiceProvider)
          .fetchTeacherDoubt(doubtId, teacherId);
    });

final teacherRepliesStreamProvider = StreamProvider.autoDispose
    .family<List<DoubtReplyModel>, String>((ref, doubtId) {
      return ref.read(doubtServiceProvider).repliesStream(doubtId);
    });

final teacherDoubtFilterProvider =
    StateProvider.autoDispose<TeacherDoubtFilter>(
      (_) => TeacherDoubtFilter.all,
    );

final teacherDoubtSearchProvider = StateProvider.autoDispose<String>((_) => '');

class TeacherReplyState {
  final bool isSending;
  final bool success;
  final String? error;

  const TeacherReplyState({
    this.isSending = false,
    this.success = false,
    this.error,
  });

  TeacherReplyState copyWith({bool? isSending, bool? success, String? error}) =>
      TeacherReplyState(
        isSending: isSending ?? this.isSending,
        success: success ?? this.success,
        error: error,
      );
}

class TeacherReplyNotifier extends AutoDisposeNotifier<TeacherReplyState> {
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
      await ref
          .read(doubtServiceProvider)
          .postTeacherReply(
            doubtId: doubtId,
            teacherId: teacherId,
            body: body.trim(),
          );
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
      TeacherReplyNotifier.new,
    );

class ResolveNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> toggle(String doubtId, {required bool resolved}) async {
    final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
    if (teacherId == null) {
      state = AsyncValue.error(
        StateError('Not authenticated'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncValue.loading();
    try {
      await ref
          .read(doubtServiceProvider)
          .markResolvedForTeacher(
            doubtId,
            teacherId: teacherId,
            resolved: resolved,
          );
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
      ResolveNotifier.new,
    );
