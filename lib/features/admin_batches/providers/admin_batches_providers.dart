// ─────────────────────────────────────────────────────────────
//  admin_batches_providers.dart
//  Riverpod providers for admin batch management.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../data/admin_batches_service.dart';

// ── Search / filter state ─────────────────────────────────────
final adminBatchListSearchProvider =
    StateProvider<String>((ref) => '');

final adminBatchCourseFilterProvider =
    StateProvider<String?>((ref) => null); // null = all courses

final adminBatchActiveFilterProvider =
    StateProvider<bool?>((ref) => null); // null = all

// ── Batch list ────────────────────────────────────────────────
final adminBatchListProvider =
    FutureProvider.autoDispose<List<AdminBatchListItem>>((ref) {
  final search   = ref.watch(adminBatchListSearchProvider);
  final courseId = ref.watch(adminBatchCourseFilterProvider);
  final active   = ref.watch(adminBatchActiveFilterProvider);
  return ref
      .watch(adminBatchesServiceProvider)
      .fetchAllBatches(
        search:     search,
        courseId:   courseId,
        activeOnly: active,
      );
});

// ── Batch detail (by batchId) ─────────────────────────────────
final adminBatchDetailProvider =
    FutureProvider.autoDispose.family<AdminBatchDetail, String>(
  (ref, batchId) =>
      ref.watch(adminBatchesServiceProvider).fetchBatchDetail(batchId),
);

// ── Course options (for picker) ───────────────────────────────
final adminBatchCourseOptionsProvider =
    FutureProvider.autoDispose<List<AdminBatchCourseOption>>(
  (ref) =>
      ref.watch(adminBatchesServiceProvider).fetchCourseOptions(),
);

// ── Student options (for enrollment picker) ───────────────────
final adminBatchStudentsProvider =
    FutureProvider.autoDispose<List<UserModel>>(
  (ref) => ref.watch(adminBatchesServiceProvider).fetchStudents(),
);

// ── Batch stats ───────────────────────────────────────────────
final adminBatchStatsProvider =
    FutureProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(adminBatchesServiceProvider).fetchBatchStats(),
);

// ── Batch form notifier ───────────────────────────────────────
class AdminBatchFormState {
  final bool    isSubmitting;
  final String? error;
  final bool    success;
  final String? createdBatchId;

  const AdminBatchFormState({
    this.isSubmitting = false,
    this.error,
    this.success = false,
    this.createdBatchId,
  });

  AdminBatchFormState copyWith({
    bool?    isSubmitting,
    String?  error,
    bool?    success,
    String?  createdBatchId,
  }) =>
      AdminBatchFormState(
        isSubmitting:   isSubmitting ?? this.isSubmitting,
        error:          error,
        success:        success ?? this.success,
        createdBatchId: createdBatchId ?? this.createdBatchId,
      );
}

class AdminBatchFormNotifier
    extends AutoDisposeNotifier<AdminBatchFormState> {
  @override
  AdminBatchFormState build() => const AdminBatchFormState();

  Future<void> create({
    required String   courseId,
    required String   batchName,
    String?           description,
    required DateTime startDate,
    DateTime?         endDate,
    required int      maxStudents,
  }) async {
    state = state.copyWith(isSubmitting: true, success: false);
    try {
      final item = await ref
          .read(adminBatchesServiceProvider)
          .createBatch(
            courseId:    courseId,
            batchName:   batchName,
            description: description,
            startDate:   startDate,
            endDate:     endDate,
            maxStudents: maxStudents,
          );
      ref.invalidate(adminBatchListProvider);
      ref.invalidate(adminBatchStatsProvider);
      state = state.copyWith(
        isSubmitting:   false,
        success:        true,
        createdBatchId: item.id,
      );
    } catch (e) {
      state = state.copyWith(
          isSubmitting: false, error: e.toString());
    }
  }

  Future<void> update({
    required String   batchId,
    String?           batchName,
    String?           description,
    String?           courseId,
    DateTime?         startDate,
    DateTime?         endDate,
    int?              maxStudents,
    bool?             isActive,
  }) async {
    state = state.copyWith(isSubmitting: true, success: false);
    try {
      await ref.read(adminBatchesServiceProvider).updateBatch(
            batchId:     batchId,
            batchName:   batchName,
            description: description,
            courseId:    courseId,
            startDate:   startDate,
            endDate:     endDate,
            maxStudents: maxStudents,
            isActive:    isActive,
          );
      ref.invalidate(adminBatchListProvider);
      ref.invalidate(adminBatchDetailProvider(batchId));
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(
          isSubmitting: false, error: e.toString());
    }
  }
}

final adminBatchFormProvider =
    NotifierProvider.autoDispose<AdminBatchFormNotifier,
        AdminBatchFormState>(AdminBatchFormNotifier.new);
