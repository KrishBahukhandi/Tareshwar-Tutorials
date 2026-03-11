// ─────────────────────────────────────────────────────────────
//  batch_management_screen.dart  –  Admin: Batch Management
//  Uses shared BatchModel from models.dart and BatchService.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/admin_service.dart';
import '../../../../shared/services/batch_service.dart';

// ── Providers ─────────────────────────────────────────────────
final batchesProvider =
    FutureProvider.autoDispose<List<BatchModel>>((ref) =>
        ref.watch(batchServiceProvider).fetchAllBatches());

final _coursesForBatchProvider =
    FutureProvider.autoDispose<List<AdminCourseRow>>((ref) =>
        ref.watch(adminServiceProvider).fetchAllCourses());

// ── Screen ────────────────────────────────────────────────────
class BatchManagementScreen extends ConsumerWidget {
  const BatchManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(batchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(batchesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Batch',
            style: TextStyle(color: Colors.white)),
        onPressed: () => _showBatchDialog(context, ref, null),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load batches',
                  style: AppTextStyles.bodyLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(batchesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (batches) => batches.isEmpty
            ? _EmptyState(
                onAdd: () => _showBatchDialog(context, ref, null))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    16, 12, 16, 80),
                itemCount: batches.length,
                separatorBuilder: (_, i) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) => _BatchCard(
                  batch: batches[i],
                  onEdit: () =>
                      _showBatchDialog(context, ref, batches[i]),
                  onDelete: () =>
                      _confirmDelete(context, ref, batches[i].id),
                  onViewEnrollments: () => context.go(
                      AppRoutes.adminBatchEnrollmentsPath(batches[i].id)),
                ),
              ),
      ),
    );
  }

  // ── Create / Edit dialog ───────────────────────────────────
  void _showBatchDialog(
      BuildContext context, WidgetRef ref, BatchModel? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _BatchDialog(
        existing: existing,
        onSave: (payload) async {
          final svc = ref.read(batchServiceProvider);
          if (existing == null) {
            await svc.createBatch(
              courseId: payload['course_id'] as String,
              batchName: payload['batch_name'] as String,
              description: payload['description'] as String?,
              startDate: payload['start_date'] as DateTime,
              endDate: payload['end_date'] as DateTime?,
              maxStudents: payload['max_students'] as int,
            );
          } else {
            await svc.updateBatch(
              batchId: existing.id,
              batchName: payload['batch_name'] as String?,
              description: payload['description'] as String?,
              startDate: payload['start_date'] as DateTime?,
              endDate: payload['end_date'] as DateTime?,
              maxStudents: payload['max_students'] as int?,
              isActive: payload['is_active'] as bool?,
            );
          }
          ref.invalidate(batchesProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Delete confirmation ────────────────────────────────────
  void _confirmDelete(
      BuildContext context, WidgetRef ref, String batchId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch'),
        content: const Text(
            'This will remove all students from the batch. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () async {
              await ref
                  .read(batchServiceProvider)
                  .deleteBatch(batchId);
              ref.invalidate(batchesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

}

// ── Batch Card ─────────────────────────────────────────────────
class _BatchCard extends StatelessWidget {
  final BatchModel batch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewEnrollments;

  const _BatchCard({
    required this.batch,
    required this.onEdit,
    required this.onDelete,
    required this.onViewEnrollments,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batch.batchName,
                          style: AppTextStyles.headlineSmall),
                      if (batch.courseTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          batch.courseTitle!,
                          style: AppTextStyles.bodySmall
                              .copyWith(
                                  color:
                                      AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(isActive: batch.isActive),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ])),
                    const PopupMenuItem(
                        value: 'enrollments',
                        child: Row(children: [
                          Icon(Icons.people_alt_rounded,
                              size: 16),
                          SizedBox(width: 8),
                          Text('View Students'),
                        ])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(
                                  color: AppColors.error)),
                        ])),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                    if (v == 'enrollments') onViewEnrollments();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info row
            Row(
              children: [
                _InfoChip(
                    icon: Icons.people_rounded,
                    label:
                        '${batch.enrolledCount}/${batch.maxStudents} students',
                    color: AppColors.primary),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: _fmt(batch.startDate),
                    color: AppColors.secondary),
                if (batch.endDate != null) ...[
                  const SizedBox(width: 8),
                  _InfoChip(
                      icon: Icons.event_available_rounded,
                      label: _fmt(batch.endDate!),
                      color: AppColors.info),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Fill bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: batch.fillPercent,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(
                  batch.fillPercent > 0.9
                      ? AppColors.error
                      : batch.fillPercent > 0.7
                          ? AppColors.warning
                          : AppColors.success,
                ),
                minHeight: 6,
              ),
            ),
            if (batch.isFull) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Batch Full',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.error)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined,
              size: 72, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('No batches yet',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Create a batch to start enrolling students',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create First Batch'),
          ),
        ],
      ),
    );
  }
}

// ── Create / Edit batch dialog ─────────────────────────────────
class _BatchDialog extends ConsumerStatefulWidget {
  final BatchModel? existing;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _BatchDialog({this.existing, required this.onSave});

  @override
  ConsumerState<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends ConsumerState<_BatchDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _maxCtrl;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  bool _saving = false;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.batchName ?? '');
    _descCtrl =
        TextEditingController(text: e?.description ?? '');
    _maxCtrl =
        TextEditingController(text: '${e?.maxStudents ?? 50}');
    _selectedCourseId = e?.courseId;
    if (e != null) {
      _startDate = e.startDate;
      _endDate = e.endDate;
      _isActive = e.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final initial =
        isEnd ? (_endDate ?? _startDate) : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2032),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _endDate = picked;
      } else {
        _startDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final coursesAsync = ref.watch(_coursesForBatchProvider);

    return AlertDialog(
      title: Text(isEdit ? 'Edit Batch' : 'Create Batch'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Batch Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Course dropdown
              coursesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (_, e) => const Text(
                    'Could not load courses'),
                data: (courses) =>
                    DropdownButtonFormField<String>(
                  initialValue: _selectedCourseId,
                  decoration:
                      const InputDecoration(labelText: 'Course *'),
                  isExpanded: true,
                  items: courses
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.title,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCourseId = v),
                  validator: (v) =>
                      v == null ? 'Select a course' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxCtrl,
                decoration: const InputDecoration(
                    labelText: 'Max Students'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(
                    '${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                trailing: const Icon(
                    Icons.calendar_today_rounded,
                    size: 18),
                onTap: () => _pickDate(isEnd: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date (optional)'),
                subtitle: Text(_endDate != null
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                    : 'Tap to set'),
                trailing: const Icon(
                    Icons.calendar_today_rounded,
                    size: 18),
                onTap: () => _pickDate(isEnd: true),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) =>
                    setState(() => _isActive = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() => _saving = true);
                  try {
                    await widget.onSave({
                      'batch_name': _nameCtrl.text.trim(),
                      'description':
                          _descCtrl.text.trim().isEmpty
                              ? null
                              : _descCtrl.text.trim(),
                      'course_id': _selectedCourseId!,
                      'max_students':
                          int.tryParse(_maxCtrl.text) ?? 50,
                      'start_date': _startDate,
                      'end_date': _endDate,
                      'is_active': _isActive,
                    });
                  } finally {
                    if (mounted) {
                      setState(() => _saving = false);
                    }
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}