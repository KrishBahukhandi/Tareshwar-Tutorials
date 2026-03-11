// ─────────────────────────────────────────────────────────────
//  analytics_widgets.dart
//  Reusable chart/card widgets for the analytics module.
// ─────────────────────────────────────────────────────────────
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/analytics_models.dart';

// ═══════════════════════════════════════════════════════════
//  SECTION CARD WRAPPER
// ═══════════════════════════════════════════════════════════

class AnalyticsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const AnalyticsCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.headlineMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SUMMARY TILE
// ═══════════════════════════════════════════════════════════

class SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const SummaryTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTextStyles.headlineLarge
                        .copyWith(color: color, fontSize: 22)),
                const SizedBox(height: 2),
                Text(label, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ENROLLMENT TREND LINE CHART
// ═══════════════════════════════════════════════════════════

class EnrollmentTrendChart extends StatelessWidget {
  final List<EnrollmentPoint> points;

  const EnrollmentTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No enrollment data yet.')),
      );
    }

    final maxY = points
        .map((p) => p.count.toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMax = maxY < 5 ? 5.0 : maxY * 1.25;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: effectiveMax,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${s.y.toInt()} students',
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
                    '${v.toInt()}',
                    style: AppTextStyles.labelSmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('MMM').format(points[idx].month),
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
                  points.length,
                  (i) =>
                      FlSpot(i.toDouble(), points[i].count.toDouble()),
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
                  color: AppColors.primary.withAlpha(30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SCORE DISTRIBUTION BAR CHART
// ═══════════════════════════════════════════════════════════

/// Buckets test attempts into score bands (0-20, 20-40, …, 80-100)
class ScoreDistributionChart extends StatelessWidget {
  final List<TestAttemptItem> attempts;

  const ScoreDistributionChart({super.key, required this.attempts});

  @override
  Widget build(BuildContext context) {
    final buckets = List<int>.filled(5, 0);
    for (final a in attempts) {
      final b = (a.percentage / 20).floor().clamp(0, 4);
      buckets[b]++;
    }

    final labels = ['0–20%', '20–40%', '40–60%', '60–80%', '80–100%'];
    final colors = [
      AppColors.error,
      AppColors.secondary,
      AppColors.warning,
      AppColors.info,
      AppColors.success,
    ];

    final maxY = buckets
        .map((b) => b.toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY < 4 ? 4 : maxY * 1.3,
            barTouchData: BarTouchData(enabled: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(labels[i],
                          style: AppTextStyles.labelSmall,
                          textAlign: TextAlign.center),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: AppTextStyles.labelSmall,
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              5,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: buckets[i].toDouble(),
                    color: colors[i],
                    width: 26,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DONUT CHART (resolution rate, completion rate, etc.)
// ═══════════════════════════════════════════════════════════

class DonutStatChart extends StatelessWidget {
  final double percent; // 0–100
  final String centerLabel;
  final Color activeColor;
  final Color trackColor;

  const DonutStatChart({
    super.key,
    required this.percent,
    required this.centerLabel,
    required this.activeColor,
    this.trackColor = const Color(0xFFE5E7EB),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 38,
              startDegreeOffset: -90,
              sections: [
                PieChartSectionData(
                  value: percent.clamp(0, 100),
                  color: activeColor,
                  radius: 14,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (100 - percent).clamp(0, 100),
                  color: trackColor,
                  radius: 14,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Text(
            centerLabel,
            style: AppTextStyles.headlineSmall
                .copyWith(fontSize: 14, color: activeColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LEGEND ITEM
// ═══════════════════════════════════════════════════════════

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      );
}

// ═══════════════════════════════════════════════════════════
//  DIFFICULT QUESTION CARD
// ═══════════════════════════════════════════════════════════

class DifficultQuestionCard extends StatelessWidget {
  final DifficultQuestion question;
  final int rank;

  const DifficultQuestionCard({
    super.key,
    required this.question,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final errorPct = question.errorRate;
    final Color barColor = errorPct >= 70
        ? AppColors.error
        : errorPct >= 40
            ? AppColors.warning
            : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: barColor.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank circle
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: barColor.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: barColor, fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.questionText,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Error rate bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: errorPct / 100,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${question.wrongAttempts} of ${question.totalAttempts} students got it wrong',
                style: AppTextStyles.labelSmall,
              ),
              Text(
                '${errorPct.toStringAsFixed(0)}%',
                style: AppTextStyles.labelMedium.copyWith(color: barColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  GRADE BADGE
// ═══════════════════════════════════════════════════════════

class GradeBadge extends StatelessWidget {
  final String grade;
  final Color color;

  const GradeBadge({super.key, required this.grade, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Center(
          child: Text(
            grade,
            style: AppTextStyles.labelLarge
                .copyWith(color: color, fontSize: 13),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
//  PROGRESS BAR ROW
// ═══════════════════════════════════════════════════════════

class ProgressBarRow extends StatelessWidget {
  final String label;
  final double value; // 0–100
  final Color color;

  const ProgressBarRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodySmall),
            Text(
              '${value.toStringAsFixed(0)}%',
              style:
                  AppTextStyles.labelMedium.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  EMPTY / LOADING PLACEHOLDERS
// ═══════════════════════════════════════════════════════════

class AnalyticsLoading extends StatelessWidget {
  const AnalyticsLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
}

class AnalyticsError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AnalyticsError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load analytics',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 6),
              Text(message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
