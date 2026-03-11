// ─────────────────────────────────────────────────────────────
//  test_attempt_screen.dart  –  Live MCQ test attempt
//  Features:
//    • Countdown timer (turns red at < 5 min)
//    • Per-question: select answer, clear, mark for review
//    • Question palette with colour-coded status
//    • Auto-submit on timer expiry
//    • Confirm-exit dialog
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/theme_barrel.dart';
import '../../../../core/utils/app_router.dart';
import '../providers/test_providers.dart';

// ─────────────────────────────────────────────────────────────
class TestAttemptScreen extends ConsumerStatefulWidget {
  final String testId;
  const TestAttemptScreen({super.key, required this.testId});

  @override
  ConsumerState<TestAttemptScreen> createState() =>
      _TestAttemptScreenState();
}

class _TestAttemptScreenState extends ConsumerState<TestAttemptScreen> {
  bool _autoSubmitTriggered = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testSessionProvider(widget.testId));
    final notifier =
        ref.read(testSessionProvider(widget.testId).notifier);

    // Auto-navigate when time is up
    if (state.isSubmitted && !_autoSubmitTriggered) {
      _autoSubmitTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          notifier.submit(context);
        }
      });
    }

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Loading test…',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (state.error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load test',
          subtitle: state.error!,
          iconColor: AppColors.error,
        ),
      );
    }
    if (state.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test')),
        backgroundColor: AppColors.background,
        body: const AppEmptyState(
          icon: Icons.quiz_outlined,
          title: 'No questions available',
          subtitle: 'This test has no questions yet.',
        ),
      );
    }

    final q = state.questions[state.currentIndex];
    final mins = state.remainingSeconds ~/ 60;
    final secs = state.remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isWarning = state.remainingSeconds < 300;
    final selectedOption = state.answers[q.id];
    final isMarked = state.markedForReview.contains(q.id);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(context, notifier, state);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(
          state: state,
          timeStr: timeStr,
          isWarning: isWarning,
          notifier: notifier,
        ),
        body: Column(
          children: [
            // ── Segmented progress ─────────────────────
            _SegmentedProgress(
              total: state.totalQuestions,
              current: state.currentIndex,
              answers: state.answers,
              questions: state.questions,
            ),

            // ── Question body ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Question header ────────────────
                    Row(
                      children: [
                        _QuestionBadge(
                          index: state.currentIndex,
                          total: state.totalQuestions,
                        ),
                        const Spacer(),
                        AppBadge(
                          label: '${q.marks} mark${q.marks != 1 ? 's' : ''}',
                          color: AppColors.info,
                          icon: Icons.stars_rounded,
                        ),
                        const SizedBox(width: 10),
                        _ReviewToggle(
                          isMarked: isMarked,
                          onTap: () =>
                              notifier.toggleMarkForReview(q.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Question image ─────────────────
                    if (q.questionImageUrl != null) ...[
                      AppCard(
                        padding: EdgeInsets.zero,
                        hasBorder: false,
                        shadows: AppShadows.sm,
                        child: ClipRRect(
                          borderRadius: AppRadius.mdAll,
                          child: Image.network(
                            q.questionImageUrl!,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── Question text ──────────────────
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(q.question,
                          style: AppTextStyles.bodyLarge
                              .copyWith(height: 1.65)),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Options ────────────────────────
                    ...List.generate(q.options.length, (i) {
                      final isSelected = selectedOption == i;
                      return _OptionTile(
                        label: String.fromCharCode(65 + i),
                        text: q.options[i],
                        isSelected: isSelected,
                        onTap: () => notifier.selectAnswer(q.id, i),
                      );
                    }),

                    // ── Clear answer ───────────────────
                    if (selectedOption != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.clear_rounded,
                              size: 15, color: AppColors.error),
                          label: Text('Clear Answer',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.error)),
                          onPressed: () => notifier.clearAnswer(q.id),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Navigation footer ──────────────────────
            _buildFooter(context, state, notifier),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar({
    required TestSessionState state,
    required String timeStr,
    required bool isWarning,
    required TestSessionNotifier notifier,
  }) =>
      AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          state.test?.title ?? 'Test',
          style: AppTextStyles.headlineSmall,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // ── Timer chip ──────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: isWarning
                  ? AppColors.error
                  : AppColors.primary,
              borderRadius: AppRadius.circle,
              boxShadow: [
                BoxShadow(
                  color: (isWarning ? AppColors.error : AppColors.primary)
                      .withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_rounded,
                    size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(timeStr,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () =>
              _confirmExit(context, notifier, state),
        ),
      );

  // ── Footer row ────────────────────────────────────────────
  Widget _buildFooter(
    BuildContext context,
    TestSessionState state,
    TestSessionNotifier notifier,
  ) {
    final isLast =
        state.currentIndex == state.questions.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
            top: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Prev ──────────────────────────────────────
          AnimatedOpacity(
            opacity: state.currentIndex > 0 ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 200),
            child: OutlinedButton.icon(
              onPressed: state.currentIndex > 0 ? notifier.goPrev : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Prev'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll),
              ),
            ),
          ),

          const Spacer(),

          // ── Palette ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.smAll,
            ),
            child: IconButton(
              icon: const Icon(Icons.grid_view_rounded,
                  color: AppColors.textSecondary, size: 20),
              tooltip: 'Question palette',
              onPressed: () =>
                  _showPalette(context, state, notifier),
            ),
          ),

          const Spacer(),

          // ── Next / Submit ──────────────────────────────
          isLast
              ? PrimaryButton(
                  label: 'Submit Test',
                  icon: Icons.check_circle_rounded,
                  fullWidth: false,
                  onTap: () =>
                      _confirmSubmit(context, notifier, state),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                )
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.mdAll),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  onPressed: notifier.goNext,
                  label: const Text('Next'),
                ),
        ],
      ),
    );
  }

  // ── Question palette sheet ────────────────────────────────
  void _showPalette(
    BuildContext context,
    TestSessionState state,
    TestSessionNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaletteSheet(
        state: state,
        onTap: (i) {
          notifier.goToQuestion(i);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Confirm submit ────────────────────────────────────────
  void _confirmSubmit(
    BuildContext context,
    TestSessionNotifier notifier,
    TestSessionState state,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: const Icon(Icons.fact_check_rounded,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Submit Test?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow('Answered', '${state.answeredCount}',
                AppColors.success),
            _statRow(
                'Unanswered',
                '${state.totalQuestions - state.answeredCount}',
                AppColors.error),
            _statRow('Marked for Review',
                '${state.reviewCount}', AppColors.warning),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Test'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smAll),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              notifier.submit(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: AppRadius.xsAll),
            ),
            const SizedBox(width: 10),
            Text(label, style: AppTextStyles.bodySmall),
            const Spacer(),
            Text(value,
                style: AppTextStyles.labelLarge.copyWith(color: color)),
          ],
        ),
      );

  // ── Confirm exit ──────────────────────────────────────────
  void _confirmExit(
    BuildContext context,
    TestSessionNotifier notifier,
    TestSessionState state,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: const Icon(Icons.exit_to_app_rounded,
                  color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Quit Test?'),
          ],
        ),
        content: const Text(
          'Your progress will be lost and the test will not be submitted.',
          style: TextStyle(height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Test'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smAll),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              context.go(AppRoutes.homeTab);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Segmented progress indicator
// ─────────────────────────────────────────────────────────────
class _SegmentedProgress extends StatelessWidget {
  final int total;
  final int current;
  final Map<String, int> answers;
  final List<dynamic> questions;

  const _SegmentedProgress({
    required this.total,
    required this.current,
    required this.answers,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${current + 1} of $total',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              Text(
                '${answers.length} answered',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Segmented pill bar
          Row(
            children: List.generate(total.clamp(0, 50), (i) {
              final Color seg;
              if (i < questions.length) {
                final qId = questions[i].id as String;
                seg = i == current
                    ? AppColors.primary
                    : answers.containsKey(qId)
                        ? AppColors.success
                        : AppColors.surfaceVariant;
              } else {
                seg = AppColors.surfaceVariant;
              }
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: seg,
                    borderRadius: AppRadius.circle,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Question badge
// ─────────────────────────────────────────────────────────────
class _QuestionBadge extends StatelessWidget {
  final int index;
  final int total;
  const _QuestionBadge({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'Q ${index + 1} / $total',
        style: AppTextStyles.labelMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Option tile
// ─────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : AppShadows.sm,
        ),
        child: Row(
          children: [
            // ── Label circle ─────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w500
                        : FontWeight.w400,
                    height: 1.5,
                  )),
            ),
            if (isSelected) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Mark for review toggle
// ─────────────────────────────────────────────────────────────
class _ReviewToggle extends StatelessWidget {
  final bool isMarked;
  final VoidCallback onTap;
  const _ReviewToggle({required this.isMarked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isMarked
              ? AppColors.warning.withValues(alpha: 0.12)
              : AppColors.surfaceVariant,
          borderRadius: AppRadius.circle,
          border: Border.all(
            color: isMarked
                ? AppColors.warning
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 14,
              color: isMarked
                  ? AppColors.warning
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              isMarked ? 'Marked' : 'Mark',
              style: AppTextStyles.labelSmall.copyWith(
                color: isMarked
                    ? AppColors.warning
                    : AppColors.textSecondary,
                fontWeight: isMarked
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Question Palette Sheet
// ─────────────────────────────────────────────────────────────
class _PaletteSheet extends StatelessWidget {
  final TestSessionState state;
  final ValueChanged<int> onTap;
  const _PaletteSheet({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
        boxShadow: AppShadows.lg,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // ── Handle ────────────────────────────────
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.circle),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.grid_view_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text('Question Palette',
                      style: AppTextStyles.headlineSmall),
                  const Spacer(),
                  AppBadge(
                    label: '${state.totalQuestions} Qs',
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Legend ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _legendItem(_paletteColor(QuestionStatus.answered),
                      'Answered (${state.answeredCount})'),
                  _legendItem(
                      _paletteColor(QuestionStatus.markedForReview),
                      'Marked (${state.reviewCount})'),
                  _legendItem(
                      _paletteColor(QuestionStatus.answeredAndMarked),
                      'Ans+Marked'),
                  _legendItem(
                      _paletteColor(QuestionStatus.notVisited),
                      'Not Answered'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5)),

            // ── Grid ──────────────────────────────────
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(AppSpacing.lg),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: state.totalQuestions,
                itemBuilder: (_, i) {
                  final status = state.statusOf(i);
                  final isCurrent = i == state.currentIndex;
                  final bg = isCurrent
                      ? AppColors.primary
                      : _paletteColor(status);
                  return GestureDetector(
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: AppRadius.smAll,
                        border: isCurrent
                            ? Border.all(
                                color: AppColors.primaryDark,
                                width: 2)
                            : null,
                        boxShadow: isCurrent ? [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ] : null,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _textColor(status, isCurrent),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _paletteColor(QuestionStatus status) {
    switch (status) {
      case QuestionStatus.answered:
        return AppColors.success;
      case QuestionStatus.markedForReview:
        return AppColors.warning;
      case QuestionStatus.answeredAndMarked:
        return AppColors.info;
      case QuestionStatus.current:
        return AppColors.primary;
      case QuestionStatus.notVisited:
        return AppColors.surfaceVariant;
    }
  }

  Color _textColor(QuestionStatus status, bool isCurrent) {
    if (isCurrent) return Colors.white;
    if (status == QuestionStatus.notVisited) return AppColors.textPrimary;
    return Colors.white;
  }

  Widget _legendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: AppRadius.xsAll),
          ),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      );
}
