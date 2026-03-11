// ─────────────────────────────────────────────────────────────
//  test_service.dart  –  Test/quiz API layer
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'supabase_service.dart';

final testServiceProvider = Provider<TestService>((ref) {
  return TestService(ref.watch(supabaseClientProvider));
});

class TestService {
  final SupabaseClient _client;
  TestService(this._client);

  Future<TestModel> fetchTest(String testId) async {
    final data = await _client.from('tests').select().eq('id', testId).single();
    return TestModel.fromJson(data);
  }

  Future<List<TestModel>> fetchTests({String? courseId}) async {
    var query = _client.from('tests').select();
    final List<Map<String, dynamic>> data;
    if (courseId != null) {
      data = await query.eq('course_id', courseId).order('created_at', ascending: false);
    } else {
      data = await query.order('created_at', ascending: false);
    }
    return data.map((t) => TestModel.fromJson(Map<String, dynamic>.from(t))).toList();
  }

  Future<List<TestModel>> fetchTestsByChapter(String chapterId) async {
    final data = await _client
        .from('tests')
        .select()
        .eq('chapter_id', chapterId)
        .eq('is_published', true)
        .order('created_at', ascending: false);
    return data
        .map((t) => TestModel.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();
  }

  /// Fetch a specific attempt by ID
  Future<TestAttemptModel?> fetchAttemptById(String attemptId) async {
    try {
      final data = await _client
          .from('test_attempts')
          .select()
          .eq('id', attemptId)
          .single();
      return TestAttemptModel.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return null;
    }
  }

  /// Fetch last attempt for a student on a specific test
  Future<TestAttemptModel?> fetchLastAttempt({
    required String testId,
    required String studentId,
  }) async {
    try {
      final data = await _client
          .from('test_attempts')
          .select()
          .eq('test_id', testId)
          .eq('student_id', studentId)
          .order('attempted_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return TestAttemptModel.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return null;
    }
  }

  /// Aggregate stats: best score, avg score, total attempts for a student
  Future<Map<String, dynamic>> fetchStudentStats(String studentId) async {
    try {
      final data = await _client
          .from('test_attempts')
          .select('score, total_marks')
          .eq('student_id', studentId);
      if (data.isEmpty) {
        return {'best': 0, 'avg': 0.0, 'total': 0};
      }
      int best = 0;
      double sum = 0;
      for (final row in data) {
        final s = row['score'] as int? ?? 0;
        if (s > best) best = s;
        sum += s;
      }
      return {
        'best': best,
        'avg': sum / data.length,
        'total': data.length,
      };
    } catch (_) {
      return {'best': 0, 'avg': 0.0, 'total': 0};
    }
  }

  Future<List<QuestionModel>> fetchQuestions(String testId) async {
    final data = await _client
        .from('questions')
        .select()
        .eq('test_id', testId)
        .order('created_at');
    return data
        .map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
        .toList();
  }

  Future<List<TestAttemptModel>> fetchAttempts({
    String? testId,
    String? studentId,
  }) async {
    var query = _client.from('test_attempts').select();
    List<Map<String, dynamic>> data;
    if (testId != null && studentId != null) {
      data = await query
          .eq('test_id', testId)
          .eq('student_id', studentId)
          .order('attempted_at', ascending: false);
    } else if (testId != null) {
      data = await query.eq('test_id', testId).order('attempted_at', ascending: false);
    } else if (studentId != null) {
      data = await query.eq('student_id', studentId).order('attempted_at', ascending: false);
    } else {
      data = await query.order('attempted_at', ascending: false);
    }
    return data.map((a) => TestAttemptModel.fromJson(Map<String, dynamic>.from(a))).toList();
  }

  Future<TestAttemptModel> submitAttempt({
    required String testId,
    required String studentId,
    required List<QuestionModel> questions,
    required Map<String, int> answers,
    required int timeTakenSeconds,
  }) async {
    int score = 0;
    int correct = 0;
    int wrong = 0;
    int skipped = 0;

    final testData = await _client.from('tests').select('negative_marks').eq('id', testId).single();
    final negMarks = (testData['negative_marks'] as num).toDouble();

    for (final q in questions) {
      final selected = answers[q.id];
      if (selected == null) {
        skipped++;
      } else if (selected == q.correctOptionIndex) {
        score += q.marks;
        correct++;
      } else {
        score -= (negMarks * q.marks).round();
        wrong++;
      }
    }

    final totalMarks = questions.fold(0, (sum, q) => sum + q.marks);
    score = score.clamp(0, totalMarks);

    final data = await _client
        .from('test_attempts')
        .insert({
          'test_id': testId,
          'student_id': studentId,
          'score': score,
          'total_marks': totalMarks,
          'correct_answers': correct,
          'wrong_answers': wrong,
          'skipped': skipped,
          'time_taken_seconds': timeTakenSeconds,
          'answers': answers,
          'attempted_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return TestAttemptModel.fromJson(data);
  }

  Future<List<TestAttemptModel>> fetchLeaderboard(String testId) async {
    final data = await _client
        .from('test_attempts')
        .select('*, users!student_id(name)')
        .eq('test_id', testId)
        .order('score', ascending: false)
        .limit(50);
    return data
        .map((a) => TestAttemptModel.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList();
  }

  // ── Teacher: create test + questions ─────────────────────
  Future<TestModel> createTest({
    required String chapterId,
    required String title,
    required int durationMinutes,
    required int totalMarks,
    double negativeMarks = 0.25,
  }) async {
    final data = await _client.from('tests').insert({
      'chapter_id': chapterId,
      'title': title,
      'duration_minutes': durationMinutes,
      'total_marks': totalMarks,
      'negative_marks': negativeMarks,
    }).select().single();
    return TestModel.fromJson(data);
  }

  Future<void> addQuestion({
    required String testId,
    required String question,
    required List<String> options,
    required int correctOptionIndex,
    int marks = 4,
    String? explanation,
  }) async {
    await _client.from('questions').insert({
      'test_id': testId,
      'question': question,
      'options': options,
      'correct_option_index': correctOptionIndex,
      'marks': marks,
      'explanation': explanation,
    });
  }
}
