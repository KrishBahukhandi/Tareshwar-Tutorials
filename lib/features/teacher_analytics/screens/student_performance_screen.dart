// ─────────────────────────────────────────────────────────────
//  student_performance_screen.dart
//  Per-student analytics: course progress, test scores, doubts.
//  Charts: score trend line, correct/wrong/skipped pie,
//          per-course progress bars.
// ─────────────────────────────────────────────────────────────
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_widgets.dart';

class StudentPerformanceScreen extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const StudentPerformanceScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(
      studentAnalyticsProvider(
        studentAnalyticsArg(studentId, studentName),
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
            const Text('Student Performance',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            Text(
              studentName,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: dataAsync.when(
        loading: () => const AnalyticsLoading(),
        error: (e, _) => AnalyticsError(
          message: e.toString(),
          onRetry: () => ref.invalidate(
            studentAnalyticsProvider(
              studentAnalyticsArg(studentId, studentName),
            ),
          ),
        ),
        data: (data) => _Body(data: data),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Body
// ─────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final StudentAnalyticsData data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Student header card ─────────────────────────
          _StudentHeaderCard(data: data),
          const SizedBox(height: 20),

          // ── Course progress section ─────────────────────
          AnalyticsCard(
            title: 'Course Progress',
            subtitle:
                '${data.courseProgress.length} enrolled courses',
            child: data.courseProgress.isEmpty
                ? const _EmptyNote(text: 'Not enrolled in any course.')
                : Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      children: data.courseProgress
                          .map((cp) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 14),
                                child: _CourseProgressItem(item: cp),
                              ))
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // ── Test performance section ────────────────────
          if (data.testAttempts.isNotEmpty) ...[
            // Score trend line chart
            AnalyticsCard(
              title: 'Score Trend',
              subtitle: 'Last ${data.testAttempts.length} attempts',
              child: _ScoreTrendChart(
                  attempts: data.testAttempts),
            ),
            const SizedBox(height: 20),

            // Correct / wrong / skipped pie
            AnalyticsCard(
              title: 'Answer Breakdown',
              subtitle: 'Cumulative across all tests',
              child: _AnswerBreakdownSection(
                  attempts: data.testAttempts),
            ),
            const SizedBox(height: 20),

            // Score distribution bar
            AnalyticsCard(
              title: 'Score Distribution',
              subtitle: 'Tests by score band',
              child: ScoreDistributionChart(
                  attempts: data.testAttempts),
            ),
            const SizedBox(height: 20),

            // Individual attempt list
            AnalyticsCard(
              title: 'Test History',
              child: _TestHistoryList(
                  attempts: data.testAttempts),
            ),
            const SizedBox(height: 20),
          ] else ...[
            AnalyticsCard(
              title: 'Test Performance',
              child: const _EmptyNote(
                  text: 'No test attempts yet.'),
            ),
            const SizedBox(height: 20),
          ],

          // ── Doubts section ──────────────────────────────
          AnalyticsCard(
            title: 'Doubts',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  DonutStatChart(
                    percent: data.totalDoubts == 0
                        ? 0
                        : data.answeredDoubts /
                            data.totalDoubts *
                            100,
                    centerLabel: data.totalDoubts == 0
                        ? '—'
                        : '${(data.answeredDoubts / data.totalDoubts * 100).toStringAsFixed(0)}%',
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
//  Student header card
// ─────────────────────────────────────────────────────────────
class _StudentHeaderCard extends StatelessWidget {
  final StudentAnalyticsData data;
  const _StudentHeaderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withAlpha(50),
            child: Text(
              data.studentName.isNotEmpty
                  ? data.studentName[0].toUpperCase()
                  : 'S',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.studentName,
                  style: AppTextStyles.headlineLarge
                      .copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.courseProgress.length} courses · ${data.testAttempts.length} tests',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Course progress item
// ─────────────────────────────────────────────────────────────
class _CourseProgressItem extends StatelessWidget {
  final CourseProgressItem item;
  const _CourseProgressItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final prog = item.progressPercent.clamp(0, 100).toDouble();
    final color = prog >= 100
        ? AppColors.success
        : prog >= 50
            ? AppColors.primary
            : AppColors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(item.courseTitle,
                  style: AppTextStyles.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Text(
              '${prog.toStringAsFixed(0)}%',
              style: AppTextStyles.labelMedium.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: prog / 100,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enrolled ${DateFormat('d MMM y').format(item.enrolledAt)}',
          style: AppTextStyles.labelSmall,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Score trend line chart
// ─────────────────────────────────────────────────────────────
class _ScoreTrendChart extends StatelessWidget {
  final List<TestAttemptItem> attempts;
  const _ScoreTrendChart({required this.attempts});

  @override
  Widget build(BuildContext context) {
    // Show last 10 attempts, oldest first
    final recent =
        attempts.reversed.take(10).toList().reversed.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${s.y.toStringAsFixed(0)}%',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ))
                    .toList(),
              ),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}%',
                    style: AppTextStyles.labelSmall,
                  ),
                  interval: 25,
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= recent.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'T${idx + 1}',
                        style: AppTextStyles.labelSmall,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  recent.length,
                  (i) => FlSpot(
                      i.toDouble(), recent[i].percentage),
                ),
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                dotData: FlDotData(
                  getDotPainter: (spot, pct, bar, idx) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withAlpha(25),
                ),
              ),
              // 60% pass-line
              LineChartBarData(
                spots: [
                  FlSpot(0, 60),
                  FlSpot(
                      (recent.length - 1).toDouble(), 60),
                ],
                isCurved: false,
                color: AppColors.error.withAlpha(120),
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
                dashArray: [6, 4],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Answer breakdown pie
// ─────────────────────────────────────────────────────────────
class _AnswerBreakdownSection extends StatelessWidget {
  final List<TestAttemptItem> attempts;
  const _AnswerBreakdownSection({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final correct = attempts.fold(0, (s, a) => s + a.correctAnswers);
    final wrong = attempts.fold(0, (s, a) => s + a.wrongAnswers);
    final skipped = attempts.fold(0, (s, a) => s + a.skipped);
    final total = correct + wrong + skipped;
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No data.')),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    value: correct.toDouble(),
                    color: AppColors.success,
                    title:
                        '${(correct / total * 100).toStringAsFixed(0)}%',
                    radius: 40,
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  PieChartSectionData(
                    value: wrong.toDouble(),
                    color: AppColors.error,
                    title:
                        '${(wrong / total * 100).toStringAsFixed(0)}%',
                    radius: 40,
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  PieChartSectionData(
                    value: skipped.toDouble(),
                    color: AppColors.textHint,
                    title:
                        '${(skipped / total * 100).toStringAsFixed(0)}%',
                    radius: 40,
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LegendDot(
                    color: AppColors.success,
                    label: 'Correct: $correct'),
                const SizedBox(height: 10),
                LegendDot(
                    color: AppColors.error,
                    label: 'Wrong: $wrong'),
                const SizedBox(height: 10),
                LegendDot(
                    color: AppColors.textHint,
                    label: 'Skipped: $skipped'),
                const SizedBox(height: 14),
                Text('Total: $total Qs',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Test history list
// ─────────────────────────────────────────────────────────────
class _TestHistoryList extends StatelessWidget {
  final List<TestAttemptItem> attempts;
  const _TestHistoryList({required this.attempts});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: attempts.length,
      separatorBuilder: (_, idx) =>
          const Divider(height: 1, indent: 8, endIndent: 8),
      itemBuilder: (_, i) => _AttemptTile(attempt: attempts[i]),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  final TestAttemptItem attempt;
  const _AttemptTile({required this.attempt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          GradeBadge(
            grade: attempt.grade,
            color: attempt.gradeColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attempt.testTitle,
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${attempt.score}/${attempt.totalMarks} · ${attempt.correctAnswers}✓ ${attempt.wrongAnswers}✗ ${attempt.skipped}—',
                  style: AppTextStyles.labelSmall,
                ),
                Text(
                  DateFormat('d MMM y, HH:mm')
                      .format(attempt.attemptedAt),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${attempt.percentage.toStringAsFixed(0)}%',
            style: AppTextStyles.labelLarge
                .copyWith(color: attempt.gradeColor),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote({required this.text});

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
