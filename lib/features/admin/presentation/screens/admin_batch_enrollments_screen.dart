// ─────────────────────────────────────────────────────────────
//  admin_batch_enrollments_screen.dart
//  Admin: view & manage students enrolled in a specific batch.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/admin_service.dart';
import '../../../../shared/services/batch_service.dart';

// ── Providers ─────────────────────────────────────────────────
final _batchDetailProvider =
    FutureProvider.autoDispose.family<BatchModel?, String>(
        (ref, batchId) =>
            ref.watch(batchServiceProvider).fetchBatchById(batchId));

final _batchEnrollmentsProvider =
    FutureProvider.autoDispose.family<List<AdminEnrollmentRow>, String>(
        (ref, batchId) =>
            ref.watch(adminServiceProvider).fetchBatchEnrollments(batchId));

final _allStudentsProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) =>
        ref.watch(adminServiceProvider).fetchUsers(role: 'student', limit: 200));

// ── Screen ─────────────────────────────────────────────────────
class AdminBatchEnrollmentsScreen extends ConsumerStatefulWidget {
  final String batchId;
  const AdminBatchEnrollmentsScreen({super.key, required this.batchId});

  @override
  ConsumerState<AdminBatchEnrollmentsScreen> createState() =>
      _AdminBatchEnrollmentsScreenState();
}

class _AdminBatchEnrollmentsScreenState
    extends ConsumerState<AdminBatchEnrollmentsScreen> {
  String _search = '';

  void _refresh() {
    ref.invalidate(_batchDetailProvider(widget.batchId));
    ref.invalidate(_batchEnrollmentsProvider(widget.batchId));
  }

  @override
  Widget build(BuildContext context) {
    final batchAsync = ref.watch(_batchDetailProvider(widget.batchId));
    final enrollAsync = ref.watch(_batchEnrollmentsProvider(widget.batchId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: batchAsync.when(
          loading: () => const Text('Batch Enrollments'),
          error: (_, e) => const Text('Batch Enrollments'),
          data: (batch) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(batch?.batchName ?? 'Batch Enrollments',
                  style: AppTextStyles.labelLarge),
              if (batch?.courseTitle != null)
                Text(batch!.courseTitle!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Enroll Student',
            onPressed: () => _showEnrollDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Batch stats header ───────────────────────────────
          batchAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, e) => const SizedBox.shrink(),
            data: (batch) =>
                batch == null ? const SizedBox.shrink() : _BatchHeader(batch: batch),
          ),

          // ── Search bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search students…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),

          // ── Enrollment list ──────────────────────────────────
          Expanded(
            child: enrollAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(message: e.toString(), onRetry: _refresh),
              data: (enrollments) {
                final filtered = _search.isEmpty
                    ? enrollments
                    : enrollments
                        .where((e) =>
                            e.studentName.toLowerCase().contains(_search) ||
                            e.studentEmail.toLowerCase().contains(_search))
                        .toList();

                if (filtered.isEmpty) {
                  return _EmptyState(
                    hasSearch: _search.isNotEmpty,
                    onEnroll: () => _showEnrollDialog(context),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _EnrollmentTile(
                    enrollment: filtered[i],
                    onRemove: () => _confirmRemove(context, filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Enroll dialog ──────────────────────────────────────────
  void _showEnrollDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _EnrollStudentSheet(
        batchId: widget.batchId,
        onEnrolled: _refresh,
      ),
    );
  }

  // ── Remove confirmation ────────────────────────────────────
  void _confirmRemove(BuildContext context, AdminEnrollmentRow e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
            'Remove ${e.studentName} from this batch?\n'
            'Their progress data will also be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(adminServiceProvider)
                    .removeEnrollment(e.id);
                _refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${e.studentName} removed'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (err) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $err')));
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

// ── Batch Header Card ──────────────────────────────────────────
class _BatchHeader extends StatelessWidget {
  final BatchModel batch;
  const _BatchHeader({required this.batch});

  @override
  Widget build(BuildContext context) {
    final fill = batch.fillPercent;
    final fillColor = fill > 0.9
        ? AppColors.error
        : fill > 0.7
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
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Capacity
              Expanded(
                child: _StatPill(
                  icon: Icons.people_rounded,
                  label: 'Enrolled',
                  value: '${batch.enrolledCount}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.group_add_rounded,
                  label: 'Capacity',
                  value: '${batch.maxStudents}',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.event_seat_rounded,
                  label: 'Available',
                  value: '${(batch.maxStudents - batch.enrolledCount).clamp(0, batch.maxStudents)}',
                  color: batch.isFull ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Started: ${batch.startDate.day}/${batch.startDate.month}/${batch.startDate.year}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              if (batch.endDate != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.event_available_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Ends: ${batch.endDate!.day}/${batch.endDate!.month}/${batch.endDate!.year}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value,
              style: AppTextStyles.headlineSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Enrollment Tile ────────────────────────────────────────────
class _EnrollmentTile extends StatelessWidget {
  final AdminEnrollmentRow enrollment;
  final VoidCallback onRemove;
  const _EnrollmentTile(
      {required this.enrollment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final initials = enrollment.studentName.isNotEmpty
        ? enrollment.studentName[0].toUpperCase()
        : '?';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(initials,
                  style: AppTextStyles.headlineSmall
                      .copyWith(color: AppColors.primary)),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(enrollment.studentName,
                      style: AppTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(enrollment.studentEmail,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    'Enrolled ${enrollment.enrolledAt.day}/${enrollment.enrolledAt.month}/${enrollment.enrolledAt.year}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Progress
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${enrollment.progressPercent.toStringAsFixed(0)}%',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.success),
                ),
                Text('progress',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(width: 4),
            // Actions
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
      ),
    );
  }
}

// ── Enroll Student Bottom Sheet ────────────────────────────────
class _EnrollStudentSheet extends ConsumerStatefulWidget {
  final String batchId;
  final VoidCallback onEnrolled;
  const _EnrollStudentSheet(
      {required this.batchId, required this.onEnrolled});

  @override
  ConsumerState<_EnrollStudentSheet> createState() =>
      _EnrollStudentSheetState();
}

class _EnrollStudentSheetState
    extends ConsumerState<_EnrollStudentSheet> {
  String _search = '';
  bool _enrolling = false;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(_allStudentsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
          Expanded(
            child: studentsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
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
                      child: Text('No students found'));
                }

                return ListView.builder(
                  controller: scrollCtrl,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final student = filtered[i];
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
                          style: AppTextStyles.bodySmall
                              .copyWith(
                                  color: AppColors.textSecondary)),
                      trailing: _enrolling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : IconButton(
                              icon: const Icon(
                                  Icons.person_add_rounded,
                                  color: AppColors.primary),
                              onPressed: () =>
                                  _enroll(student),
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
    setState(() => _enrolling = true);
    try {
      await ref.read(adminServiceProvider).enrollStudent(
            studentId: student.id,
            batchId: widget.batchId,
          );
      widget.onEnrolled();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${student.name} enrolled successfully'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }
}

// ── Empty State ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onEnroll;
  const _EmptyState({required this.hasSearch, required this.onEnroll});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No students match your search' : 'No students enrolled yet',
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 8),
              Text(
                'Add students to this batch',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onEnroll,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Enroll First Student'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error View ─────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

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
