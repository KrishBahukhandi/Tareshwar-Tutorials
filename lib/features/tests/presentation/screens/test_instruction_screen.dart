// ─────────────────────────────────────────────────────────────
//  test_instruction_screen.dart  –  Pre-test instructions
//  Shows test details, rules, and a "Start Test" CTA.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart'
    show testDetailProvider, testQuestionsProvider, lastAttemptProvider;
import '../../../../shared/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
class TestInstructionScreen extends ConsumerWidget {
  final String testId;
  const TestInstructionScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(testDetailProvider(testId));
    final questionsAsync = ref.watch(testQuestionsProvider(testId));
    final userId = ref.read(authServiceProvider).currentAuthUser?.id ?? '';

    final lastAttemptAsync = ref.watch(
      lastAttemptProvider((testId: testId, studentId: userId)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Test Instructions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: testAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading test',
          subtitle: e.toString(),
          iconColor: AppColors.error,
        ),
        data: (test) => _buildBody(
          context,
          test: test,
          questionsAsync: questionsAsync,
          lastAttemptAsync: lastAttemptAsync,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required TestModel test,
    required AsyncValue<List<QuestionModel>> questionsAsync,
    required AsyncValue<TestAttemptModel?> lastAttemptAsync,
  }) {
    final qCount = questionsAsync.valueOrNull?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero card ──────────────────────────────────
          AppCard(
            gradient: AppColors.primaryGradient,
            hasBorder: false,
            shadows: AppShadows.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quiz_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(test.title,
                    style: AppTextStyles.headlineLarge
                        .copyWith(color: Colors.white)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _infoChip(Icons.timer_outlined,
                        '${test.durationMinutes} min'),
                    _infoChip(Icons.help_outline_rounded,
                        '$qCount questions'),
                    _infoChip(Icons.star_outline_rounded,
                        '${test.totalMarks} marks'),
                    if (test.negativeMarks > 0)
                      _infoChip(
                          Icons.remove_circle_outline_rounded,
                          '-${test.negativeMarks} / wrong'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Previous attempt ──────────────────────────
          lastAttemptAsync.when(
            data: (attempt) => attempt != null
                ? _PreviousAttemptCard(attempt: attempt, testId: testId)
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // ── Marking scheme ────────────────────────────
          Text('Marking Scheme', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          _MarkingSchemeCard(test: test),
          const SizedBox(height: AppSpacing.lg),

          // ── Instructions ──────────────────────────────
          Text('Instructions', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          _InstructionList(
            instructions: [
              'This test consists of $qCount Multiple Choice Questions (MCQ).',
              'Total duration is ${test.durationMinutes} minutes. The test will auto-submit when time runs out.',
              'Each correct answer awards marks as specified per question.',
              test.negativeMarks > 0
                  ? '${test.negativeMarks} marks will be deducted for every wrong answer.'
                  : 'There is NO negative marking.',
              'Unanswered questions carry zero marks.',
              'You can mark a question for review and revisit it later.',
              'Use the question palette to navigate between questions.',
              'Do not close the app during the test.',
              'Once submitted, the test cannot be retaken.',
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Start CTA ─────────────────────────────────
          PrimaryButton(
            label: 'Start Test',
            icon: Icons.play_arrow_rounded,
            onTap: () =>
                context.go(AppRoutes.testAttemptPath(testId)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: Colors.white70)),
        ],
      );
}

// ── Previous attempt banner ───────────────────────────────────
class _PreviousAttemptCard extends StatelessWidget {
  final TestAttemptModel attempt;
  final String testId;
  const _PreviousAttemptCard(
      {required this.attempt, required this.testId});

  @override
  Widget build(BuildContext context) {
    final pct = attempt.percentage;
    final color = pct >= 60 ? AppColors.success : AppColors.error;

    return AppCard(
      color: color.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.history_rounded, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Previous Attempt',
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 3),
                Text(
                  '${attempt.score}/${attempt.totalMarks}  •  ${pct.toStringAsFixed(1)}%  •  Grade: ${attempt.grade}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GhostButton(
            label: 'View',
            onTap: () => context.push(
                AppRoutes.testResultPath(testId),
                extra: attempt),
          ),
        ],
      ),
    );
  }
}

// ── Marking scheme card ───────────────────────────────────────
class _MarkingSchemeCard extends StatelessWidget {
  final TestModel test;
  const _MarkingSchemeCard({required this.test});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          _SchemeItem(
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            label: 'Correct',
            desc: '+Marks',
          ),
          const SizedBox(width: AppSpacing.sm),
          _SchemeItem(
            icon: Icons.cancel_rounded,
            color: AppColors.error,
            label: 'Wrong',
            desc: test.negativeMarks > 0
                ? '-${test.negativeMarks}'
                : 'No deduction',
          ),
          const SizedBox(width: AppSpacing.sm),
          _SchemeItem(
            icon: Icons.remove_circle_rounded,
            color: AppColors.warning,
            label: 'Skipped',
            desc: '0 marks',
          ),
        ],
      ),
    );
  }
}

class _SchemeItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String desc;
  const _SchemeItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                style:
                    AppTextStyles.labelSmall.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(desc,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

// ── Instruction list ──────────────────────────────────────────
class _InstructionList extends StatelessWidget {
  final List<String> instructions;
  const _InstructionList({required this.instructions});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: instructions.asMap().entries.map((e) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: e.key < instructions.length - 1
                    ? AppSpacing.sm
                    : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${e.key + 1}',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(e.value,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
