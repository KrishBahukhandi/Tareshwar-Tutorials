// ─────────────────────────────────────────────────────────────
//  teacher_test_providers.dart
//  Riverpod state for the Teacher Tests module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/auth_service.dart';
import '../data/teacher_test_repository.dart';

final teacherTestsProvider = FutureProvider.autoDispose
    .family<List<TestModel>, String>((ref, chapterId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) return [];
      return ref.read(teacherTestRepoProvider).fetchTests(chapterId, teacherId);
    });

final testQuestionsProvider = FutureProvider.autoDispose
    .family<List<QuestionModel>, String>((ref, testId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) return [];
      return ref
          .read(teacherTestRepoProvider)
          .fetchQuestions(testId, teacherId);
    });

final teacherTestDetailProvider = FutureProvider.autoDispose
    .family<TestModel, String>((ref, testId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) {
        throw StateError('You must be signed in as a teacher.');
      }
      return ref.read(teacherTestRepoProvider).fetchTest(testId, teacherId);
    });

final teacherTestStatsProvider = FutureProvider.autoDispose
    .family<TeacherTestStats, String>((ref, testId) async {
      final teacherId = ref.watch(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) {
        throw StateError('You must be signed in as a teacher.');
      }
      return ref
          .read(teacherTestRepoProvider)
          .fetchTestStats(testId, teacherId);
    });

class AsyncFormState {
  final bool isSubmitting;
  final String? error;
  final bool success;

  const AsyncFormState({
    this.isSubmitting = false,
    this.error,
    this.success = false,
  });

  AsyncFormState copyWith({bool? isSubmitting, String? error, bool? success}) =>
      AsyncFormState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
        success: success ?? this.success,
      );
}

class TestFormNotifier extends AutoDisposeNotifier<AsyncFormState> {
  @override
  AsyncFormState build() => const AsyncFormState();

  Future<TestModel?> create({
    required String chapterId,
    String? courseId,
    required String title,
    required int durationMinutes,
    int totalMarks = 0,
    double negativeMarks = 0.25,
  }) async {
    state = const AsyncFormState(isSubmitting: true);
    try {
      final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) throw StateError('Not authenticated');
      final test = await ref
          .read(teacherTestRepoProvider)
          .createTest(
            teacherId: teacherId,
            chapterId: chapterId,
            courseId: courseId,
            title: title,
            durationMinutes: durationMinutes,
            totalMarks: totalMarks,
            negativeMarks: negativeMarks,
            isPublished: false,
          );
      ref.invalidate(teacherTestsProvider(chapterId));
      state = const AsyncFormState(success: true);
      return test;
    } catch (e) {
      state = AsyncFormState(error: e.toString());
      return null;
    }
  }

  void reset() => state = const AsyncFormState();
}

final testFormProvider =
    AutoDisposeNotifierProvider<TestFormNotifier, AsyncFormState>(
      TestFormNotifier.new,
    );

class TestEditNotifier extends AutoDisposeNotifier<AsyncFormState> {
  @override
  AsyncFormState build() => const AsyncFormState();

  Future<void> update({
    required String testId,
    required String chapterId,
    required String title,
    required int durationMinutes,
    required int totalMarks,
    double negativeMarks = 0.25,
  }) async {
    state = const AsyncFormState(isSubmitting: true);
    try {
      final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) throw StateError('Not authenticated');
      await ref
          .read(teacherTestRepoProvider)
          .updateTest(
            teacherId: teacherId,
            testId: testId,
            title: title,
            durationMinutes: durationMinutes,
            totalMarks: totalMarks,
            negativeMarks: negativeMarks,
          );
      ref.invalidate(teacherTestsProvider(chapterId));
      ref.invalidate(teacherTestDetailProvider(testId));
      ref.invalidate(teacherTestStatsProvider(testId));
      state = const AsyncFormState(success: true);
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  Future<void> togglePublish(
    String testId, {
    required String chapterId,
    required bool publish,
  }) async {
    try {
      final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) throw StateError('Not authenticated');
      await ref
          .read(teacherTestRepoProvider)
          .togglePublish(testId, teacherId: teacherId, publish: publish);
      ref.invalidate(teacherTestsProvider(chapterId));
      ref.invalidate(teacherTestDetailProvider(testId));
      ref.invalidate(teacherTestStatsProvider(testId));
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  Future<void> delete(String testId, {required String chapterId}) async {
    state = const AsyncFormState(isSubmitting: true);
    try {
      final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) throw StateError('Not authenticated');
      await ref
          .read(teacherTestRepoProvider)
          .deleteTest(testId, teacherId: teacherId);
      ref.invalidate(teacherTestsProvider(chapterId));
      ref.invalidate(teacherTestDetailProvider(testId));
      ref.invalidate(teacherTestStatsProvider(testId));
      state = const AsyncFormState(success: true);
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  void reset() => state = const AsyncFormState();
}

final testEditProvider =
    AutoDisposeNotifierProvider<TestEditNotifier, AsyncFormState>(
      TestEditNotifier.new,
    );

class QuestionFormNotifier extends AutoDisposeNotifier<AsyncFormState> {
  @override
  AsyncFormState build() => const AsyncFormState();

  Future<void> create({
    required String testId,
    required String question,
    required List<String> options,
    required int correctOptionIndex,
    required int marks,
    String? explanation,
  }) async {
    state = const AsyncFormState(isSubmitting: true);
    try {
      final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) throw StateError('Not authenticated');
      await ref
          .read(teacherTestRepoProvider)
          .createQuestion(
            teacherId: teacherId,
            testId: testId,
            question: question,
            options: options,
            correctOptionIndex: correctOptionIndex,
            marks: marks,
            explanation: explanation,
          );
      await ref
          .read(teacherTestRepoProvider)
          .syncTotalMarks(testId, teacherId: teacherId);
      ref.invalidate(testQuestionsProvider(testId));
      ref.invalidate(teacherTestDetailProvider(testId));
      ref.invalidate(teacherTestStatsProvider(testId));
      state = const AsyncFormState(success: true);
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  Future<void> update({
    required String questionId,
    required String testId,
    required String question,
    required List<String> options,
    required int correctOptionIndex,
    required int marks,
    String? explanation,
  }) async {
    state = const AsyncFormState(isSubmitting: true);
    try {
      final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) throw StateError('Not authenticated');
      await ref
          .read(teacherTestRepoProvider)
          .updateQuestion(
            teacherId: teacherId,
            questionId: questionId,
            testId: testId,
            question: question,
            options: options,
            correctOptionIndex: correctOptionIndex,
            marks: marks,
            explanation: explanation,
          );
      await ref
          .read(teacherTestRepoProvider)
          .syncTotalMarks(testId, teacherId: teacherId);
      ref.invalidate(testQuestionsProvider(testId));
      ref.invalidate(teacherTestDetailProvider(testId));
      ref.invalidate(teacherTestStatsProvider(testId));
      state = const AsyncFormState(success: true);
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  Future<void> delete({
    required String questionId,
    required String testId,
  }) async {
    state = const AsyncFormState(isSubmitting: true);
    try {
      final teacherId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (teacherId == null) throw StateError('Not authenticated');
      await ref
          .read(teacherTestRepoProvider)
          .deleteQuestion(questionId, teacherId: teacherId, testId: testId);
      await ref
          .read(teacherTestRepoProvider)
          .syncTotalMarks(testId, teacherId: teacherId);
      ref.invalidate(testQuestionsProvider(testId));
      ref.invalidate(teacherTestDetailProvider(testId));
      ref.invalidate(teacherTestStatsProvider(testId));
      state = const AsyncFormState(success: true);
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  void reset() => state = const AsyncFormState();
}

final questionFormProvider =
    AutoDisposeNotifierProvider<QuestionFormNotifier, AsyncFormState>(
      QuestionFormNotifier.new,
    );
