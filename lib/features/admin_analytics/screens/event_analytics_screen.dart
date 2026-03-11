// ─────────────────────────────────────────────────────────────
//  event_analytics_screen.dart
//
//  Full-page Event Analytics screen for admins.
//  Shows:
//    • 5 KPI cards from analytics_events (lecture starts,
//      completions, tests attempted, courses completed,
//      live classes joined)
//    • Active-user counts (7 d / 30 d)
//    • Daily activity line-chart (last 30 days, per event type)
//    • Top lectures table
//    • Top tests table
//    • Recent events feed
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/services/analytics_service.dart'
    show AnalyticsEvent;
import '../providers/analytics_providers.dart';
import '../widgets/admin_analytics_widgets.dart';

// ─────────────────────────────────────────────────────────────
class EventAnalyticsScreen extends ConsumerWidget {
  const EventAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync  = ref.watch(platformAnalyticsStatsProvider);
    final dailyAsync  = ref.watch(dailyActivityProvider);
    final lectAsync   = ref.watch(topLecturesProvider);
    final testsAsync  = ref.watch(topTestsProvider);
    final recentAsync = ref.watch(recentAnalyticsEventsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformAnalyticsStatsProvider);
          ref.invalidate(dailyActivityProvider);
          ref.invalidate(topLecturesProvider);
          ref.invalidate(topTestsProvider);
          ref.invalidate(recentAnalyticsEventsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Event Analytics',
                            style: AppTextStyles.displaySmall),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time engagement metrics from platform activity.',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {
                      ref.invalidate(platformAnalyticsStatsProvider);
                      ref.invalidate(dailyActivityProvider);
                      ref.invalidate(topLecturesProvider);
                      ref.invalidate(topTestsProvider);
                      ref.invalidate(recentAnalyticsEventsProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Event KPI stat cards ────────────────────────
              statsAsync.when(
                loading: () => const AnalyticsSkeletonLoader(),
                error: (e, _) => _ErrorBanner(e.toString()),
                data: (s) => Column(
                  children: [
                    // Row 1 – 3 cards
                    LayoutBuilder(builder: (ctx, c) {
                      final cols = c.maxWidth > 700 ? 3 : 2;
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: c.maxWidth > 700 ? 2.0 : 1.55,
                        children: [
                          AnalyticsStatCard(
                            label: 'Lectures Started',
                            value: '${s.lecturesStarted}',
                            icon: Icons.play_circle_outline_rounded,
                            color: AppColors.primary,
                            subtitle: 'All-time',
                          ),
                          AnalyticsStatCard(
                            label: 'Lectures Completed',
                            value: '${s.lecturesCompleted}',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.success,
                            subtitle: '${s.lectureCompletionRate.toStringAsFixed(1)}% completion rate',
                          ),
                          AnalyticsStatCard(
                            label: 'Tests Attempted',
                            value: '${s.testsAttempted}',
                            icon: Icons.quiz_outlined,
                            color: AppColors.warning,
                            subtitle: 'All-time',
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 14),
                    // Row 2 – 2 wide cards + 2 active-user cards
                    LayoutBuilder(builder: (ctx, c) {
                      final cols = c.maxWidth > 700 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: c.maxWidth > 700 ? 2.2 : 1.55,
                        children: [
                          AnalyticsStatCard(
                            label: 'Courses Completed',
                            value: '${s.coursesCompleted}',
                            icon: Icons.school_rounded,
                            color: AppColors.accent,
                            subtitle: 'All-time',
                          ),
                          AnalyticsStatCard(
                            label: 'Live Classes Joined',
                            value: '${s.liveClassesJoined}',
                            icon: Icons.live_tv_rounded,
                            color: AppColors.error,
                            subtitle: 'All-time',
                          ),
                          AnalyticsStatCard(
                            label: 'Active Users (7d)',
                            value: '${s.last7dActive}',
                            icon: Icons.people_outline_rounded,
                            color: AppColors.info,
                            subtitle: 'Distinct users',
                          ),
                          AnalyticsStatCard(
                            label: 'Active Users (30d)',
                            value: '${s.last30dActive}',
                            icon: Icons.people_rounded,
                            color: AppColors.info,
                            subtitle: 'Distinct users',
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Daily Activity Line Chart ───────────────────
              AnalyticsChartCard(
                title: 'Daily Activity',
                subtitle: 'Event counts over the last 30 days',
                child: dailyAsync.when(
                  loading: () => const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => _ErrorBanner(e.toString()),
                  data: (data) => _DailyActivityChart(data: data),
                ),
              ),
              const SizedBox(height: 20),

              // ── Top Lectures + Top Tests (side-by-side on wide) ──
              LayoutBuilder(builder: (ctx, c) {
                final isWide = c.maxWidth > 750;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnalyticsChartCard(
                          title: 'Top Lectures',
                          subtitle: 'By start count (all-time)',
                          child: lectAsync.when(
                            loading: () => const _LoadingBox(),
                            error: (e, _) => _ErrorBanner(e.toString()),
                            data: (list) => _TopLecturesTable(list),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AnalyticsChartCard(
                          title: 'Top Tests',
                          subtitle: 'By attempt count (all-time)',
                          child: testsAsync.when(
                            loading: () => const _LoadingBox(),
                            error: (e, _) => _ErrorBanner(e.toString()),
                            data: (list) => _TopTestsTable(list),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Column(children: [
                  AnalyticsChartCard(
                    title: 'Top Lectures',
                    subtitle: 'By start count (all-time)',
                    child: lectAsync.when(
                      loading: () => const _LoadingBox(),
                      error: (e, _) => _ErrorBanner(e.toString()),
                      data: (list) => _TopLecturesTable(list),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnalyticsChartCard(
                    title: 'Top Tests',
                    subtitle: 'By attempt count (all-time)',
                    child: testsAsync.when(
                      loading: () => const _LoadingBox(),
                      error: (e, _) => _ErrorBanner(e.toString()),
                      data: (list) => _TopTestsTable(list),
                    ),
                  ),
                ]);
              }),
              const SizedBox(height: 20),

              // ── Recent Events Feed ─────────────────────────
              AnalyticsChartCard(
                title: 'Recent Events',
                subtitle: 'Latest 50 platform events',
                child: recentAsync.when(
                  loading: () => const _LoadingBox(),
                  error: (e, _) => _ErrorBanner(e.toString()),
                  data: (list) => _RecentEventsFeed(list),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Daily Activity Line Chart
// ─────────────────────────────────────────────────────────────
class _DailyActivityChart extends StatelessWidget {
  const _DailyActivityChart({required this.data});
  final List<DailyEventPoint> data;

  static final _eventColors = {
    AnalyticsEvent.lectureStarted:   AppColors.primary,
    AnalyticsEvent.lectureCompleted: AppColors.success,
    AnalyticsEvent.testAttempted:    AppColors.warning,
    AnalyticsEvent.courseCompleted:  AppColors.accent,
    AnalyticsEvent.liveClassJoined:  AppColors.error,
  };

  static final _eventLabels = {
    AnalyticsEvent.lectureStarted:   'Lecture Started',
    AnalyticsEvent.lectureCompleted: 'Lecture Completed',
    AnalyticsEvent.testAttempted:    'Test Attempted',
    AnalyticsEvent.courseCompleted:  'Course Completed',
    AnalyticsEvent.liveClassJoined:  'Live Joined',
  };

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded, size: 48, color: AppColors.textHint),
              SizedBox(height: 8),
              Text('No event data in the last 30 days',
                  style: TextStyle(color: AppColors.textHint)),
            ],
          ),
        ),
      );
    }

    // Build a map of eventType → list of (day, count) sorted
    final Map<String, Map<DateTime, int>> byType = {};
    for (final pt in data) {
      byType.putIfAbsent(pt.eventType, () => {})[pt.day] =
          (byType[pt.eventType]?[pt.day] ?? 0) + pt.count;
    }

    // Collect all unique days, sorted
    final allDays = data.map((p) => p.day).toSet().toList()
      ..sort();

    final dayFmt = DateFormat('MMM d');

    // Build legend
    final legendItems = byType.keys
        .where((t) => _eventColors.containsKey(t))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: legendItems.map((type) {
              final color = _eventColors[type] ?? AppColors.textHint;
              final label = _eventLabels[type] ?? type;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(label,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Chart table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rows per event type
                  ...legendItems.map((type) {
                    final color = _eventColors[type] ?? AppColors.textHint;
                    final label = _eventLabels[type] ?? type;
                    final typeData = byType[type] ?? {};
                    final maxCount = typeData.values.fold(
                        0, (a, b) => a > b ? a : b);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(label,
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: color,
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          ...allDays.map((day) {
                            final count = typeData[day] ?? 0;
                            final ratio = maxCount == 0
                                ? 0.0
                                : count / maxCount;
                            return Tooltip(
                              message:
                                  '${dayFmt.format(day)}: $count',
                              child: Container(
                                width: 20,
                                height: 28,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 1),
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  width: 16,
                                  height: ratio == 0
                                      ? 2
                                      : (ratio * 24).clamp(2, 24),
                                  decoration: BoxDecoration(
                                    color: count == 0
                                        ? AppColors.border
                                        : color
                                            .withValues(alpha: 0.3 + ratio * 0.7),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3)),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                  // X-axis day labels (show every 5th)
                  Row(
                    children: [
                      const SizedBox(width: 128),
                      ...allDays.asMap().entries.map((e) {
                        final i = e.key;
                        final day = e.value;
                        return SizedBox(
                          width: 22,
                          child: i % 5 == 0
                              ? RotatedBox(
                                  quarterTurns: 1,
                                  child: Text(
                                    dayFmt.format(day),
                                    style: AppTextStyles.labelSmall
                                        .copyWith(fontSize: 9),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Top Lectures Table
// ─────────────────────────────────────────────────────────────
class _TopLecturesTable extends StatelessWidget {
  const _TopLecturesTable(this.items);
  final List<TopLecture> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('No lecture data yet.',
              style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: items.map((lec) {
          final pct = lec.completionRate;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lec.lectureTitle,
                        style: AppTextStyles.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${lec.startCount} starts',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${lec.completedCount} completed',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint, fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Top Tests Table
// ─────────────────────────────────────────────────────────────
class _TopTestsTable extends StatelessWidget {
  const _TopTestsTable(this.items);
  final List<TopTest> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('No test data yet.',
              style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: items.map((t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.testTitle,
                        style: AppTextStyles.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${t.attemptCount} attempts',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: t.avgScore / 100,
                          minHeight: 6,
                          backgroundColor:
                              AppColors.warning.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.warning),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Avg ${t.avgScore.toStringAsFixed(1)}%',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Recent Events Feed
// ─────────────────────────────────────────────────────────────
class _RecentEventsFeed extends StatelessWidget {
  const _RecentEventsFeed(this.events);
  final List<AnalyticsEventModel> events;

  static final _icons = {
    AnalyticsEvent.lectureStarted:   (Icons.play_circle_outline_rounded, AppColors.primary),
    AnalyticsEvent.lectureCompleted: (Icons.check_circle_outline_rounded, AppColors.success),
    AnalyticsEvent.testAttempted:    (Icons.quiz_outlined, AppColors.warning),
    AnalyticsEvent.courseCompleted:  (Icons.school_rounded, AppColors.accent),
    AnalyticsEvent.liveClassJoined:  (Icons.live_tv_rounded, AppColors.error),
  };

  static final _labels = {
    AnalyticsEvent.lectureStarted:   'Lecture Started',
    AnalyticsEvent.lectureCompleted: 'Lecture Completed',
    AnalyticsEvent.testAttempted:    'Test Attempted',
    AnalyticsEvent.courseCompleted:  'Course Completed',
    AnalyticsEvent.liveClassJoined:  'Live Class Joined',
  };

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('No recent events.',
              style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }

    final timeFmt = DateFormat('MMM d, HH:mm');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final e = events[i];
        final iconInfo = _icons[e.eventType];
        final iconData  = iconInfo?.$1 ?? Icons.bolt_rounded;
        final iconColor = iconInfo?.$2 ?? AppColors.textHint;
        final label  = _labels[e.eventType] ?? e.eventType;
        final data   = e.eventData;
        final title  = data['lecture_title'] as String? ??
            data['test_title'] as String? ??
            data['course_title'] as String? ??
            data['live_class_title'] as String? ??
            '—';

        return ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          title: Text(label, style: AppTextStyles.labelMedium),
          subtitle: Text(
            title,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            timeFmt.format(e.createdAt.toLocal()),
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textHint, fontSize: 10),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────
class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
