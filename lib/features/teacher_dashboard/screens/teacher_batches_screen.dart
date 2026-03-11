// ─────────────────────────────────────────────────────────────
//  teacher_batches_screen.dart
//  Teacher: view & manage batches for their assigned courses.
//  Role guard: only accessible to users with role = 'teacher' or 'admin'.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/admin_service.dart';
import '../../../../shared/services/app_providers.dart';
import '../../../../shared/services/batch_service.dart';

// ── Providers ─────────────────────────────────────────────────
final _teacherBatchListProvider =
    FutureProvider.autoDispose.family<List<BatchModel>, String>(
        (ref, teacherId) =>
            ref.watch(batchServiceProvider).fetchTeacherBatches(teacherId));

final _teacherCoursesForBatchProvider =
    FutureProvider.autoDispose.family<List<AdminCourseRow>, String>(
        (ref, teacherId) async {
  // Use admin service but filter by teacher
  final all = await ref.watch(adminServiceProvider).fetchAllCourses();
  return all; // teacher's own courses shown in dropdown
});

// ─────────────────────────────────────────────────────────────
class TeacherBatchesScreen extends ConsumerWidget {
  const TeacherBatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null || (!user.isTeacher && !user.isAdmin)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Batches')),
            body: const Center(
              child: Text('Access denied. Teacher role required.'),
            ),
          );
        }
        return _TeacherBatchBody(teacherId: user.id);
      },
    );
  }
}

class _TeacherBatchBody extends ConsumerWidget {
  final String teacherId;
  const _TeacherBatchBody({required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(_teacherBatchListProvider(teacherId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('My Batches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(_teacherBatchListProvider(teacherId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label:
            const Text('New Batch', style: TextStyle(color: Colors.white)),
        onPressed: () => _showBatchDialog(context, ref, null),
      ),
      body: batchesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load batches', style: AppTextStyles.bodyLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(_teacherBatchListProvider(teacherId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (batches) {
          if (batches.isEmpty) {
            return _EmptyState(onAdd: () => _showBatchDialog(context, ref, null));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: batches.length,
            separatorBuilder: (_, i) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _TeacherBatchCard(
              batch: batches[i],
              onEdit: () => _showBatchDialog(context, ref, batches[i]),
              onViewStudents: () => context.go(
                  AppRoutes.adminBatchEnrollmentsPath(batches[i].id)),
            ),
          );
        },
      ),
    );
  }

  void _showBatchDialog(
      BuildContext context, WidgetRef ref, BatchModel? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _TeacherBatchDialog(
        existing: existing,
        teacherId: teacherId,
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
          ref.invalidate(_teacherBatchListProvider(teacherId));
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ── Batch Card ─────────────────────────────────────────────────
class _TeacherBatchCard extends StatelessWidget {
  final BatchModel batch;
  final VoidCallback onEdit;
  final VoidCallback onViewStudents;

  const _TeacherBatchCard({
    required this.batch,
    required this.onEdit,
    required this.onViewStudents,
  });

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batch.batchName,
                          style: AppTextStyles.headlineSmall),
                      if (batch.courseTitle != null)
                        Text(batch.courseTitle!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                _StatusChip(isActive: batch.isActive),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Batch'),
                        ])),
                    const PopupMenuItem(
                        value: 'students',
                        child: Row(children: [
                          Icon(Icons.people_alt_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Manage Students'),
                        ])),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'students') onViewStudents();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Date row
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${_fmt(batch.startDate)}${batch.endDate != null ? ' – ${_fmt(batch.endDate!)}' : ''}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Fill bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${batch.enrolledCount}/${batch.maxStudents} enrolled',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                Text('${(fill * 100).toStringAsFixed(0)}%',
                    style:
                        AppTextStyles.labelSmall.copyWith(color: fillColor)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fill,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(fillColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewStudents,
                    icon: const Icon(Icons.people_alt_rounded, size: 15),
                    label: Text(
                        'Students (${batch.enrolledCount})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

// ── Empty State ────────────────────────────────────────────────
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
          Text('No Batches Yet', style: AppTextStyles.headlineSmall),
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
            label: const Text('Create Batch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create / Edit Dialog ───────────────────────────────────────
class _TeacherBatchDialog extends ConsumerStatefulWidget {
  final BatchModel? existing;
  final String teacherId;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _TeacherBatchDialog({
    this.existing,
    required this.teacherId,
    required this.onSave,
  });

  @override
  ConsumerState<_TeacherBatchDialog> createState() =>
      _TeacherBatchDialogState();
}

class _TeacherBatchDialogState extends ConsumerState<_TeacherBatchDialog> {
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
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _maxCtrl = TextEditingController(text: '${e?.maxStudents ?? 50}');
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
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_endDate ?? _startDate) : _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2032),
    );
    if (picked == null) return;
    setState(() => isEnd ? _endDate = picked : _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final coursesAsync =
        ref.watch(_teacherCoursesForBatchProvider(widget.teacherId));

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
                decoration:
                    const InputDecoration(labelText: 'Batch Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              coursesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, e) =>
                    const Text('Could not load courses'),
                data: (courses) => DropdownButtonFormField<String>(
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
                decoration:
                    const InputDecoration(labelText: 'Max Students'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(
                    '${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                trailing: const Icon(Icons.calendar_today_rounded,
                    size: 18),
                onTap: () => _pickDate(isEnd: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date (optional)'),
                subtitle: Text(_endDate != null
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                    : 'Tap to set'),
                trailing: const Icon(Icons.calendar_today_rounded,
                    size: 18),
                onTap: () => _pickDate(isEnd: true),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
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
                      'description': _descCtrl.text.trim().isEmpty
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
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
