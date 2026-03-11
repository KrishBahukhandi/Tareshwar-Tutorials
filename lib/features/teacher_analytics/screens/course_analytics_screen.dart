// ─────────────────────────────────────────────────────────────
//  course_analytics_screen.dart
//  Drill-down analytics for a single course.
//  Shows: completion ring, progress list, test summaries,
//  score distribution chart, difficult questions, doubts.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_widgets.dart';

class CourseAnalyticsScreen extends ConsumerWidget {
  final String courseId;
  final String courseTitle;

  const CourseAnalyticsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(
      courseAnalyticsProvider(
        courseAnalyticsArg(courseId, courseTitle),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Course Analytics',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            Text(
              courseTitle,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: dataAsync.when(
        loading: () => const AnalyticsLoading(),
        error: (e, _) => AnalyticsError(
          message: e.toString(),
          onRetry: () => ref.invalidate(
            courseAnalyticsProvider(
              courseAnalyticsArg(courseId, courseTitle),
            ),
          ),
        ),
        data: (data) => _CourseAnalyticsBody(data: data),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Body
// ─────────────────────────────────────────────────────────────
class _CourseAnalyticsBody extends StatelessWidget {
  final CourseAnalyticsData data;
  const _CourseAnalyticsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    // Collect ALL attempts across all tests for the distribution chart
    final allAttemptItems = <TestAttemptItem>[];
    for (final t in data.testSummaries) {
      // Synthetic items from summary stats (avg only)
      for (int i = 0; i < t.attemptCount; i++) {
        allAttemptItems.add(TestAttemptItem(
          testId: t.testId,
          testTitle: t.testTitle,
          score: t.avgScore.toInt(),
          totalMarks: t.totalMarks,
          correctAnswers: 0,
          wrongAnswers: 0,
          skipped: 0,
          attemptedAt: DateTime.now(),
        ));
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Overview rings row ─────────────────────────
          _OverviewRingsRow(data: data),
          const SizedBox(height: 20),

          // ── Student progress list ───────────────────────
          AnalyticsCard(
            title: 'Student Progress',
            subtitle:
                '${data.studentProgress.length} enrolled students',
            child: data.studentProgress.isEmpty
                ? const _EmptyState(
                    text: 'No students enrolled yet.')
                : _StudentProgressList(
                    rows: data.studentProgress),
          ),
          const SizedBox(height: 20),

          // ── Test summaries ──────────────────────────────
          if (data.testSummaries.isNotEmpty) ...[
            AnalyticsCard(
              title: 'Score Distribution',
              subtitle: 'All test attempts combined',
              child: ScoreDistributionChart(
                  attempts: allAttemptItems),
            ),
            const SizedBox(height: 20),

            // ── Per-test cards ───────────────────────────
            Text('Test Breakdown',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 12),
            ...data.testSummaries
                .map((t) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: 16),
                      child: _TestAnalyticsCard(test: t),
                    )),
          ],

          // ── Doubts section ──────────────────────────────
          AnalyticsCard(
            title: 'Doubts',
            subtitle: 'For lectures in this course',
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  DonutStatChart(
                    percent: data.doubtResolutionRate,
                    centerLabel:
                        '${data.doubtResolutionRate.toStringAsFixed(0)}%',
                    activeColor: AppColors.success,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        LegendDot(
                            color: AppColors.success,
                            label:
                                'Resolved: ${data.answeredDoubts}'),
                        const SizedBox(height: 10),
                        LegendDot(
                            color: AppColors.warning,
                            label:
                                'Pending: ${data.totalDoubts - data.answeredDoubts}'),
                        const SizedBox(height: 10),
                        LegendDot(
                            color: AppColors.textHint,
                            label:
                                'Total: ${data.totalDoubts}'),
                      ],
                    ),
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
//  Overview rings: completion, avg progress
// ─────────────────────────────────────────────────────────────
class _OverviewRingsRow extends StatelessWidget {
  final CourseAnalyticsData data;
  const _OverviewRingsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                DonutStatChart(
                  percent: data.completionRate,
                  centerLabel:
                      '${data.completionRate.toStringAsFixed(0)}%',
                  activeColor: AppColors.success,
                ),
                const SizedBox(height: 10),
                Text('Completion Rate',
                    style: AppTextStyles.labelMedium,
                    textAlign: TextAlign.center),
                Text(
                  '${data.completedStudents} / ${data.enrolledStudents}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                DonutStatChart(
                  percent: data.avgProgressPercent,
                  centerLabel:
                      '${data.avgProgressPercent.toStringAsFixed(0)}%',
                  activeColor: AppColors.primary,
                ),
                const SizedBox(height: 10),
                Text('Avg Progress',
                    style: AppTextStyles.labelMedium,
                    textAlign: TextAlign.center),
                Text(
                  '${data.enrolledStudents} students',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                DonutStatChart(
                  percent: data.testSummaries.isNotEmpty
                      ? data.testSummaries
                              .map((t) => t.avgPercent)
                              .reduce((a, b) => a + b) /
                          data.testSummaries.length
                      : 0,
                  centerLabel: data.testSummaries.isNotEmpty
                      ? '${(data.testSummaries.map((t) => t.avgPercent).reduce((a, b) => a + b) / data.testSummaries.length).toStringAsFixed(0)}%'
                      : '—',
                  activeColor: AppColors.info,
                ),
                const SizedBox(height: 10),
                Text('Avg Test Score',
                    style: AppTextStyles.labelMedium,
                    textAlign: TextAlign.center),
                Text(
                  '${data.testSummaries.fold(0, (s, t) => s + t.attemptCount)} attempts',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Student progress list
// ─────────────────────────────────────────────────────────────
class _StudentProgressList extends StatelessWidget {
  final List<StudentProgressRow> rows;
  const _StudentProgressList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: rows.length,
      separatorBuilder: (_, idx) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _StudentProgressTile(
        row: rows[i],
        index: i,
      ),
    );
  }
}

class _StudentProgressTile extends StatelessWidget {
  final StudentProgressRow row;
  final int index;
  const _StudentProgressTile(
      {required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    final prog = row.progressPercent.clamp(0, 100).toDouble();
    final color = prog >= 100
        ? AppColors.success
        : prog >= 50
            ? AppColors.primary
            : AppColors.warning;

    return InkWell(
      onTap: () => context.push(
        AppRoutes.studentPerformancePath(row.studentId),
        extra: row.studentName,
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withAlpha(25),
              child: Text(
                row.studentName.isNotEmpty
                    ? row.studentName[0].toUpperCase()
                    : 'S',
                style: AppTextStyles.labelMedium
                    .copyWith(color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(row.studentName,
                            style: AppTextStyles.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '${prog.toStringAsFixed(0)}%',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: prog / 100,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enrolled ${DateFormat('d MMM y').format(row.enrolledAt)}',
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Test analytics card
// ─────────────────────────────────────────────────────────────
class _TestAnalyticsCard extends StatefulWidget {
  final TestSummaryRow test;
  const _TestAnalyticsCard({required this.test});

  @override
  State<_TestAnalyticsCard> createState() =>
      _TestAnalyticsCardState();
}

class _TestAnalyticsCardState extends State<_TestAnalyticsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.test;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          InkWell(
            onTap: () =>
                setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.quiz_rounded,
                        color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(t.testTitle,
                            style: AppTextStyles.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '${t.attemptCount} attempts · Avg ${t.avgPercent.toStringAsFixed(0)}%',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // ── Stats row ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _StatChip(
                    label: 'High',
                    value:
                        '${t.highestPercent.toStringAsFixed(0)}%',
                    color: AppColors.success),
                const SizedBox(width: 8),
                _StatChip(
                    label: 'Avg',
                    value:
                        '${t.avgPercent.toStringAsFixed(0)}%',
                    color: AppColors.primary),
                const SizedBox(width: 8),
                _StatChip(
                    label: 'Low',
                    value:
                        '${t.lowestPercent.toStringAsFixed(0)}%',
                    color: AppColors.error),
              ],
            ),
          ),

          // ── Expanded: difficult questions ────────────────
          if (_expanded && t.difficultQuestions.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Most Difficult Questions',
                style: AppTextStyles.headlineSmall,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: t.difficultQuestions
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8),
                          child: DifficultQuestionCard(
                            question: e.value,
                            rank: e.key + 1,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          if (_expanded && t.difficultQuestions.isEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No question-level data available yet.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.labelLarge
                    .copyWith(color: color, fontSize: 13)),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 10)),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Center(
          child: Text(text,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ),
      );
}
