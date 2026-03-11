// ─────────────────────────────────────────────────────────────
//  question_form_screen.dart
//  Internal shared stateful form used by both
//  AddQuestionScreen and EditQuestionScreen.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/models.dart';
import '../providers/teacher_test_providers.dart';

// ─────────────────────────────────────────────────────────────
//  ADD QUESTION SCREEN
// ─────────────────────────────────────────────────────────────
class AddQuestionScreen extends ConsumerStatefulWidget {
  final String testId;
  final String testTitle;
  final String chapterId;
  final String chapterName;
  final String courseTitle;

  const AddQuestionScreen({
    super.key,
    required this.testId,
    this.testTitle = 'Test',
    this.chapterId = '',
    this.chapterName = 'Chapter',
    this.courseTitle = 'Course',
  });

  @override
  ConsumerState<AddQuestionScreen> createState() =>
      _AddQuestionScreenState();
}

class _AddQuestionScreenState extends ConsumerState<AddQuestionScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionFormProvider);

    ref.listen(questionFormProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
      }
      if (next.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question added!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(questionFormProvider.notifier).reset();
        Navigator.of(context).pop(true);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, 'Add Question'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _QuestionForm(
              isLoading: state.isSubmitting,
              submitLabel: 'Add Question',
              onSubmit: (data) async {
                await ref.read(questionFormProvider.notifier).create(
                      testId: widget.testId,
                      question: data.question,
                      options: data.options,
                      correctOptionIndex: data.correctOptionIndex,
                      marks: data.marks,
                      explanation: data.explanation,
                    );
              },
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String title) =>
      AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            Text(
              '${widget.courseTitle} › ${widget.chapterName} › ${widget.testTitle}',
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  EDIT QUESTION SCREEN
// ─────────────────────────────────────────────────────────────
class EditQuestionScreen extends ConsumerStatefulWidget {
  final QuestionModel question;
  final String testTitle;
  final String chapterName;
  final String courseTitle;

  const EditQuestionScreen({
    super.key,
    required this.question,
    this.testTitle = 'Test',
    this.chapterName = 'Chapter',
    this.courseTitle = 'Course',
  });

  @override
  ConsumerState<EditQuestionScreen> createState() =>
      _EditQuestionScreenState();
}

class _EditQuestionScreenState extends ConsumerState<EditQuestionScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionFormProvider);

    ref.listen(questionFormProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
      }
      if (next.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question updated!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(questionFormProvider.notifier).reset();
        Navigator.of(context).pop(true);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, 'Edit Question'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _QuestionForm(
              initial: widget.question,
              isLoading: state.isSubmitting,
              submitLabel: 'Save Changes',
              onSubmit: (data) async {
                await ref.read(questionFormProvider.notifier).update(
                      questionId: widget.question.id,
                      testId: widget.question.testId,
                      question: data.question,
                      options: data.options,
                      correctOptionIndex: data.correctOptionIndex,
                      marks: data.marks,
                      explanation: data.explanation,
                    );
              },
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String title) =>
      AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            Text(
              '${widget.courseTitle} › ${widget.chapterName} › ${widget.testTitle}',
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  SHARED FORM DATA DTO
// ─────────────────────────────────────────────────────────────
class _QuestionData {
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final int marks;
  final String? explanation;

  const _QuestionData({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.marks,
    this.explanation,
  });
}

// ─────────────────────────────────────────────────────────────
//  SHARED QUESTION FORM WIDGET
// ─────────────────────────────────────────────────────────────
class _QuestionForm extends StatefulWidget {
  final QuestionModel? initial;
  final bool isLoading;
  final String submitLabel;
  final Future<void> Function(_QuestionData data) onSubmit;

  const _QuestionForm({
    this.initial,
    required this.isLoading,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<_QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends State<_QuestionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionCtrl;
  late final List<TextEditingController> _optionCtrls;
  late final TextEditingController _marksCtrl;
  late final TextEditingController _explanationCtrl;
  int _correctIndex = 0;

  static const _optionLabels = ['A', 'B', 'C', 'D'];
  static const _optionColors = [
    Color(0xFF6C63FF),
    Color(0xFFFF6584),
    Color(0xFF43E97B),
    Color(0xFFF59E0B),
  ];

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _questionCtrl =
        TextEditingController(text: q?.question ?? '');
    _optionCtrls = List.generate(
      4,
      (i) => TextEditingController(
          text: (q != null && i < q.options.length) ? q.options[i] : ''),
    );
    _marksCtrl = TextEditingController(
        text: (q?.marks ?? 4).toString());
    _explanationCtrl =
        TextEditingController(text: q?.explanation ?? '');
    _correctIndex = q?.correctOptionIndex ?? 0;
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    _marksCtrl.dispose();
    _explanationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onSubmit(
      _QuestionData(
        question: _questionCtrl.text.trim(),
        options: _optionCtrls.map((c) => c.text.trim()).toList(),
        correctOptionIndex: _correctIndex,
        marks: int.tryParse(_marksCtrl.text.trim()) ?? 4,
        explanation: _explanationCtrl.text.trim().isEmpty
            ? null
            : _explanationCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Question text ──────────────────────────────
          _SectionLabel('QUESTION'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _questionCtrl,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Enter the question text…',
              alignLabelWithHint: true,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty
                    ? 'Question text is required'
                    : null,
          ),

          const SizedBox(height: 24),

          // ── Options ────────────────────────────────────
          _SectionLabel('OPTIONS  •  Tap the circle to mark correct answer'),
          const SizedBox(height: 10),
          ...List.generate(4, (i) => _OptionField(
                label: _optionLabels[i],
                color: _optionColors[i],
                controller: _optionCtrls[i],
                isSelected: _correctIndex == i,
                onSelect: () => setState(() => _correctIndex = i),
              )),

          const SizedBox(height: 24),

          // ── Marks + Explanation ────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Marks
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Marks *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _marksCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '4',
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.warning, width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.star_rounded,
                            size: 18, color: AppColors.warning),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1) return 'Required';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Explanation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Explanation (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _explanationCtrl,
                      maxLines: 3,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Why is this answer correct?',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.info, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Submit ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : _submit,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                widget.isLoading ? 'Saving…' : widget.submitLabel,
                style: AppTextStyles.button,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Option field row
// ─────────────────────────────────────────────────────────────
class _OptionField extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController controller;
  final bool isSelected;
  final VoidCallback onSelect;

  const _OptionField({
    required this.label,
    required this.color,
    required this.controller,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Correct-answer radio button
          GestureDetector(
            onTap: onSelect,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.success
                    : AppColors.surfaceVariant,
                border: Border.all(
                  color: isSelected ? AppColors.success : color,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text input
          Expanded(
            child: TextFormField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Option $label',
                filled: true,
                fillColor: isSelected
                    ? AppColors.success.withAlpha(18)
                    : AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: isSelected
                      ? const BorderSide(
                          color: AppColors.success, width: 1.5)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: isSelected
                      ? const BorderSide(
                          color: AppColors.success, width: 1.5)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? 'Option $label required'
                      : null,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 20),
          ],
        ],
      ),
    );
  }
}

// ── Utility labels ────────────────────────────────────────────
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
