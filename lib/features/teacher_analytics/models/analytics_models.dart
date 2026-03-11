// ─────────────────────────────────────────────────────────────
//  analytics_models.dart
//  Pure data classes for the Teacher Analytics module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
//  TOP-LEVEL SUMMARY
// ═══════════════════════════════════════════════════════════

class TeacherAnalyticsSummary {
  final int totalStudents;
  final int totalCourses;
  final int totalTests;
  final int totalAttempts;
  final double averageScore;
  final double averageCompletion;
  final int pendingDoubts;
  final int resolvedDoubts;

  const TeacherAnalyticsSummary({
    required this.totalStudents,
    required this.totalCourses,
    required this.totalTests,
    required this.totalAttempts,
    required this.averageScore,
    required this.averageCompletion,
    required this.pendingDoubts,
    required this.resolvedDoubts,
  });

  double get doubtResolutionRate =>
      (pendingDoubts + resolvedDoubts) == 0
          ? 0
          : resolvedDoubts / (pendingDoubts + resolvedDoubts) * 100;
}

// ═══════════════════════════════════════════════════════════
//  COURSE-LEVEL ANALYTICS
// ═══════════════════════════════════════════════════════════

class CourseAnalyticsData {
  final String courseId;
  final String courseTitle;
  final int enrolledStudents;
  final int completedStudents;
  final double avgProgressPercent;
  final List<StudentProgressRow> studentProgress;
  final List<TestSummaryRow> testSummaries;
  final int totalDoubts;
  final int answeredDoubts;

  const CourseAnalyticsData({
    required this.courseId,
    required this.courseTitle,
    required this.enrolledStudents,
    required this.completedStudents,
    required this.avgProgressPercent,
    required this.studentProgress,
    required this.testSummaries,
    required this.totalDoubts,
    required this.answeredDoubts,
  });

  double get completionRate =>
      enrolledStudents == 0 ? 0 : completedStudents / enrolledStudents * 100;

  double get doubtResolutionRate =>
      totalDoubts == 0 ? 0 : answeredDoubts / totalDoubts * 100;
}

class StudentProgressRow {
  final String studentId;
  final String studentName;
  final double progressPercent;
  final DateTime enrolledAt;
  final int lecturesWatched;
  final int totalLectures;

  const StudentProgressRow({
    required this.studentId,
    required this.studentName,
    required this.progressPercent,
    required this.enrolledAt,
    required this.lecturesWatched,
    required this.totalLectures,
  });

  bool get isCompleted => progressPercent >= 100;
}

class TestSummaryRow {
  final String testId;
  final String testTitle;
  final int totalMarks;
  final int attemptCount;
  final double avgScore;
  final double avgPercent;
  final double highestPercent;
  final double lowestPercent;
  final List<DifficultQuestion> difficultQuestions;

  const TestSummaryRow({
    required this.testId,
    required this.testTitle,
    required this.totalMarks,
    required this.attemptCount,
    required this.avgScore,
    required this.avgPercent,
    required this.highestPercent,
    required this.lowestPercent,
    required this.difficultQuestions,
  });
}

class DifficultQuestion {
  final String questionId;
  final String questionText;
  final int totalAttempts;
  final int wrongAttempts;

  const DifficultQuestion({
    required this.questionId,
    required this.questionText,
    required this.totalAttempts,
    required this.wrongAttempts,
  });

  double get errorRate =>
      totalAttempts == 0 ? 0 : wrongAttempts / totalAttempts * 100;
}

// ═══════════════════════════════════════════════════════════
//  STUDENT-LEVEL ANALYTICS
// ═══════════════════════════════════════════════════════════

class StudentAnalyticsData {
  final String studentId;
  final String studentName;
  final List<CourseProgressItem> courseProgress;
  final List<TestAttemptItem> testAttempts;
  final int totalDoubts;
  final int answeredDoubts;

  const StudentAnalyticsData({
    required this.studentId,
    required this.studentName,
    required this.courseProgress,
    required this.testAttempts,
    required this.totalDoubts,
    required this.answeredDoubts,
  });

  double get avgTestScore {
    if (testAttempts.isEmpty) return 0;
    return testAttempts.map((a) => a.percentage).reduce((a, b) => a + b) /
        testAttempts.length;
  }

  double get avgProgress {
    if (courseProgress.isEmpty) return 0;
    return courseProgress
            .map((c) => c.progressPercent)
            .reduce((a, b) => a + b) /
        courseProgress.length;
  }
}

class CourseProgressItem {
  final String courseId;
  final String courseTitle;
  final double progressPercent;
  final int lecturesWatched;
  final int totalLectures;
  final DateTime enrolledAt;

  const CourseProgressItem({
    required this.courseId,
    required this.courseTitle,
    required this.progressPercent,
    required this.lecturesWatched,
    required this.totalLectures,
    required this.enrolledAt,
  });
}

class TestAttemptItem {
  final String testId;
  final String testTitle;
  final int score;
  final int totalMarks;
  final int correctAnswers;
  final int wrongAnswers;
  final int skipped;
  final DateTime attemptedAt;

  const TestAttemptItem({
    required this.testId,
    required this.testTitle,
    required this.score,
    required this.totalMarks,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.skipped,
    required this.attemptedAt,
  });

  double get percentage =>
      totalMarks == 0 ? 0 : score / totalMarks * 100;

  String get grade {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  Color get gradeColor {
    if (percentage >= 80) return const Color(0xFF10B981);
    if (percentage >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

// ═══════════════════════════════════════════════════════════
//  GLOBAL RANKING
// ═══════════════════════════════════════════════════════════

class StudentRankEntry {
  final String studentId;
  final String studentName;
  final double avgScore;
  final int totalAttempts;
  final double avgProgress;

  const StudentRankEntry({
    required this.studentId,
    required this.studentName,
    required this.avgScore,
    required this.totalAttempts,
    required this.avgProgress,
  });
}

// ═══════════════════════════════════════════════════════════
//  ENROLLMENT TREND
// ═══════════════════════════════════════════════════════════

class EnrollmentPoint {
  final DateTime month;
  final int count;

  const EnrollmentPoint({required this.month, required this.count});
}
