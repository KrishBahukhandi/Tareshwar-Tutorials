// ─────────────────────────────────────────────────────────────
//  performance_analysis_screen.dart  –  Student performance
//  Aggregate stats, score trend chart, attempt history, grades.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart';

// ─────────────────────────────────────────────────────────────
class PerformanceAnalysisScreen extends ConsumerWidget {
  const PerformanceAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(studentAttemptsProvider);
    final statsAsync = ref.watch(studentTestStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Performance'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: attemptsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading data',
          subtitle: e.toString(),
          iconColor: AppColors.error,
        ),
        data: (attempts) => statsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Error loading stats',
            subtitle: e.toString(),
            iconColor: AppColors.error,
          ),
          data: (stats) => _Body(
            attempts: attempts,
            stats: stats,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Body
// ─────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final List<TestAttemptModel> attempts;
  final Map<String, dynamic> stats;
  const _Body({required this.attempts, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (attempts.isEmpty) {
      return AppEmptyState(
        icon: Icons.analytics_outlined,
        title: 'No attempts yet',
        subtitle:
            'Attempt tests to see your performance analysis here.',
        actionLabel: 'Browse Tests',
        onAction: () => context.push(AppRoutes.testListPath()),
      );
    }

    final sorted = [...attempts]
      ..sort((a, b) => a.attemptedAt.compareTo(b.attemptedAt));

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
              AppSpacing.md, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero stats row ─────────────────────────────
          _StatsHero(stats: stats, totalAttempts: attempts.length),
          const SizedBox(height: AppSpacing.lg),

          // ── Score trend chart ──────────────────────────
          if (sorted.length >= 2) ...[
            Text('Score Trend',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            _ScoreChart(attempts: sorted),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Grade distribution ─────────────────────────
          Text('Grade Distribution',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          _GradeDistribution(attempts: attempts),
          const SizedBox(height: AppSpacing.lg),

          // ── Accuracy breakdown ─────────────────────────
          Text('Overall Accuracy',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          _AccuracyBreakdown(attempts: attempts),
          const SizedBox(height: AppSpacing.lg),

          // ── Attempt history ────────────────────────────
          Text('Attempt History',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          _AttemptHistory(attempts: sorted.reversed.toList()),
        ],
      ),
    );
  }
}

// ── Hero stats ────────────────────────────────────────────────
class _StatsHero extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int totalAttempts;
  const _StatsHero(
      {required this.stats, required this.totalAttempts});

  @override
  Widget build(BuildContext context) {
    final best = stats['best'] as int? ?? 0;
    final avg = (stats['avg'] as num?)?.toDouble() ?? 0.0;

    return AppCard(
      gradient: AppColors.primaryGradient,
      hasBorder: false,
      shadows: AppShadows.md,
      child: Row(
        children: [
          _HeroStat(
            icon: Icons.emoji_events_rounded,
            value: '$best',
            label: 'Best Score',
          ),
          _HeroStat(
            icon: Icons.bar_chart_rounded,
            value: avg.toStringAsFixed(1),
            label: 'Avg. Score',
          ),
          _HeroStat(
            icon: Icons.history_rounded,
            value: '$totalAttempts',
            label: 'Attempts',
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _HeroStat(
      {required this.icon,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: AppTextStyles.headlineMedium
                    .copyWith(color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: Colors.white70)),
          ],
        ),
      );
}

// ── Score trend line chart ────────────────────────────────────
class _ScoreChart extends StatelessWidget {
  final List<TestAttemptModel> attempts;
  const _ScoreChart({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final spots = attempts.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.percentage);
    }).toList();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.border,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 25,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}%',
                    style: AppTextStyles.labelSmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, _) => Text(
                    '#${(v + 1).toInt()}',
                    style: AppTextStyles.labelSmall,
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${s.y.toStringAsFixed(1)}%',
                          AppTextStyles.labelSmall
                              .copyWith(color: Colors.white),
                        ))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2.5,
                belowBarData: BarAreaData(
                  show: true,
                  color:
                      AppColors.primary.withValues(alpha: 0.08),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeColor: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grade distribution bar chart ──────────────────────────────
class _GradeDistribution extends StatelessWidget {
  final List<TestAttemptModel> attempts;
  const _GradeDistribution({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final gradeMap = <String, int>{
      'A+': 0, 'A': 0, 'B': 0, 'C': 0, 'D': 0, 'F': 0,
    };
    for (final a in attempts) {
      gradeMap[a.grade] = (gradeMap[a.grade] ?? 0) + 1;
    }

    final colors = {
      'A+': AppColors.success,
      'A': const Color(0xFF34D399),
      'B': AppColors.info,
      'C': AppColors.warning,
      'D': const Color(0xFFFB923C),
      'F': AppColors.error,
    };

    final maxVal =
        gradeMap.values.reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: gradeMap.entries.map((e) {
          final count = e.value;
          final color = colors[e.key] ?? AppColors.primary;
          final barH =
              maxVal > 0 ? (count / maxVal) * 100.0 : 0.0;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: color)),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  height: barH.clamp(6.0, 100.0),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(e.key,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: color)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Accuracy breakdown ────────────────────────────────────────
class _AccuracyBreakdown extends StatelessWidget {
  final List<TestAttemptModel> attempts;
  const _AccuracyBreakdown({required this.attempts});

  @override
  Widget build(BuildContext context) {
    int totalCorrect = 0;
    int totalWrong = 0;
    int totalSkipped = 0;

    for (final a in attempts) {
      totalCorrect += a.correctAnswers;
      totalWrong += a.wrongAnswers;
      totalSkipped += a.skipped;
    }

    final totalQ = totalCorrect + totalWrong + totalSkipped;
    final accuracy =
        totalQ > 0 ? (totalCorrect / totalQ) * 100 : 0.0;

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AccStat(
                label: 'Correct',
                value: '$totalCorrect',
                color: AppColors.success,
                icon: Icons.check_circle_outline_rounded,
              ),
              _AccStat(
                label: 'Wrong',
                value: '$totalWrong',
                color: AppColors.error,
                icon: Icons.cancel_outlined,
              ),
              _AccStat(
                label: 'Skipped',
                value: '$totalSkipped',
                color: AppColors.warning,
                icon: Icons.remove_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(
            value: (accuracy / 100).clamp(0.0, 1.0),
            color: AppColors.success,
            height: 10,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Accuracy',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary)),
              Text(
                '${accuracy.toStringAsFixed(1)}%',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _AccStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.headlineMedium
                  .copyWith(color: color)),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      );
}

// ── Attempt history list ──────────────────────────────────────
class _AttemptHistory extends ConsumerWidget {
  final List<TestAttemptModel> attempts;
  const _AttemptHistory({required this.attempts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: attempts.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, i) {
        final a = attempts[i];
        final color = a.percentage >= 60
            ? AppColors.success
            : AppColors.error;
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          onTap: () => context.push(
              AppRoutes.testResultPath(a.testId),
              extra: a),
          child: Row(
            children: [
              // Grade badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    a.grade,
                    style: AppTextStyles.headlineSmall
                        .copyWith(color: color),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDate(a.attemptedAt),
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${a.correctAnswers}✓  ${a.wrongAnswers}✗  ${a.skipped} skip',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Score
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${a.score}/${a.totalMarks}',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: color),
                  ),
                  Text(
                    '${a.percentage.toStringAsFixed(1)}%',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
