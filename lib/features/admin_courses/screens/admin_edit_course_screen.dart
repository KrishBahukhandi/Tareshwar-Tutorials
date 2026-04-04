// ─────────────────────────────────────────────────────────────
//  admin_edit_course_screen.dart
//  Admin form to edit course — mirrors the create form fields:
//  class level, name, max students, description, subjects,
//  timeline, pricing, thumbnail, teacher, status toggles.
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
  final AdminCourseListItem course;
  const AdminEditCourseScreen({super.key, required this.course});

  @override
  ConsumerState<AdminEditCourseScreen> createState() =>
      _AdminEditCourseScreenState();
}

class _AdminEditCourseScreenState
    extends ConsumerState<AdminEditCourseScreen> {
  final _formKey         = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _thumbCtrl;
  late final TextEditingController _maxStudentsCtrl;
  final _subjectCtrl = TextEditingController();

  late String       _selectedTeacherId;
  String?           _classLevel;
  DateTime?         _startDate;
  DateTime?         _endDate;
  late List<String> _subjectsOverview;
  late bool         _isPublished;
  late bool         _isActive;

  static const List<String> _classLevels = [
    'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _titleCtrl         = TextEditingController(text: c.title);
    _descCtrl          = TextEditingController(text: c.description);
    _priceCtrl         = TextEditingController(text: c.price.toStringAsFixed(0));
    _thumbCtrl         = TextEditingController(text: c.thumbnailUrl ?? '');
    _maxStudentsCtrl   = TextEditingController(text: '${c.maxStudents}');
    _selectedTeacherId = c.teacherId;
    _classLevel        = c.classLevel;
    _startDate         = c.startDate;
    _endDate           = c.endDate;
    _subjectsOverview  = List<String>.from(c.subjectsOverview);
    _isPublished       = c.isPublished;
    _isActive          = c.isActive;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _thumbCtrl.dispose();
    _maxStudentsCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  void _addSubject(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !_subjectsOverview.contains(trimmed)) {
      setState(() => _subjectsOverview.add(trimmed));
    }
    _subjectCtrl.clear();
  }

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _endDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(adminCourseFormProvider.notifier).update(
          courseId:         widget.course.id,
          teacherId:        _selectedTeacherId,
          title:            _titleCtrl.text.trim(),
          description:      _descCtrl.text.trim(),
          price:            double.tryParse(_priceCtrl.text) ?? 0,
          thumbnailUrl:     _thumbCtrl.text.trim().isEmpty ? null : _thumbCtrl.text.trim(),
          classLevel:       _classLevel,
          maxStudents:      int.tryParse(_maxStudentsCtrl.text) ?? 50,
          startDate:        _startDate,
          endDate:          _endDate,
          subjectsOverview: _subjectsOverview,
          isPublished:      _isPublished,
          isActive:         _isActive,
        );
  }

  @override
  Widget build(BuildContext context) {
    final formState     = ref.watch(adminCourseFormProvider);
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
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (formState.isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          TextButton(
            onPressed: formState.isSubmitting ? null : _save,
            child: const Text('Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ───────────────────────────────
                  _EditHeader(course: widget.course),
                  const SizedBox(height: 8),

                  // ── CLASS LEVEL ──────────────────────────
                  const AdminFormSectionHeader(title: 'CLASS'),
                  _ClassLevelDropdown(
                    value: _classLevel,
                    levels: _classLevels,
                    onChanged: (v) => setState(() => _classLevel = v),
                  ),

                  // ── BASIC INFO ───────────────────────────
                  const AdminFormSectionHeader(title: 'COURSE DETAILS'),
                  AdminLabeledTextField(
                    label: 'Course Name *',
                    controller: _titleCtrl,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Course name is required' : null,
                  ),
                  AdminLabeledTextField(
                    label: 'Description *',
                    controller: _descCtrl,
                    maxLines: 4,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Description is required' : null,
                  ),

                  // ── CAPACITY ─────────────────────────────
                  const AdminFormSectionHeader(title: 'CAPACITY'),
                  AdminLabeledTextField(
                    label: 'Max Students *',
                    controller: _maxStudentsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if ((int.tryParse(v) ?? 0) < 1) return 'Must be at least 1';
                      return null;
                    },
                  ),

                  // ── SUBJECTS ─────────────────────────────
                  const AdminFormSectionHeader(title: 'SUBJECTS TAUGHT'),
                  _SubjectChipInput(
                    subjects: _subjectsOverview,
                    controller: _subjectCtrl,
                    onAdd: _addSubject,
                    onRemove: (s) => setState(() => _subjectsOverview.remove(s)),
                  ),

                  // ── TIMELINE ─────────────────────────────
                  const AdminFormSectionHeader(title: 'TIMELINE'),
                  _DateRangePicker(
                    startDate: _startDate,
                    endDate: _endDate,
                    onPickStart: _pickStartDate,
                    onPickEnd: _pickEndDate,
                  ),

                  // ── PRICING ──────────────────────────────
                  const AdminFormSectionHeader(title: 'PRICING'),
                  AdminLabeledTextField(
                    label: 'Price (₹)',
                    hint: '0 for free',
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Enter a valid number';
                      return null;
                    },
                  ),

                  // ── THUMBNAIL ────────────────────────────
                  const AdminFormSectionHeader(title: 'THUMBNAIL'),
                  AdminLabeledTextField(
                    label: 'Thumbnail URL',
                    hint: 'https://…',
                    controller: _thumbCtrl,
                  ),

                  // ── TEACHER ──────────────────────────────
                  const AdminFormSectionHeader(title: 'TEACHER ASSIGNMENT'),
                  teachersAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
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
                        if (v != null) setState(() => _selectedTeacherId = v);
                      },
                    ),
                  ),

                  // ── STATUS ───────────────────────────────
                  const AdminFormSectionHeader(title: 'STATUS'),
                  _StatusToggles(
                    isPublished: _isPublished,
                    isActive: _isActive,
                    onPublishedChanged: (v) => setState(() => _isPublished = v),
                    onActiveChanged: (v) => setState(() => _isActive = v),
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
//  Edit header
// ─────────────────────────────────────────────────────────────
class _EditHeader extends StatelessWidget {
  final AdminCourseListItem course;
  const _EditHeader({required this.course});

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
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Course', style: AppTextStyles.headlineLarge),
                const SizedBox(height: 4),
                Text(
                  'ID: ${course.id.substring(0, 8)}…',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
          if (course.classLevel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(course.classLevel!,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.info)),
            ),
          const SizedBox(width: 8),
          CourseStatusBadge(published: course.isPublished),
        ],
      ),
    );
  }
}

// ── Shared helper widgets (same as create screen) ─────────────

class _ClassLevelDropdown extends StatelessWidget {
  final String? value;
  final List<String> levels;
  final ValueChanged<String?> onChanged;
  const _ClassLevelDropdown({required this.value, required this.levels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text('Select class level',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
          items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SubjectChipInput extends StatelessWidget {
  final List<String> subjects;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  const _SubjectChipInput({required this.subjects, required this.controller, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subjects.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: subjects
                  .map((s) => Chip(
                        label: Text(s, style: AppTextStyles.labelSmall),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => onRemove(s),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      ))
                  .toList(),
            ),
          if (subjects.isNotEmpty) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'e.g. Physics, Maths…',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: onAdd,
                ),
              ),
              TextButton.icon(
                onPressed: () => onAdd(controller.text),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          Text('Press Add or Enter after each subject',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DateRangePicker extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  const _DateRangePicker({required this.startDate, required this.endDate, required this.onPickStart, required this.onPickEnd});

  String _fmt(DateTime? d) => d == null
      ? 'Not set'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _DateTile(label: 'Start Date', value: _fmt(startDate), icon: Icons.calendar_today_outlined, onTap: onPickStart)),
          Container(width: 1, height: 60, color: AppColors.border),
          Expanded(child: _DateTile(label: 'End Date', value: _fmt(endDate), icon: Icons.event_outlined, onTap: onPickEnd)),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTextStyles.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusToggles extends StatelessWidget {
  final bool isPublished;
  final bool isActive;
  final ValueChanged<bool> onPublishedChanged;
  final ValueChanged<bool> onActiveChanged;
  const _StatusToggles({required this.isPublished, required this.isActive, required this.onPublishedChanged, required this.onActiveChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _ToggleTile(
            title: 'Published',
            subtitle: isPublished ? 'Visible to students.' : 'Draft — hidden from students.',
            value: isPublished,
            onChanged: onPublishedChanged,
            activeColor: AppColors.success,
          ),
          const Divider(height: 1),
          _ToggleTile(
            title: 'Active',
            subtitle: isActive ? 'Open for enrollments.' : 'Closed — no new enrollments.',
            value: isActive,
            onChanged: onActiveChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  const _ToggleTile({required this.title, required this.subtitle, required this.value, required this.onChanged, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: activeColor),
        ],
      ),
    );
  }
}
