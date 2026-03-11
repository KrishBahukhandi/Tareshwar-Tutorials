// ─────────────────────────────────────────────────────────────
//  admin_analytics_widgets.dart
//  Reusable UI components for the Admin Analytics Dashboard.
//
//  Exports:
//    • AnalyticsStatCard         – KPI tile with icon, value, label
//    • AnalyticsChartCard        – card wrapper with title/subtitle
//    • RevenueChart              – BarChart of monthly revenue
//    • StudentGrowthChart        – LineChart of monthly new students
//    • CompletionRingChart       – PieChart / donut for completion rate
//    • AnalyticsSkeletonLoader   – shimmer placeholder
// ─────────────────────────────────────────────────────────────
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/admin_analytics_service.dart';

// ─────────────────────────────────────────────────────────────
//  Currency helper
// ─────────────────────────────────────────────────────────────
final _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _fmtInr(double v) => _inr.format(v);

String _compact(double v) {
  if (v >= 1000000) return '₹${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
  return _fmtInr(v);
}

// ─────────────────────────────────────────────────────────────
//  AnalyticsStatCard
// ─────────────────────────────────────────────────────────────
class AnalyticsStatCard extends StatelessWidget {
  const AnalyticsStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
  });

  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final String?  subtitle;
  final String?  trend; // e.g. '+8 this month'

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend!,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.success, fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTextStyles.displaySmall.copyWith(color: color),
          ),
          const SizedBox(height: 3),
          Text(label, style: AppTextStyles.labelMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  AnalyticsChartCard  – generic wrapper
// ─────────────────────────────────────────────────────────────
class AnalyticsChartCard extends StatelessWidget {
  const AnalyticsChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String  title;
  final String? subtitle;
  final Widget? trailing;
  final Widget  child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.headlineSmall),
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
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RevenueChart  – monthly revenue BarChart (last 12 months)
// ─────────────────────────────────────────────────────────────
class RevenueChart extends StatefulWidget {
  const RevenueChart({super.key, required this.data});

  final List<MonthlyDataPoint> data;

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const _EmptyChart(message: 'No revenue data available');
    }

    final maxVal = widget.data
        .map((d) => d.value)
        .fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMax = maxVal < 1 ? 1000.0 : maxVal * 1.30;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 20),
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            maxY: effectiveMax,
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                setState(() {
                  _touchedIndex = (event.isInterestedForInteractions &&
                          response?.spot != null)
                      ? response!.spot!.touchedBarGroupIndex
                      : null;
                });
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, gI, rod, rI) => BarTooltipItem(
                  '${widget.data[gI].label}\n${_fmtInr(rod.toY)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(
                    _compact(v),
                    style: AppTextStyles.labelSmall
                        .copyWith(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= widget.data.length) {
                      return const SizedBox.shrink();
                    }
                    // Show every other label to avoid clutter
                    if (i % 2 != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        widget.data[i].label,
                        style: AppTextStyles.labelSmall
                            .copyWith(fontSize: 10),
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
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(widget.data.length, (i) {
              final isTouched = _touchedIndex == i;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: widget.data[i].value,
                    width: isTouched ? 18 : 14,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                    gradient: LinearGradient(
                      colors: isTouched
                          ? [AppColors.primaryDark, AppColors.primary]
                          : [
                              AppColors.primary.withValues(alpha: 0.75),
                              AppColors.primary,
                            ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  StudentGrowthChart  – monthly new-student LineChart
// ─────────────────────────────────────────────────────────────
class StudentGrowthChart extends StatelessWidget {
  const StudentGrowthChart({super.key, required this.data});

  final List<MonthlyDataPoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyChart(message: 'No student data available');
    }

    final maxVal =
        data.map((d) => d.value).fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMax = maxVal < 5 ? 5.0 : maxVal * 1.30;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 20, 20),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: effectiveMax,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${data[s.x.toInt()].label}\n'
                          '${s.y.toInt()} students',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
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
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: AppTextStyles.labelSmall
                        .copyWith(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) {
                      return const SizedBox.shrink();
                    }
                    if (i % 2 != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        data[i].label,
                        style: AppTextStyles.labelSmall
                            .copyWith(fontSize: 10),
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
                    data.length,
                    (i) => FlSpot(
                          i.toDouble(),
                          data[i].value,
                        )),
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppColors.accent,
                barWidth: 3,
                dotData: FlDotData(
                  getDotPainter: (spot, _, __, ___) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.accent,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.20),
                      AppColors.accent.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
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

// ─────────────────────────────────────────────────────────────
//  CompletionRingChart  – donut for course completion rate
// ─────────────────────────────────────────────────────────────
class CompletionRingChart extends StatefulWidget {
  const CompletionRingChart({
    super.key,
    required this.completionRate,
    required this.total,
    required this.completed,
  });

  final double completionRate; // 0 – 100
  final int    total;
  final int    completed;

  @override
  State<CompletionRingChart> createState() => _CompletionRingChartState();
}

class _CompletionRingChartState extends State<CompletionRingChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final pct       = widget.completionRate.clamp(0.0, 100.0);
    final remaining = 100.0 - pct;
    final incomplete = widget.total - widget.completed;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Donut
          SizedBox(
            width: 160,
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 48,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex =
                          (event.isInterestedForInteractions &&
                                  response?.touchedSection != null)
                              ? response!
                                  .touchedSection!.touchedSectionIndex
                              : -1;
                    });
                  },
                ),
                sections: [
                  PieChartSectionData(
                    value: pct == 0 ? 0.001 : pct,
                    color: _touchedIndex == 0
                        ? AppColors.success
                        : AppColors.success.withValues(alpha: 0.85),
                    radius: _touchedIndex == 0 ? 44 : 38,
                    title: '',
                    badgeWidget: _touchedIndex == 0
                        ? _Badge(
                            '${pct.toStringAsFixed(1)}%',
                            AppColors.success)
                        : null, // ignore: use_null_aware_elements
                    badgePositionPercentageOffset: 1.2,
                  ),
                  PieChartSectionData(
                    value: remaining == 0 ? 0.001 : remaining,
                    color: _touchedIndex == 1
                        ? AppColors.error
                        : AppColors.error.withValues(alpha: 0.25),
                    radius: _touchedIndex == 1 ? 44 : 38,
                    title: '',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: AppTextStyles.displaySmall
                      .copyWith(color: AppColors.success),
                ),
                Text(
                  'Course Completion Rate',
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: 16),
                _LegendItem(
                  color: AppColors.success,
                  label: 'Completed',
                  count: widget.completed,
                ),
                const SizedBox(height: 8),
                _LegendItem(
                  color: AppColors.error.withValues(alpha: 0.5),
                  label: 'Incomplete',
                  count: incomplete,
                ),
                const SizedBox(height: 8),
                _LegendItem(
                  color: AppColors.border,
                  label: 'Total Enrollments',
                  count: widget.total,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color  color;
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600),
        ),
      );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    this.bold = false,
  });

  final Color  color;
  final String label;
  final int    count;
  final bool   bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight:
                  bold ? FontWeight.w600 : FontWeight.normal,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          '$count',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight:
                bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _EmptyChart
// ─────────────────────────────────────────────────────────────
class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 48,
                color: AppColors.textHint),
            const SizedBox(height: 8),
            Text(message,
                style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  AnalyticsSkeletonLoader  – shimmer placeholder
// ─────────────────────────────────────────────────────────────
class AnalyticsSkeletonLoader extends StatefulWidget {
  const AnalyticsSkeletonLoader({super.key});

  @override
  State<AnalyticsSkeletonLoader> createState() =>
      _AnalyticsSkeletonLoaderState();
}

class _AnalyticsSkeletonLoaderState extends State<AnalyticsSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Column(
          children: [
            // Stat card row
            Row(
              children: List.generate(
                  4,
                  (_) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _SkeletonBox(height: 120),
                        ),
                      )),
            ),
            const SizedBox(height: 20),
            _SkeletonBox(height: 290),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _SkeletonBox(height: 270)),
              const SizedBox(width: 16),
              Expanded(child: _SkeletonBox(height: 270)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(18),
        ),
      );
}
