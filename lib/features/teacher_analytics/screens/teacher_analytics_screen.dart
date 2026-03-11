// ─────────────────────────────────────────────────────────────
//  teacher_analytics_screen.dart
//  Main analytics hub: summary tiles, enrollment trend chart,
//  score distribution, doubt resolution ring, leaderboard,
//  and per-course drill-down cards.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/services/course_service.dart';
import '../../../shared/services/auth_service.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_widgets.dart';

class TeacherAnalyticsScreen extends ConsumerWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final trendAsync = ref.watch(enrollmentTrendProvider);
    final leaderAsync = ref.watch(studentLeaderboardProvider);
    final courseIdsAsync = ref.watch(teacherCourseIdsProvider);
    final uid = ref.read(authServiceProvider).currentAuthUser?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, ref),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsSummaryProvider);
          ref.invalidate(enrollmentTrendProvider);
          ref.invalidate(studentLeaderboardProvider);
          ref.invalidate(teacherCourseIdsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ─────────────────────────────
              Text('Analytics', style: AppTextStyles.displaySmall),
              const SizedBox(height: 4),
              Text(
                'Insights across all your courses and students.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // ── Summary tiles ────────────────────────────
              summaryAsync.when(
                loading: () => const AnalyticsLoading(),
                error: (e, _) => AnalyticsError(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(analyticsSummaryProvider),
                ),
                data: (s) => _SummaryGrid(summary: s),
              ),
              const SizedBox(height: 24),

              // ── Enrollment trend ─────────────────────────
              AnalyticsCard(
                title: 'Enrollment Trend',
                subtitle: 'New students over the last 6 months',
                child: trendAsync.when(
                  loading: () => const AnalyticsLoading(),
                  error: (e, _) => AnalyticsError(message: e.toString()),
                  data: (pts) => EnrollmentTrendChart(points: pts),
                ),
              ),
              const SizedBox(height: 20),

              // ── Doubt resolution ring + score dist ──────
              summaryAsync.maybeWhen(
                data: (s) => _DoubtAndScoreRow(summary: s),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // ── Per-course cards ─────────────────────────
              AnalyticsCard(
                title: 'Course Analytics',
                subtitle: 'Tap a course for a detailed breakdown',
                child: courseIdsAsync.when(
                  loading: () => const AnalyticsLoading(),
                  error: (e, _) =>
                      AnalyticsError(message: e.toString()),
                  data: (ids) => uid == null
                      ? const SizedBox.shrink()
                      : _CourseCardList(
                          courseIds: ids, teacherId: uid),
                ),
              ),
              const SizedBox(height: 20),

              // ── Student leaderboard ───────────────────────
              AnalyticsCard(
                title: 'Top Students',
                subtitle: 'Ranked by average test score',
                child: leaderAsync.when(
                  loading: () => const AnalyticsLoading(),
                  error: (e, _) => AnalyticsError(message: e.toString()),
                  data: (entries) => entries.isEmpty
                      ? const _EmptyNote(
                          text: 'No test attempts yet.')
                      : _LeaderboardList(entries: entries),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: const Color(0xFF1C1B2E),
      foregroundColor: Colors.white,
      title: const Text(
        'Analytics',
        style: TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Summary grid (2×2 tiles)
// ─────────────────────────────────────────────────────────────
class _SummaryGrid extends StatelessWidget {
  final TeacherAnalyticsSummary summary;
  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        'Total Students',
        '${summary.totalStudents}',
        Icons.people_alt_rounded,
        AppColors.primary,
      ),
      (
        'Total Tests',
        '${summary.totalTests}',
        Icons.quiz_rounded,
        AppColors.info,
      ),
      (
        'Avg Score',
        '${summary.averageScore.toStringAsFixed(0)}%',
        Icons.star_rounded,
        AppColors.warning,
      ),
      (
        'Avg Completion',
        '${summary.averageCompletion.toStringAsFixed(0)}%',
        Icons.trending_up_rounded,
        AppColors.success,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: tiles
          .map((t) => SummaryTile(
                label: t.$1,
                value: t.$2,
                icon: t.$3,
                color: t.$4,
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Doubt resolution donut + score stats row
// ─────────────────────────────────────────────────────────────
class _DoubtAndScoreRow extends StatelessWidget {
  final TeacherAnalyticsSummary summary;
  const _DoubtAndScoreRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 600;
      final doubtCard = AnalyticsCard(
        title: 'Doubt Resolution',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              DonutStatChart(
                percent: summary.doubtResolutionRate,
                centerLabel:
                    '${summary.doubtResolutionRate.toStringAsFixed(0)}%',
                activeColor: AppColors.success,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LegendDot(
                        color: AppColors.success,
                        label:
                            'Resolved: ${summary.resolvedDoubts}'),
                    const SizedBox(height: 10),
                    LegendDot(
                        color: AppColors.warning,
                        label: 'Pending: ${summary.pendingDoubts}'),
                    const SizedBox(height: 10),
                    LegendDot(
                        color: AppColors.textHint,
                        label:
                            'Total: ${summary.resolvedDoubts + summary.pendingDoubts}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      final scoreCard = AnalyticsCard(
        title: 'Test Performance',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              ProgressBarRow(
                label: 'Average Score',
                value: summary.averageScore,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              ProgressBarRow(
                label: 'Avg Completion',
                value: summary.averageCompletion,
                color: AppColors.success,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Attempts',
                      style: AppTextStyles.bodySmall),
                  Text('${summary.totalAttempts}',
                      style: AppTextStyles.labelLarge),
                ],
              ),
            ],
          ),
        ),
      );

      return wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: doubtCard),
                const SizedBox(width: 16),
                Expanded(child: scoreCard),
              ],
            )
          : Column(children: [
              doubtCard,
              const SizedBox(height: 16),
              scoreCard,
            ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────
//  Per-course cards list
// ─────────────────────────────────────────────────────────────
class _CourseCardList extends ConsumerWidget {
  final List<String> courseIds;
  final String teacherId;

  const _CourseCardList({
    required this.courseIds,
    required this.teacherId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (courseIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: _EmptyNote(text: 'No courses yet.'),
      );
    }

    // Use a simple FutureBuilder to get course titles
    return FutureBuilder(
      future: ref
          .read(courseServiceProvider)
          .fetchTeacherCourses(teacherId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AnalyticsLoading();
        }
        final courses = snap.data ?? [];
        if (courses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: _EmptyNote(text: 'No courses yet.'),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: courses.length,
          separatorBuilder: (_, idx) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final c = courses[i] as dynamic;
            return _CourseAnalyticsTile(
              courseId: c.id as String,
              courseTitle: c.title as String,
              totalStudents: (c.totalStudents as int?) ?? 0,
              totalLectures: (c.totalLectures as int?) ?? 0,
              isPublished: c.isPublished as bool,
            );
          },
        );
      },
    );
  }
}

class _CourseAnalyticsTile extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  final int totalStudents;
  final int totalLectures;
  final bool isPublished;

  const _CourseAnalyticsTile({
    required this.courseId,
    required this.courseTitle,
    required this.totalStudents,
    required this.totalLectures,
    required this.isPublished,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        AppRoutes.courseAnalyticsPath(courseId),
        extra: courseTitle,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseTitle,
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniStat(
                          icon: Icons.people_rounded,
                          label: '$totalStudents students'),
                      const SizedBox(width: 12),
                      _MiniStat(
                          icon: Icons.play_circle_outline_rounded,
                          label: '$totalLectures lectures'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isPublished
                            ? AppColors.success
                            : AppColors.warning)
                        .withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPublished ? 'Published' : 'Draft',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isPublished
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
//  Student leaderboard list
// ─────────────────────────────────────────────────────────────
class _LeaderboardList extends ConsumerWidget {
  final List<StudentRankEntry> entries;
  const _LeaderboardList({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = entries.take(10).toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: top.length,
      separatorBuilder: (_, idx) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LeaderRow(
        rank: i + 1,
        entry: top[i],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank;
  final StudentRankEntry entry;
  const _LeaderRow({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : AppColors.textSecondary;

    return InkWell(
      onTap: () => context.push(
        AppRoutes.studentPerformancePath(entry.studentId),
        extra: entry.studentName,
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isTop3
              ? rankColor.withAlpha(15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isTop3
                  ? rankColor.withAlpha(60)
                  : AppColors.border),
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: rankColor.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: rankColor, fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withAlpha(25),
              child: Text(
                entry.studentName.isNotEmpty
                    ? entry.studentName[0].toUpperCase()
                    : 'S',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.studentName,
                      style: AppTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${entry.totalAttempts} tests · ${entry.avgProgress.toStringAsFixed(0)}% progress',
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
            ),
            // Score chip
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${entry.avgScore.toStringAsFixed(0)}%',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Center(
          child: Text(text,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ),
      );
}
