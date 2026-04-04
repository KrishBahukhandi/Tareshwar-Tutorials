// ─────────────────────────────────────────────────────────────
//  admin_create_course_screen.dart
//  Admin form to create a new course.
//  Fields: class level, name, max students, description,
//          subjects taught, start/end date, pricing, thumbnail,
//          teacher assignment, publish toggle.
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
  final _formKey         = GlobalKey<FormState>();
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _priceCtrl       = TextEditingController(text: '0');
  final _thumbCtrl       = TextEditingController();
  final _maxStudentsCtrl = TextEditingController(text: '50');
  final _subjectCtrl     = TextEditingController(); // chip input

  String?        _selectedTeacherId;
  String?        _classLevel;
  DateTime?      _startDate;
  DateTime?      _endDate;
  List<String>   _subjectsOverview = [];
  bool           _isPublished = false;
  bool           _isActive    = true;

  static const List<String> _classLevels = [
    'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12',
  ];

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

  // ── Add a subject chip ─────────────────────────────────────
  void _addSubject(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !_subjectsOverview.contains(trimmed)) {
      setState(() => _subjectsOverview.add(trimmed));
    }
    _subjectCtrl.clear();
  }

  // ── Date pickers ───────────────────────────────────────────
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

  // ── Submit ─────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a teacher'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    await ref.read(adminCourseFormProvider.notifier).create(
          teacherId:        _selectedTeacherId!,
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
            content: Text('Course created successfully!'),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Create Course',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (formState.isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
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
                  _PageHeader(
                    icon: Icons.add_box_rounded,
                    title: 'New Course',
                    subtitle: 'Fill in the course details below. '
                        'Students will enroll directly into this course.',
                    color: AppColors.primary,
                  ),
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
                    hint: 'e.g. Class 12 Physics Full Course',
                    controller: _titleCtrl,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Course name is required' : null,
                  ),
                  AdminLabeledTextField(
                    label: 'Description *',
                    hint: 'What will students learn? Provide a clear overview.',
                    controller: _descCtrl,
                    maxLines: 4,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Description is required' : null,
                  ),

                  // ── CAPACITY ─────────────────────────────
                  const AdminFormSectionHeader(title: 'CAPACITY'),
                  AdminLabeledTextField(
                    label: 'Max Students *',
                    hint: 'e.g. 50',
                    controller: _maxStudentsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if ((int.tryParse(v) ?? 0) < 1) return 'Must be at least 1';
                      return null;
                    },
                  ),

                  // ── SUBJECTS OVERVIEW ────────────────────
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

                  // ── MEDIA ────────────────────────────────
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
                    data: (teachers) => teachers.isEmpty
                        ? _NoTeacherWarning()
                        : TeacherPickerDropdown(
                            teachers: teachers,
                            selectedId: _selectedTeacherId,
                            onChanged: (v) =>
                                setState(() => _selectedTeacherId = v),
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
//  Class level dropdown
// ─────────────────────────────────────────────────────────────
class _ClassLevelDropdown extends StatelessWidget {
  final String? value;
  final List<String> levels;
  final ValueChanged<String?> onChanged;

  const _ClassLevelDropdown({
    required this.value,
    required this.levels,
    required this.onChanged,
  });

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
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textHint)),
          items: levels
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Subject chip input
// ─────────────────────────────────────────────────────────────
class _SubjectChipInput extends StatelessWidget {
  final List<String> subjects;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const _SubjectChipInput({
    required this.subjects,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

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
          // Existing chips
          if (subjects.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: subjects
                  .map((s) => Chip(
                        label: Text(s, style: AppTextStyles.labelSmall),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => onRemove(s),
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ))
                  .toList(),
            ),
          if (subjects.isNotEmpty) const SizedBox(height: 10),
          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'e.g. Physics, Maths, Chemistry…',
                    hintStyle: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
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
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Press Add or Enter after each subject',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Date range picker
// ─────────────────────────────────────────────────────────────
class _DateRangePicker extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DateRangePicker({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

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
          Expanded(
            child: _DateTile(
              label: 'Start Date',
              value: _fmt(startDate),
              icon: Icons.calendar_today_outlined,
              onTap: onPickStart,
            ),
          ),
          Container(width: 1, height: 60, color: AppColors.border),
          Expanded(
            child: _DateTile(
              label: 'End Date',
              value: _fmt(endDate),
              icon: Icons.event_outlined,
              onTap: onPickEnd,
            ),
          ),
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

  const _DateTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

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
                Text(label,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTextStyles.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Status toggles (published + active)
// ─────────────────────────────────────────────────────────────
class _StatusToggles extends StatelessWidget {
  final bool isPublished;
  final bool isActive;
  final ValueChanged<bool> onPublishedChanged;
  final ValueChanged<bool> onActiveChanged;

  const _StatusToggles({
    required this.isPublished,
    required this.isActive,
    required this.onPublishedChanged,
    required this.onActiveChanged,
  });

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
            title: 'Publish Immediately',
            subtitle: isPublished
                ? 'Visible to students right away.'
                : 'Save as draft — students won\'t see this.',
            value: isPublished,
            onChanged: onPublishedChanged,
            activeColor: AppColors.success,
          ),
          const Divider(height: 1),
          _ToggleTile(
            title: 'Mark as Active',
            subtitle: isActive
                ? 'Course is open for new enrollments.'
                : 'Course is closed — no new enrollments.',
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

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  No-teacher warning
// ─────────────────────────────────────────────────────────────
class _NoTeacherWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No teachers registered yet. Add a teacher account first.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Page header
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
          width: 52, height: 52,
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
