// ─────────────────────────────────────────────────────────────
//  download_providers.dart  –  Riverpod providers for the
//  offline downloads feature.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/auth_service.dart' show currentUserProvider;
import 'data/download_database.dart';
import 'data/download_model.dart';
import 'data/download_service.dart';

export 'data/download_model.dart';
export 'data/download_service.dart' show downloadServiceProvider;

// ── All completed downloads for the current student ──────────
final studentDownloadsProvider =
    FutureProvider.autoDispose<List<DownloadedLecture>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(downloadServiceProvider).getAllDownloads(user.id);
});

// ── Download state for a single lecture ──────────────────────
//   Returns the DB row (or null if not downloaded).
final lectureDownloadProvider = FutureProvider.autoDispose
    .family<DownloadedLecture?, String>((ref, lectureId) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(downloadServiceProvider).getDownload(
        lectureId: lectureId,
        studentId: user.id,
      );
});

// ── Live progress stream for a single lecture ─────────────────
//   Wraps the DownloadService stream in a Riverpod StreamProvider.
final downloadProgressProvider = StreamProvider.autoDispose
    .family<DownloadedLecture, String>((ref, lectureId) {
  return ref.watch(downloadServiceProvider).progressStream(lectureId);
});

// ── Total storage used ────────────────────────────────────────
final downloadStorageProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return 0;
  return DownloadDatabase.instance.totalSizeBytes(user.id);
});

// ── NotifierProvider that triggers list refresh ───────────────
//   Call `ref.invalidate(downloadsRefreshProvider)` after mutations.
final downloadsRefreshProvider =
    StateProvider.autoDispose<int>((ref) => 0);
