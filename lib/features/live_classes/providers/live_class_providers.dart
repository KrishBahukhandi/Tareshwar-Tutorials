// ─────────────────────────────────────────────────────────────
//  live_class_providers.dart  –  Riverpod providers
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/auth_service.dart';
import '../data/live_class_model.dart';
import '../data/live_class_service.dart';

export '../data/live_class_model.dart';
export '../data/live_class_service.dart';

// ── Student: all live classes for enrolled batches ────────────
final studentLiveClassesProvider =
    FutureProvider.autoDispose<List<LiveClassModel>>((ref) async {
  final uid = ref.watch(authServiceProvider).currentAuthUser?.id;
  if (uid == null) return [];
  return ref.watch(liveClassServiceProvider).fetchStudentLiveClasses(uid);
});

// ── Student: upcoming only (live + not-yet-started) ──────────
final studentUpcomingLiveClassesProvider =
    FutureProvider.autoDispose<List<LiveClassModel>>((ref) async {
  final uid = ref.watch(authServiceProvider).currentAuthUser?.id;
  if (uid == null) return [];
  return ref.watch(liveClassServiceProvider).fetchUpcomingForStudent(uid);
});

// ── Teacher: their own classes ────────────────────────────────
final teacherLiveClassesProvider =
    FutureProvider.autoDispose<List<LiveClassModel>>((ref) async {
  final uid = ref.watch(authServiceProvider).currentAuthUser?.id;
  if (uid == null) return [];
  return ref.watch(liveClassServiceProvider).fetchTeacherLiveClasses(uid);
});

// ── Admin: all classes ────────────────────────────────────────
final adminLiveClassesProvider =
    FutureProvider.autoDispose<List<LiveClassModel>>((ref) {
  return ref.watch(liveClassServiceProvider).fetchAllLiveClasses();
});

// ── Single class detail ───────────────────────────────────────
final liveClassDetailProvider =
    FutureProvider.autoDispose.family<LiveClassModel?, String>((ref, id) {
  return ref.watch(liveClassServiceProvider).fetchById(id);
});

// ── Filter state (student list) ───────────────────────────────
enum LiveClassFilter { all, upcoming, live, ended }

final liveClassFilterProvider =
    StateProvider.autoDispose<LiveClassFilter>((_) => LiveClassFilter.upcoming);
