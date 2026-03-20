// ─────────────────────────────────────────────────────────────
//  teacher_test_repository.dart
//  Supabase CRUD for teacher-side MCQ Test management.
//  Tables: tests, questions, test_attempts
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';

final teacherTestRepoProvider = Provider<TeacherTestRepository>((ref) {
  return TeacherTestRepository(ref.watch(supabaseClientProvider));
});

class TeacherTestStats {
  final int questionCount;
  final int attemptCount;

  const TeacherTestStats({
    required this.questionCount,
    required this.attemptCount,
  });

  bool get hasAttempts => attemptCount > 0;
}

class TeacherTestRepository {
  final SupabaseClient _db;

  TeacherTestRepository(this._db);

  Future<void> _requireTeacherOwnsChapter(
    String chapterId,
    String teacherId,
  ) async {
    final chapter = await _db
        .from('chapters')
        .select('subject_id')
        .eq('id', chapterId)
        .maybeSingle();
    if (chapter == null) {
      throw StateError('Chapter not found.');
    }

    final subject = await _db
        .from('subjects')
        .select('course_id')
        .eq('id', chapter['subject_id'] as String)
        .maybeSingle();
    if (subject == null) {
      throw StateError('Subject not found for this chapter.');
    }

    final course = await _db
        .from('courses')
        .select('teacher_id')
        .eq('id', subject['course_id'] as String)
        .maybeSingle();
    if (course == null || course['teacher_id'] != teacherId) {
      throw StateError(
        'You do not have permission to manage tests for this chapter.',
      );
    }
  }

  Future<String> _requireTeacherOwnsTest(
    String testId,
    String teacherId,
  ) async {
    final test = await _db
        .from('tests')
        .select('chapter_id')
        .eq('id', testId)
        .maybeSingle();
    if (test == null) {
      throw StateError('Test not found.');
    }

    final chapterId = test['chapter_id'] as String;
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    return chapterId;
  }

  Future<void> _ensureTestIsEditable(String testId, String teacherId) async {
    await _requireTeacherOwnsTest(testId, teacherId);
    final attempts = await _db
        .from('test_attempts')
        .select('id')
        .eq('test_id', testId);
    if (attempts.isNotEmpty) {
      throw StateError(
        'This test already has student attempts, so editing is locked.',
      );
    }
  }

  // ════════════════════════════════════════════════════════
  //  TESTS
  // ════════════════════════════════════════════════════════

  Future<List<TestModel>> fetchTests(String chapterId, String teacherId) async {
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    final data = await _db
        .from('tests')
        .select()
        .eq('chapter_id', chapterId)
        .order('created_at', ascending: false);
    return data
        .map((j) => TestModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<TestModel> fetchTest(String testId, String teacherId) async {
    await _requireTeacherOwnsTest(testId, teacherId);
    final data = await _db.from('tests').select().eq('id', testId).single();
    return TestModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<TeacherTestStats> fetchTestStats(
    String testId,
    String teacherId,
  ) async {
    await _requireTeacherOwnsTest(testId, teacherId);
    final questions = await _db
        .from('questions')
        .select('id')
        .eq('test_id', testId);
    final attempts = await _db
        .from('test_attempts')
        .select('id')
        .eq('test_id', testId);
    return TeacherTestStats(
      questionCount: questions.length,
      attemptCount: attempts.length,
    );
  }

  Future<TestModel> createTest({
    required String teacherId,
    required String chapterId,
    String? courseId,
    required String title,
    required int durationMinutes,
    required int totalMarks,
    double negativeMarks = 0.25,
    bool isPublished = false,
  }) async {
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    final data = await _db
        .from('tests')
        .insert({
          'chapter_id': chapterId,
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

  Future<TestModel> updateTest({
    required String teacherId,
    required String testId,
    required String title,
    required int durationMinutes,
    required int totalMarks,
    double negativeMarks = 0.25,
  }) async {
    await _requireTeacherOwnsTest(testId, teacherId);
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

  Future<void> togglePublish(
    String testId, {
    required String teacherId,
    required bool publish,
  }) async {
    await _ensureTestIsEditable(testId, teacherId);
    await _db.from('tests').update({'is_published': publish}).eq('id', testId);
  }

  Future<void> deleteTest(String testId, {required String teacherId}) async {
    await _ensureTestIsEditable(testId, teacherId);
    await _db.from('tests').delete().eq('id', testId);
  }

  // ════════════════════════════════════════════════════════
  //  QUESTIONS
  // ════════════════════════════════════════════════════════

  Future<List<QuestionModel>> fetchQuestions(
    String testId,
    String teacherId,
  ) async {
    await _requireTeacherOwnsTest(testId, teacherId);
    final data = await _db
        .from('questions')
        .select()
        .eq('test_id', testId)
        .order('created_at', ascending: true);
    return data
        .map((j) => QuestionModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<QuestionModel> createQuestion({
    required String teacherId,
    required String testId,
    required String question,
    required List<String> options,
    required int correctOptionIndex,
    required int marks,
    String? explanation,
  }) async {
    assert(options.length == 4, 'Exactly 4 options required');
    await _ensureTestIsEditable(testId, teacherId);
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

  Future<QuestionModel> updateQuestion({
    required String teacherId,
    required String questionId,
    required String testId,
    required String question,
    required List<String> options,
    required int correctOptionIndex,
    required int marks,
    String? explanation,
  }) async {
    assert(options.length == 4, 'Exactly 4 options required');
    await _ensureTestIsEditable(testId, teacherId);
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

  Future<void> deleteQuestion(
    String questionId, {
    required String teacherId,
    required String testId,
  }) async {
    await _ensureTestIsEditable(testId, teacherId);
    await _db.from('questions').delete().eq('id', questionId);
  }

  Future<void> syncTotalMarks(
    String testId, {
    required String teacherId,
  }) async {
    final questions = await fetchQuestions(testId, teacherId);
    final total = questions.fold<int>(0, (sum, q) => sum + q.marks);
    await _db.from('tests').update({'total_marks': total}).eq('id', testId);
  }
}
