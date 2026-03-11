// ─────────────────────────────────────────────────────────────
//  admin_payments_widgets.dart
//  Shared UI components for Admin Payment Management.
// ─────────────────────────────────────────────────────────────
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/admin_payments_service.dart';

// ─────────────────────────────────────────────────────────────
//  Currency formatter
// ─────────────────────────────────────────────────────────────
final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String fmtInr(double v) => _inr.format(v);

// ─────────────────────────────────────────────────────────────
//  Payment Status Badge
// ─────────────────────────────────────────────────────────────
class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({super.key, required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      PaymentStatus.completed => (AppColors.success,  Icons.check_circle_rounded),
      PaymentStatus.pending   => (AppColors.warning,  Icons.schedule_rounded),
      PaymentStatus.failed    => (AppColors.error,    Icons.cancel_rounded),
      PaymentStatus.refunded  => (AppColors.info,     Icons.replay_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Revenue Stat Card
// ─────────────────────────────────────────────────────────────
class RevenueStatCard extends StatelessWidget {
  const RevenueStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
  });

  final String  label;
  final String  value;
  final IconData icon;
  final Color   color;
  final String? subtitle;
  final String? trend; // e.g. '+12% vs last month'

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.success),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: AppTextStyles.headlineLarge.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Payment Table Card wrapper
// ─────────────────────────────────────────────────────────────
class PaymentTableCard extends StatelessWidget {
  const PaymentTableCard({
    super.key,
    required this.title,
    this.headerActions,
    required this.child,
  });

  final String        title;
  final List<Widget>? headerActions;
  final Widget        child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            child: Row(
              children: [
                Text(title, style: AppTextStyles.headlineSmall),
                const Spacer(),
                if (headerActions != null) ...headerActions!,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Payment Row Tile (for list view)
// ─────────────────────────────────────────────────────────────
class PaymentListTile extends StatelessWidget {
  const PaymentListTile({
    super.key,
    required this.payment,
    this.onTap,
    this.onStatusChange,
  });

  final PaymentRow            payment;
  final VoidCallback?         onTap;
  final ValueChanged<PaymentStatus>? onStatusChange;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                payment.studentName.isNotEmpty
                    ? payment.studentName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            // Student + course
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payment.studentName,
                      style: AppTextStyles.labelLarge,
                      overflow: TextOverflow.ellipsis),
                  Text(payment.studentEmail,
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Course
            Expanded(
              flex: 3,
              child: Text(
                payment.courseTitle,
                style: AppTextStyles.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Amount
            SizedBox(
              width: 90,
              child: Text(
                fmtInr(payment.amount),
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textPrimary),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 16),
            // Status badge
            PaymentStatusBadge(status: payment.status),
            const SizedBox(width: 16),
            // Date
            SizedBox(
              width: 90,
              child: Text(
                DateFormat('dd MMM yy').format(payment.createdAt.toLocal()),
                style: AppTextStyles.caption,
                textAlign: TextAlign.right,
              ),
            ),
            // Actions menu
            if (onStatusChange != null)
              PopupMenuButton<PaymentStatus>(
                iconSize: 18,
                tooltip: 'Change status',
                itemBuilder: (ctx) => PaymentStatus.values
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              PaymentStatusBadge(status: s),
                            ],
                          ),
                        ))
                    .toList(),
                onSelected: onStatusChange,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Monthly Revenue Bar Chart
// ─────────────────────────────────────────────────────────────
class MonthlyRevenueChart extends StatelessWidget {
  const MonthlyRevenueChart({super.key, required this.data});

  final List<MonthlyRevenue> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No revenue data yet'));
    }

    final maxY = data.map((d) => d.amount).reduce((a, b) => a > b ? a : b);
    final barGroups = data.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.amount,
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.7),
                AppColors.primary,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        barGroups: barGroups,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '₹${(value / 1000).toStringAsFixed(0)}k',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[idx].month,
                    style: AppTextStyles.caption,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppColors.surfaceVariant,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              fmtInr(rod.toY),
              AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Course Revenue Pie Chart
// ─────────────────────────────────────────────────────────────
class CourseRevenuePieChart extends StatefulWidget {
  const CourseRevenuePieChart({super.key, required this.data});

  final List<CourseRevenue> data;

  @override
  State<CourseRevenuePieChart> createState() => _CourseRevenuePieChartState();
}

class _CourseRevenuePieChartState extends State<CourseRevenuePieChart> {
  int _touched = -1;

  static const _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.info,
    AppColors.warning,
    Color(0xFF9C27B0),
    Color(0xFFFF5722),
  ];

  @override
  Widget build(BuildContext context) {
    final top    = widget.data.take(6).toList();
    final total  = top.fold<double>(0, (s, c) => s + c.totalRevenue);

    if (top.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: top.asMap().entries.map((e) {
                final isTouched = e.key == _touched;
                final pct = total > 0 ? e.value.totalRevenue / total * 100 : 0.0;
                return PieChartSectionData(
                  value: e.value.totalRevenue,
                  color: _palette[e.key % _palette.length],
                  radius: isTouched ? 64 : 54,
                  title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                  titleStyle: AppTextStyles.labelSmall
                      .copyWith(color: Colors.white),
                );
              }).toList(),
              pieTouchData: PieTouchData(
                touchCallback: (event, resp) {
                  setState(() {
                    _touched = (resp?.touchedSection?.touchedSectionIndex) ?? -1;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 44,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: top.asMap().entries.map((e) {
              final color = _palette[e.key % _palette.length];
              final pct   = total > 0
                  ? e.value.totalRevenue / total * 100
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.value.courseTitle,
                        style: AppTextStyles.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────
class PaymentEmptyState extends StatelessWidget {
  const PaymentEmptyState({
    super.key,
    this.message = 'No transactions found',
    this.subtitle,
  });

  final String  message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 14),
            Text(message, style: AppTextStyles.headlineSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Date range picker row
// ─────────────────────────────────────────────────────────────
class DateRangeRow extends StatelessWidget {
  const DateRangeRow({
    super.key,
    required this.from,
    required this.to,
    required this.onFromPicked,
    required this.onToPicked,
    required this.onClear,
  });

  final DateTime?             from;
  final DateTime?             to;
  final ValueChanged<DateTime> onFromPicked;
  final ValueChanged<DateTime> onToPicked;
  final VoidCallback           onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DateButton(
          label: from == null
              ? 'From date'
              : DateFormat('dd MMM yy').format(from!),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: from ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (d != null) onFromPicked(d);
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('–', style: TextStyle(color: AppColors.textHint)),
        ),
        _DateButton(
          label: to == null
              ? 'To date'
              : DateFormat('dd MMM yy').format(to!),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: to ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (d != null) onToPicked(d);
          },
        ),
        if (from != null || to != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onClear,
            tooltip: 'Clear dates',
          ),
        ],
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppColors.textHint),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
