// ─────────────────────────────────────────────────────────────
//  teacher_test_repository.dart
//  Supabase CRUD for teacher-side MCQ Test management.
//  Tables: tests, questions
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';

final teacherTestRepoProvider = Provider<TeacherTestRepository>((ref) {
  return TeacherTestRepository(ref.watch(supabaseClientProvider));
});

class TeacherTestRepository {
  final SupabaseClient _db;
  TeacherTestRepository(this._db);

  // ════════════════════════════════════════════════════════
  //  TESTS
  // ════════════════════════════════════════════════════════

  /// Fetch all tests belonging to a chapter.
  Future<List<TestModel>> fetchTests(String chapterId) async {
    final data = await _db
        .from('tests')
        .select()
        .eq('chapter_id', chapterId)
        .order('created_at', ascending: false);
    return data
        .map((j) => TestModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// Fetch a single test by ID.
  Future<TestModel> fetchTest(String testId) async {
    final data = await _db
        .from('tests')
        .select()
        .eq('id', testId)
        .single();
    return TestModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Create a new test. Returns the persisted row.
  Future<TestModel> createTest({
    required String chapterId,
    String? courseId,
    required String title,
    required int durationMinutes,
    required int totalMarks,
    double negativeMarks = 0.25,
    bool isPublished = false,
  }) async {
    final data = await _db
        .from('tests')
        .insert({
          'chapter_id': chapterId,
          'course_id': courseId,
          'title': title,
          'duration_minutes': durationMinutes,
          'total_marks': totalMarks,
          'negative_marks': negativeMarks,
          'is_published': isPublished,
        })
        .select()
        .single();
    return TestModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Update test metadata.
  Future<TestModel> updateTest({
    required String testId,
    required String title,
    required int durationMinutes,
    required int totalMarks,
    double negativeMarks = 0.25,
  }) async {
    final data = await _db
        .from('tests')
        .update({
          'title': title,
          'duration_minutes': durationMinutes,
          'total_marks': totalMarks,
          'negative_marks': negativeMarks,
        })
        .eq('id', testId)
        .select()
        .single();
    return TestModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Toggle publish state.
  Future<void> togglePublish(String testId, {required bool publish}) async {
    await _db
        .from('tests')
        .update({'is_published': publish})
        .eq('id', testId);
  }

  /// Delete a test and all its questions (cascade handled by DB or done here).
  Future<void> deleteTest(String testId) async {
    // Questions have ON DELETE CASCADE in Supabase schema so one call suffices.
    await _db.from('tests').delete().eq('id', testId);
  }

  // ════════════════════════════════════════════════════════
  //  QUESTIONS
  // ════════════════════════════════════════════════════════

  /// Fetch all questions for a test, ordered by insertion.
  Future<List<QuestionModel>> fetchQuestions(String testId) async {
    final data = await _db
        .from('questions')
        .select()
        .eq('test_id', testId)
        .order('created_at', ascending: true);
    return data
        .map((j) => QuestionModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// Add a new MCQ question to a test.
  Future<QuestionModel> createQuestion({
    required String testId,
    required String question,
    required List<String> options,
    required int correctOptionIndex,
    required int marks,
    String? explanation,
  }) async {
    assert(options.length == 4, 'Exactly 4 options required');
    final data = await _db
        .from('questions')
        .insert({
          'test_id': testId,
          'question': question,
          'options': options,
          'correct_option_index': correctOptionIndex,
          'marks': marks,
          'explanation': explanation,
        })
        .select()
        .single();
    return QuestionModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Update an existing question.
  Future<QuestionModel> updateQuestion({
    required String questionId,
    required String question,
    required List<String> options,
    required int correctOptionIndex,
    required int marks,
    String? explanation,
  }) async {
    assert(options.length == 4, 'Exactly 4 options required');
    final data = await _db
        .from('questions')
        .update({
          'question': question,
          'options': options,
          'correct_option_index': correctOptionIndex,
          'marks': marks,
          'explanation': explanation,
        })
        .eq('id', questionId)
        .select()
        .single();
    return QuestionModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Delete a single question.
  Future<void> deleteQuestion(String questionId) async {
    await _db.from('questions').delete().eq('id', questionId);
  }

  /// Recalculate and patch total_marks on the test based on its questions.
  Future<void> syncTotalMarks(String testId) async {
    final questions = await fetchQuestions(testId);
    final total = questions.fold<int>(0, (sum, q) => sum + q.marks);
    await _db
        .from('tests')
        .update({'total_marks': total})
        .eq('id', testId);
  }
}
