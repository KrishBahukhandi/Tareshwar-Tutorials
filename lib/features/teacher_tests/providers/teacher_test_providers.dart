// ─────────────────────────────────────────────────────────────
//  teacher_test_providers.dart
//  Riverpod state for the Teacher Tests module.
//  Covers: test list, question list, and form notifiers
//  for create/edit test and create/edit/delete question.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../data/teacher_test_repository.dart';

// ═════════════════════════════════════════════════════════════
//  READ PROVIDERS
// ═════════════════════════════════════════════════════════════

/// All tests for a given chapter.
final teacherTestsProvider = FutureProvider.autoDispose
    .family<List<TestModel>, String>((ref, chapterId) async {
  return ref.read(teacherTestRepoProvider).fetchTests(chapterId);
});

/// All questions for a given test.
final testQuestionsProvider = FutureProvider.autoDispose
    .family<List<QuestionModel>, String>((ref, testId) async {
  return ref.read(teacherTestRepoProvider).fetchQuestions(testId);
});

/// Single test detail (used in preview / edit header).
final teacherTestDetailProvider = FutureProvider.autoDispose
    .family<TestModel, String>((ref, testId) async {
  return ref.read(teacherTestRepoProvider).fetchTest(testId);
});

// ═════════════════════════════════════════════════════════════
//  SHARED FORM STATE
// ═════════════════════════════════════════════════════════════

class AsyncFormState {
  final bool isSubmitting;
  final String? error;
  final bool success;

  const AsyncFormState({
    this.isSubmitting = false,
    this.error,
    this.success = false,
  });

  AsyncFormState copyWith({
    bool? isSubmitting,
    String? error,
    bool? success,
  }) =>
      AsyncFormState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
        success: success ?? this.success,
      );
}

// ═════════════════════════════════════════════════════════════
//  TEST FORM NOTIFIER  (create)
// ═════════════════════════════════════════════════════════════

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
      final test = await ref.read(teacherTestRepoProvider).createTest(
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
        TestFormNotifier.new);

// ═════════════════════════════════════════════════════════════
//  TEST EDIT NOTIFIER  (update + publish toggle)
// ═════════════════════════════════════════════════════════════

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
      await ref.read(teacherTestRepoProvider).updateTest(
            testId: testId,
            title: title,
            durationMinutes: durationMinutes,
            totalMarks: totalMarks,
            negativeMarks: negativeMarks,
          );
      ref.invalidate(teacherTestsProvider(chapterId));
      ref.invalidate(teacherTestDetailProvider(testId));
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
      await ref
          .read(teacherTestRepoProvider)
          .togglePublish(testId, publish: publish);
      ref.invalidate(teacherTestsProvider(chapterId));
      ref.invalidate(teacherTestDetailProvider(testId));
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  Future<void> delete(String testId, {required String chapterId}) async {
    state = const AsyncFormState(isSubmitting: true);
    try {
      await ref.read(teacherTestRepoProvider).deleteTest(testId);
      ref.invalidate(teacherTestsProvider(chapterId));
      state = const AsyncFormState(success: true);
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  void reset() => state = const AsyncFormState();
}

final testEditProvider =
    AutoDisposeNotifierProvider<TestEditNotifier, AsyncFormState>(
        TestEditNotifier.new);

// ═════════════════════════════════════════════════════════════
//  QUESTION FORM NOTIFIER  (add + edit)
// ═════════════════════════════════════════════════════════════

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
      await ref.read(teacherTestRepoProvider).createQuestion(
            testId: testId,
            question: question,
            options: options,
            correctOptionIndex: correctOptionIndex,
            marks: marks,
            explanation: explanation,
          );
      // Sync total_marks so test header stays accurate.
      await ref.read(teacherTestRepoProvider).syncTotalMarks(testId);
      ref.invalidate(testQuestionsProvider(testId));
      ref.invalidate(teacherTestDetailProvider(testId));
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
      await ref.read(teacherTestRepoProvider).updateQuestion(
            questionId: questionId,
            question: question,
            options: options,
            correctOptionIndex: correctOptionIndex,
            marks: marks,
            explanation: explanation,
          );
      await ref.read(teacherTestRepoProvider).syncTotalMarks(testId);
      ref.invalidate(testQuestionsProvider(testId));
      ref.invalidate(teacherTestDetailProvider(testId));
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
      await ref.read(teacherTestRepoProvider).deleteQuestion(questionId);
      await ref.read(teacherTestRepoProvider).syncTotalMarks(testId);
      ref.invalidate(testQuestionsProvider(testId));
      ref.invalidate(teacherTestDetailProvider(testId));
      state = const AsyncFormState(success: true);
    } catch (e) {
      state = AsyncFormState(error: e.toString());
    }
  }

  void reset() => state = const AsyncFormState();
}

final questionFormProvider =
    AutoDisposeNotifierProvider<QuestionFormNotifier, AsyncFormState>(
        QuestionFormNotifier.new);
