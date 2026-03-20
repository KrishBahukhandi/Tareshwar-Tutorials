// ─────────────────────────────────────────────────────────────
//  test_preview_screen.dart
//  Preview + manage a teacher test, including metadata,
//  publishing, and question editing.
// ─────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/models/models.dart';
import '../providers/teacher_test_providers.dart';
import '../widgets/question_card.dart';
import 'question_form_screen.dart';

class TestPreviewScreen extends ConsumerWidget {
  final String testId;
  final String chapterId;
  final String chapterName;
  final String courseTitle;

  const TestPreviewScreen({
    super.key,
    required this.testId,
    required this.chapterId,
    this.chapterName = 'Chapter',
    this.courseTitle = 'Course',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(teacherTestDetailProvider(testId));
    final questionsAsync = ref.watch(testQuestionsProvider(testId));
    final statsAsync = ref.watch(teacherTestStatsProvider(testId));
    final editState = ref.watch(testEditProvider);

    ref.listen(testEditProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(testEditProvider.notifier).reset();
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
            const Text(
              'Test Preview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$courseTitle › $chapterName',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          testAsync.when(
            data: (test) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Add Question',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: statsAsync.valueOrNull?.hasAttempts == true
                      ? null
                      : () => _openAddQuestion(context, test),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Test actions',
                  icon: const Icon(Icons.more_vert_rounded),
                  enabled: true,
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _openEditTestDialog(context, ref, test);
                    } else if (value == 'delete') {
                      await _confirmDeleteTest(context, ref, test.title);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit test'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Delete test'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: testAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
        ),
        data: (test) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _TestMetaBanner(
                title: test.title,
                durationMinutes: test.durationMinutes,
                totalMarks: test.totalMarks,
                negativeMarks: test.negativeMarks,
                isPublished: test.isPublished,
                questionCount:
                    statsAsync.valueOrNull?.questionCount ??
                    questionsAsync.valueOrNull?.length ??
                    0,
                attemptCount: statsAsync.valueOrNull?.attemptCount ?? 0,
                isLocked: statsAsync.valueOrNull?.hasAttempts ?? false,
                isToggling: editState.isSubmitting,
                onTogglePublish: (publish) async {
                  final hasQuestions =
                      (statsAsync.valueOrNull?.questionCount ??
                          questionsAsync.valueOrNull?.length ??
                          0) >
                      0;
                  if (publish && !hasQuestions) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Add at least one question before publishing this test.',
                        ),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }

                  await ref
                      .read(testEditProvider.notifier)
                      .togglePublish(
                        testId,
                        chapterId: chapterId,
                        publish: publish,
                      );
                  ref.invalidate(teacherTestDetailProvider(testId));
                },
              ),
            ),
            questionsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Error loading questions: $e',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
              data: (questions) {
                if (questions.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyQuestions(
                      onAdd: () => _openAddQuestion(context, test),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    separatorBuilder: (context, index) =>
                        const SizedBox.shrink(),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final question = questions[index];
                      return QuestionCard(
                        question: question,
                        index: index + 1,
                        showAnswer: true,
                        onEdit: statsAsync.valueOrNull?.hasAttempts == true
                            ? null
                            : () => _openEditQuestion(
                                context,
                                question,
                                testTitle: test.title,
                              ),
                        onDelete: statsAsync.valueOrNull?.hasAttempts == true
                            ? null
                            : () => _confirmDeleteQuestion(
                                context,
                                ref,
                                question.id,
                                questionNum: index + 1,
                              ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: testAsync.maybeWhen(
        data: (test) => FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: statsAsync.valueOrNull?.hasAttempts == true
              ? null
              : () => _openAddQuestion(context, test),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Question'),
        ),
        orElse: () => null,
      ),
    );
  }

  void _openAddQuestion(BuildContext context, TestModel test) {
    context.push(
      AppRoutes.addQuestionPath(testId),
      extra: {
        'testTitle': test.title,
        'courseTitle': courseTitle,
        'chapterName': chapterName,
        'chapterId': chapterId,
      },
    );
  }

  void _openEditQuestion(
    BuildContext context,
    QuestionModel question, {
    required String testTitle,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UncontrolledProviderScope(
          container: ProviderScope.containerOf(context),
          child: EditQuestionScreen(
            question: question,
            testTitle: testTitle,
            chapterName: chapterName,
            courseTitle: courseTitle,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteQuestion(
    BuildContext context,
    WidgetRef ref,
    String questionId, {
    required int questionNum,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Question $questionNum?',
          style: AppTextStyles.headlineSmall,
        ),
        content: Text(
          'This cannot be undone. The total marks for this test will be recalculated.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(questionFormProvider.notifier)
          .delete(questionId: questionId, testId: testId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question deleted. Total marks updated.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _openEditTestDialog(
    BuildContext context,
    WidgetRef ref,
    TestModel test,
  ) async {
    final stats = await ref.read(teacherTestStatsProvider(testId).future);
    if (!context.mounted) return;
    if (stats.hasAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This test already has student attempts, so its structure is locked.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController(text: test.title);
    final durationCtrl = TextEditingController(
      text: test.durationMinutes.toString(),
    );
    final negativeCtrl = TextEditingController(
      text: test.negativeMarks.toString(),
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Edit Test', style: AppTextStyles.headlineSmall),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Test title',
                    prefixIcon: Icon(Icons.quiz_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  validator: (value) {
                    final minutes = int.tryParse(value ?? '');
                    if (minutes == null || minutes < 1) {
                      return 'Enter valid minutes';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: negativeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Negative marks',
                    prefixIcon: Icon(Icons.remove_circle_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final negative = double.tryParse(value.trim());
                    if (negative == null || negative < 0) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Total marks stay in sync with question marks automatically.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await ref
                  .read(testEditProvider.notifier)
                  .update(
                    testId: testId,
                    chapterId: chapterId,
                    title: titleCtrl.text.trim(),
                    durationMinutes:
                        int.tryParse(durationCtrl.text.trim()) ?? 30,
                    totalMarks: test.totalMarks,
                    negativeMarks:
                        double.tryParse(negativeCtrl.text.trim()) ?? 0.25,
                  );
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );

    titleCtrl.dispose();
    durationCtrl.dispose();
    negativeCtrl.dispose();

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test details updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmDeleteTest(
    BuildContext context,
    WidgetRef ref,
    String testTitle,
  ) async {
    final stats = await ref.read(teacherTestStatsProvider(testId).future);
    if (!context.mounted) return;
    if (stats.hasAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This test has ${stats.attemptCount} student attempt(s), so deletion is blocked.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete test?', style: AppTextStyles.headlineSmall),
        content: Text(
          'Delete "$testTitle" and all of its questions? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(testEditProvider.notifier)
          .delete(testId, chapterId: chapterId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test deleted.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).maybePop();
      }
    }
  }
}

class _TestMetaBanner extends StatelessWidget {
  final String title;
  final int durationMinutes;
  final int totalMarks;
  final double negativeMarks;
  final bool isPublished;
  final int questionCount;
  final int attemptCount;
  final bool isLocked;
  final bool isToggling;
  final ValueChanged<bool> onTogglePublish;

  const _TestMetaBanner({
    required this.title,
    required this.durationMinutes,
    required this.totalMarks,
    required this.negativeMarks,
    required this.isPublished,
    required this.questionCount,
    required this.attemptCount,
    required this.isLocked,
    required this.isToggling,
    required this.onTogglePublish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1B2E), Color(0xFF2D2B4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              _PublishToggle(
                isPublished: isPublished,
                isLoading: isToggling,
                onChanged: onTogglePublish,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _StatPill(
                icon: Icons.timer_outlined,
                label: '$durationMinutes min',
                color: AppColors.info,
              ),
              _StatPill(
                icon: Icons.star_rounded,
                label: '$totalMarks marks',
                color: AppColors.warning,
              ),
              _StatPill(
                icon: Icons.format_list_numbered_rounded,
                label: '$questionCount questions',
                color: AppColors.primary,
              ),
              _StatPill(
                icon: Icons.people_alt_outlined,
                label: '$attemptCount attempts',
                color: AppColors.info,
              ),
              _StatPill(
                icon: Icons.remove_circle_outline_rounded,
                label: '-$negativeMarks / wrong',
                color: AppColors.error,
              ),
            ],
          ),
          if (isLocked) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withAlpha(90)),
              ),
              child: Text(
                'This test already has student attempts. Editing questions or deleting the test is locked to protect result integrity. You can still unpublish it for future students.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublishToggle extends StatelessWidget {
  final bool isPublished;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const _PublishToggle({
    required this.isPublished,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isPublished ? 'Published' : 'Draft',
          style: TextStyle(
            color: isPublished ? AppColors.success : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else
          Switch.adaptive(
            value: isPublished,
            onChanged: onChanged,
            activeThumbColor: AppColors.success,
            activeTrackColor: AppColors.success.withAlpha(160),
          ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(35),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _EmptyQuestions extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyQuestions({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.quiz_outlined,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text('No questions yet', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Add MCQ questions to this test.\nStudents will see them in the order you add.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Question'),
            ),
          ],
        ),
      ),
    );
  }
}
