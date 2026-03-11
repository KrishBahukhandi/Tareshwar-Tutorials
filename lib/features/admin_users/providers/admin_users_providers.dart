// ─────────────────────────────────────────────────────────────
//  admin_users_providers.dart
//  All Riverpod providers for the admin user-management module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../data/admin_users_service.dart';

// ── Search / filter state ─────────────────────────────────────
final adminUsersStudentSearchProvider = StateProvider<String>((ref) => '');
final adminUsersTeacherSearchProvider = StateProvider<String>((ref) => '');

// ── Student list ──────────────────────────────────────────────
final adminStudentListProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) {
  final search = ref.watch(adminUsersStudentSearchProvider);
  return ref.watch(adminUsersServiceProvider).fetchUsers(
        role: 'student',
        search: search,
        limit: 200,
      );
});

// ── Teacher list ──────────────────────────────────────────────
final adminTeacherListProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) {
  final search = ref.watch(adminUsersTeacherSearchProvider);
  return ref.watch(adminUsersServiceProvider).fetchUsers(
        role: 'teacher',
        search: search,
        limit: 200,
      );
});

// ── Student detail ────────────────────────────────────────────
final adminStudentDetailProvider =
    FutureProvider.autoDispose.family<AdminUserDetail, String>(
  (ref, userId) =>
      ref.watch(adminUsersServiceProvider).fetchStudentDetail(userId),
);

// ── Teacher detail ────────────────────────────────────────────
final adminTeacherDetailProvider =
    FutureProvider.autoDispose.family<AdminTeacherDetail, String>(
  (ref, userId) =>
      ref.watch(adminUsersServiceProvider).fetchTeacherDetail(userId),
);
