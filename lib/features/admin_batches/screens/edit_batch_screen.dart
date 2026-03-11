// ─────────────────────────────────────────────────────────────
//  edit_batch_screen.dart
//  Admin: Edit an existing batch.
//
//  Accepts [AdminBatchListItem] via GoRouter's state.extra,
//  or falls back to fetching by batchId.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../data/admin_batches_service.dart';
import '../providers/admin_batches_providers.dart';
import '../widgets/admin_batches_widgets.dart';

class EditBatchScreen extends ConsumerStatefulWidget {
  final String             batchId;
  final AdminBatchListItem? existing;

  const EditBatchScreen({
    super.key,
    required this.batchId,
    this.existing,
  });

  @override
  ConsumerState<EditBatchScreen> createState() =>
      _EditBatchScreenState();
}

class _EditBatchScreenState extends ConsumerState<EditBatchScreen> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _maxCtrl;

  String?   _courseId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool      _active = true;
  bool      _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _maxCtrl  = TextEditingController(text: '50');

    // Pre-populate if existing passed directly
    if (widget.existing != null) {
      _populateFrom(widget.existing!);
    }
  }

  void _populateFrom(AdminBatchListItem b) {
    _nameCtrl.text = b.batchName;
    _descCtrl.text = b.description ?? '';
    _maxCtrl.text  = '${b.maxStudents}';
    _courseId      = b.courseId;
    _startDate     = b.startDate;
    _endDate       = b.endDate;
    _active        = b.isActive;
    _initialized   = true;
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

    // If we don't have the batch object, fetch it
    if (!_initialized && widget.existing == null) {
      final detailAsync =
          ref.watch(adminBatchDetailProvider(widget.batchId));
      detailAsync.whenData((detail) {
        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _populateFrom(detail.batch));
            }
          });
        }
      });
    }

    // Navigate back when update succeeds
    ref.listen(adminBatchFormProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Batch updated successfully'),
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
        title: const Text('Edit Batch',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: !_initialized && widget.existing == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Batch Details ──────────────────────
                        BatchSectionCard(
                          title: 'Batch Details',
                          children: [
                            // Course picker
                            coursesAsync.when(
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (e, _) => Text('Error: $e',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(
                                          color: AppColors.error)),
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
                                prefixIcon:
                                    Icon(Icons.layers_rounded),
                              ),
                              textCapitalization:
                                  TextCapitalization.words,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                            ),
                            const SizedBox(height: 16),

                            // Description
                            TextFormField(
                              controller: _descCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                prefixIcon: Icon(
                                    Icons.description_outlined),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 3,
                              minLines: 2,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Schedule ───────────────────────────
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
                                    onPicked: (d) => setState(
                                        () => _startDate = d),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: BatchDatePickerField(
                                    label: 'End Date',
                                    value: _endDate,
                                    onPicked: (d) => setState(
                                        () => _endDate = d),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Capacity & Settings ────────────────
                        BatchSectionCard(
                          title: 'Capacity & Settings',
                          children: [
                            TextFormField(
                              controller: _maxCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Max Students *',
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
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Active',
                                  style: AppTextStyles.labelLarge),
                              subtitle: Text(
                                _active
                                    ? 'Batch is visible and accepting enrollments'
                                    : 'Batch is hidden from students',
                                style: AppTextStyles.bodySmall
                                    .copyWith(
                                        color:
                                            AppColors.textSecondary),
                              ),
                              value: _active,
                              activeThumbColor: AppColors.primary,
                              onChanged: (v) =>
                                  setState(() => _active = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Error ──────────────────────────────
                        if (formState.error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error
                                  .withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(formState.error!,
                                      style: AppTextStyles.bodySmall
                                          .copyWith(
                                              color: AppColors.error)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Submit ─────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: formState.isSubmitting
                                    ? null
                                    : () => context.pop(),
                                style: OutlinedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 14)),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14),
                                ),
                                onPressed: formState.isSubmitting
                                    ? null
                                    : _submit,
                                child: formState.isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                    : const Text('Save Changes'),
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

    await ref.read(adminBatchFormProvider.notifier).update(
          batchId:     widget.batchId,
          batchName:   _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          courseId:    _courseId,
          startDate:   _startDate,
          endDate:     _endDate,
          maxStudents: int.parse(_maxCtrl.text),
          isActive:    _active,
        );
  }
}
