// ─────────────────────────────────────────────────────────────
//  test_result_screen.dart  –  Result + per-question analysis
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/theme_barrel.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart'
    show testQuestionsProvider, testLeaderboardProvider;

// ─────────────────────────────────────────────────────────────
class TestResultScreen extends ConsumerWidget {
  final String testId;
  const TestResultScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = GoRouterState.of(context).extra;
    final attempt = extra as TestAttemptModel?;

    if (attempt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const AppEmptyState(
          icon: Icons.assignment_outlined,
          title: 'No result data',
          subtitle: 'Could not find result information.',
        ),
      );
    }

    final questionsAsync = ref.watch(testQuestionsProvider(testId));
    final isPassed = attempt.percentage >= 60;
    final gradeColor = isPassed ? AppColors.success : AppColors.error;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 320,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                onPressed: () => context.go(AppRoutes.homeTab),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _ResultHero(
                    attempt: attempt,
                    gradeColor: gradeColor,
                    isPassed: isPassed),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Container(
                  color: AppColors.surface,
                  child: const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: 'Summary'),
                      Tab(text: 'Review'),
                      Tab(text: 'Leaderboard'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _SummaryTab(attempt: attempt, gradeColor: gradeColor),
              _ReviewTab(
                  attempt: attempt, questionsAsync: questionsAsync),
              _LeaderboardTab(testId: testId),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Result hero header
// ─────────────────────────────────────────────────────────────
class _ResultHero extends StatelessWidget {
  final TestAttemptModel attempt;
  final Color gradeColor;
  final bool isPassed;
  const _ResultHero(
      {required this.attempt,
      required this.gradeColor,
      required this.isPassed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isPassed
            ? AppColors.greenGradient
            : const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Emoji / icon ───────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isPassed ? '🏆' : '📘',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPassed ? 'Excellent Work!' : 'Keep Practicing!',
                style: AppTextStyles.displaySmall
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Grade: ${attempt.grade}',
                style: AppTextStyles.headlineMedium
                    .copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              // ── Score ring ─────────────────────────
              CircularPercentIndicator(
                radius: 60,
                lineWidth: 9,
                percent: (attempt.percentage / 100).clamp(0.0, 1.0),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${attempt.score}',
                      style: AppTextStyles.headlineLarge
                          .copyWith(color: Colors.white,
                              fontWeight: FontWeight.w800),
                    ),
                    Text('/${attempt.totalMarks}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white60)),
                  ],
                ),
                progressColor: Colors.white,
                backgroundColor: Colors.white24,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animationDuration: 800,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Summary tab
// ─────────────────────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final TestAttemptModel attempt;
  final Color gradeColor;
  const _SummaryTab(
      {required this.attempt, required this.gradeColor});

  @override
  Widget build(BuildContext context) {
    final accuracy = attempt.correctAnswers + attempt.wrongAnswers > 0
        ? (attempt.correctAnswers /
                (attempt.correctAnswers + attempt.wrongAnswers)) *
            100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Score headline card ────────────────────
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            shadows: AppShadows.md,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BigStat(
                  value: '${attempt.percentage.toStringAsFixed(1)}%',
                  label: 'Score',
                  color: gradeColor,
                ),
                _VerticalDivider(),
                _BigStat(
                  value: attempt.grade,
                  label: 'Grade',
                  color: gradeColor,
                ),
                _VerticalDivider(),
                _BigStat(
                  value:
                      '${attempt.timeTakenSeconds ~/ 60}m ${attempt.timeTakenSeconds % 60}s',
                  label: 'Time',
                  color: AppColors.info,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Stats grid ─────────────────────────────
          Row(
            children: [
              _StatCard(
                value: '${attempt.correctAnswers}',
                label: 'Correct',
                color: AppColors.success,
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatCard(
                value: '${attempt.wrongAnswers}',
                label: 'Wrong',
                color: AppColors.error,
                icon: Icons.cancel_outlined,
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatCard(
                value: '${attempt.skipped}',
                label: 'Skipped',
                color: AppColors.warning,
                icon: Icons.remove_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _StatCard(
                value: '${accuracy.toStringAsFixed(0)}%',
                label: 'Accuracy',
                color: AppColors.primary,
                icon: Icons.ads_click_rounded,
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatCard(
                value: '${attempt.score}/${attempt.totalMarks}',
                label: 'Score',
                color: gradeColor,
                icon: Icons.star_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Attempt date ───────────────────────────
          AppCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            shadows: [],
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Attempted on ${_fmtDate(attempt.attemptedAt)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── CTA button ─────────────────────────────
          SecondaryButton(
            label: 'Back to Home',
            icon: Icons.home_outlined,
            onTap: () => context.go(AppRoutes.homeTab),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _BigStat(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: AppTextStyles.headlineMedium.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      );
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 44, color: AppColors.border);
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          shadows: AppShadows.sm,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(value,
                  style: AppTextStyles.headlineSmall.copyWith(color: color)),
              Text(label, style: AppTextStyles.labelSmall),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Review tab – per-question breakdown
// ─────────────────────────────────────────────────────────────
class _ReviewTab extends StatelessWidget {
  final TestAttemptModel attempt;
  final AsyncValue<List<QuestionModel>> questionsAsync;

  const _ReviewTab(
      {required this.attempt, required this.questionsAsync});

  @override
  Widget build(BuildContext context) {
    return questionsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (questions) => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: questions.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _QuestionReviewCard(
          index: i,
          question: questions[i],
          selectedOption: attempt.answers[questions[i].id],
        ),
      ),
    );
  }
}

class _QuestionReviewCard extends StatefulWidget {
  final int index;
  final QuestionModel question;
  final int? selectedOption;

  const _QuestionReviewCard({
    required this.index,
    required this.question,
    this.selectedOption,
  });

  @override
  State<_QuestionReviewCard> createState() => _QuestionReviewCardState();
}

class _QuestionReviewCardState extends State<_QuestionReviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final selected = widget.selectedOption;
    final correct = q.correctOptionIndex;
    final isCorrect = selected == correct;
    final isSkipped = selected == null;

    final statusColor = isSkipped
        ? AppColors.warning
        : isCorrect
            ? AppColors.success
            : AppColors.error;
    final statusIcon = isSkipped
        ? Icons.remove_circle_outline_rounded
        : isCorrect
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded;
    final statusLabel =
        isSkipped ? 'Skipped' : isCorrect ? 'Correct' : 'Wrong';

    return AppCard(
      padding: EdgeInsets.zero,
      hasBorder: true,
      shadows: AppShadows.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: statusColor,
                                fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      q.question,
                      style: AppTextStyles.bodyMedium,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppBadge(
                    label: statusLabel,
                    color: statusColor,
                    icon: statusIcon,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded: options + explanation ────────
          if (_expanded) ...[
            Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Options
                  ...List.generate(q.options.length, (i) {
                    final isCorrectOpt = i == correct;
                    final isSelectedOpt = i == selected;
                    Color? bg;
                    Color borderColor = AppColors.border;
                    if (isCorrectOpt) {
                      bg = AppColors.success.withValues(alpha: 0.08);
                      borderColor = AppColors.success;
                    } else if (isSelectedOpt && !isCorrectOpt) {
                      bg = AppColors.error.withValues(alpha: 0.08);
                      borderColor = AppColors.error;
                    }
                    return Container(
                      margin:
                          const EdgeInsets.only(bottom: AppSpacing.xs),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: AppRadius.smAll,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isCorrectOpt
                                  ? AppColors.success
                                      .withValues(alpha: 0.15)
                                  : isSelectedOpt && !isCorrectOpt
                                      ? AppColors.error
                                          .withValues(alpha: 0.15)
                                      : AppColors.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(q.options[i],
                                style: AppTextStyles.bodyMedium),
                          ),
                          if (isCorrectOpt)
                            const Icon(Icons.check_rounded,
                                color: AppColors.success, size: 16),
                          if (isSelectedOpt && !isCorrectOpt)
                            const Icon(Icons.close_rounded,
                                color: AppColors.error, size: 16),
                        ],
                      ),
                    );
                  }),

                  // Explanation
                  if (q.explanation != null &&
                      q.explanation!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.07),
                        borderRadius: AppRadius.smAll,
                        border: Border.all(
                            color: AppColors.info
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: AppRadius.xsAll,
                            ),
                            child: const Icon(
                                Icons.lightbulb_rounded,
                                size: 14,
                                color: AppColors.info),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Explanation',
                                    style: AppTextStyles.labelSmall
                                        .copyWith(
                                            color: AppColors.info,
                                            fontWeight:
                                                FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(q.explanation!,
                                    style: AppTextStyles.bodySmall
                                        .copyWith(height: 1.6)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Leaderboard tab
// ─────────────────────────────────────────────────────────────
class _LeaderboardTab extends ConsumerWidget {
  final String testId;
  const _LeaderboardTab({required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lbAsync = ref.watch(testLeaderboardProvider(testId));

    return lbAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (attempts) {
        if (attempts.isEmpty) {
          return const AppEmptyState(
            icon: Icons.leaderboard_outlined,
            title: 'No attempts yet',
            subtitle: 'Be the first on the leaderboard!',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: attempts.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppSpacing.xs),
          itemBuilder: (_, i) {
            final a = attempts[i];
            final rank = i + 1;
            final rankColor = rank == 1
                ? const Color(0xFFFFD700)
                : rank == 2
                    ? const Color(0xFFC0C0C0)
                    : rank == 3
                        ? const Color(0xFFCD7F32)
                        : AppColors.textSecondary;
            final isTop3 = rank <= 3;
            return AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              shadows: isTop3 ? AppShadows.md : AppShadows.sm,
              child: Row(
                children: [
                  // ── Rank ──────────────────────────
                  SizedBox(
                    width: 36,
                    child: isTop3
                        ? Text(
                            _medal(rank),
                            style:
                                const TextStyle(fontSize: 22),
                            textAlign: TextAlign.center,
                          )
                        : Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '#$rank',
                                style:
                                    AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // ── Avatar ────────────────────────
                  CircleAvatar(
                    radius: 19,
                    backgroundColor:
                        rankColor.withValues(alpha: 0.15),
                    child: Text(
                      (a.studentId.isNotEmpty
                              ? a.studentId[0]
                              : 'S')
                          .toUpperCase(),
                      style: AppTextStyles.labelMedium
                          .copyWith(color: rankColor,
                              fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student ${a.studentId.substring(0, 6)}',
                          style: AppTextStyles.labelLarge,
                        ),
                        Text(
                          '${a.percentage.toStringAsFixed(1)}%',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${a.score}/${a.totalMarks}',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isTop3)
                        AppBadge(
                          label: rank == 1
                              ? 'Top scorer'
                              : 'Top 3',
                          color: rankColor,
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _medal(int rank) =>
      rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
}
