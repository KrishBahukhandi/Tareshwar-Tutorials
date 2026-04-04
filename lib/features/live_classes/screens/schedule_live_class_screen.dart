// ─────────────────────────────────────────────────────────────
//  schedule_live_class_screen.dart  –  Teacher: create / edit
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/models/models.dart';
import '../../../../features/teacher_courses/providers/teacher_course_providers.dart'
    show myCoursesProvider;
import '../data/live_class_model.dart';
import '../data/live_class_service.dart';

class ScheduleLiveClassScreen extends ConsumerStatefulWidget {
  /// Pass an existing class to edit mode
  final LiveClassModel? existing;

  const ScheduleLiveClassScreen({super.key, this.existing});

  @override
  ConsumerState<ScheduleLiveClassScreen> createState() =>
      _ScheduleLiveClassScreenState();
}

class _ScheduleLiveClassScreenState
    extends ConsumerState<ScheduleLiveClassScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _linkCtrl;
  late final TextEditingController _durationCtrl;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedCourseId;
  bool _saving = false;
  bool _notifSent = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl    = TextEditingController(text: e?.title ?? '');
    _descCtrl     = TextEditingController(text: e?.description ?? '');
    _linkCtrl     = TextEditingController(text: e?.meetingLink ?? '');
    _durationCtrl = TextEditingController(
        text: e != null ? e.durationMinutes.toString() : '60');
    if (e != null) {
      _selectedDate     = e.startTime;
      _selectedTime     = TimeOfDay.fromDateTime(e.startTime);
      _selectedCourseId = e.courseId;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _linkCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  // ── Date + time pickers ───────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  DateTime? get _combinedDateTime {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  // ── Save ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null) {
      _showError('Please select a course');
      return;
    }
    if (_combinedDateTime == null) {
      _showError('Please select date and time');
      return;
    }

    final uid = ref.read(authServiceProvider).currentAuthUser?.id;
    if (uid == null) return;

    setState(() => _saving = true);
    final svc = ref.read(liveClassServiceProvider);

    try {
      if (_isEdit) {
        await svc.updateLiveClass(
          id: widget.existing!.id,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          meetingLink: _linkCtrl.text.trim(),
          startTime: _combinedDateTime,
          durationMinutes: int.tryParse(_durationCtrl.text) ?? 60,
        );
        _showSuccess('Live class updated!');
      } else {
        final created = await svc.scheduleLiveClass(
          courseId: _selectedCourseId!,
          teacherId: uid,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          meetingLink: _linkCtrl.text.trim(),
          startTime: _combinedDateTime!,
          durationMinutes: int.tryParse(_durationCtrl.text) ?? 60,
        );

        if (_notifSent) {
          await svc.sendLiveClassNotification(
            liveClassId: created.id,
            courseId: _selectedCourseId!,
            title: _titleCtrl.text.trim(),
            startTime: _combinedDateTime!,
          );
        }
        _showSuccess('Live class scheduled!');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(myCoursesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Live Class' : 'Schedule Live Class',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                _isEdit ? 'Update' : 'Schedule',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Title ─────────────────────────────────────
            _SectionLabel('Class Title'),
            _Field(
              controller: _titleCtrl,
              hint: 'e.g. "Chapter 5 – Algebra Live Revision"',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              maxLines: 1,
            ),
            const SizedBox(height: 20),

            // ── Description ───────────────────────────────
            _SectionLabel('Description (optional)'),
            _Field(
              controller: _descCtrl,
              hint: 'What will be covered in this session?',
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // ── Course selector ───────────────────────────
            _SectionLabel('Course'),
            coursesAsync.when(
              loading: () => const _LoadingBox(),
              error: (error, _) => const Text('Failed to load courses'),
              data: (courses) => _CourseDropdown(
                courses: courses,
                selectedId: _selectedCourseId,
                onChanged: (id) => setState(() => _selectedCourseId = id),
              ),
            ),
            const SizedBox(height: 20),

            // ── Date & Time ───────────────────────────────
            _SectionLabel('Date & Time'),
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: Icons.calendar_today_rounded,
                    label: _selectedDate == null
                        ? 'Pick Date'
                        : _formatDate(_selectedDate!),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerButton(
                    icon: Icons.access_time_rounded,
                    label: _selectedTime == null
                        ? 'Pick Time'
                        : _selectedTime!.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Duration ──────────────────────────────────
            _SectionLabel('Duration (minutes)'),
            _Field(
              controller: _durationCtrl,
              hint: '60',
              keyboardType: TextInputType.number,
              maxLines: 1,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid duration';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Meeting Link ───────────────────────────────
            _SectionLabel('Meeting Link'),
            _Field(
              controller: _linkCtrl,
              hint: 'https://meet.google.com/xxx-yyyy-zzz',
              keyboardType: TextInputType.url,
              maxLines: 1,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Meeting link is required';
                if (!v.trim().startsWith('http')) return 'Enter a valid URL';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Notify students toggle ─────────────────────
            if (!_isEdit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Notify students immediately',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Send push notification to all enrolled students',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _notifSent,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  thumbColor: WidgetStateProperty.resolveWith<Color?>(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : null,
                  ),
                  onChanged: (v) => setState(() => _notifSent = v),
                ),
              ),
            const SizedBox(height: 32),

            // ── Submit button ──────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: Icon(_isEdit ? Icons.save_rounded : Icons.event_rounded),
                label: Text(
                  _isEdit ? 'Update Class' : 'Schedule Class',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────
//  Helper widgets
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );
}

class _CourseDropdown extends StatelessWidget {
  final List<CourseModel> courses;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _CourseDropdown({
    required this.courses,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedId,
            hint: const Text('Select course',
                style: TextStyle(color: AppColors.textHint)),
            items: courses
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.classLevel != null
                            ? '${c.classLevel} · ${c.title}'
                            : c.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}
