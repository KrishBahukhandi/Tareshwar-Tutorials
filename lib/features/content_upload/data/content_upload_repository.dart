// ─────────────────────────────────────────────────────────────
//  content_upload_repository.dart
//  Supabase Storage uploads + DB writes for the Content Upload
//  module. Covers: Subject, Chapter, and Lecture creation with
//  video/PDF file uploads.
// ─────────────────────────────────────────────────────────────
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/storage_access_service.dart';
import '../../../shared/services/supabase_service.dart';

final contentUploadRepoProvider = Provider<ContentUploadRepository>((ref) {
  return ContentUploadRepository(ref.watch(supabaseClientProvider));
});

class ContentUploadRepository {
  final SupabaseClient _db;
  ContentUploadRepository(this._db);

  Future<void> _requireTeacherOwnsCourse(
    String courseId,
    String teacherId,
  ) async {
    final course = await _db
        .from('courses')
        .select('teacher_id')
        .eq('id', courseId)
        .maybeSingle();
    if (course == null || course['teacher_id'] != teacherId) {
      throw StateError('You do not have permission to manage this course.');
    }
  }

  Future<String> _requireTeacherOwnsSubject(
    String subjectId,
    String teacherId,
  ) async {
    final subject = await _db
        .from('subjects')
        .select('course_id')
        .eq('id', subjectId)
        .maybeSingle();
    if (subject == null) throw StateError('Subject not found.');
    final courseId = subject['course_id'] as String;
    await _requireTeacherOwnsCourse(courseId, teacherId);
    return courseId;
  }

  Future<String> _requireTeacherOwnsChapter(
    String chapterId,
    String teacherId,
  ) async {
    final chapter = await _db
        .from('chapters')
        .select('subject_id')
        .eq('id', chapterId)
        .maybeSingle();
    if (chapter == null) throw StateError('Chapter not found.');
    final subjectId = chapter['subject_id'] as String;
    await _requireTeacherOwnsSubject(subjectId, teacherId);
    return subjectId;
  }

  Future<String> _uploadFile({
    required String bucket,
    required String storagePath,
    required Uint8List bytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);

    await _db.storage
        .from(bucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    onProgress?.call(0.9);
    onProgress?.call(1.0);
    return StorageAccessService.buildStorageRef(
      bucket: bucket,
      path: storagePath,
    );
  }

  String _storagePath({required String courseId, required String fileName}) =>
      '$courseId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

  Future<String> uploadVideo({
    required String courseId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) => _uploadFile(
    bucket: AppConstants.lectureVideosBucket,
    storagePath: _storagePath(courseId: courseId, fileName: fileName),
    bytes: bytes,
    mimeType: _mimeFromExt(fileName) ?? 'video/mp4',
    onProgress: onProgress,
  );

  Future<String> uploadPdf({
    required String courseId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) => _uploadFile(
    bucket: AppConstants.notesBucket,
    storagePath: _storagePath(courseId: courseId, fileName: fileName),
    bytes: bytes,
    mimeType: 'application/pdf',
    onProgress: onProgress,
  );

  Future<SubjectModel> createSubject({
    required String teacherId,
    required String courseId,
    required String name,
    required int sortOrder,
  }) async {
    final session = _db.auth.currentSession;
    if (session == null) throw StateError('Not authenticated.');

    final dio = Dio();
    final response = await dio.post(
      '${AppConstants.webApiBaseUrl}/api/create-subject',
      data: {
        'courseId': courseId,
        'name': name,
        'sortOrder': sortOrder,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      ),
    );

    return SubjectModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<SubjectModel>> fetchSubjects(
    String courseId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);
    final data = await _db
        .from('subjects')
        .select()
        .eq('course_id', courseId)
        .order('sort_order');
    return data
        .map(
          (j) => SubjectModel.fromJson({
            ...Map<String, dynamic>.from(j),
            'chapters': <dynamic>[],
          }),
        )
        .toList();
  }

  Future<ChapterModel> createChapter({
    required String teacherId,
    required String subjectId,
    required String name,
    required int sortOrder,
  }) async {
    final session = _db.auth.currentSession;
    if (session == null) throw StateError('Not authenticated.');

    final dio = Dio();
    final response = await dio.post(
      '${AppConstants.webApiBaseUrl}/api/create-chapter',
      data: {
        'subjectId': subjectId,
        'name': name,
        'sortOrder': sortOrder,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      ),
    );

    return ChapterModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<ChapterModel>> fetchChapters(
    String subjectId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsSubject(subjectId, teacherId);
    final data = await _db
        .from('chapters')
        .select()
        .eq('subject_id', subjectId)
        .order('sort_order');
    return data
        .map(
          (j) => ChapterModel.fromJson({
            ...Map<String, dynamic>.from(j),
            'lectures': <dynamic>[],
          }),
        )
        .toList();
  }

  Future<LectureModel> createLecture({
    required String teacherId,
    required String chapterId,
    required String courseId,
    required String title,
    String? description,
    Uint8List? videoBytes,
    String? videoFileName,
    Uint8List? pdfBytes,
    String? pdfFileName,
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
    void Function(double progress)? onProgress,
  }) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);
    await _requireTeacherOwnsChapter(chapterId, teacherId);

    String? videoUrl;
    String? notesUrl;

    if (videoBytes != null && videoFileName != null) {
      onProgress?.call(0.05);
      videoUrl = await uploadVideo(
        courseId: courseId,
        fileName: videoFileName,
        bytes: videoBytes,
        onProgress: (p) => onProgress?.call(0.05 + p * 0.55),
      );
    }

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

    final session = _db.auth.currentSession;
    if (session == null) throw StateError('Not authenticated.');

    final dio = Dio();
    final response = await dio.post(
      '${AppConstants.webApiBaseUrl}/api/create-lecture',
      data: {
        'chapterId': chapterId,
        'courseId': courseId,
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'notesUrl': notesUrl,
        'durationSeconds': durationSeconds,
        'isFree': isFree,
        'sortOrder': sortOrder,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      ),
    );

    onProgress?.call(1.0);
    return LectureModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<LectureModel>> fetchLectures(
    String chapterId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    final data = await _db
        .from('lectures')
        .select()
        .eq('chapter_id', chapterId)
        .order('sort_order');
    return data
        .map((j) => LectureModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  static String? _mimeFromExt(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const map = {
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      'webm': 'video/webm',
    };
    return map[ext];
  }
}
