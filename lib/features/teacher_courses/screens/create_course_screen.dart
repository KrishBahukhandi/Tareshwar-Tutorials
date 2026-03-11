// ─────────────────────────────────────────────────────────────
//  create_course_screen.dart
//  Full-page form to create a new course.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/teacher_course_providers.dart';
import '../widgets/course_form_fields.dart';

class CreateCourseScreen extends ConsumerStatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  ConsumerState<CreateCourseScreen> createState() =>
      _CreateCourseScreenState();
}

class _CreateCourseScreenState
    extends ConsumerState<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _thumbCtrl = TextEditingController();
  String? _category;

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
    await ref.read(courseFormProvider.notifier).create(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          price: double.tryParse(_priceCtrl.text) ?? 0,
          thumbnailUrl: _thumbCtrl.text.trim().isEmpty
              ? null
              : _thumbCtrl.text.trim(),
          categoryTag: _category,
        );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(courseFormProvider);

    // Navigate back on success
    ref.listen(courseFormProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course created!')),
        );
        Navigator.of(context).pop();
      }
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.error!),
              backgroundColor: AppColors.error),
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
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────
                  _PageHeader(
                    icon: Icons.add_box_rounded,
                    title: 'New Course',
                    subtitle:
                        'Fill in the details below. You can add subjects, chapters and lectures after saving.',
                  ),
                  const SizedBox(height: 8),

                  // ── Basic info ───────────────────────
                  const FormSectionHeader(title: 'BASIC INFORMATION'),

                  LabeledTextField(
                    label: 'Course Title *',
                    hint: 'e.g. Class 12 Physics Full Course',
                    controller: _titleCtrl,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Title is required' : null,
                  ),

                  LabeledTextField(
                    label: 'Description *',
                    hint:
                        'What will students learn? Give a brief overview.',
                    controller: _descCtrl,
                    maxLines: 4,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Description is required'
                        : null,
                  ),

                  // ── Pricing ──────────────────────────
                  const FormSectionHeader(title: 'PRICING'),

                  LabeledTextField(
                    label: 'Price (₹)',
                    hint: '0 for free',
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
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

                  // ── Media & category ─────────────────
                  const FormSectionHeader(title: 'MEDIA & CATEGORY'),

                  LabeledTextField(
                    label: 'Thumbnail URL',
                    hint: 'https://…',
                    controller: _thumbCtrl,
                  ),

                  CategoryDropdown(
                    value: _category,
                    onChanged: (v) => setState(() => _category = v),
                  ),

                  const SizedBox(height: 32),

                  FormSubmitButton(
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
class _PageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PageHeader(
      {required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      );
}
