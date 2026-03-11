// ─────────────────────────────────────────────────────────────
//  progress_widgets.dart  –  Shared progress UI components
//
//  Exports:
//    • CourseProgressBar          – thin animated bar + label
//    • ChapterProgressIndicator   – compact row with fraction text
//    • LectureCompletionBadge     – ✓ tick / partial ring for tiles
//    • ContinueLearningCard       – "continue where you left off" card
//    • CourseProgressLoader       – ConsumerWidget data-fetch wrapper
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart'
    show courseProgressProvider;
import '../../../../shared/services/progress_service.dart'
    show CourseProgress, ChapterProgress;

// ─────────────────────────────────────────────────────────────
//  1. CourseProgressBar
// ─────────────────────────────────────────────────────────────
class CourseProgressBar extends StatelessWidget {
  final double percent;
  final int? completedLectures;
  final int? totalLectures;
  final bool showLabel;
  final double height;

  const CourseProgressBar({
    super.key,
    required this.percent,
    this.completedLectures,
    this.totalLectures,
    this.showLabel = true,
    this.height = 6,
  });

  Color get _barColor {
    if (percent >= 1.0) return AppColors.success;
    if (percent >= 0.5) return AppColors.primary;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final safe = percent.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  safe >= 1.0 ? 'Completed ✓' : 'Progress',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _barColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  completedLectures != null && totalLectures != null
                      ? '$completedLectures / $totalLectures'
                      : '${(safe * 100).round()}%',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: safe),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => LinearProgressIndicator(
              value: value,
              minHeight: height,
              backgroundColor: _barColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(_barColor),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  2. ChapterProgressIndicator
// ─────────────────────────────────────────────────────────────
class ChapterProgressIndicator extends StatelessWidget {
  final ChapterProgress progress;
  const ChapterProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = progress.isComplete ? AppColors.success : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          progress.isComplete
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${progress.completedLectures}/${progress.totalLectures}',
          style: AppTextStyles.labelSmall.copyWith(color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  3. LectureCompletionBadge
// ─────────────────────────────────────────────────────────────
class LectureCompletionBadge extends StatelessWidget {
  final bool completed;
  final int watchedSeconds;
  final int totalSeconds;

  const LectureCompletionBadge({
    super.key,
    required this.completed,
    this.watchedSeconds = 0,
    this.totalSeconds = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            size: 14, color: AppColors.success),
      );
    }
    if (watchedSeconds > 5 && totalSeconds > 0) {
      final pct = (watchedSeconds / totalSeconds).clamp(0.0, 1.0);
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: pct,
          strokeWidth: 2.5,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        ),
      );
    }
    return const SizedBox(width: 24, height: 24);
  }
}

// ─────────────────────────────────────────────────────────────
//  4. ContinueLearningCard
// ─────────────────────────────────────────────────────────────
class ContinueLearningCard extends StatelessWidget {
  final CourseModel course;
  final CourseProgress progress;
  final VoidCallback onTap;
  final VoidCallback? onContinueLecture;

  const ContinueLearningCard({
    super.key,
    required this.course,
    required this.progress,
    required this.onTap,
    this.onContinueLecture,
  });

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final pct = progress.percent;
    final hasLecture = progress.lastWatchedLecture != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              height: 76,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      course.title,
                      style: AppTextStyles.headlineSmall.copyWith(
                          color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(pct * 100).round()}%',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CourseProgressBar(
                    percent: pct,
                    showLabel: false,
                    height: 5,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${progress.completedLectures} / ${progress.totalLectures} lectures',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  if (hasLecture) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.play_circle_outline_rounded,
                            size: 13, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            progress.lastWatchedLecture!.title,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (progress.lastWatchedSeconds > 0)
                      Text(
                        'at ${_fmt(progress.lastWatchedSeconds)}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint),
                      ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onContinueLecture ?? onTap,
                      icon: Icon(
                        progress.isComplete
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded,
                        size: 15,
                      ),
                      label: Text(
                        progress.isComplete
                            ? 'Review'
                            : hasLecture
                                ? 'Continue'
                                : 'Start',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(36),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
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
}

// ─────────────────────────────────────────────────────────────
//  5. CourseProgressLoader
// ─────────────────────────────────────────────────────────────
typedef ProgressBuilder = Widget Function(CourseProgress progress);

class CourseProgressLoader extends ConsumerWidget {
  final String studentId;
  final String courseId;
  final ProgressBuilder builder;
  final Widget? loadingWidget;

  const CourseProgressLoader({
    super.key,
    required this.studentId,
    required this.courseId,
    required this.builder,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (studentId: studentId, courseId: courseId);
    return ref.watch(courseProgressProvider(key)).when(
          data: builder,
          loading: () => loadingWidget ?? const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
        );
  }
}
