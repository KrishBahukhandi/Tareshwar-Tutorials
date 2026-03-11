// ─────────────────────────────────────────────────────────────
//  admin_course_detail_screen.dart
//  Full course profile: stats, teacher info, batch list,
//  enrollment counts, and admin actions (edit, delete, toggle).
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../data/admin_courses_service.dart';
import '../providers/admin_courses_providers.dart';
import '../widgets/admin_courses_widgets.dart';

// ─────────────────────────────────────────────────────────────
class AdminCourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const AdminCourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync =
        ref.watch(adminCourseDetailProvider(courseId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: const Text('Course Details',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (detailAsync.value != null) ...[
            // Publish / Unpublish
            TextButton.icon(
              icon: Icon(
                detailAsync.value!.course.isPublished
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
                color: Colors.white70,
              ),
              label: Text(
                detailAsync.value!.course.isPublished
                    ? 'Unpublish'
                    : 'Publish',
                style:
                    const TextStyle(color: Colors.white70),
              ),
              onPressed: () => _togglePublish(
                  context, ref, detailAsync.value!.course),
            ),
            // Edit
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: Colors.white70),
              label: const Text('Edit',
                  style: TextStyle(color: Colors.white70)),
              onPressed: () => context.push(
                AppRoutes.adminEditCoursePath(courseId),
                extra: detailAsync.value!.course,
              ),
            ),
            // Delete
            IconButton(
              tooltip: 'Delete Course',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white70),
              onPressed: () =>
                  _deleteCourse(context, ref, detailAsync.value!.course),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(adminCourseDetailProvider(courseId)),
        ),
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────
  Future<void> _togglePublish(
    BuildContext ctx,
    WidgetRef ref,
    AdminCourseListItem c,
  ) async {
    final action = c.isPublished ? 'Unpublish' : 'Publish';
    final confirmed = await confirmCourseAction(
      ctx,
      title: '$action Course',
      message: c.isPublished
          ? '"${c.title}" will be hidden from students.'
          : 'Make "${c.title}" visible to students?',
      confirmLabel: action,
      confirmColor:
          c.isPublished ? AppColors.warning : AppColors.success,
    );
    if (!confirmed) return;
    await ref
        .read(adminCoursesServiceProvider)
        .togglePublished(c.id, publish: !c.isPublished);
    ref.invalidate(adminCourseDetailProvider(courseId));
    ref.invalidate(adminCourseListProvider);
  }

  Future<void> _deleteCourse(
    BuildContext ctx,
    WidgetRef ref,
    AdminCourseListItem c,
  ) async {
    final confirmed = await confirmCourseAction(
      ctx,
      title: 'Delete Course',
      message:
          'Permanently delete "${c.title}"?\n'
          'All batches, enrollments, and content will be removed. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await ref
        .read(adminCoursesServiceProvider)
        .deleteCourse(c.id);
    ref.invalidate(adminCourseListProvider);
    if (ctx.mounted) ctx.pop();
  }
}

// ─────────────────────────────────────────────────────────────
//  Main detail body
// ─────────────────────────────────────────────────────────────
class _DetailBody extends StatelessWidget {
  final AdminCourseDetail detail;
  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 860;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 340,
                    child: Column(children: [
                      _CourseInfoCard(detail: detail),
                      const SizedBox(height: 16),
                      _StatsRow(detail: detail),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _BatchesSection(
                        batches: detail.batches,
                        courseId: detail.course.id),
                  ),
                ],
              )
            : Column(children: [
                _CourseInfoCard(detail: detail),
                const SizedBox(height: 16),
                _StatsRow(detail: detail),
                const SizedBox(height: 16),
                _BatchesSection(
                    batches: detail.batches,
                    courseId: detail.course.id),
              ]);
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Course info card (left column)
// ─────────────────────────────────────────────────────────────
class _CourseInfoCard extends StatelessWidget {
  final AdminCourseDetail detail;
  const _CourseInfoCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final c = detail.course;
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
          // ── Thumbnail or gradient header ────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
            child: c.thumbnailUrl != null &&
                    c.thumbnailUrl!.isNotEmpty
                ? Image.network(
                    c.thumbnailUrl!,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _gradientHeader(),
                  )
                : _gradientHeader(),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + badges
                Text(c.title,
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    CourseStatusBadge(published: c.isPublished),
                    if (c.categoryTag != null)
                      CategoryBadge(category: c.categoryTag),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                Text(c.description,
                    style: AppTextStyles.bodySmall,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Info rows
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Teacher',
                  value: c.teacherName,
                ),
                _InfoRow(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Price',
                  value: c.price == 0
                      ? 'Free'
                      : '₹${c.price.toStringAsFixed(0)}',
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Created',
                  value: fmtCourseDate(c.createdAt),
                ),
                _InfoRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Course ID',
                  value: c.id,
                  mono: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientHeader() => Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.9),
              AppColors.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.menu_book_rounded,
            color: Colors.white54, size: 56),
      );
}

// ─────────────────────────────────────────────────────────────
//  Stats row
// ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final AdminCourseDetail detail;
  const _StatsRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    final c = detail.course;
    return Row(
      children: [
        Expanded(
          child: CourseStatChip(
            label: 'Batches',
            value: '${c.totalBatches}',
            icon: Icons.groups_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CourseStatChip(
            label: 'Students',
            value: '${c.totalEnrollments}',
            icon: Icons.people_alt_rounded,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CourseStatChip(
            label: 'Lectures',
            value: '${c.totalLectures}',
            icon: Icons.play_lesson_rounded,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Batches section
// ─────────────────────────────────────────────────────────────
class _BatchesSection extends StatelessWidget {
  final List<AdminCourseBatch> batches;
  final String courseId;

  const _BatchesSection(
      {required this.batches, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return CourseSectionCard(
      title: 'Batches (${batches.length})',
      icon: Icons.groups_rounded,
      iconColor: AppColors.primary,
      child: batches.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(28),
              child: AdminCoursesEmptyState(
                message:
                    'No batches yet.\nCreate batches via the Batches panel.',
                icon: Icons.groups_outlined,
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: batches.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 20),
              itemBuilder: (_, i) {
                final b = batches[i];
                return _BatchTile(batch: b);
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Batch list tile
// ─────────────────────────────────────────────────────────────
class _BatchTile extends StatelessWidget {
  final AdminCourseBatch batch;
  const _BatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (batch.isActive ? AppColors.primary : AppColors.textHint)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.group_rounded,
            color: batch.isActive
                ? AppColors.primary
                : AppColors.textHint,
            size: 20),
      ),
      title: Text(batch.batchName, style: AppTextStyles.labelLarge),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${fmtCourseDate(batch.startDate)}'
            '${batch.endDate != null ? ' – ${fmtCourseDate(batch.endDate!)}' : ''}',
            style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 4),
          // Enrollment progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: batch.fillPercent,
                    backgroundColor:
                        AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      batch.isFull
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${batch.enrolledCount}/${batch.maxStudents}',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (batch.isActive
                  ? AppColors.success
                  : AppColors.textHint)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          batch.isActive ? 'Active' : 'Ended',
          style: AppTextStyles.labelSmall.copyWith(
            color: batch.isActive
                ? AppColors.success
                : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Info row
// ─────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace', fontSize: 11)
                  : AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Error body
// ─────────────────────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text('Could not load course',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 6),
          Text(message,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            onPressed: onRetry,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Caption style helper (if not in AppTextStyles)
// ─────────────────────────────────────────────────────────────
