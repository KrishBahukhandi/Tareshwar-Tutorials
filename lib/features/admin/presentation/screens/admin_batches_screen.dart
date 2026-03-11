// ─────────────────────────────────────────────────────────────
//  admin_batches_screen.dart  –  Batch management (new sidebar version)
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/services/admin_service.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_top_bar.dart';
import 'admin_batch_enrollments_screen.dart';

class AdminBatchesScreen extends ConsumerStatefulWidget {
  const AdminBatchesScreen({super.key});

  @override
  ConsumerState<AdminBatchesScreen> createState() =>
      _AdminBatchesScreenState();
}

class _AdminBatchesScreenState
    extends ConsumerState<AdminBatchesScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedBatchId; // for inline enrollment panel

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(adminBatchListProvider);
    final search = ref.watch(adminBatchSearchProvider);
    final isSplit =
        MediaQuery.sizeOf(context).width > 1100 &&
            _selectedBatchId != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isSplit
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _batchTable(
                        context, ref, batchesAsync, search),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: AdminBatchEnrollmentsScreen(
                        batchId: _selectedBatchId!),
                  ),
                ],
              )
            : _batchTable(context, ref, batchesAsync, search),
      ),
    );
  }

  Widget _batchTable(BuildContext context, WidgetRef ref,
      AsyncValue<List<AdminBatchRow>> batchesAsync, String search) {
    return AdminTableCard(
      title: 'Batches',
      headerActions: [
        _SearchField(
          controller: _searchCtrl,
          onChanged: (v) =>
              ref.read(adminBatchSearchProvider.notifier).state = v,
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Batch'),
          onPressed: () =>
              _showBatchDialog(context, ref, null),
        ),
      ],
      child: batchesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Error: $e',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.error)),
        ),
        data: (batches) {
          final filtered = search.isEmpty
              ? batches
              : batches
                  .where((b) =>
                      b.batchName
                          .toLowerCase()
                          .contains(search.toLowerCase()) ||
                      b.courseTitle
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                  .toList();

          if (filtered.isEmpty) {
            return const _EmptyState(message: 'No batches found');
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width - 48,
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    AppColors.surfaceVariant),
                dataRowMinHeight: 56,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Batch Name')),
                  DataColumn(label: Text('Course')),
                  DataColumn(label: Text('Students')),
                  DataColumn(label: Text('Dates')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filtered.asMap().entries.map((e) {
                  final i = e.key;
                  final b = e.value;
                  final isSelected = _selectedBatchId == b.id;
                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary.withValues(alpha: 0.06);
                      }
                      return null;
                    }),
                    cells: [
                      DataCell(Text('${i + 1}',
                          style: AppTextStyles.labelMedium)),
                      DataCell(
                        Text(b.batchName,
                            style: AppTextStyles.labelLarge),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(b.courseTitle,
                              style: AppTextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      DataCell(_FillIndicator(
                          enrolled: b.enrolledCount,
                          max: b.maxStudents)),
                      DataCell(Text(
                        _dateRange(b.startDate, b.endDate),
                        style: AppTextStyles.bodySmall,
                      )),
                      DataCell(_BatchStatusBadge(
                          active: b.isActive)),
                      DataCell(_BatchActions(
                        batch: b,
                        isSelected: isSelected,
                        onViewEnrollments: () => setState(
                            () => _selectedBatchId =
                                isSelected ? null : b.id),
                        onEdit: () =>
                            _showBatchDialog(context, ref, b),
                        onToggle: () async {
                          await ref
                              .read(adminServiceProvider)
                              .updateBatch(
                                  batchId: b.id,
                                  isActive: !b.isActive);
                          ref.invalidate(adminBatchListProvider);
                        },
                        onDelete: () =>
                            _confirmDelete(context, ref, b),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AdminBatchRow batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text(
            'Delete "${batch.batchName}"? All enrollments in this batch will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(adminServiceProvider).deleteBatch(batch.id);
      if (_selectedBatchId == batch.id) {
        setState(() => _selectedBatchId = null);
      }
      ref.invalidate(adminBatchListProvider);
    }
  }

  Future<void> _showBatchDialog(BuildContext context, WidgetRef ref,
      AdminBatchRow? existing) async {
    await showDialog(
      context: context,
      builder: (_) => _BatchDialog(existing: existing),
    );
    ref.invalidate(adminBatchListProvider);
  }
}

// ── Batch create/edit dialog ──────────────────────────────────
class _BatchDialog extends ConsumerStatefulWidget {
  final AdminBatchRow? existing;
  const _BatchDialog({this.existing});

  @override
  ConsumerState<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends ConsumerState<_BatchDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _maxCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _courseId;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.batchName ?? '');
    _descCtrl = TextEditingController();
    _maxCtrl =
        TextEditingController(text: '${e?.maxStudents ?? 50}');
    _startDate = e?.startDate;
    _endDate = e?.endDate;
    _courseId = e?.courseId;
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(adminCoursesProvider);
    final isEdit = widget.existing != null;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit Batch' : 'Create Batch',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 20),
                // Course
                coursesAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (courses) => DropdownButtonFormField<String>(
                    initialValue: _courseId,
                    decoration: const InputDecoration(
                        labelText: 'Course *'),
                    items: courses
                        .map((c) => DropdownMenuItem(
                            value: c.id, child: Text(c.title)))
                        .toList(),
                    validator: (v) =>
                        v == null ? 'Select a course' : null,
                    onChanged: (v) =>
                        setState(() => _courseId = v),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Batch Name *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _DatePicker(
                      label: 'Start Date *',
                      value: _startDate,
                      onPicked: (d) =>
                          setState(() => _startDate = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePicker(
                      label: 'End Date',
                      value: _endDate,
                      onPicked: (d) =>
                          setState(() => _endDate = d),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _maxCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Max Students *'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  activeThumbColor: AppColors.primary,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Text(isEdit ? 'Save' : 'Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a start date')));
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = ref.read(adminServiceProvider);
      if (widget.existing == null) {
        await svc.createBatch(
          courseId: _courseId!,
          batchName: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          startDate: _startDate!,
          endDate: _endDate,
          maxStudents: int.parse(_maxCtrl.text),
        );
      } else {
        await svc.updateBatch(
          batchId: widget.existing!.id,
          batchName: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          maxStudents: int.tryParse(_maxCtrl.text),
          isActive: _active,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Date picker helper ────────────────────────────────────────
class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;

  const _DatePicker(
      {required this.label,
      this.value,
      required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_rounded,
              size: 16),
        ),
        child: Text(
          value == null
              ? 'Select'
              : '${value!.day}/${value!.month}/${value!.year}',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
String _dateRange(DateTime start, DateTime? end) {
  final s = '${start.day}/${start.month}/${start.year}';
  if (end == null) return 'From $s';
  return '$s → ${end.day}/${end.month}/${end.year}';
}

class _FillIndicator extends StatelessWidget {
  final int enrolled;
  final int max;
  const _FillIndicator(
      {required this.enrolled, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? enrolled / max : 0.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$enrolled / $max',
            style: AppTextStyles.labelSmall),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                pct >= 1.0
                    ? AppColors.error
                    : pct >= 0.8
                        ? AppColors.warning
                        : AppColors.success,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BatchStatusBadge extends StatelessWidget {
  final bool active;
  const _BatchStatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: AppTextStyles.labelSmall.copyWith(
            color: active ? AppColors.success : AppColors.error,
            fontSize: 11),
      ),
    );
  }
}

class _BatchActions extends StatelessWidget {
  final AdminBatchRow batch;
  final bool isSelected;
  final VoidCallback onViewEnrollments;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _BatchActions({
    required this.batch,
    required this.isSelected,
    required this.onViewEnrollments,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isSelected
              ? 'Hide Enrollments'
              : 'View Enrollments',
          icon: Icon(
            isSelected
                ? Icons.people_alt_rounded
                : Icons.people_outline_rounded,
            size: 18,
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          onPressed: onViewEnrollments,
        ),
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_rounded,
              size: 18, color: AppColors.info),
          onPressed: onEdit,
        ),
        IconButton(
          tooltip: batch.isActive ? 'Deactivate' : 'Activate',
          icon: Icon(
            batch.isActive
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            size: 18,
            color: batch.isActive
                ? AppColors.warning
                : AppColors.success,
          ),
          onPressed: onToggle,
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded,
              size: 18, color: AppColors.error),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.controller, required this.onChanged});

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
          hintText: 'Search…',
          hintStyle: AppTextStyles.bodySmall,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textHint),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0),
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

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(message,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
