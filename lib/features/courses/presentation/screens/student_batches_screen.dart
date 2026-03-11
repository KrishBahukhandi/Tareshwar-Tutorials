// ─────────────────────────────────────────────────────────────
//  student_batches_screen.dart
//  Student: view all enrolled batches → navigate to course content
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart';

// ─────────────────────────────────────────────────────────────
class StudentBatchesScreen extends ConsumerWidget {
  const StudentBatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (user) => user == null
          ? const Scaffold(
              body: Center(child: Text('Not logged in')))
          : _BatchesBody(userId: user.id),
    );
  }
}

class _BatchesBody extends ConsumerWidget {
  final String userId;
  const _BatchesBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(studentBatchesProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('My Batches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(studentBatchesProvider(userId)),
          ),
        ],
      ),
      body: batchesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(studentBatchesProvider(userId)),
        ),
        data: (batches) {
          if (batches.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _BatchCard(batch: batches[i]),
          );
        },
      ),
    );
  }
}

// ── Batch Card ─────────────────────────────────────────────────
class _BatchCard extends StatelessWidget {
  final BatchModel batch;
  const _BatchCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final fill = batch.fillPercent;
    final fillColor = fill > 0.9
        ? AppColors.error
        : fill > 0.7
            ? AppColors.warning
            : AppColors.success;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to course detail
          context.go(AppRoutes.courseDetailPath(batch.courseId));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(batch.batchName,
                            style: AppTextStyles.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (batch.courseTitle != null) ...[
                          const SizedBox(height: 2),
                          Text(batch.courseTitle!,
                              style: AppTextStyles.bodySmall
                                  .copyWith(
                                      color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                        if (batch.teacherName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 12,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text(batch.teacherName!,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(
                                          color:
                                              AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatusBadge(isActive: batch.isActive),
                ],
              ),

              const SizedBox(height: 14),

              // ── Date info ───────────────────────────────────
              Row(
                children: [
                  _DateChip(
                    icon: Icons.play_circle_outline_rounded,
                    label:
                        'Starts ${_fmt(batch.startDate)}',
                    color: AppColors.success,
                  ),
                  if (batch.endDate != null) ...[
                    const SizedBox(width: 8),
                    _DateChip(
                      icon: Icons.flag_outlined,
                      label: 'Ends ${_fmt(batch.endDate!)}',
                      color: AppColors.secondary,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // ── Capacity bar ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${batch.enrolledCount} / ${batch.maxStudents} students',
                              style: AppTextStyles.bodySmall
                                  .copyWith(
                                      color: AppColors.textSecondary),
                            ),
                            Text(
                              '${(fill * 100).toStringAsFixed(0)}% full',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: fillColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fill,
                            backgroundColor: AppColors.surfaceVariant,
                            valueColor:
                                AlwaysStoppedAnimation(fillColor),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => context
                        .go(AppRoutes.courseDetailPath(batch.courseId)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('View',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? AppColors.success : AppColors.textHint;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _DateChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Empty State ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined,
                size: 80, color: AppColors.textHint),
            const SizedBox(height: 20),
            Text('No Batches Yet',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 10),
            Text(
              'You haven\'t been enrolled in any batches yet.\n'
              'Contact your institute or ask admin to enroll you.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.search),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Browse Courses'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

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
