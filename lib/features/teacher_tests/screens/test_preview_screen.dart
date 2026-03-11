// ─────────────────────────────────────────────────────────────
//  test_preview_screen.dart
//  Full read-only preview of a test: metadata banner,
//  publish toggle, all questions with correct answers shown.
//  Teachers can also add / edit / delete questions from here.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
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
    final editState = ref.watch(testEditProvider);

    ref.listen(testEditProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
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
            const Text('Test Preview',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            Text(
              '$courseTitle › $chapterName',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Add question button
          testAsync.when(
            data: (test) => IconButton(
              tooltip: 'Add Question',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => context.push(
                AppRoutes.addQuestionPath(testId),
                extra: {
                  'testTitle': test.title,
                  'courseTitle': courseTitle,
                  'chapterName': chapterName,
                  'chapterId': chapterId,
                },
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
        ],
      ),

      body: testAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.error)),
        ),
        data: (test) => CustomScrollView(
          slivers: [
            // ── Test metadata banner ───────────────────
            SliverToBoxAdapter(
              child: _TestMetaBanner(
                title: test.title,
                durationMinutes: test.durationMinutes,
                totalMarks: test.totalMarks,
                negativeMarks: test.negativeMarks,
                isPublished: test.isPublished,
                isToggling: editState.isSubmitting,
                onTogglePublish: (publish) async {
                  await ref
                      .read(testEditProvider.notifier)
                      .togglePublish(
                        testId,
                        chapterId: chapterId,
                        publish: publish,
                      );
                  // Refresh test detail
                  ref.invalidate(teacherTestDetailProvider(testId));
                },
              ),
            ),

            // ── Questions list ────────────────────────
            questionsAsync.when(
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Text('Error loading questions: $e',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.error)),
                ),
              ),
              data: (questions) {
                if (questions.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyQuestions(
                      onAdd: () => context.push(
                        AppRoutes.addQuestionPath(testId),
                        extra: {
                          'testTitle': test.title,
                          'courseTitle': courseTitle,
                          'chapterName': chapterName,
                          'chapterId': chapterId,
                        },
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    separatorBuilder: (context, index) => const SizedBox.shrink(),
                    itemCount: questions.length,
                    itemBuilder: (context, i) {
                      final question = questions[i];
                      return QuestionCard(
                        question: question,
                        index: i + 1,
                        showAnswer: true,
                        onEdit: () => _openEdit(context, ref, question,
                            testTitle: test.title),
                        onDelete: () => _confirmDelete(
                            context, ref, question.id,
                            questionNum: i + 1),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // ── FAB: add question ────────────────────────────
      floatingActionButton: testAsync.maybeWhen(
        data: (test) => FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => context.push(
            AppRoutes.addQuestionPath(testId),
            extra: {
              'testTitle': test.title,
              'courseTitle': courseTitle,
              'chapterName': chapterName,
              'chapterId': chapterId,
            },
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Question'),
        ),
        orElse: () => null,
      ),
    );
  }

  void _openEdit(BuildContext context, WidgetRef ref, q,
      {required String testTitle}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: EditQuestionScreen(
          question: q,
          testTitle: testTitle,
          chapterName: chapterName,
          courseTitle: courseTitle,
        ),
      ),
    ));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String questionId, {
    required int questionNum,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Question $questionNum?',
            style: AppTextStyles.headlineSmall),
        content: Text(
          'This cannot be undone. The total marks for this test will be recalculated.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(questionFormProvider.notifier).delete(
            questionId: questionId,
            testId: testId,
          );
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Test metadata banner
// ─────────────────────────────────────────────────────────────
class _TestMetaBanner extends StatelessWidget {
  final String title;
  final int durationMinutes;
  final int totalMarks;
  final double negativeMarks;
  final bool isPublished;
  final bool isToggling;
  final ValueChanged<bool> onTogglePublish;

  const _TestMetaBanner({
    required this.title,
    required this.durationMinutes,
    required this.totalMarks,
    required this.negativeMarks,
    required this.isPublished,
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
          // Title + publish toggle
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTextStyles.headlineMedium
                        .copyWith(color: Colors.white)),
              ),
              // Published chip + switch
              _PublishToggle(
                isPublished: isPublished,
                isLoading: isToggling,
                onChanged: onTogglePublish,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Stats row
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
                icon: Icons.remove_circle_outline_rounded,
                label: '-$negativeMarks / wrong',
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublishToggle extends StatelessWidget {
  final bool isPublished;
  final bool isLoading;
  final ValueChanged<bool> onChanged;
  const _PublishToggle(
      {required this.isPublished,
      required this.isLoading,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isPublished ? 'Published' : 'Draft',
          style: TextStyle(
            color: isPublished
                ? AppColors.success
                : Colors.white54,
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
                strokeWidth: 2, color: Colors.white),
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
  const _StatPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            Text(label,
                style: AppTextStyles.labelMedium
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────
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
              child: const Icon(Icons.quiz_outlined,
                  size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No questions yet',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Add MCQ questions to this test.\nStudents will see them in the order you add.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
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
