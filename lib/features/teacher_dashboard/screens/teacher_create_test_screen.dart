// ─────────────────────────────────────────────────────────────
//  teacher_create_test_screen.dart  –  Create test shell form
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/teacher_dashboard_providers.dart';

class TeacherCreateTestScreen extends ConsumerStatefulWidget {
  const TeacherCreateTestScreen({super.key});

  @override
  ConsumerState<TeacherCreateTestScreen> createState() =>
      _TeacherCreateTestScreenState();
}

class _TeacherCreateTestScreenState
    extends ConsumerState<TeacherCreateTestScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _durCtrl    = TextEditingController(text: '60');
  final _marksCtrl  = TextEditingController(text: '100');
  String? _selectedCourseId;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(teacherCoursesListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Test', style: AppTextStyles.displaySmall),
            const SizedBox(height: 4),
            Text(
              'Build a new test for any of your courses.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Test Title'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Chapter 3 – Mechanics Test',
                      prefixIcon: Icon(Icons.quiz_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Title is required'
                            : null,
                  ),
                  const SizedBox(height: 20),

                  _Label('Link to Course'),
                  const SizedBox(height: 8),
                  coursesAsync.when(
                    loading: () =>
                        const LinearProgressIndicator(),
                    error: (e, _) => Text('$e',
                        style: AppTextStyles.bodySmall),
                    data: (courses) =>
                        DropdownButtonFormField<String>(
                      initialValue: _selectedCourseId,
                      decoration: const InputDecoration(
                        prefixIcon:
                            Icon(Icons.menu_book_rounded),
                      ),
                      hint: const Text('Select a course'),
                      items: courses
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.title),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCourseId = v),
                      validator: (_) =>
                          _selectedCourseId == null
                              ? 'Please select a course'
                              : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _Label('Duration (minutes)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _durCtrl,
                              keyboardType:
                                  TextInputType.number,
                              decoration: const InputDecoration(
                                prefixIcon:
                                    Icon(Icons.timer_outlined),
                              ),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                return n == null || n < 1
                                    ? 'Enter a valid duration'
                                    : null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _Label('Total Marks'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _marksCtrl,
                              keyboardType:
                                  TextInputType.number,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                    Icons.star_border_rounded),
                              ),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                return n == null || n < 1
                                    ? 'Enter valid marks'
                                    : null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary
                              .withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Question builder is coming soon. '
                            'Save this test shell and add questions '
                            'via the question editor.',
                            style: AppTextStyles.bodySmall
                                .copyWith(
                                    color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Test'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Test "${_titleCtrl.text.trim()}" saved (question editor coming soon).',
        ),
        backgroundColor: AppColors.success,
      ),
    );
    _titleCtrl.clear();
    setState(() => _selectedCourseId = null);
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.labelLarge);
}
