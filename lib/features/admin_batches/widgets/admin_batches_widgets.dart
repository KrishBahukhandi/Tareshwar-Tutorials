// ─────────────────────────────────────────────────────────────
//  admin_batches_widgets.dart
//  Shared UI components for Admin Batch Management.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/admin_batches_service.dart';

// ─────────────────────────────────────────────────────────────
//  Batch Status Badge
// ─────────────────────────────────────────────────────────────
class BatchStatusBadge extends StatelessWidget {
  final bool isActive;
  const BatchStatusBadge({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: AppTextStyles.labelSmall.copyWith(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Capacity Fill Indicator
// ─────────────────────────────────────────────────────────────
class CapacityFillBar extends StatelessWidget {
  final int enrolled;
  final int max;
  final double barWidth;

  const CapacityFillBar({
    super.key,
    required this.enrolled,
    required this.max,
    this.barWidth = 90,
  });

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (enrolled / max).clamp(0.0, 1.0) : 0.0;
    final color = pct >= 1.0
        ? AppColors.error
        : pct >= 0.8
            ? AppColors.warning
            : AppColors.success;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$enrolled',
                style: AppTextStyles.labelSmall
                    .copyWith(color: color)),
            Text(' / $max',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: barWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stat Card
// ─────────────────────────────────────────────────────────────
class BatchStatCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const BatchStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style:
                      AppTextStyles.headlineMedium.copyWith(color: color)),
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Batch Info Header (inside detail / students screen)
// ─────────────────────────────────────────────────────────────
class BatchInfoHeader extends StatelessWidget {
  final AdminBatchListItem batch;

  const BatchInfoHeader({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    final fill      = batch.fillPercent;
    final fillColor = fill >= 1.0
        ? AppColors.error
        : fill >= 0.8
            ? AppColors.warning
            : AppColors.success;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.batchName,
                        style: AppTextStyles.headlineMedium),
                    const SizedBox(height: 2),
                    Text(batch.courseTitle,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary)),
                  ],
                ),
              ),
              BatchStatusBadge(isActive: batch.isActive),
            ],
          ),
          const SizedBox(height: 12),
          // ── Stats row ──────────────────────────────────────
          Row(
            children: [
              _MiniStat(
                icon: Icons.people_rounded,
                label: 'Enrolled',
                value: '${batch.enrolledCount}',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                icon: Icons.group_add_rounded,
                label: 'Capacity',
                value: '${batch.maxStudents}',
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                icon: Icons.event_seat_rounded,
                label: 'Available',
                value: '${batch.availableSeats}',
                color: batch.isFull ? AppColors.error : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Fill bar ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(fill * 100).toStringAsFixed(0)}% full',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: fillColor),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fill,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(fillColor),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              if (batch.isFull) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded,
                          size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text('Full',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // ── Dates + teacher ────────────────────────────────
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _MetaChip(
                icon: Icons.person_rounded,
                label: batch.teacherName,
              ),
              _MetaChip(
                icon: Icons.calendar_today_rounded,
                label:
                    'From ${_fmt(batch.startDate)}',
              ),
              if (batch.endDate != null)
                _MetaChip(
                  icon: Icons.event_available_rounded,
                  label: 'Until ${_fmt(batch.endDate!)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 2),
            Text(value,
                style:
                    AppTextStyles.headlineSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Search Field
// ─────────────────────────────────────────────────────────────
class BatchSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const BatchSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search…',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.bodySmall,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textHint),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Date Picker Field
// ─────────────────────────────────────────────────────────────
class BatchDatePickerField extends StatelessWidget {
  final String    label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;
  final bool      required;

  const BatchDatePickerField({
    super.key,
    required this.label,
    this.value,
    required this.onPicked,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(
          value == null
              ? required
                  ? 'Select (required)'
                  : 'Optional'
              : '${value!.day}/${value!.month}/${value!.year}',
          style: AppTextStyles.bodyMedium.copyWith(
            color: value == null
                ? AppColors.textHint
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────
class BatchEmptyState extends StatelessWidget {
  final String   title;
  final String?  subtitle;
  final IconData icon;
  final Widget?  action;

  const BatchEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textHint),
            const SizedBox(height: 14),
            Text(title,
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Error View
// ─────────────────────────────────────────────────────────────
class BatchErrorView extends StatelessWidget {
  final String    message;
  final VoidCallback onRetry;

  const BatchErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Something went wrong',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Section Card (used in Create / Edit Batch forms)
// ─────────────────────────────────────────────────────────────
class BatchSectionCard extends StatelessWidget {
  final String       title;
  final List<Widget> children;

  const BatchSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(title,
                style: AppTextStyles.headlineSmall
                    .copyWith(fontSize: 14)),
          ),
          const Divider(height: 20, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Course Picker Dropdown (used in Create / Edit Batch forms)
// ─────────────────────────────────────────────────────────────
class BatchCoursePicker extends StatelessWidget {
  final List<AdminBatchCourseOption> courses;
  final String?                      selectedId;
  final ValueChanged<String?>        onChanged;

  const BatchCoursePicker({
    super.key,
    required this.courses,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Course *',
        hintText: 'Select a course',
        prefixIcon: Icon(Icons.school_rounded),
      ),
      items: courses
          .map((c) => DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(c.title,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(c.teacherName,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ))
          .toList(),
      validator: (v) => v == null ? 'Please select a course' : null,
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Table Card wrapper (consistent with admin pattern)
// ─────────────────────────────────────────────────────────────
class AdminBatchTableCard extends StatelessWidget {
  final String        title;
  final List<Widget>? headerActions;
  final Widget        child;

  const AdminBatchTableCard({
    super.key,
    required this.title,
    this.headerActions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 16, 16, 14),
            child: Row(
              children: [
                Text(title, style: AppTextStyles.headlineSmall),
                const Spacer(),
                if (headerActions != null) ...headerActions!,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // ── Content ─────────────────────────────────────
          child,
        ],
      ),
    );
  }
}
