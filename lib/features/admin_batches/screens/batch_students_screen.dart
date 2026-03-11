// ─────────────────────────────────────────────────────────────
//  batch_students_screen.dart
//  Admin: View and manage all students enrolled in a batch.
//
//  Features:
//    • View enrolled students (name, email, phone, progress)
//    • Search enrolled students
//    • Remove student from batch (with confirmation)
//    • Enroll new student (bottom sheet picker)
//    • Batch header with capacity stats
//    • Pull-to-refresh
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../data/admin_batches_service.dart';
import '../providers/admin_batches_providers.dart';
import '../widgets/admin_batches_widgets.dart';

class BatchStudentsScreen extends ConsumerStatefulWidget {
  final String batchId;
  const BatchStudentsScreen({super.key, required this.batchId});

  @override
  ConsumerState<BatchStudentsScreen> createState() =>
      _BatchStudentsScreenState();
}

class _BatchStudentsScreenState
    extends ConsumerState<BatchStudentsScreen> {
  String _search = '';

  void _refresh() {
    ref.invalidate(adminBatchDetailProvider(widget.batchId));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(adminBatchDetailProvider(widget.batchId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E1A),
        foregroundColor: Colors.white,
        title: detailAsync.when(
          loading: () => const Text('Batch Students',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          error: (e, s) => const Text('Batch Students',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          data: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.batch.batchName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16)),
              Text(d.batch.courseTitle,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Enroll Student',
            onPressed: () => _showEnrollSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          const SizedBox(width: 4),
        ],
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => BatchErrorView(
          message: e.toString(),
          onRetry: _refresh,
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            slivers: [
              // ── Batch info header ────────────────────────────
              SliverToBoxAdapter(
                child: BatchInfoHeader(batch: detail.batch),
              ),

              // ── Summary stats ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: BatchStatCard(
                          icon: Icons.people_rounded,
                          label: 'Enrolled',
                          value: '${detail.batch.enrolledCount}',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BatchStatCard(
                          icon: Icons.event_seat_rounded,
                          label: 'Available',
                          value:
                              '${detail.batch.availableSeats}',
                          color: detail.batch.isFull
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Enroll button (if not full) ──────────────────
              if (!detail.batch.isFull)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 46)),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: Text(
                        'Enroll a Student (${detail.batch.availableSeats} seats left)',
                      ),
                      onPressed: () => _showEnrollSheet(context),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.error
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text('Batch is full – no seats available.',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Search bar ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search students…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    onChanged: (v) =>
                        setState(() => _search = v.toLowerCase()),
                  ),
                ),
              ),

              // ── Student count label ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    '${detail.enrollments.length} student(s) enrolled',
                    style: AppTextStyles.labelMedium,
                  ),
                ),
              ),

              // ── Student list ─────────────────────────────────
              if (detail.enrollments.isEmpty)
                SliverToBoxAdapter(
                  child: BatchEmptyState(
                    title: 'No students enrolled yet',
                    subtitle:
                        'Tap the "Enroll a Student" button to add students.',
                    icon: Icons.people_outline_rounded,
                    action: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.person_add_rounded,
                          size: 16),
                      label: const Text('Enroll First Student'),
                      onPressed: () => _showEnrollSheet(context),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final filtered = _search.isEmpty
                            ? detail.enrollments
                            : detail.enrollments
                                .where((e) =>
                                    e.studentName
                                        .toLowerCase()
                                        .contains(_search) ||
                                    e.studentEmail
                                        .toLowerCase()
                                        .contains(_search))
                                .toList();

                        if (i >= filtered.length) return null;

                        final enrollment = filtered[i];
                        return _EnrolledStudentTile(
                          enrollment: enrollment,
                          onRemove: () =>
                              _confirmRemove(context, enrollment),
                        );
                      },
                      childCount: _search.isEmpty
                          ? detail.enrollments.length
                          : detail.enrollments
                              .where((e) =>
                                  e.studentName
                                      .toLowerCase()
                                      .contains(_search) ||
                                  e.studentEmail
                                      .toLowerCase()
                                      .contains(_search))
                              .length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Enroll sheet ─────────────────────────────────────────────
  void _showEnrollSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _EnrollStudentSheet(
        batchId: widget.batchId,
        onEnrolled: _refresh,
      ),
    );
  }

  // ── Remove confirmation ──────────────────────────────────────
  void _confirmRemove(
      BuildContext context, AdminBatchEnrollment enrollment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
          'Remove ${enrollment.studentName} from this batch?\n'
          'Their progress data will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(adminBatchesServiceProvider)
                    .removeEnrollment(enrollment.id);
                _refresh();
                ref.invalidate(adminBatchListProvider);
                ref.invalidate(adminBatchStatsProvider);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          '${enrollment.studentName} removed'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Enrolled student tile
// ─────────────────────────────────────────────────────────────
class _EnrolledStudentTile extends StatelessWidget {
  final AdminBatchEnrollment enrollment;
  final VoidCallback onRemove;

  const _EnrolledStudentTile({
    required this.enrollment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final initials = enrollment.studentName.isNotEmpty
        ? enrollment.studentName[0].toUpperCase()
        : '?';
    final progress = enrollment.progressPercent / 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ── Avatar ──────────────────────────────────────
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.1),
              child: Text(initials,
                  style: AppTextStyles.headlineSmall
                      .copyWith(color: AppColors.primary)),
            ),
            const SizedBox(width: 12),

            // ── Info ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(enrollment.studentName,
                      style: AppTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(enrollment.studentEmail,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (enrollment.studentPhone != null) ...[
                    const SizedBox(height: 2),
                    Text(enrollment.studentPhone!,
                        style: AppTextStyles.bodySmall
                            .copyWith(
                                color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 6),
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(
                              progress >= 0.8
                                  ? AppColors.success
                                  : AppColors.info,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${enrollment.progressPercent.toStringAsFixed(0)}%',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.info),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Enrolled date + actions ──────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Enrolled',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  '${enrollment.enrolledAt.day}/'
                  '${enrollment.enrolledAt.month}/'
                  '${enrollment.enrolledAt.year}',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: 6),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        Icon(Icons.person_remove_rounded,
                            size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Remove',
                            style: TextStyle(color: AppColors.error)),
                      ]),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'remove') onRemove();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Enroll Student Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _EnrollStudentSheet extends ConsumerStatefulWidget {
  final String       batchId;
  final VoidCallback onEnrolled;

  const _EnrollStudentSheet({
    required this.batchId,
    required this.onEnrolled,
  });

  @override
  ConsumerState<_EnrollStudentSheet> createState() =>
      _EnrollStudentSheetState();
}

class _EnrollStudentSheetState
    extends ConsumerState<_EnrollStudentSheet> {
  String _search = '';
  bool   _enrolling = false;
  String? _enrollingStudentId;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(adminBatchStudentsProvider);
    final detailAsync =
        ref.watch(adminBatchDetailProvider(widget.batchId));

    // Already-enrolled IDs set for quick lookup
    final enrolledIds = detailAsync.whenOrNull(
          data: (d) =>
              d.enrollments.map((e) => e.studentId).toSet(),
        ) ??
        {};

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('Enroll a Student',
                      style: AppTextStyles.headlineSmall),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 18),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
              onChanged: (v) =>
                  setState(() => _search = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),

          // Student list
          Expanded(
            child: studentsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
              data: (students) {
                final filtered = _search.isEmpty
                    ? students
                    : students
                        .where((s) =>
                            s.name.toLowerCase().contains(_search) ||
                            s.email.toLowerCase().contains(_search))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No students found',
                          style: TextStyle(
                              color: AppColors.textSecondary)));
                }

                return ListView.builder(
                  controller: scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final student = filtered[i];
                    final isEnrolled =
                        enrolledIds.contains(student.id);
                    final isEnrollingThis =
                        _enrollingStudentId == student.id;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          student.name.isNotEmpty
                              ? student.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.primary),
                        ),
                      ),
                      title: Text(student.name,
                          style: AppTextStyles.labelLarge),
                      subtitle: Text(student.email,
                          style: AppTextStyles.bodySmall),
                      trailing: isEnrolled
                          ? Chip(
                              label: const Text('Enrolled'),
                              backgroundColor: AppColors.success
                                  .withValues(alpha: 0.1),
                              labelStyle: AppTextStyles.labelSmall
                                  .copyWith(
                                      color: AppColors.success),
                              padding: EdgeInsets.zero,
                            )
                          : isEnrollingThis
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.person_add_rounded,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: 'Enroll',
                                  onPressed: _enrolling
                                      ? null
                                      : () => _enroll(student),
                                ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enroll(UserModel student) async {
    if (_enrolling) return;
    setState(() {
      _enrolling = true;
      _enrollingStudentId = student.id;
    });
    try {
      await ref.read(adminBatchesServiceProvider).enrollStudent(
            studentId: student.id,
            batchId:   widget.batchId,
          );
      ref.invalidate(adminBatchStudentsProvider);
      ref.invalidate(adminBatchListProvider);
      ref.invalidate(adminBatchStatsProvider);
      widget.onEnrolled();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${student.name} enrolled successfully'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _enrolling = false;
          _enrollingStudentId = null;
        });
      }
    }
  }
}
