// ─────────────────────────────────────────────────────────────
//  download_service.dart  –  Manages lecture video downloads
//
//  Responsibilities:
//    • Enqueue & execute HTTP downloads with Dio
//    • Emit real-time progress via StreamController
//    • Persist state in SQLite (DownloadDatabase)
//    • Save files to app's documents directory
//    • Delete local files when a download is removed
// ─────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'download_database.dart';
import 'download_model.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(Supabase.instance.client);
});

// ─────────────────────────────────────────────────────────────
class DownloadService {
  DownloadService(this._client);

  final SupabaseClient _client;
  final _db  = DownloadDatabase.instance;
  final _dio = Dio();

  // Active cancel tokens keyed by lectureId
  final _cancelTokens = <String, CancelToken>{};

  // Per-download progress streams
  final _progressControllers =
      <String, StreamController<DownloadedLecture>>{};

  // ── Expose a stream for UI to listen to ────────────────────
  Stream<DownloadedLecture> progressStream(String lectureId) {
    _progressControllers.putIfAbsent(
      lectureId,
      () => StreamController<DownloadedLecture>.broadcast(),
    );
    return _progressControllers[lectureId]!.stream;
  }

  void _emit(String lectureId, DownloadedLecture dl) {
    _progressControllers[lectureId]?.add(dl);
  }

  // ── Public API ──────────────────────────────────────────────

  Future<List<DownloadedLecture>> getAllDownloads(String studentId) =>
      _db.getAllForStudent(studentId);

  Future<DownloadedLecture?> getDownload({
    required String lectureId,
    required String studentId,
  }) =>
      _db.get(lectureId: lectureId, studentId: studentId);

  Future<int> totalSizeBytes(String studentId) =>
      _db.totalSizeBytes(studentId);

  Future<String?> _resolveCourseIdForLecture(String lectureId) async {
    final lecture = await _client
        .from('lectures')
        .select('chapter_id')
        .eq('id', lectureId)
        .maybeSingle();
    if (lecture == null) return null;

    final chapter = await _client
        .from('chapters')
        .select('subject_id')
        .eq('id', lecture['chapter_id'] as String)
        .maybeSingle();
    if (chapter == null) return null;

    final subject = await _client
        .from('subjects')
        .select('course_id')
        .eq('id', chapter['subject_id'] as String)
        .maybeSingle();
    return subject?['course_id'] as String?;
  }

  Future<bool> canAccessLecture({
    required String lectureId,
    required String studentId,
  }) async {
    final courseId = await _resolveCourseIdForLecture(lectureId);
    if (courseId == null) return false;

    final enrollments = await _client
        .from('enrollments')
        .select('id, batches!inner(course_id)')
        .eq('student_id', studentId)
        .eq('batches.course_id', courseId)
        .limit(1);
    return enrollments.isNotEmpty;
  }

  Future<bool> validateDownloadAccess(DownloadedLecture dl) {
    return canAccessLecture(lectureId: dl.lectureId, studentId: dl.studentId);
  }

  // ── Start a download ─────────────────────────────────────────
  Future<void> startDownload({
    required String lectureId,
    required String studentId,
    required String videoUrl,
    required String title,
    required String courseTitle,
    required int durationSeconds,
  }) async {
    final hasAccess = await canAccessLecture(
      lectureId: lectureId,
      studentId: studentId,
    );
    if (!hasAccess) {
      throw StateError(
        'This lecture is no longer available for offline access on your account.',
      );
    }

    // Prevent duplicate downloads
    final existing = await _db.get(lectureId: lectureId, studentId: studentId);
    if (existing != null &&
        (existing.isCompleted || existing.isDownloading)) {
      return;
    }

    // Prepare save directory
    final dir = await _localDir(studentId);
    final filename = '$lectureId.mp4';
    final savePath = p.join(dir.path, filename);

    // Initial queued record
    var dl = DownloadedLecture(
      lectureId:       lectureId,
      studentId:       studentId,
      title:           title,
      courseTitle:     courseTitle,
      durationSeconds: durationSeconds,
      localPath:       savePath,
      fileSizeBytes:   0,
      status:          DownloadStatus.downloading,
      progress:        0.0,
      downloadedAt:    DateTime.now(),
    );
    await _db.upsert(dl);
    _emit(lectureId, dl);

    final cancelToken = CancelToken();
    _cancelTokens[lectureId] = cancelToken;

    try {
      await _dio.download(
        videoUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) async {
          if (total <= 0) return;
          final progress = received / total;
          dl = dl.copyWith(
            progress:      progress,
            fileSizeBytes: total,
            status:        DownloadStatus.downloading,
          );
          await _db.upsert(dl);
          _emit(lectureId, dl);
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          sendTimeout:    const Duration(seconds: 30),
        ),
      );

      // Get actual file size after download
      final file = File(savePath);
      final size = await file.exists() ? await file.length() : 0;

      dl = dl.copyWith(
        status:        DownloadStatus.completed,
        progress:      1.0,
        fileSizeBytes: size,
      );
      await _db.upsert(dl);
      _emit(lectureId, dl);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        dl = dl.copyWith(status: DownloadStatus.paused);
      } else {
        dl = dl.copyWith(status: DownloadStatus.failed);
      }
      await _db.upsert(dl);
      _emit(lectureId, dl);
    } catch (_) {
      dl = dl.copyWith(status: DownloadStatus.failed);
      await _db.upsert(dl);
      _emit(lectureId, dl);
    } finally {
      _cancelTokens.remove(lectureId);
    }
  }

  // ── Cancel / pause an active download ──────────────────────
  Future<void> cancelDownload({
    required String lectureId,
    required String studentId,
  }) async {
    _cancelTokens[lectureId]?.cancel('User cancelled');
    _cancelTokens.remove(lectureId);

    final existing = await _db.get(lectureId: lectureId, studentId: studentId);
    if (existing != null && !existing.isCompleted) {
      final dl = existing.copyWith(status: DownloadStatus.paused);
      await _db.upsert(dl);
      _emit(lectureId, dl);
    }
  }

  // ── Delete a download (file + DB row) ─────────────────────
  Future<void> deleteDownload({
    required String lectureId,
    required String studentId,
  }) async {
    // Cancel if active
    _cancelTokens[lectureId]?.cancel('Deleted');
    _cancelTokens.remove(lectureId);

    final existing = await _db.get(lectureId: lectureId, studentId: studentId);
    if (existing != null) {
      final file = File(existing.localPath);
      if (await file.exists()) await file.delete();
    }
    await _db.delete(lectureId: lectureId, studentId: studentId);
  }

  // ── Delete ALL downloads for a student ────────────────────
  Future<void> deleteAllDownloads(String studentId) async {
    final all = await _db.getAllForStudent(studentId);
    for (final dl in all) {
      _cancelTokens[dl.lectureId]?.cancel('Deleted all');
      final file = File(dl.localPath);
      if (await file.exists()) await file.delete();
    }
    _cancelTokens.removeWhere(
        (key, _) => all.any((dl) => dl.lectureId == key));
    await _db.deleteAllForStudent(studentId);
  }

  // ── Validate a download (file still exists?) ───────────────
  Future<bool> isFileValid(DownloadedLecture dl) async {
    if (!dl.isCompleted) return false;
    return File(dl.localPath).exists();
  }

  Future<void> purgeIfUnauthorized(DownloadedLecture dl) async {
    final hasAccess = await validateDownloadAccess(dl);
    if (hasAccess) return;

    final file = File(dl.localPath);
    if (await file.exists()) await file.delete();
    await _db.delete(lectureId: dl.lectureId, studentId: dl.studentId);
  }

  // ── Local storage directory per student ────────────────────
  Future<Directory> _localDir(String studentId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'downloads', studentId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Cleanup ────────────────────────────────────────────────
  void dispose() {
    for (final ct in _cancelTokens.values) {
      ct.cancel('Service disposed');
    }
    for (final sc in _progressControllers.values) {
      sc.close();
    }
  }
}
