// ─────────────────────────────────────────────────────────────
//  create_test_screen.dart
//  Teacher fills in test metadata, saves it to Supabase,
//  then lands on AddQuestionScreen to populate questions.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../providers/teacher_test_providers.dart';

class CreateTestScreen extends ConsumerStatefulWidget {
  /// Chapter this test belongs to.
  final String chapterId;
  final String? courseId;
  final String chapterName;
  final String courseTitle;

  const CreateTestScreen({
    super.key,
    required this.chapterId,
    this.courseId,
    this.chapterName = 'Chapter',
    this.courseTitle = 'Course',
  });

  @override
  ConsumerState<CreateTestScreen> createState() =>
      _CreateTestScreenState();
}

class _CreateTestScreenState extends ConsumerState<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '30');
  final _negativeCtrl = TextEditingController(text: '0.25');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    _negativeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final test = await ref.read(testFormProvider.notifier).create(
          chapterId: widget.chapterId,
          courseId: widget.courseId,
          title: _titleCtrl.text.trim(),
          durationMinutes: int.tryParse(_durationCtrl.text.trim()) ?? 30,
          negativeMarks:
              double.tryParse(_negativeCtrl.text.trim()) ?? 0.25,
        );
    if (test != null && mounted) {
      // Navigate to AddQuestion for the newly created test.
      context.push(
        AppRoutes.addQuestionPath(test.id),
        extra: {
          'testTitle': test.title,
          'courseTitle': widget.courseTitle,
          'chapterName': widget.chapterName,
          'chapterId': widget.chapterId,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testFormProvider);

    ref.listen(testFormProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Test',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            Text(
              '${widget.courseTitle} › ${widget.chapterName}',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info card ──────────────────────────
                  _HeaderCard(
                    courseTitle: widget.courseTitle,
                    chapterName: widget.chapterName,
                  ),

                  const SizedBox(height: 28),

                  // ── Test Title ─────────────────────────
                  _SectionLabel('TEST DETAILS'),
                  const SizedBox(height: 14),

                  _FieldLabel('Test Title *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyles.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Chapter 1 – Practice Test',
                      prefixIcon: Icon(Icons.quiz_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Title is required'
                            : null,
                  ),

                  const SizedBox(height: 16),

                  // ── Duration + Negative marks (row) ────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Duration (minutes) *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _durationCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: AppTextStyles.bodyMedium,
                              decoration: const InputDecoration(
                                hintText: '30',
                                prefixIcon: Icon(
                                    Icons.timer_outlined,
                                    size: 20,
                                    color: AppColors.secondary),
                              ),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1) {
                                  return 'Enter valid minutes';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Negative Marks'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _negativeCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: AppTextStyles.bodyMedium,
                              decoration: const InputDecoration(
                                hintText: '0.25',
                                prefixIcon: Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 20,
                                    color: AppColors.error),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return null;
                                }
                                if (double.tryParse(v.trim()) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Helper note ────────────────────────
                  _InfoNote(
                    'Total marks will be auto-calculated from '
                    'individual question marks after you add questions.',
                  ),

                  const SizedBox(height: 28),

                  // ── Submit ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: state.isSubmitting ? null : _submit,
                      icon: state.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white))
                          : const Icon(Icons.arrow_forward_rounded,
                              size: 20),
                      label: Text(
                        state.isSubmitting
                            ? 'Creating…'
                            : 'Save & Add Questions',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final String courseTitle;
  final String chapterName;
  const _HeaderCard(
      {required this.courseTitle, required this.chapterName});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6C63FF); // AppColors.primary
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withAlpha(40), shape: BoxShape.circle),
            child: const Icon(Icons.assignment_rounded,
                color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New MCQ Test',
                    style:
                        AppTextStyles.headlineSmall.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(
                  'Create a timed multiple-choice test for $chapterName '
                  'in $courseTitle.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTextStyles.headlineSmall.copyWith(
          color: AppColors.primary, fontSize: 12, letterSpacing: 0.8));
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTextStyles.bodyMedium
          .copyWith(fontWeight: FontWeight.w600, fontSize: 13));
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote(this.text);
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.info),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.info))),
        ],
      );
}
