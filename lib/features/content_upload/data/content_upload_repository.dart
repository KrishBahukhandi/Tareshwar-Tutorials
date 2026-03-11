// ─────────────────────────────────────────────────────────────
//  content_upload_repository.dart
//  Supabase Storage uploads + DB writes for the Content Upload
//  module. Covers: Subject, Chapter, and Lecture creation with
//  video/PDF file uploads.
// ─────────────────────────────────────────────────────────────
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';

final contentUploadRepoProvider =
    Provider<ContentUploadRepository>((ref) {
  return ContentUploadRepository(ref.watch(supabaseClientProvider));
});

class ContentUploadRepository {
  final SupabaseClient _db;
  ContentUploadRepository(this._db);

  // ════════════════════════════════════════════════════════
  //  STORAGE UPLOAD HELPERS
  // ════════════════════════════════════════════════════════

  /// Upload [bytes] to [bucket] at [storagePath].
  /// Returns the public URL of the uploaded file.
  Future<String> _uploadFile({
    required String bucket,
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);

    await _db.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    onProgress?.call(0.9);
    final url = _db.storage.from(bucket).getPublicUrl(storagePath);
    onProgress?.call(1.0);
    return url;
  }

  /// Builds a unique storage path scoped to the course.
  String _storagePath({
    required String courseId,
    required String fileName,
  }) =>
      '$courseId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

  // ════════════════════════════════════════════════════════
  //  VIDEO UPLOAD
  // ════════════════════════════════════════════════════════

  Future<String> uploadVideo({
    required String courseId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) =>
      _uploadFile(
        bucket: AppConstants.lectureVideosBucket,
        storagePath: _storagePath(courseId: courseId, fileName: fileName),
        bytes: bytes,
        mimeType: _mimeFromExt(fileName) ?? 'video/mp4',
        onProgress: onProgress,
      );

  // ════════════════════════════════════════════════════════
  //  PDF / NOTES UPLOAD
  // ════════════════════════════════════════════════════════

  Future<String> uploadPdf({
    required String courseId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) =>
      _uploadFile(
        bucket: AppConstants.notesBucket,
        storagePath: _storagePath(courseId: courseId, fileName: fileName),
        bytes: bytes,
        mimeType: 'application/pdf',
        onProgress: onProgress,
      );

  // ════════════════════════════════════════════════════════
  //  SUBJECTS
  // ════════════════════════════════════════════════════════

  Future<SubjectModel> createSubject({
    required String courseId,
    required String name,
    required int sortOrder,
  }) async {
    final data = await _db
        .from('subjects')
        .insert({
          'course_id': courseId,
          'name': name,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return SubjectModel.fromJson({
      ...Map<String, dynamic>.from(data),
      'chapters': <dynamic>[],
    });
  }

  Future<List<SubjectModel>> fetchSubjects(String courseId) async {
    final data = await _db
        .from('subjects')
        .select()
        .eq('course_id', courseId)
        .order('sort_order');
    return data
        .map((j) => SubjectModel.fromJson({
              ...Map<String, dynamic>.from(j),
              'chapters': <dynamic>[],
            }))
        .toList();
  }

  // ════════════════════════════════════════════════════════
  //  CHAPTERS
  // ════════════════════════════════════════════════════════

  Future<ChapterModel> createChapter({
    required String subjectId,
    required String name,
    required int sortOrder,
  }) async {
    final data = await _db
        .from('chapters')
        .insert({
          'subject_id': subjectId,
          'name': name,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return ChapterModel.fromJson({
      ...Map<String, dynamic>.from(data),
      'lectures': <dynamic>[],
    });
  }

  Future<List<ChapterModel>> fetchChapters(String subjectId) async {
    final data = await _db
        .from('chapters')
        .select()
        .eq('subject_id', subjectId)
        .order('sort_order');
    return data
        .map((j) => ChapterModel.fromJson({
              ...Map<String, dynamic>.from(j),
              'lectures': <dynamic>[],
            }))
        .toList();
  }

  // ════════════════════════════════════════════════════════
  //  LECTURES
  // ════════════════════════════════════════════════════════

  /// Full upload: picks up video/pdf bytes, pushes to Storage,
  /// then inserts the lecture row.
  Future<LectureModel> createLecture({
    required String chapterId,
    required String courseId,
    required String title,
    String? description,
    // Video
    Uint8List? videoBytes,
    String? videoFileName,
    // PDF notes
    Uint8List? pdfBytes,
    String? pdfFileName,
    // Meta
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
    void Function(double progress)? onProgress,
  }) async {
    String? videoUrl;
    String? notesUrl;

    // ── Upload video ──────────────────────────────────────
    if (videoBytes != null && videoFileName != null) {
      onProgress?.call(0.05);
      videoUrl = await uploadVideo(
        courseId: courseId,
        fileName: videoFileName,
        bytes: videoBytes,
        onProgress: (p) => onProgress?.call(0.05 + p * 0.55),
      );
    }

    // ── Upload PDF ────────────────────────────────────────
    if (pdfBytes != null && pdfFileName != null) {
      onProgress?.call(0.6);
      notesUrl = await uploadPdf(
        courseId: courseId,
        fileName: pdfFileName,
        bytes: pdfBytes,
        onProgress: (p) => onProgress?.call(0.6 + p * 0.3),
      );
    }

    onProgress?.call(0.92);

    // ── Insert DB row ─────────────────────────────────────
    final data = await _db
        .from('lectures')
        .insert({
          'chapter_id': chapterId,
          'title': title,
          'description': description,
          'video_url': videoUrl,
          'notes_url': notesUrl,
          'duration_seconds': durationSeconds,
          'is_free': isFree,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    onProgress?.call(1.0);
    return LectureModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<LectureModel>> fetchLectures(String chapterId) async {
    final data = await _db
        .from('lectures')
        .select()
        .eq('chapter_id', chapterId)
        .order('sort_order');
    return data
        .map((j) => LectureModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  // ════════════════════════════════════════════════════════
  //  MIME HELPER
  // ════════════════════════════════════════════════════════

  static String? _mimeFromExt(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const map = {
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      'webm': 'video/webm',
      'pdf': 'application/pdf',
    };
    return map[ext];
  }
}
