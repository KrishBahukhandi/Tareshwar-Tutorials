// ─────────────────────────────────────────────────────────────
//  progress_service.dart  –  Lecture / Chapter / Course progress
//
//  All data is stored in the existing `watch_progress` table:
//    student_id, lecture_id, watched_seconds, completed, updated_at
//
//  This service adds higher-level aggregation:
//    • per-lecture progress (resume position + completion)
//    • per-chapter completion percentage
//    • per-course completion percentage
//    • "continue learning" card data (last-watched lecture per course)
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'analytics_service.dart';
import 'supabase_service.dart';

final progressServiceProvider = Provider<ProgressService>((ref) {
  return ProgressService(
    ref.watch(supabaseClientProvider),
    ref.watch(analyticsServiceProvider),
  );
});

// ─────────────────────────────────────────────────────────────
//  Value objects returned by this service
// ─────────────────────────────────────────────────────────────

/// Aggregated progress for a single chapter.
class ChapterProgress {
  final String chapterId;
  final int totalLectures;
  final int completedLectures;

  const ChapterProgress({
    required this.chapterId,
    required this.totalLectures,
    required this.completedLectures,
  });

  double get percent =>
      totalLectures == 0 ? 0 : completedLectures / totalLectures;

  bool get isComplete => completedLectures >= totalLectures && totalLectures > 0;
}

/// Aggregated progress for a full course.
class CourseProgress {
  final String courseId;
  final int totalLectures;
  final int completedLectures;
  final LectureModel? lastWatchedLecture;
  final int lastWatchedSeconds;

  const CourseProgress({
    required this.courseId,
    required this.totalLectures,
    required this.completedLectures,
    this.lastWatchedLecture,
    this.lastWatchedSeconds = 0,
  });

  /// 0.0 – 1.0
  double get percent =>
      totalLectures == 0 ? 0 : completedLectures / totalLectures;

  /// 0 – 100 rounded
  int get percentInt => (percent * 100).round();

  bool get isComplete => completedLectures >= totalLectures && totalLectures > 0;
  bool get hasStarted => completedLectures > 0 || lastWatchedSeconds > 0;
}

// ─────────────────────────────────────────────────────────────
class ProgressService {
  final SupabaseClient _db;
  final AnalyticsService _analytics;

  ProgressService(this._db, this._analytics);

  // ── Write throttle ──────────────────────────────────────────
  // At 5k concurrent students calling saveProgress every 10s,
  // that is 500 writes/sec. We skip the DB write if the lecture
  // hasn't changed state significantly since the last write.
  // Completion writes are ALWAYS passed through.
  final Map<String, (int, DateTime)> _writeThrottle = {};
  static const _writeInterval = Duration(seconds: 15);
  static const _writeProgressDelta = 10; // seconds of watched time

  // ───────────────────────────────────────────────────────────
  //  1. Single lecture progress (used by player to resume)
  // ───────────────────────────────────────────────────────────
  Future<LectureProgressModel?> fetchLectureProgress({
    required String studentId,
    required String lectureId,
  }) async {
    try {
      final row = await _db
          .from('watch_progress')
          .select()
          .eq('student_id', studentId)
          .eq('lecture_id', lectureId)
          .maybeSingle();
      if (row == null) return null;
      return LectureProgressModel.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────
  //  2. Upsert progress (called from player every 10 s + on dispose)
  //     courseId / courseTitle are optional: when supplied, the service
  //     checks whether the course just reached 100% and fires the
  //     analytics course_completed event (exactly once via DB check).
  // ───────────────────────────────────────────────────────────
  Future<void> saveProgress({
    required String studentId,
    required String lectureId,
    required int watchedSeconds,
    required bool completed,
    String? courseId,
    String? courseTitle,
  }) async {
    // Throttle non-completion writes to reduce DB pressure.
    if (!completed) {
      final key = '$studentId:$lectureId';
      final now = DateTime.now();
      final last = _writeThrottle[key];
      if (last != null) {
        final elapsed = now.difference(last.$2);
        final delta = (watchedSeconds - last.$1).abs();
        if (elapsed < _writeInterval && delta < _writeProgressDelta) return;
      }
      _writeThrottle[key] = (watchedSeconds, now);
    }

    await _db.from('watch_progress').upsert({
      'student_id':      studentId,
      'lecture_id':      lectureId,
      'watched_seconds': watchedSeconds,
      'completed':       completed,
      'updated_at':      DateTime.now().toIso8601String(),
    });

    // Analytics: check if the whole course is now complete
    if (completed && courseId != null) {
      _checkAndTrackCourseCompleted(
        studentId:   studentId,
        courseId:    courseId,
        courseTitle: courseTitle ?? courseId,
      );
    }
  }

  /// Fires `course_completed` analytics event if (and only if) the
  /// course has just reached 100% for the first time.  Runs async /
  /// fire-and-forget – errors are swallowed.
  Future<void> _checkAndTrackCourseCompleted({
    required String studentId,
    required String courseId,
    required String courseTitle,
  }) async {
    try {
      final progress = await fetchCourseProgress(
        studentId: studentId,
        courseId:  courseId,
      );
      if (progress.isComplete) {
        _analytics.trackCourseCompleted(
          courseId:       courseId,
          courseTitle:    courseTitle,
          totalLectures:  progress.totalLectures,
        );
      }
    } catch (_) {
      // Never break UX
    }
  }

  // ───────────────────────────────────────────────────────────
  //  3. All progress rows for a student (bulk fetch for UI)
  // ───────────────────────────────────────────────────────────
  Future<Map<String, LectureProgressModel>> fetchAllProgress(
      String studentId) async {
    try {
      final rows = await _db
          .from('watch_progress')
          .select()
          .eq('student_id', studentId);
      return {
        for (final r in rows)
          r['lecture_id'] as String: LectureProgressModel.fromJson(
              Map<String, dynamic>.from(r))
      };
    } catch (_) {
      return {};
    }
  }

  // ───────────────────────────────────────────────────────────
  //  4. Chapter-level progress
  //  lectureIds = all lecture IDs that belong to the chapter
  // ───────────────────────────────────────────────────────────
  Future<ChapterProgress> fetchChapterProgress({
    required String studentId,
    required String chapterId,
    required List<String> lectureIds,
  }) async {
    if (lectureIds.isEmpty) {
      return ChapterProgress(
        chapterId: chapterId,
        totalLectures: 0,
        completedLectures: 0,
      );
    }
    try {
      final rows = await _db
          .from('watch_progress')
          .select('lecture_id, completed')
          .eq('student_id', studentId)
          .inFilter('lecture_id', lectureIds);

      final completedIds = {
        for (final r in rows)
          if (r['completed'] as bool? ?? false) r['lecture_id'] as String
      };

      return ChapterProgress(
        chapterId: chapterId,
        totalLectures: lectureIds.length,
        completedLectures: completedIds.length,
      );
    } catch (_) {
      return ChapterProgress(
        chapterId: chapterId,
        totalLectures: lectureIds.length,
        completedLectures: 0,
      );
    }
  }

  // ───────────────────────────────────────────────────────────
  //  5. Course-level progress + "continue learning" lecture
  // ───────────────────────────────────────────────────────────
  Future<CourseProgress> fetchCourseProgress({
    required String studentId,
    required String courseId,
  }) async {
    try {
      // Resolve all lecture IDs for this course in one query
      // Path: lectures → chapters → subjects (where course_id = courseId)
      final subjectRows = await _db
          .from('subjects')
          .select('id')
          .eq('course_id', courseId);

      if (subjectRows.isEmpty) {
        return CourseProgress(courseId: courseId, totalLectures: 0, completedLectures: 0);
      }

      final subjectIds = subjectRows.map((s) => s['id'] as String).toList();

      final chapterRows = await _db
          .from('chapters')
          .select('id')
          .inFilter('subject_id', subjectIds);

      if (chapterRows.isEmpty) {
        return CourseProgress(courseId: courseId, totalLectures: 0, completedLectures: 0);
      }

      final chapterIds = chapterRows.map((c) => c['id'] as String).toList();

      final lectureRows = await _db
          .from('lectures')
          .select('id, title, description, video_url, notes_url, duration_seconds, is_free, sort_order, chapter_id, created_at')
          .inFilter('chapter_id', chapterIds);

      if (lectureRows.isEmpty) {
        return CourseProgress(courseId: courseId, totalLectures: 0, completedLectures: 0);
      }

      final allLectureIds = lectureRows.map((l) => l['id'] as String).toList();

      // Fetch progress for all of them in one query
      final progressRows = await _db
          .from('watch_progress')
          .select()
          .eq('student_id', studentId)
          .inFilter('lecture_id', allLectureIds);

      final progressMap = <String, Map<String, dynamic>>{
        for (final r in progressRows) r['lecture_id'] as String: r
      };

      int completedCount = 0;
      String? lastLectureId;
      DateTime? lastUpdated;
      int lastWatchedSecs = 0;

      for (final r in progressRows) {
        final lid = r['lecture_id'] as String;
        if (r['completed'] as bool? ?? false) completedCount++;

        final updAt = DateTime.tryParse(r['updated_at'] as String? ?? '');
        if (updAt != null && (lastUpdated == null || updAt.isAfter(lastUpdated))) {
          lastUpdated = updAt;
          lastLectureId = lid;
          lastWatchedSecs = r['watched_seconds'] as int? ?? 0;
        }
      }

      // Build the "continue learning" LectureModel if we have a last-watched
      LectureModel? lastLecture;
      if (lastLectureId != null) {
        final lectureRow = lectureRows.firstWhere(
          (l) => l['id'] == lastLectureId,
          orElse: () => <String, dynamic>{},
        );
        if (lectureRow.isNotEmpty) {
          // Only show as "continue" if not yet completed
          final isCompleted = progressMap[lastLectureId]?['completed'] as bool? ?? false;
          if (!isCompleted) {
            lastLecture = LectureModel.fromJson({
              ...Map<String, dynamic>.from(lectureRow),
              'attachments': <dynamic>[],
            });
          } else {
            // Find first incomplete lecture ordered by sort_order
            final incomplete = lectureRows.where((l) {
              final lid = l['id'] as String;
              return !(progressMap[lid]?['completed'] as bool? ?? false);
            }).toList();
            if (incomplete.isNotEmpty) {
              lastLecture = LectureModel.fromJson({
                ...Map<String, dynamic>.from(incomplete.first),
                'attachments': <dynamic>[],
              });
              lastLectureId = lastLecture.id;
              lastWatchedSecs = progressMap[lastLectureId]?['watched_seconds'] as int? ?? 0;
            }
          }
        }
      }

      return CourseProgress(
        courseId: courseId,
        totalLectures: allLectureIds.length,
        completedLectures: completedCount,
        lastWatchedLecture: lastLecture,
        lastWatchedSeconds: lastWatchedSecs,
      );
    } catch (_) {
      return CourseProgress(courseId: courseId, totalLectures: 0, completedLectures: 0);
    }
  }

  // ───────────────────────────────────────────────────────────
  //  6. All course progresses for a student's enrolled courses
  //
  //  Uses 4 queries total regardless of how many courses are
  //  enrolled (previously fired 4×N sequential queries).
  //  At 5k students × 5 courses this reduces DB load from
  //  100k queries → 20k queries on the home-screen load.
  // ───────────────────────────────────────────────────────────
  Future<List<CourseProgress>> fetchAllCourseProgresses({
    required String studentId,
    required List<String> courseIds,
  }) async {
    if (courseIds.isEmpty) return [];
    try {
      // Query 1: all subjects for all enrolled courses
      final subjectRows = await _db
          .from('subjects')
          .select('id, course_id')
          .inFilter('course_id', courseIds);

      if (subjectRows.isEmpty) {
        return courseIds
            .map((id) => CourseProgress(courseId: id, totalLectures: 0, completedLectures: 0))
            .toList();
      }

      final subjectIds = subjectRows.map((s) => s['id'] as String).toList();

      // Query 2: all chapters for those subjects
      final chapterRows = await _db
          .from('chapters')
          .select('id, subject_id')
          .inFilter('subject_id', subjectIds);

      if (chapterRows.isEmpty) {
        return courseIds
            .map((id) => CourseProgress(courseId: id, totalLectures: 0, completedLectures: 0))
            .toList();
      }

      final chapterIds = chapterRows.map((c) => c['id'] as String).toList();

      // Query 3: all lectures for those chapters
      final lectureRows = await _db
          .from('lectures')
          .select('id, chapter_id, title, description, video_url, notes_url, duration_seconds, is_free, sort_order, created_at')
          .inFilter('chapter_id', chapterIds);

      if (lectureRows.isEmpty) {
        return courseIds
            .map((id) => CourseProgress(courseId: id, totalLectures: 0, completedLectures: 0))
            .toList();
      }

      final allLectureIds = lectureRows.map((l) => l['id'] as String).toList();

      // Query 4: all watch_progress rows for this student across all those lectures
      final progressRows = await _db
          .from('watch_progress')
          .select('lecture_id, completed, watched_seconds, updated_at')
          .eq('student_id', studentId)
          .inFilter('lecture_id', allLectureIds);

      // Build lookup maps in-memory
      final subjectToCourse = <String, String>{
        for (final s in subjectRows) s['id'] as String: s['course_id'] as String,
      };
      final chapterToSubject = <String, String>{
        for (final c in chapterRows) c['id'] as String: c['subject_id'] as String,
      };
      final lecturesByCourse = <String, List<Map<String, dynamic>>>{};

      for (final l in lectureRows) {
        final chapterId = l['chapter_id'] as String;
        final subjectId = chapterToSubject[chapterId];
        if (subjectId == null) continue;
        final courseId = subjectToCourse[subjectId];
        if (courseId == null) continue;
        lecturesByCourse
            .putIfAbsent(courseId, () => [])
            .add(Map<String, dynamic>.from(l as Map));
      }

      final progressMap = <String, Map<String, dynamic>>{
        for (final r in progressRows)
          r['lecture_id'] as String: Map<String, dynamic>.from(r as Map),
      };

      // Compute CourseProgress for each course from in-memory maps
      return courseIds.map((courseId) {
        final lectures = lecturesByCourse[courseId] ?? [];
        if (lectures.isEmpty) {
          return CourseProgress(courseId: courseId, totalLectures: 0, completedLectures: 0);
        }

        int completedCount = 0;
        String? lastLectureId;
        DateTime? lastUpdated;
        int lastWatchedSecs = 0;

        for (final l in lectures) {
          final lid = l['id'] as String;
          final prog = progressMap[lid];
          if (prog != null) {
            if (prog['completed'] as bool? ?? false) completedCount++;
            final updAt = DateTime.tryParse(prog['updated_at'] as String? ?? '');
            if (updAt != null &&
                (lastUpdated == null || updAt.isAfter(lastUpdated))) {
              lastUpdated = updAt;
              lastLectureId = lid;
              lastWatchedSecs = prog['watched_seconds'] as int? ?? 0;
            }
          }
        }

        LectureModel? lastLecture;
        if (lastLectureId != null) {
          final isCompleted =
              progressMap[lastLectureId]?['completed'] as bool? ?? false;
          final lectureRow = lectures.firstWhere(
            (l) => l['id'] == lastLectureId,
            orElse: () => <String, dynamic>{},
          );
          if (!isCompleted && lectureRow.isNotEmpty) {
            lastLecture = LectureModel.fromJson({
              ...lectureRow,
              'attachments': <dynamic>[],
            });
          } else {
            final incomplete = lectures.where((l) {
              final lid = l['id'] as String;
              return !(progressMap[lid]?['completed'] as bool? ?? false);
            }).toList();
            if (incomplete.isNotEmpty) {
              final next = Map<String, dynamic>.from(incomplete.first as Map);
              lastLecture = LectureModel.fromJson({
                ...next,
                'attachments': <dynamic>[],
              });
              lastWatchedSecs =
                  progressMap[lastLecture.id]?['watched_seconds'] as int? ?? 0;
            }
          }
        }

        return CourseProgress(
          courseId: courseId,
          totalLectures: lectures.length,
          completedLectures: completedCount,
          lastWatchedLecture: lastLecture,
          lastWatchedSeconds: lastWatchedSecs,
        );
      }).toList();
    } catch (_) {
      return courseIds
          .map((id) => CourseProgress(courseId: id, totalLectures: 0, completedLectures: 0))
          .toList();
    }
  }

  // ───────────────────────────────────────────────────────────
  //  7. Completed courses count
  // ───────────────────────────────────────────────────────────
  Future<int> countCompletedCourses({
    required String studentId,
    required List<String> courseIds,
  }) async {
    final progresses = await fetchAllCourseProgresses(
      studentId: studentId,
      courseIds: courseIds,
    );
    return progresses.where((p) => p.isComplete).length;
  }
}
