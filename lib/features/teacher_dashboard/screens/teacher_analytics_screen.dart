// ─────────────────────────────────────────────────────────────
//  teacher_analytics_screen.dart
//  Bar chart (enrolment per course) + pie chart (doubt resolution)
//  + sortable course breakdown table.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/models.dart';
import '../providers/teacher_dashboard_providers.dart';

class TeacherAnalyticsScreen extends ConsumerWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync   = ref.watch(teacherDashboardStatsProvider);
    final coursesAsync = ref.watch(teacherCoursesListProvider);
    final doubtsAsync  = ref.watch(teacherAllDoubtsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics', style: AppTextStyles.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Insights about your courses, students, and engagement.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          // ── Summary row ───────────────────────────────────
          statsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.error)),
            data: (stats) => _SummaryRow(stats: stats),
          ),
          const SizedBox(height: 28),

          // ── Charts ────────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 720;
            final bar = coursesAsync.when(
              loading: () => const _LoadingChart(),
              error: (e, st) => const SizedBox(),
              data: (c) => _EnrolmentBarChart(courses: c),
            );
            final pie = doubtsAsync.when(
              loading: () => const _LoadingChart(),
              error: (e, st) => const SizedBox(),
              data: (d) => _DoubtPieChart(doubts: d),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: bar),
                      const SizedBox(width: 20),
                      Expanded(child: pie),
                    ],
                  )
                : Column(children: [
                    bar,
                    const SizedBox(height: 20),
                    pie,
                  ]);
          }),

          const SizedBox(height: 28),

          // ── Course table ──────────────────────────────────
          Text('Course Breakdown',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 12),
          coursesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, st) => const SizedBox(),
            data: (c) =>
                c.isEmpty ? const _EmptyNote() : _CourseTable(courses: c),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Summary row
// ─────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final TeacherDashboardStats stats;
  const _SummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Courses',         '${stats.totalCourses}',  AppColors.primary),
      ('Students',        '${stats.totalStudents}',  const Color(0xFF10B981)),
      ('Pending Doubts',  '${stats.pendingDoubts}',  AppColors.warning),
      ('Lectures',        '${stats.totalLectures}',  AppColors.secondary),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items
          .map((item) => SizedBox(
                width: 160,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: item.$3.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: item.$3.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$2,
                          style: AppTextStyles.displaySmall
                              .copyWith(color: item.$3)),
                      const SizedBox(height: 2),
                      Text(item.$1,
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bar chart – students per course
// ─────────────────────────────────────────────────────────────
class _EnrolmentBarChart extends StatelessWidget {
  final List<CourseModel> courses;
  const _EnrolmentBarChart({required this.courses});

  @override
  Widget build(BuildContext context) {
    final items = courses.take(6).toList();
    if (items.isEmpty) return const SizedBox();

    final maxY = items
        .map((c) => (c.totalStudents ?? 0).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b) * 1.3;

    return _ChartCard(
      title: 'Students Per Course',
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY < 10 ? 10 : maxY,
            barTouchData: BarTouchData(enabled: true),
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
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i >= items.length) return const SizedBox();
                    final t = items[i].title;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        t.length > 8 ? '${t.substring(0, 8)}…' : t,
                        style: AppTextStyles.labelSmall,
                      ),
                    );
                  },
                ),
              ),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              drawHorizontalLine: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              items.length,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (items[i].totalStudents ?? 0).toDouble(),
                    color: AppColors.primary,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY < 10 ? 10 : maxY,
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
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

// ─────────────────────────────────────────────────────────────
//  Pie chart – doubt resolution
// ─────────────────────────────────────────────────────────────
class _DoubtPieChart extends StatelessWidget {
  final List<DoubtModel> doubts;
  const _DoubtPieChart({required this.doubts});

  @override
  Widget build(BuildContext context) {
    final answered = doubts.where((d) => d.isAnswered).length;
    final pending  = doubts.length - answered;
    final total    = doubts.length;

    return _ChartCard(
      title: 'Doubt Resolution',
      child: total == 0
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No doubts yet.')),
            )
          : Column(
              children: [
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: answered.toDouble(),
                          color: AppColors.success,
                          title:
                              '${(answered / total * 100).toStringAsFixed(0)}%',
                          radius: 55,
                          titleStyle: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white),
                        ),
                        PieChartSectionData(
                          value: pending.toDouble(),
                          color: AppColors.warning,
                          title:
                              '${(pending / total * 100).toStringAsFixed(0)}%',
                          radius: 55,
                          titleStyle: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legend(
                        color: AppColors.success,
                        label: 'Answered ($answered)'),
                    const SizedBox(width: 20),
                    _Legend(
                        color: AppColors.warning,
                        label: 'Pending ($pending)'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
//  Chart card wrapper
// ─────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Course breakdown data table
// ─────────────────────────────────────────────────────────────
class _CourseTable extends StatelessWidget {
  final List<CourseModel> courses;
  const _CourseTable({required this.courses});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DataTable(
            columnSpacing: 28,
            headingRowColor:
                WidgetStateProperty.all(AppColors.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Course')),
              DataColumn(label: Text('Students'), numeric: true),
              DataColumn(label: Text('Lectures'), numeric: true),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Status')),
            ],
            rows: courses.map((c) => DataRow(cells: [
              DataCell(SizedBox(
                width: 200,
                child: Text(c.title,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge),
              )),
              DataCell(Text('${c.totalStudents ?? 0}')),
              DataCell(Text('${c.totalLectures ?? 0}')),
              DataCell(Text(c.price == 0
                  ? 'Free'
                  : '₹${c.price.toStringAsFixed(0)}')),
              DataCell(_StatusDot(isPublished: c.isPublished)),
            ])).toList(),
          ),
        ),
      );
}

class _StatusDot extends StatelessWidget {
  final bool isPublished;
  const _StatusDot({required this.isPublished});

  @override
  Widget build(BuildContext context) {
    final color = isPublished ? AppColors.success : AppColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(isPublished ? 'Published' : 'Draft',
            style: AppTextStyles.labelSmall.copyWith(color: color)),
      ],
    );
  }
}

class _LoadingChart extends StatelessWidget {
  const _LoadingChart();

  @override
  Widget build(BuildContext context) => Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote();

  @override
  Widget build(BuildContext context) => Center(
        child: Text('No courses yet.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
      );
}
