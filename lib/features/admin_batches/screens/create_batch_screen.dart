// ─────────────────────────────────────────────────────────────
//  create_batch_screen.dart
//  Admin: Create a new batch.
//
//  Fields:
//    • Course (required, picker with all courses)
//    • Batch Name (required)
//    • Description (optional)
//    • Start Date (required)
//    • End Date (optional)
//    • Max Students (required, default 50)
//    • Active toggle (default true)
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/admin_batches_providers.dart';
import '../widgets/admin_batches_widgets.dart';

class CreateBatchScreen extends ConsumerStatefulWidget {
  /// Optional pre-selected course ID (e.g., when navigated
  /// from the Course Detail screen's "Add Batch" button).
  final String? preselectedCourseId;

  const CreateBatchScreen({super.key, this.preselectedCourseId});

  @override
  ConsumerState<CreateBatchScreen> createState() =>
      _CreateBatchScreenState();
}

class _CreateBatchScreenState
    extends ConsumerState<CreateBatchScreen> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _maxCtrl;

  String?   _courseId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool      _active = true;

  @override
  void initState() {
    super.initState();
    _courseId  = widget.preselectedCourseId;
    _nameCtrl  = TextEditingController();
    _descCtrl  = TextEditingController();
    _maxCtrl   = TextEditingController(text: '50');
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
    final formState    = ref.watch(adminBatchFormProvider);
    final coursesAsync = ref.watch(adminBatchCourseOptionsProvider);

    // Navigate back when creation succeeds
    ref.listen(adminBatchFormProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Batch created successfully'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
      if (next.error != null && prev?.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${next.error}'),
          backgroundColor: AppColors.error,
        ));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E1A),
        foregroundColor: Colors.white,
        title: const Text('Create New Batch',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Title card ───────────────────────────────
                  BatchSectionCard(
                    title: 'Batch Details',
                    children: [
                      // Course picker
                      coursesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error loading courses: $e',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.error)),
                        data: (courses) => BatchCoursePicker(
                          courses: courses,
                          selectedId: _courseId,
                          onChanged: (v) =>
                              setState(() => _courseId = v),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Batch name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Batch Name *',
                          hintText: 'e.g. Batch A – JEE 2025',
                          prefixIcon: Icon(Icons.layers_rounded),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Batch name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Optional description for this batch',
                          prefixIcon:
                              Icon(Icons.description_outlined),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        minLines: 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Schedule card ────────────────────────────
                  BatchSectionCard(
                    title: 'Schedule',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: BatchDatePickerField(
                              label: 'Start Date *',
                              value: _startDate,
                              required: true,
                              onPicked: (d) =>
                                  setState(() => _startDate = d),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: BatchDatePickerField(
                              label: 'End Date',
                              value: _endDate,
                              onPicked: (d) =>
                                  setState(() => _endDate = d),
                            ),
                          ),
                        ],
                      ),
                      if (_endDate != null &&
                          _startDate != null &&
                          _endDate!.isBefore(_startDate!)) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 14, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Text(
                              'End date should be after start date',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.warning),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Capacity & settings ──────────────────────
                  BatchSectionCard(
                    title: 'Capacity & Settings',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _maxCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Max Students *',
                                hintText: '50',
                                prefixIcon:
                                    Icon(Icons.group_rounded),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1) {
                                  return 'Enter a valid number (≥ 1)';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Active',
                            style: AppTextStyles.labelLarge),
                        subtitle: Text(
                          _active
                              ? 'Batch is visible and open for enrollment'
                              : 'Batch is hidden from students',
                          style: AppTextStyles.bodySmall
                              .copyWith(
                                  color: AppColors.textSecondary),
                        ),
                        value: _active,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) =>
                            setState(() => _active = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Submit ───────────────────────────────────
                  if (formState.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(formState.error!,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.error)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: formState.isSubmitting
                              ? null
                              : () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          onPressed: formState.isSubmitting
                              ? null
                              : _submit,
                          child: formState.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text('Create Batch'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    if (_courseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a course'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a start date'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    if (_endDate != null && _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('End date must be after start date'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    await ref.read(adminBatchFormProvider.notifier).create(
          courseId:    _courseId!,
          batchName:   _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          startDate:   _startDate!,
          endDate:     _endDate,
          maxStudents: int.parse(_maxCtrl.text),
        );
  }
}
