// ─────────────────────────────────────────────────────────────
//  content_upload_providers.dart
//  Riverpod state notifiers for Subject, Chapter, and Lecture
//  creation within the Content Upload module.
// ─────────────────────────────────────────────────────────────
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/auth_service.dart';
import '../data/content_upload_repository.dart';

class FormAsyncState {
  final bool isSubmitting;
  final double uploadProgress;
  final String? error;
  final bool success;

  const FormAsyncState({
    this.isSubmitting = false,
    this.uploadProgress = 0.0,
    this.error,
    this.success = false,
  });

  FormAsyncState copyWith({
    bool? isSubmitting,
    double? uploadProgress,
    String? error,
    bool? success,
  }) => FormAsyncState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    error: error,
    success: success ?? this.success,
  );
}

final subjectsListProvider = FutureProvider.autoDispose
    .family<List<SubjectModel>, String>((ref, courseId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) return [];
      return ref
          .read(contentUploadRepoProvider)
          .fetchSubjects(courseId, teacherId: teacherId);
    });

final chaptersListProvider = FutureProvider.autoDispose
    .family<List<ChapterModel>, String>((ref, subjectId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) return [];
      return ref
          .read(contentUploadRepoProvider)
          .fetchChapters(subjectId, teacherId: teacherId);
    });

final lecturesListProvider = FutureProvider.autoDispose
    .family<List<LectureModel>, String>((ref, chapterId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) return [];
      return ref
          .read(contentUploadRepoProvider)
          .fetchLectures(chapterId, teacherId: teacherId);
    });

final createSubjectProvider =
    AutoDisposeNotifierProvider<CreateSubjectNotifier, FormAsyncState>(
      CreateSubjectNotifier.new,
    );

class CreateSubjectNotifier extends AutoDisposeNotifier<FormAsyncState> {
  @override
  FormAsyncState build() => const FormAsyncState();

  Future<void> submit({
    required String courseId,
    required String name,
    required int sortOrder,
  }) async {
    final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
    if (teacherId == null) {
      state = const FormAsyncState(error: 'Not authenticated');
      return;
    }
    state = const FormAsyncState(isSubmitting: true);
    try {
      await ref
          .read(contentUploadRepoProvider)
          .createSubject(
            teacherId: teacherId,
            courseId: courseId,
            name: name,
            sortOrder: sortOrder,
          );
      ref.invalidate(subjectsListProvider(courseId));
      state = const FormAsyncState(success: true);
    } catch (e) {
      state = FormAsyncState(error: e.toString());
    }
  }

  void reset() => state = const FormAsyncState();
}

final createChapterProvider =
    AutoDisposeNotifierProvider<CreateChapterNotifier, FormAsyncState>(
      CreateChapterNotifier.new,
    );

class CreateChapterNotifier extends AutoDisposeNotifier<FormAsyncState> {
  @override
  FormAsyncState build() => const FormAsyncState();

  Future<void> submit({
    required String subjectId,
    required String name,
    required int sortOrder,
  }) async {
    final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
    if (teacherId == null) {
      state = const FormAsyncState(error: 'Not authenticated');
      return;
    }
    state = const FormAsyncState(isSubmitting: true);
    try {
      await ref
          .read(contentUploadRepoProvider)
          .createChapter(
            teacherId: teacherId,
            subjectId: subjectId,
            name: name,
            sortOrder: sortOrder,
          );
      ref.invalidate(chaptersListProvider(subjectId));
      state = const FormAsyncState(success: true);
    } catch (e) {
      state = FormAsyncState(error: e.toString());
    }
  }

  void reset() => state = const FormAsyncState();
}

final uploadLectureProvider =
    AutoDisposeNotifierProvider<UploadLectureNotifier, FormAsyncState>(
      UploadLectureNotifier.new,
    );

class UploadLectureNotifier extends AutoDisposeNotifier<FormAsyncState> {
  @override
  FormAsyncState build() => const FormAsyncState();

  Future<void> submit({
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
  }) async {
    final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
    if (teacherId == null) {
      state = const FormAsyncState(error: 'Not authenticated');
      return;
    }
    state = const FormAsyncState(isSubmitting: true, uploadProgress: 0.0);
    try {
      await ref
          .read(contentUploadRepoProvider)
          .createLecture(
            teacherId: teacherId,
            chapterId: chapterId,
            courseId: courseId,
            title: title,
            description: description,
            videoBytes: videoBytes,
            videoFileName: videoFileName,
            pdfBytes: pdfBytes,
            pdfFileName: pdfFileName,
            durationSeconds: durationSeconds,
            isFree: isFree,
            sortOrder: sortOrder,
            onProgress: (p) {
              state = state.copyWith(uploadProgress: p);
            },
          );
      ref.invalidate(lecturesListProvider(chapterId));
      state = const FormAsyncState(success: true, uploadProgress: 1.0);
    } catch (e) {
      state = FormAsyncState(error: e.toString());
    }
  }

  void reset() => state = const FormAsyncState();
}
