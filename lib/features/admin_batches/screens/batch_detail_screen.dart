// ─────────────────────────────────────────────────────────────
//  batch_detail_screen.dart
//  Admin: Full batch profile with stats, enrolled students,
//  quick-enroll / edit / delete controls.
//
//  Can be used as:
//    • Full-page screen (embedded: false, default)
//    • Inline split-panel widget (embedded: true)
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../data/admin_batches_service.dart';
import '../providers/admin_batches_providers.dart';
import '../widgets/admin_batches_widgets.dart';

class BatchDetailScreen extends ConsumerWidget {
  final String batchId;

  /// When [embedded] is true the screen renders without its own
  /// Scaffold / AppBar (used for the split-panel inline view).
  final bool embedded;

  const BatchDetailScreen({
    super.key,
    required this.batchId,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminBatchDetailProvider(batchId));

    if (embedded) {
      return detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => BatchErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(
              adminBatchDetailProvider(batchId)),
        ),
        data: (detail) =>
            _EmbeddedBody(detail: detail, onRefresh: () {
          ref.invalidate(adminBatchDetailProvider(batchId));
        }),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E1A),
        foregroundColor: Colors.white,
        title: detailAsync.when(
          loading: () => const Text('Batch Detail',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          error: (e, s) => const Text('Batch Detail',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          data: (d) => Text(d.batch.batchName,
              style:
                  const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: detailAsync.whenOrNull(
          data: (detail) => [
            IconButton(
              icon: const Icon(Icons.people_rounded),
              tooltip: 'Manage Students',
              onPressed: () =>
                  context.push(AppRoutes.adminBatchStudentsPath(batchId)),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Batch',
              onPressed: () {
                context.push(
                  AppRoutes.adminEditBatchPath(batchId),
                  extra: detail.batch,
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => BatchErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(
              adminBatchDetailProvider(batchId)),
        ),
        data: (detail) => _DetailBody(
          detail: detail,
          onRefresh: () =>
              ref.invalidate(adminBatchDetailProvider(batchId)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Full-page detail body
// ─────────────────────────────────────────────────────────────
class _DetailBody extends ConsumerWidget {
  final AdminBatchDetail detail;
  final VoidCallback onRefresh;

  const _DetailBody({required this.detail, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = detail.batch;

    return CustomScrollView(
      slivers: [
        // ── Info header ────────────────────────────────────────
        SliverToBoxAdapter(
          child: BatchInfoHeader(batch: batch),
        ),

        // ── Stats cards ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: BatchStatCard(
                    icon: Icons.people_rounded,
                    label: 'Enrolled',
                    value: '${batch.enrolledCount}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BatchStatCard(
                    icon: Icons.event_seat_rounded,
                    label: 'Available',
                    value: '${batch.availableSeats}',
                    color: batch.isFull
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BatchStatCard(
                    icon: Icons.percent_rounded,
                    label: 'Fill Rate',
                    value:
                        '${(batch.fillPercent * 100).toStringAsFixed(0)}%',
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Description ────────────────────────────────────────
        if (batch.description != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _InfoCard(
                title: 'Description',
                child: Text(
                  batch.description!,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],

        // ── Enrolled Students section ──────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text('Enrolled Students',
                    style: AppTextStyles.headlineSmall),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded,
                      size: 14),
                  label: const Text('View All'),
                  onPressed: () => context
                      .push(AppRoutes.adminBatchStudentsPath(batch.id)),
                ),
              ],
            ),
          ),
        ),

        // ── Student list (preview of first 5) ─────────────────
        if (detail.enrollments.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BatchEmptyState(
                title: 'No students enrolled',
                subtitle: 'Add students from the Manage Students page.',
                icon: Icons.people_outline_rounded,
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Enroll Students'),
                  onPressed: () => context
                      .push(AppRoutes.adminBatchStudentsPath(batch.id)),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i >= detail.enrollments.length) {
                    return null;
                  }
                  return _StudentPreviewTile(
                      enrollment: detail.enrollments[i]);
                },
                childCount: detail.enrollments.length > 5
                    ? 5
                    : detail.enrollments.length,
              ),
            ),
          ),

        if (detail.enrollments.length > 5)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextButton(
                onPressed: () => context
                    .push(AppRoutes.adminBatchStudentsPath(batch.id)),
                child: Text(
                  '+ ${detail.enrollments.length - 5} more students',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ),

        // ── Action buttons ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ActionRow(
              batch: batch,
              onEnrollStudents: () => context
                  .push(AppRoutes.adminBatchStudentsPath(batch.id)),
              onEditBatch: () => context.push(
                AppRoutes.adminEditBatchPath(batch.id),
                extra: batch,
              ),
              onToggleActive: () async {
                await ref
                    .read(adminBatchesServiceProvider)
                    .toggleBatchActive(batch.id, !batch.isActive);
                onRefresh();
                ref.invalidate(adminBatchListProvider);
              },
              onDeleteBatch: () =>
                  _confirmDelete(context, ref, batch),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      AdminBatchListItem batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text(
          'Delete "${batch.batchName}"?\n\n'
          'All ${batch.enrolledCount} enrollment(s) will also be removed.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(adminBatchesServiceProvider).deleteBatch(batch.id);
      ref.invalidate(adminBatchListProvider);
      ref.invalidate(adminBatchStatsProvider);
      if (context.mounted) context.pop();
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Embedded split-panel body
// ─────────────────────────────────────────────────────────────
class _EmbeddedBody extends ConsumerWidget {
  final AdminBatchDetail detail;
  final VoidCallback onRefresh;

  const _EmbeddedBody(
      {required this.detail, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = detail.batch;

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
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: const BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batch.batchName,
                          style: AppTextStyles.headlineSmall,
                          overflow: TextOverflow.ellipsis),
                      Text(batch.courseTitle,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
                BatchStatusBadge(isActive: batch.isActive),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded,
                      size: 16),
                  tooltip: 'Full Detail',
                  onPressed: () => context
                      .push(AppRoutes.adminBatchDetailPath(batch.id)),
                ),
              ],
            ),
          ),

          // Stats mini row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _EmbeddedStat(
                    label: 'Enrolled',
                    value: '${batch.enrolledCount}',
                    color: AppColors.primary),
                _EmbeddedStat(
                    label: 'Capacity',
                    value: '${batch.maxStudents}',
                    color: AppColors.secondary),
                _EmbeddedStat(
                    label: 'Available',
                    value: '${batch.availableSeats}',
                    color: batch.isFull
                        ? AppColors.error
                        : AppColors.success),
              ],
            ),
          ),

          // Enroll CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Manage Students'),
                onPressed: () => context
                    .push(AppRoutes.adminBatchStudentsPath(batch.id)),
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text('Students',
                style: AppTextStyles.labelMedium),
          ),

          // Student list
          Expanded(
            child: detail.enrollments.isEmpty
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No students enrolled',
                        style:
                            TextStyle(color: AppColors.textHint)),
                  ))
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: detail.enrollments.length,
                    separatorBuilder: (context, i) => const Divider(
                        height: 1, indent: 52),
                    itemBuilder: (context, i) =>
                        _EmbeddedStudentRow(
                            enrollment: detail.enrollments[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmbeddedStat extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _EmbeddedStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.headlineSmall
                  .copyWith(color: color)),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _EmbeddedStudentRow extends StatelessWidget {
  final AdminBatchEnrollment enrollment;
  const _EmbeddedStudentRow({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final initials = enrollment.studentName.isNotEmpty
        ? enrollment.studentName[0].toUpperCase()
        : '?';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 17,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(initials,
            style: const TextStyle(
                color: AppColors.primary, fontSize: 13)),
      ),
      title: Text(enrollment.studentName,
          style: AppTextStyles.labelLarge,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(enrollment.studentEmail,
          style: AppTextStyles.bodySmall,
          overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${enrollment.progressPercent.toStringAsFixed(0)}%',
        style: AppTextStyles.labelSmall
            .copyWith(color: AppColors.success),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Supporting widgets
// ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String  title;
  final Widget  child;
  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StudentPreviewTile extends StatelessWidget {
  final AdminBatchEnrollment enrollment;
  const _StudentPreviewTile({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final initials = enrollment.studentName.isNotEmpty
        ? enrollment.studentName[0].toUpperCase()
        : '?';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(initials,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.primary)),
        ),
        title: Text(enrollment.studentName,
            style: AppTextStyles.labelLarge),
        subtitle: Text(enrollment.studentEmail,
            style: AppTextStyles.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${enrollment.progressPercent.toStringAsFixed(0)}%',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.success),
            ),
            const SizedBox(width: 4),
            Text(' progress',
                style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final AdminBatchListItem batch;
  final VoidCallback onEnrollStudents;
  final VoidCallback onEditBatch;
  final VoidCallback onToggleActive;
  final VoidCallback onDeleteBatch;

  const _ActionRow({
    required this.batch,
    required this.onEnrollStudents,
    required this.onEditBatch,
    required this.onToggleActive,
    required this.onDeleteBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary),
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Enroll Students'),
          onPressed: onEnrollStudents,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: const Text('Edit Batch'),
          onPressed: onEditBatch,
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor:
                batch.isActive ? AppColors.warning : AppColors.success,
            side: BorderSide(
              color: batch.isActive
                  ? AppColors.warning
                  : AppColors.success,
            ),
          ),
          icon: Icon(
            batch.isActive
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            size: 16,
          ),
          label: Text(batch.isActive ? 'Deactivate' : 'Activate'),
          onPressed: onToggleActive,
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Delete'),
          onPressed: onDeleteBatch,
        ),
      ],
    );
  }
}
