// ─────────────────────────────────────────────────────────────
//  admin_edit_course_screen.dart
//  Admin form to edit course metadata, reassign teacher,
//  update price, thumbnail, category, and publish state.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/admin_courses_service.dart';
import '../providers/admin_courses_providers.dart';
import '../widgets/admin_courses_widgets.dart';

// ─────────────────────────────────────────────────────────────
class AdminEditCourseScreen extends ConsumerStatefulWidget {
  /// The course being edited (passed via router extra).
  final AdminCourseListItem course;

  const AdminEditCourseScreen({super.key, required this.course});

  @override
  ConsumerState<AdminEditCourseScreen> createState() =>
      _AdminEditCourseScreenState();
}

class _AdminEditCourseScreenState
    extends ConsumerState<AdminEditCourseScreen> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _thumbCtrl;

  late String _selectedTeacherId;
  String? _category;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _titleCtrl        = TextEditingController(text: c.title);
    _descCtrl         = TextEditingController(text: c.description);
    _priceCtrl        = TextEditingController(
        text: c.price.toStringAsFixed(0));
    _thumbCtrl        = TextEditingController(
        text: c.thumbnailUrl ?? '');
    _selectedTeacherId = c.teacherId;
    _category         = c.categoryTag;
    _isPublished      = c.isPublished;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(adminCourseFormProvider.notifier).update(
          courseId:     widget.course.id,
          teacherId:    _selectedTeacherId,
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

    ref.listen(adminCourseFormProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course updated successfully!'),
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
        title: Text(
          widget.course.title,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
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
          TextButton(
            onPressed: formState.isSubmitting ? null : _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
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
                    courseId: widget.course.id,
                    isPublished: _isPublished,
                    category: _category,
                  ),
                  const SizedBox(height: 8),

                  // ── Basic info ───────────────────────────
                  const AdminFormSectionHeader(
                      title: 'BASIC INFORMATION'),
                  AdminLabeledTextField(
                    label: 'Course Title *',
                    controller: _titleCtrl,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Title is required'
                        : null,
                  ),
                  AdminLabeledTextField(
                    label: 'Description *',
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
                    data: (teachers) => TeacherPickerDropdown(
                      teachers: teachers,
                      selectedId: _selectedTeacherId,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedTeacherId = v);
                        }
                      },
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
                    label: 'Save Changes',
                    isLoading: formState.isSubmitting,
                    onPressed: _save,
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
//  Page header with course ID chip
// ─────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final String courseId;
  final bool isPublished;
  final String? category;

  const _PageHeader({
    required this.courseId,
    required this.isPublished,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Course',
                    style: AppTextStyles.headlineLarge),
                const SizedBox(height: 4),
                Text(
                  'ID: ${courseId.substring(0, 8)}…',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
          if (category != null) CategoryBadge(category: category),
          const SizedBox(width: 8),
          CourseStatusBadge(published: isPublished),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Publish toggle
// ─────────────────────────────────────────────────────────────
class _PublishToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PublishToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Text('Published',
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  value
                      ? 'Course is visible to students.'
                      : 'Course is in draft mode — hidden from students.',
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
