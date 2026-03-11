// ─────────────────────────────────────────────────────────────
//  edit_course_screen.dart
//  Edit course metadata + manage full Subject→Chapter→Lecture tree.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/models.dart';
import '../providers/teacher_course_providers.dart';
import '../widgets/course_form_fields.dart';
import '../widgets/course_outline_editor.dart';

class EditCourseScreen extends ConsumerStatefulWidget {
  final CourseModel course;
  const EditCourseScreen({super.key, required this.course});

  @override
  ConsumerState<EditCourseScreen> createState() =>
      _EditCourseScreenState();
}

class _EditCourseScreenState extends ConsumerState<EditCourseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _thumbCtrl;
  String? _category;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _titleCtrl =
        TextEditingController(text: widget.course.title);
    _descCtrl =
        TextEditingController(text: widget.course.description);
    _priceCtrl = TextEditingController(
        text: widget.course.price.toStringAsFixed(0));
    _thumbCtrl =
        TextEditingController(text: widget.course.thumbnailUrl ?? '');
    _category = widget.course.categoryTag;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(courseFormProvider.notifier).update(
          courseId: widget.course.id,
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

    ref.listen(courseFormProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course updated!')));
      }
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error));
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
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(
                icon: Icon(Icons.info_outline_rounded, size: 18),
                text: 'Details'),
            Tab(
                icon: Icon(Icons.account_tree_rounded, size: 18),
                text: 'Structure'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Tab 1: Details ─────────────────────────
          _DetailsTab(
            formKey: _formKey,
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            priceCtrl: _priceCtrl,
            thumbCtrl: _thumbCtrl,
            category: _category,
            onCategoryChanged: (v) =>
                setState(() => _category = v),
            isSubmitting: formState.isSubmitting,
            onSave: _saveDetails,
          ),

          // ── Tab 2: Structure ───────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StructureHeader(courseId: widget.course.id),
                  const SizedBox(height: 16),
                  CourseOutlineEditor(courseId: widget.course.id),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Details tab body
// ─────────────────────────────────────────────────────────────
class _DetailsTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController thumbCtrl;
  final String? category;
  final ValueChanged<String?> onCategoryChanged;
  final bool isSubmitting;
  final VoidCallback onSave;

  const _DetailsTab({
    required this.formKey,
    required this.titleCtrl,
    required this.descCtrl,
    required this.priceCtrl,
    required this.thumbCtrl,
    required this.category,
    required this.onCategoryChanged,
    required this.isSubmitting,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormSectionHeader(
                      title: 'BASIC INFORMATION'),
                  LabeledTextField(
                    label: 'Course Title *',
                    controller: titleCtrl,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  LabeledTextField(
                    label: 'Description *',
                    controller: descCtrl,
                    maxLines: 4,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const FormSectionHeader(title: 'PRICING'),
                  LabeledTextField(
                    label: 'Price (₹)',
                    controller: priceCtrl,
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
                  const FormSectionHeader(
                      title: 'MEDIA & CATEGORY'),
                  LabeledTextField(
                    label: 'Thumbnail URL',
                    controller: thumbCtrl,
                  ),
                  CategoryDropdown(
                    value: category,
                    onChanged: onCategoryChanged,
                  ),
                  const SizedBox(height: 32),
                  FormSubmitButton(
                    label: 'Save Changes',
                    isLoading: isSubmitting,
                    onPressed: onSave,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Structure tab header with stats
// ─────────────────────────────────────────────────────────────
class _StructureHeader extends ConsumerWidget {
  final String courseId;
  const _StructureHeader({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlineAsync = ref.watch(courseOutlineProvider(courseId));

    return outlineAsync.maybeWhen(
      data: (subjects) {
        int chapters = 0;
        int lectures = 0;
        for (final s in subjects) {
          chapters += s.chapters.length;
          for (final c in s.chapters) {
            lectures += c.lectures.length;
          }
        }
        return Row(
          children: [
            _StatPill(
                label: '${subjects.length} subjects',
                color: AppColors.primary),
            const SizedBox(width: 8),
            _StatPill(
                label: '$chapters chapters',
                color: AppColors.secondary),
            const SizedBox(width: 8),
            _StatPill(
                label: '$lectures lectures',
                color: AppColors.info),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      );
}
