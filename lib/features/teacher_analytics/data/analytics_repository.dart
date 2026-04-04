// ─────────────────────────────────────────────────────────────
//  analytics_repository.dart
//  All Supabase queries for the Teacher Analytics module.
//  Queries: enrollments, watch_progress, test_attempts, doubts.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase_service.dart';
import '../models/analytics_models.dart';

final analyticsRepositoryProvider =
    Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(supabaseClientProvider));
});

class AnalyticsRepository {
  final SupabaseClient _db;
  AnalyticsRepository(this._db);

  // ═══════════════════════════════════════════════════════
  //  SUMMARY
  // ═══════════════════════════════════════════════════════

  /// Build the top-level summary for a teacher's courses.
  Future<TeacherAnalyticsSummary> fetchSummary(
      List<String> courseIds) async {
    if (courseIds.isEmpty) {
      return const TeacherAnalyticsSummary(
        totalStudents: 0,
        totalCourses: 0,
        totalTests: 0,
        totalAttempts: 0,
        averageScore: 0,
        averageCompletion: 0,
        pendingDoubts: 0,
        resolvedDoubts: 0,
      );
    }

    // Enrollments (direct by course_id)
    final enrollRows = await _db
        .from('enrollments')
        .select('student_id, progress_percent')
        .inFilter('course_id', courseIds);

    int totalStudents = 0;
    double avgCompletion = 0;
    {
      final unique =
          (enrollRows as List).map((r) => r['student_id'] as String).toSet();
      totalStudents = unique.length;
      if (enrollRows.isNotEmpty) {
        final total = enrollRows.fold<double>(
            0, (s, r) => s + ((r['progress_percent'] as num).toDouble()));
        avgCompletion = total / enrollRows.length;
      }
    }

    // Tests for these courses (via chapters→subjects→courses)
    final subjectRows = await _db
        .from('subjects')
        .select('id')
        .inFilter('course_id', courseIds);
    final subjectIds =
        subjectRows.map((r) => r['id'] as String).toList();

    int totalTests = 0;
    int totalAttempts = 0;
    double avgScore = 0;

    if (subjectIds.isNotEmpty) {
      final chapterRows = await _db
          .from('chapters')
          .select('id')
          .inFilter('subject_id', subjectIds);
      final chapterIds =
          chapterRows.map((r) => r['id'] as String).toList();

      if (chapterIds.isNotEmpty) {
        final testRows = await _db
            .from('tests')
            .select('id, total_marks')
            .inFilter('chapter_id', chapterIds);
        totalTests = testRows.length;
        final testIds =
            testRows.map((r) => r['id'] as String).toList();

        if (testIds.isNotEmpty) {
          final attemptRows = await _db
              .from('test_attempts')
              .select('score, total_marks')
              .inFilter('test_id', testIds);
          totalAttempts = attemptRows.length;
          if (attemptRows.isNotEmpty) {
            final scoreSum = attemptRows.fold<double>(
                0,
                (s, r) =>
                    s +
                    ((r['score'] as num).toDouble() /
                        (r['total_marks'] as num).toDouble() *
                        100));
            avgScore = scoreSum / attemptRows.length;
          }
        }
      }
    }

    // Doubts
    final doubtRows = await _db
        .from('doubts')
        .select('is_answered');

    int resolvedDoubts = 0;
    int pendingDoubts = 0;
    for (final r in doubtRows) {
      if (r['is_answered'] as bool? ?? false) {
        resolvedDoubts++;
      } else {
        pendingDoubts++;
      }
    }

    return TeacherAnalyticsSummary(
      totalStudents: totalStudents,
      totalCourses: courseIds.length,
      totalTests: totalTests,
      totalAttempts: totalAttempts,
      averageScore: avgScore,
      averageCompletion: avgCompletion,
      pendingDoubts: pendingDoubts,
      resolvedDoubts: resolvedDoubts,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  ENROLLMENT TREND (last 6 months)
  // ═══════════════════════════════════════════════════════

  Future<List<EnrollmentPoint>> fetchEnrollmentTrend(
      List<String> courseIds) async {
    if (courseIds.isEmpty) return [];

    final since =
        DateTime.now().subtract(const Duration(days: 180));
    final rows = await _db
        .from('enrollments')
        .select('enrolled_at')
        .inFilter('course_id', courseIds)
        .gte('enrolled_at', since.toIso8601String())
        .order('enrolled_at', ascending: true);

    // Bucket by month
    final Map<String, int> buckets = {};
    for (final r in rows) {
      final dt = DateTime.parse(r['enrolled_at'] as String);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      buckets[key] = (buckets[key] ?? 0) + 1;
    }

    // Build 6 ordered points
    final now = DateTime.now();
    final points = <EnrollmentPoint>[];
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key =
          '${m.year}-${m.month.toString().padLeft(2, '0')}';
      points.add(
          EnrollmentPoint(month: m, count: buckets[key] ?? 0));
    }
    return points;
  }

  // ═══════════════════════════════════════════════════════
  //  STUDENT LEADERBOARD
  // ═══════════════════════════════════════════════════════

  Future<List<StudentRankEntry>> fetchStudentLeaderboard(
      List<String> courseIds) async {
    if (courseIds.isEmpty) return [];

    // Enrollments with student name + progress
    final enrollRows = await _db
        .from('enrollments')
        .select('student_id, progress_percent, users!student_id(name)')
        .inFilter('course_id', courseIds);

    if ((enrollRows as List).isEmpty) return [];

    // Group by student
    final Map<String, _StudentAcc> acc = {};
    for (final r in enrollRows) {
      final sid = r['student_id'] as String;
      final name =
          (r['users'] as Map?)?.get('name') as String? ?? 'Student';
      final prog = (r['progress_percent'] as num).toDouble();
      if (!acc.containsKey(sid)) {
        acc[sid] = _StudentAcc(name: name);
      }
      acc[sid]!.progressValues.add(prog);
    }

    // Test attempts
    final subjectRows = await _db
        .from('subjects')
        .select('id')
        .inFilter('course_id', courseIds);
    final subjectIds =
        subjectRows.map((r) => r['id'] as String).toList();

    if (subjectIds.isNotEmpty) {
      final chapterRows = await _db
          .from('chapters')
          .select('id')
          .inFilter('subject_id', subjectIds);
      final chapterIds =
          chapterRows.map((r) => r['id'] as String).toList();

      if (chapterIds.isNotEmpty) {
        final testRows = await _db
            .from('tests')
            .select('id')
            .inFilter('chapter_id', chapterIds);
        final testIds =
            testRows.map((r) => r['id'] as String).toList();

        if (testIds.isNotEmpty) {
          final attemptRows = await _db
              .from('test_attempts')
              .select('student_id, score, total_marks')
              .inFilter('test_id', testIds);

          for (final r in attemptRows) {
            final sid = r['student_id'] as String;
            if (!acc.containsKey(sid)) continue;
            final pct = (r['score'] as num).toDouble() /
                (r['total_marks'] as num).toDouble() *
                100;
            acc[sid]!.scoreValues.add(pct);
          }
        }
      }
    }

    final entries = acc.entries.map((e) {
      final v = e.value;
      final avgScore = v.scoreValues.isEmpty
          ? 0.0
          : v.scoreValues.reduce((a, b) => a + b) /
              v.scoreValues.length;
      final avgProg = v.progressValues.isEmpty
          ? 0.0
          : v.progressValues.reduce((a, b) => a + b) /
              v.progressValues.length;
      return StudentRankEntry(
        studentId: e.key,
        studentName: v.name,
        avgScore: avgScore,
        totalAttempts: v.scoreValues.length,
        avgProgress: avgProg,
      );
    }).toList();

    entries.sort((a, b) => b.avgScore.compareTo(a.avgScore));
    return entries;
  }

  // ═══════════════════════════════════════════════════════
  //  COURSE ANALYTICS
  // ═══════════════════════════════════════════════════════

  Future<CourseAnalyticsData> fetchCourseAnalytics(
      String courseId, String courseTitle) async {
    // Enrollments for this course
    final enrollRows = await _db
        .from('enrollments')
        .select(
            'student_id, progress_percent, enrolled_at, users!student_id(name)')
        .eq('course_id', courseId);

    List<StudentProgressRow> studentProgress = [];
    int completedStudents = 0;
    double avgProgress = 0;

    {
      final Map<String, _StudentAcc> acc = {};
      for (final r in enrollRows as List) {
        final sid = r['student_id'] as String;
        final name =
            (r['users'] as Map?)?.get('name') as String? ?? 'Student';
        final prog = (r['progress_percent'] as num).toDouble();
        final enrolled = DateTime.parse(r['enrolled_at'] as String);
        if (!acc.containsKey(sid)) {
          acc[sid] = _StudentAcc(name: name, enrolledAt: enrolled);
        }
        final existing = acc[sid]!;
        existing.progressValues.add(prog);
        if (enrolled.isBefore(existing.enrolledAt!)) {
          existing.enrolledAt = enrolled;
        }
      }

      double totalProg = 0;
      for (final e in acc.entries) {
        final v = e.value;
        final prog = v.progressValues.isNotEmpty
            ? v.progressValues.reduce((a, b) => a + b) /
                v.progressValues.length
            : 0.0;
        if (prog >= 100) completedStudents++;
        totalProg += prog;
        studentProgress.add(StudentProgressRow(
          studentId: e.key,
          studentName: v.name,
          progressPercent: prog,
          enrolledAt: v.enrolledAt ?? DateTime.now(),
          lecturesWatched: 0,
          totalLectures: 0,
        ));
      }
      if (acc.isNotEmpty) avgProgress = totalProg / acc.length;
      studentProgress
          .sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    }

    // Tests + attempts + difficult questions
    final subjectRows = await _db
        .from('subjects')
        .select('id')
        .eq('course_id', courseId);
    final subjectIds =
        subjectRows.map((r) => r['id'] as String).toList();

    List<TestSummaryRow> testSummaries = [];
    if (subjectIds.isNotEmpty) {
      final chapterRows = await _db
          .from('chapters')
          .select('id')
          .inFilter('subject_id', subjectIds);
      final chapterIds =
          chapterRows.map((r) => r['id'] as String).toList();

      if (chapterIds.isNotEmpty) {
        final testRows = await _db
            .from('tests')
            .select('id, title, total_marks')
            .inFilter('chapter_id', chapterIds);

        for (final t in testRows) {
          final tid = t['id'] as String;
          final title = t['title'] as String;
          final totalMarks = t['total_marks'] as int;

          final attemptRows = await _db
              .from('test_attempts')
              .select('score, total_marks, answers')
              .eq('test_id', tid);

          int attemptCount = attemptRows.length;
          double avgScore = 0;
          double avgPct = 0;
          double highPct = 0;
          double lowPct = 100;

          if (attemptCount > 0) {
            double scoreSum = 0;
            double pctSum = 0;
            for (final a in attemptRows) {
              final sc = (a['score'] as num).toDouble();
              final tm = (a['total_marks'] as num).toDouble();
              final pct = tm == 0 ? 0.0 : sc / tm * 100;
              scoreSum += sc;
              pctSum += pct;
              if (pct > highPct) highPct = pct;
              if (pct < lowPct) lowPct = pct;
            }
            avgScore = scoreSum / attemptCount;
            avgPct = pctSum / attemptCount;
          } else {
            lowPct = 0;
          }

          // Difficult questions: count wrong answers per question
          final questionRows = await _db
              .from('questions')
              .select('id, question')
              .eq('test_id', tid);

          final Map<String, int> wrongCount = {};
          final Map<String, int> totalCount = {};
          final Map<String, String> qText = {};
          for (final q in questionRows) {
            final qid = q['id'] as String;
            qText[qid] = q['question'] as String;
            wrongCount[qid] = 0;
            totalCount[qid] = 0;
          }

          for (final a in attemptRows) {
            final answers =
                Map<String, dynamic>.from(a['answers'] as Map);
            for (final q in questionRows) {
              final qid = q['id'] as String;
              final correctIdx = q['correct_option_index'] as int;
              final chosen = answers[qid] as int?;
              totalCount[qid] = (totalCount[qid] ?? 0) + 1;
              if (chosen != null && chosen != correctIdx) {
                wrongCount[qid] = (wrongCount[qid] ?? 0) + 1;
              }
            }
          }

          final difficultQs = qText.entries
              .map((e) => DifficultQuestion(
                    questionId: e.key,
                    questionText: e.value,
                    totalAttempts: totalCount[e.key] ?? 0,
                    wrongAttempts: wrongCount[e.key] ?? 0,
                  ))
              .where((q) => q.totalAttempts > 0)
              .toList()
            ..sort((a, b) => b.errorRate.compareTo(a.errorRate));

          testSummaries.add(TestSummaryRow(
            testId: tid,
            testTitle: title,
            totalMarks: totalMarks,
            attemptCount: attemptCount,
            avgScore: avgScore,
            avgPercent: avgPct,
            highestPercent: highPct,
            lowestPercent: lowPct,
            difficultQuestions: difficultQs.take(5).toList(),
          ));
        }
      }
    }

    // Doubts linked to this course's lectures
    final lectureRows = await _fetchCourseLectureIds(courseId);
    int totalDoubts = 0;
    int answeredDoubts = 0;
    if (lectureRows.isNotEmpty) {
      final doubtRows = await _db
          .from('doubts')
          .select('is_answered')
          .inFilter('lecture_id', lectureRows);
      totalDoubts = doubtRows.length;
      answeredDoubts =
          doubtRows.where((d) => d['is_answered'] as bool? ?? false).length;
    }

    return CourseAnalyticsData(
      courseId: courseId,
      courseTitle: courseTitle,
      enrolledStudents: studentProgress.length,
      completedStudents: completedStudents,
      avgProgressPercent: avgProgress,
      studentProgress: studentProgress,
      testSummaries: testSummaries,
      totalDoubts: totalDoubts,
      answeredDoubts: answeredDoubts,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  STUDENT ANALYTICS
  // ═══════════════════════════════════════════════════════

  Future<StudentAnalyticsData> fetchStudentAnalytics(
      String studentId, String studentName, List<String> courseIds) async {
    if (courseIds.isEmpty) {
      return StudentAnalyticsData(
        studentId: studentId,
        studentName: studentName,
        courseProgress: [],
        testAttempts: [],
        totalDoubts: 0,
        answeredDoubts: 0,
      );
    }

    // --- Course progress ---
    List<CourseProgressItem> courseProgress = [];
    {
      final enrollRows = await _db
          .from('enrollments')
          .select('course_id, progress_percent, enrolled_at')
          .eq('student_id', studentId)
          .inFilter('course_id', courseIds);

      // Fetch course titles
      final courseRows = await _db
          .from('courses')
          .select('id, title, total_lectures')
          .inFilter('id', courseIds);
      final Map<String, String> courseTitleMap = {
        for (final r in courseRows) r['id'] as String: r['title'] as String,
      };
      final Map<String, int> courseLectures = {
        for (final r in courseRows)
          r['id'] as String: (r['total_lectures'] as int? ?? 0),
      };

      for (final r in enrollRows as List) {
        final cid = r['course_id'] as String;
        courseProgress.add(CourseProgressItem(
          courseId: cid,
          courseTitle: courseTitleMap[cid] ?? 'Course',
          progressPercent: (r['progress_percent'] as num).toDouble(),
          lecturesWatched: 0,
          totalLectures: courseLectures[cid] ?? 0,
          enrolledAt: DateTime.parse(r['enrolled_at'] as String),
        ));
      }
    }

    // --- Test attempts ---
    final subjectRows = await _db
        .from('subjects')
        .select('id')
        .inFilter('course_id', courseIds);
    final subjectIds =
        subjectRows.map((r) => r['id'] as String).toList();

    List<TestAttemptItem> testAttempts = [];
    if (subjectIds.isNotEmpty) {
      final chapterRows = await _db
          .from('chapters')
          .select('id')
          .inFilter('subject_id', subjectIds);
      final chapterIds =
          chapterRows.map((r) => r['id'] as String).toList();

      if (chapterIds.isNotEmpty) {
        final testRows = await _db
            .from('tests')
            .select('id, title')
            .inFilter('chapter_id', chapterIds);
        final Map<String, String> testTitles = {
          for (final r in testRows) r['id'] as String: r['title'] as String,
        };
        final testIds = testRows.map((r) => r['id'] as String).toList();

        if (testIds.isNotEmpty) {
          final attemptRows = await _db
              .from('test_attempts')
              .select(
                  'test_id, score, total_marks, correct_answers, wrong_answers, skipped, attempted_at')
              .eq('student_id', studentId)
              .inFilter('test_id', testIds)
              .order('attempted_at', ascending: false);

          for (final r in attemptRows) {
            final tid = r['test_id'] as String;
            testAttempts.add(TestAttemptItem(
              testId: tid,
              testTitle: testTitles[tid] ?? 'Test',
              score: r['score'] as int,
              totalMarks: r['total_marks'] as int,
              correctAnswers: r['correct_answers'] as int,
              wrongAnswers: r['wrong_answers'] as int,
              skipped: r['skipped'] as int,
              attemptedAt:
                  DateTime.parse(r['attempted_at'] as String),
            ));
          }
        }
      }
    }

    // --- Doubts ---
    final doubtRows = await _db
        .from('doubts')
        .select('is_answered')
        .eq('student_id', studentId);
    final totalDoubts = doubtRows.length;
    final answeredDoubts = doubtRows
        .where((d) => d['is_answered'] as bool? ?? false)
        .length;

    return StudentAnalyticsData(
      studentId: studentId,
      studentName: studentName,
      courseProgress: courseProgress,
      testAttempts: testAttempts,
      totalDoubts: totalDoubts,
      answeredDoubts: answeredDoubts,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════

  Future<List<String>> _fetchCourseLectureIds(String courseId) async {
    try {
      final subjects = await _db
          .from('subjects')
          .select('id')
          .eq('course_id', courseId);
      final sids = subjects.map((r) => r['id'] as String).toList();
      if (sids.isEmpty) return [];

      final chapters = await _db
          .from('chapters')
          .select('id')
          .inFilter('subject_id', sids);
      final cids = chapters.map((r) => r['id'] as String).toList();
      if (cids.isEmpty) return [];

      final lectures = await _db
          .from('lectures')
          .select('id')
          .inFilter('chapter_id', cids);
      return lectures.map((r) => r['id'] as String).toList();
    } catch (_) {
      return [];
    }
  }
}

// ── Internal accumulator for grouping by student ─────────────
class _StudentAcc {
  final String name;
  final List<double> progressValues = [];
  final List<double> scoreValues = [];
  DateTime? enrolledAt;

  _StudentAcc({required this.name, this.enrolledAt});
}

extension _MapGet on Map {
  dynamic get(Object? key) => this[key];
}
