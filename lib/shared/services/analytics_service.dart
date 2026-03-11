// ─────────────────────────────────────────────────────────────
//  analytics_service.dart  –  Platform-wide event tracking
//
//  Fires "fire-and-forget" events to the analytics_events table.
//  Never throws – all errors are silently swallowed so that a
//  tracking failure never breaks user-facing flows.
//
//  Supported events:
//    • lecture_started
//    • lecture_completed
//    • test_attempted
//    • course_completed
//    • live_class_joined
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

// ─────────────────────────────────────────────────────────────
//  Event-type constants
// ─────────────────────────────────────────────────────────────
abstract final class AnalyticsEvent {
  static const lectureStarted   = 'lecture_started';
  static const lectureCompleted = 'lecture_completed';
  static const testAttempted    = 'test_attempted';
  static const courseCompleted  = 'course_completed';
  static const liveClassJoined  = 'live_class_joined';
}

// ─────────────────────────────────────────────────────────────
//  Model for a single analytics event row
// ─────────────────────────────────────────────────────────────
class AnalyticsEventModel {
  final String id;
  final String? userId;
  final String eventType;
  final Map<String, dynamic> eventData;
  final DateTime createdAt;

  const AnalyticsEventModel({
    required this.id,
    this.userId,
    required this.eventType,
    required this.eventData,
    required this.createdAt,
  });

  factory AnalyticsEventModel.fromJson(Map<String, dynamic> json) =>
      AnalyticsEventModel(
        id:        json['id'] as String,
        userId:    json['user_id'] as String?,
        eventType: json['event_type'] as String,
        eventData: Map<String, dynamic>.from(
            (json['event_data'] as Map?) ?? {}),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ─────────────────────────────────────────────────────────────
//  Daily activity data point (for charts)
// ─────────────────────────────────────────────────────────────
class DailyEventPoint {
  final DateTime day;
  final String eventType;
  final int count;

  const DailyEventPoint({
    required this.day,
    required this.eventType,
    required this.count,
  });
}

// ─────────────────────────────────────────────────────────────
//  Per-event totals
// ─────────────────────────────────────────────────────────────
class EventTotals {
  final String eventType;
  final int total;
  final int last7d;
  final int last30d;

  const EventTotals({
    required this.eventType,
    required this.total,
    required this.last7d,
    required this.last30d,
  });

  factory EventTotals.fromJson(Map<String, dynamic> json) => EventTotals(
        eventType: json['event_type'] as String,
        total:     (json['total'] as num).toInt(),
        last7d:    (json['last_7d'] as num).toInt(),
        last30d:   (json['last_30d'] as num).toInt(),
      );
}

// ─────────────────────────────────────────────────────────────
//  Aggregate analytics stats (for admin dashboard)
// ─────────────────────────────────────────────────────────────
class PlatformAnalyticsStats {
  final int lecturesStarted;
  final int lecturesCompleted;
  final int testsAttempted;
  final int coursesCompleted;
  final int liveClassesJoined;
  final int last7dActive;   // distinct users with any event in 7d
  final int last30dActive;  // distinct users with any event in 30d

  const PlatformAnalyticsStats({
    required this.lecturesStarted,
    required this.lecturesCompleted,
    required this.testsAttempted,
    required this.coursesCompleted,
    required this.liveClassesJoined,
    required this.last7dActive,
    required this.last30dActive,
  });

  /// Lecture completion rate as a percentage (0–100)
  double get lectureCompletionRate => lecturesStarted == 0
      ? 0
      : (lecturesCompleted / lecturesStarted) * 100;
}

// ─────────────────────────────────────────────────────────────
//  Top content items
// ─────────────────────────────────────────────────────────────
class TopLecture {
  final String lectureId;
  final String lectureTitle;
  final int startCount;
  final int completedCount;

  const TopLecture({
    required this.lectureId,
    required this.lectureTitle,
    required this.startCount,
    required this.completedCount,
  });

  double get completionRate =>
      startCount == 0 ? 0 : (completedCount / startCount) * 100;
}

class TopTest {
  final String testId;
  final String testTitle;
  final int attemptCount;
  final double avgScore;

  const TopTest({
    required this.testId,
    required this.testTitle,
    required this.attemptCount,
    required this.avgScore,
  });
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.watch(supabaseClientProvider));
});

// ─────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────
class AnalyticsService {
  AnalyticsService(this._db);
  final SupabaseClient _db;

  static const _table = 'analytics_events';

  // ── Current user helper ───────────────────────────────────
  String? get _uid => _db.auth.currentUser?.id;

  // ══════════════════════════════════════════════════════════
  //  TRACK EVENTS  (fire-and-forget, never throws)
  // ══════════════════════════════════════════════════════════

  /// Track lecture_started
  Future<void> trackLectureStarted({
    required String lectureId,
    required String lectureTitle,
    String? courseId,
    String? courseTitle,
  }) =>
      _track(AnalyticsEvent.lectureStarted, {
        'lecture_id':    lectureId,
        'lecture_title': lectureTitle,
        if (courseId != null) 'course_id': courseId,
        if (courseTitle != null) 'course_title': courseTitle,
      });

  /// Track lecture_completed
  Future<void> trackLectureCompleted({
    required String lectureId,
    required String lectureTitle,
    int? watchedSeconds,
    int? durationSeconds,
    String? courseId,
  }) =>
      _track(AnalyticsEvent.lectureCompleted, {
        'lecture_id':       lectureId,
        'lecture_title':    lectureTitle,
        if (watchedSeconds != null) 'watched_seconds': watchedSeconds,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        if (courseId != null) 'course_id': courseId,
      });

  /// Track test_attempted (call after submission with result)
  Future<void> trackTestAttempted({
    required String testId,
    required String testTitle,
    required double score,
    required double totalMarks,
    required int timeTakenSeconds,
  }) =>
      _track(AnalyticsEvent.testAttempted, {
        'test_id':           testId,
        'test_title':        testTitle,
        'score':             score,
        'total_marks':       totalMarks,
        'percentage':        totalMarks > 0 ? (score / totalMarks) * 100 : 0,
        'time_taken_seconds': timeTakenSeconds,
      });

  /// Track course_completed
  Future<void> trackCourseCompleted({
    required String courseId,
    required String courseTitle,
    int? totalLectures,
  }) =>
      _track(AnalyticsEvent.courseCompleted, {
        'course_id':      courseId,
        'course_title':   courseTitle,
        if (totalLectures != null) 'total_lectures': totalLectures,
      });

  /// Track live_class_joined
  Future<void> trackLiveClassJoined({
    required String liveClassId,
    required String liveClassTitle,
    String? courseId,
    String? batchId,
  }) =>
      _track(AnalyticsEvent.liveClassJoined, {
        'live_class_id':    liveClassId,
        'live_class_title': liveClassTitle,
        if (courseId != null) 'course_id': courseId,
        if (batchId != null) 'batch_id': batchId,
      });

  // ══════════════════════════════════════════════════════════
  //  READ: ADMIN ANALYTICS
  // ══════════════════════════════════════════════════════════

  /// Aggregate platform-wide event stats
  Future<PlatformAnalyticsStats> fetchPlatformStats() async {
    final rows = await _db.from(_table).select('event_type, user_id, created_at');
    final list = List<Map<String, dynamic>>.from(rows as List);

    final now = DateTime.now();
    final ago7  = now.subtract(const Duration(days: 7));
    final ago30 = now.subtract(const Duration(days: 30));

    int lecturesStarted   = 0;
    int lecturesCompleted = 0;
    int testsAttempted    = 0;
    int coursesCompleted  = 0;
    int liveClassesJoined = 0;

    final active7d  = <String>{};
    final active30d = <String>{};

    for (final r in list) {
      final type = r['event_type'] as String;
      final uid  = r['user_id'] as String?;
      final ts   = DateTime.parse(r['created_at'] as String);

      switch (type) {
        case AnalyticsEvent.lectureStarted:   lecturesStarted++;   break;
        case AnalyticsEvent.lectureCompleted: lecturesCompleted++; break;
        case AnalyticsEvent.testAttempted:    testsAttempted++;    break;
        case AnalyticsEvent.courseCompleted:  coursesCompleted++;  break;
        case AnalyticsEvent.liveClassJoined:  liveClassesJoined++; break;
      }

      if (uid != null) {
        if (ts.isAfter(ago7))  active7d.add(uid);
        if (ts.isAfter(ago30)) active30d.add(uid);
      }
    }

    return PlatformAnalyticsStats(
      lecturesStarted:   lecturesStarted,
      lecturesCompleted: lecturesCompleted,
      testsAttempted:    testsAttempted,
      coursesCompleted:  coursesCompleted,
      liveClassesJoined: liveClassesJoined,
      last7dActive:      active7d.length,
      last30dActive:     active30d.length,
    );
  }

  /// Daily event counts for the last [days] days, one entry per day per type.
  Future<List<DailyEventPoint>> fetchDailyActivity({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await _db
        .from(_table)
        .select('event_type, created_at')
        .gte('created_at', cutoff.toIso8601String())
        .order('created_at');

    final Map<String, Map<String, int>> agg = {};
    // key: 'YYYY-MM-DD|event_type' → count

    for (final r in rows as List) {
      final type = r['event_type'] as String;
      final ts   = DateTime.parse(r['created_at'] as String).toLocal();
      final day  = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-'
          '${ts.day.toString().padLeft(2, '0')}';
      final k = '$day|$type';
      agg[k] = (agg[k] ?? {})..update(type, (v) => v + 1, ifAbsent: () => 1);
    }

    final result = <DailyEventPoint>[];
    agg.forEach((k, _) {
      final parts = k.split('|');
      final day   = DateTime.parse(parts[0]);
      final type  = parts[1];
      final count = agg[k]![type] ?? 0;
      result.add(DailyEventPoint(day: day, eventType: type, count: count));
    });

    result.sort((a, b) => a.day.compareTo(b.day));
    return result;
  }

  /// Top N most-started lectures
  Future<List<TopLecture>> fetchTopLectures({int limit = 10}) async {
    final rows = await _db
        .from(_table)
        .select('event_type, event_data')
        .inFilter('event_type', [
          AnalyticsEvent.lectureStarted,
          AnalyticsEvent.lectureCompleted,
        ]);

    final Map<String, Map<String, dynamic>> map = {};

    for (final r in rows as List) {
      final type = r['event_type'] as String;
      final data = Map<String, dynamic>.from(r['event_data'] as Map? ?? {});
      final id   = data['lecture_id'] as String?;
      if (id == null) continue;

      map[id] ??= {
        'title': data['lecture_title'] ?? id,
        'starts': 0,
        'completes': 0,
      };
      if (type == AnalyticsEvent.lectureStarted) {
        map[id]!['starts'] = (map[id]!['starts'] as int) + 1;
      } else {
        map[id]!['completes'] = (map[id]!['completes'] as int) + 1;
      }
    }

    final list = map.entries
        .map((e) => TopLecture(
              lectureId:      e.key,
              lectureTitle:   e.value['title'] as String,
              startCount:     e.value['starts'] as int,
              completedCount: e.value['completes'] as int,
            ))
        .toList()
      ..sort((a, b) => b.startCount.compareTo(a.startCount));

    return list.take(limit).toList();
  }

  /// Top N most-attempted tests with avg score
  Future<List<TopTest>> fetchTopTests({int limit = 10}) async {
    final rows = await _db
        .from(_table)
        .select('event_data')
        .eq('event_type', AnalyticsEvent.testAttempted);

    final Map<String, Map<String, dynamic>> map = {};

    for (final r in rows as List) {
      final data = Map<String, dynamic>.from(r['event_data'] as Map? ?? {});
      final id   = data['test_id'] as String?;
      if (id == null) continue;

      map[id] ??= {
        'title':      data['test_title'] ?? id,
        'count':      0,
        'scoreSum':   0.0,
      };
      map[id]!['count']    = (map[id]!['count'] as int) + 1;
      map[id]!['scoreSum'] = (map[id]!['scoreSum'] as double) +
          ((data['percentage'] as num?)?.toDouble() ?? 0);
    }

    final list = map.entries
        .map((e) {
          final count = e.value['count'] as int;
          return TopTest(
            testId:       e.key,
            testTitle:    e.value['title'] as String,
            attemptCount: count,
            avgScore:     count == 0
                ? 0
                : (e.value['scoreSum'] as double) / count,
          );
        })
        .toList()
      ..sort((a, b) => b.attemptCount.compareTo(a.attemptCount));

    return list.take(limit).toList();
  }

  /// Recent events (for admin activity feed)
  Future<List<AnalyticsEventModel>> fetchRecentEvents({int limit = 50}) async {
    final rows = await _db
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((r) => AnalyticsEventModel.fromJson(
            Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ══════════════════════════════════════════════════════════
  //  PRIVATE HELPER
  // ══════════════════════════════════════════════════════════
  Future<void> _track(
      String eventType, Map<String, dynamic> data) async {
    try {
      await _db.from(_table).insert({
        'user_id':    _uid,
        'event_type': eventType,
        'event_data': data,
      });
    } catch (_) {
      // Intentionally silent – analytics must never break UX
    }
  }
}
