// ─────────────────────────────────────────────────────────────
//  admin_create_course_screen.dart
//  Admin form to create a new course and assign a teacher.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/admin_courses_providers.dart';
import '../widgets/admin_courses_widgets.dart';

// ─────────────────────────────────────────────────────────────
class AdminCreateCourseScreen extends ConsumerStatefulWidget {
  const AdminCreateCourseScreen({super.key});

  @override
  ConsumerState<AdminCreateCourseScreen> createState() =>
      _AdminCreateCourseScreenState();
}

class _AdminCreateCourseScreenState
    extends ConsumerState<AdminCreateCourseScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _priceCtrl   = TextEditingController(text: '0');
  final _thumbCtrl   = TextEditingController();

  String? _selectedTeacherId;
  String? _category;
  bool    _isPublished = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(adminCourseFormProvider.notifier).create(
          teacherId:    _selectedTeacherId!,
          title:        _titleCtrl.text.trim(),
          description:  _descCtrl.text.trim(),
          price:        double.tryParse(_priceCtrl.text) ?? 0,
          thumbnailUrl: _thumbCtrl.text.trim().isEmpty
              ? null
              : _thumbCtrl.text.trim(),
          categoryTag:  _category,
          isPublished:  _isPublished,
        );
  }

  @override
  Widget build(BuildContext context) {
    final formState    = ref.watch(adminCourseFormProvider);
    final teachersAsync = ref.watch(adminTeacherOptionsProvider);

    // React to success / error
    ref.listen(adminCourseFormProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: const Text('Create Course',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (formState.isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Page header ──────────────────────────
                  _PageHeader(
                    icon: Icons.add_box_rounded,
                    title: 'New Course',
                    subtitle:
                        'Fill in the course details. Assign a teacher, set the price, and optionally publish immediately.',
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),

                  // ── Basic info ───────────────────────────
                  const AdminFormSectionHeader(
                      title: 'BASIC INFORMATION'),
                  AdminLabeledTextField(
                    label: 'Course Title *',
                    hint: 'e.g. Class 12 Physics Full Course',
                    controller: _titleCtrl,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Title is required'
                        : null,
                  ),
                  AdminLabeledTextField(
                    label: 'Description *',
                    hint:
                        'What will students learn? Provide a clear overview.',
                    controller: _descCtrl,
                    maxLines: 4,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Description is required'
                        : null,
                  ),

                  // ── Teacher assignment ───────────────────
                  const AdminFormSectionHeader(
                      title: 'TEACHER ASSIGNMENT'),
                  teachersAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                          child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Could not load teachers: $e',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.error)),
                    ),
                    data: (teachers) => teachers.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.warning
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: AppColors.warning,
                                      size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'No teachers registered yet. '
                                      'Add a teacher account first.',
                                      style:
                                          AppTextStyles.bodySmall
                                              .copyWith(
                                                  color: AppColors
                                                      .warning),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : TeacherPickerDropdown(
                            teachers: teachers,
                            selectedId: _selectedTeacherId,
                            onChanged: (v) => setState(
                                () => _selectedTeacherId = v),
                          ),
                  ),

                  // ── Pricing ──────────────────────────────
                  const AdminFormSectionHeader(title: 'PRICING'),
                  AdminLabeledTextField(
                    label: 'Price (₹)',
                    hint: '0 for free',
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),

                  // ── Media & category ─────────────────────
                  const AdminFormSectionHeader(
                      title: 'MEDIA & CATEGORY'),
                  AdminLabeledTextField(
                    label: 'Thumbnail URL',
                    hint: 'https://…',
                    controller: _thumbCtrl,
                  ),
                  AdminCategoryDropdown(
                    value: _category,
                    onChanged: (v) =>
                        setState(() => _category = v),
                  ),

                  // ── Publish toggle ───────────────────────
                  const AdminFormSectionHeader(
                      title: 'PUBLISH SETTINGS'),
                  _PublishToggle(
                    value: _isPublished,
                    onChanged: (v) =>
                        setState(() => _isPublished = v),
                  ),

                  const SizedBox(height: 32),
                  AdminFormSubmitButton(
                    label: 'Create Course',
                    isLoading: formState.isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Publish toggle widget
// ─────────────────────────────────────────────────────────────
class _PublishToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PublishToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Publish Immediately',
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  value
                      ? 'Course will be visible to students right away.'
                      : 'Save as draft — students won\'t see this course.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Page header widget
// ─────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _PageHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headlineLarge),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
