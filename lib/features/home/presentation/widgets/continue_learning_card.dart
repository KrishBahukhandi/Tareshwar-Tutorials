// ─────────────────────────────────────────────────────────────
//  continue_learning_card.dart  –  Enrolled course progress card.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../domain/entities/enrolled_course_entity.dart';

class ContinueLearningCard extends StatelessWidget {
  final EnrolledCourseEntity course;
  final VoidCallback onTap;

  const ContinueLearningCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (course.progressPercent / 100).clamp(0.0, 1.0);
    final isComplete = progress >= 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : AppColors.border.withValues(alpha: 0.55),
          ),
          boxShadow: AppShadows.md,
        ),
        child: Row(
          children: [
            // ── Left accent bar ────────────────────────────
            Container(
              width: 4,
              height: 120,
              decoration: BoxDecoration(
                gradient: isComplete
                    ? const LinearGradient(
                        colors: [AppColors.success, Color(0xFF38F9D7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                ),
              ),
            ),

            // ── Thumbnail ──────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: _Thumbnail(url: course.thumbnailUrl),
            ),

            // ── Content ────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.sm,
                    AppSpacing.sm, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    if (course.categoryTag != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: AppBadge(
                          label: course.categoryTag!.toUpperCase(),
                          color: AppColors.primary,
                          fontSize: 9,
                        ),
                      ),

                    // Title
                    Text(
                      course.title,
                      style: AppTextStyles.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Teacher
                    if (course.teacherName != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 11, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              course.teacherName!,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Progress
                    AppProgressBar(
                      value: progress,
                      height: 5,
                      color: isComplete ? AppColors.success : AppColors.primary,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isComplete
                              ? '✓ Completed'
                              : '${course.progressPercent.toStringAsFixed(0)}% done',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isComplete
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (course.totalLectures > 0)
                          Text(
                            '${course.completedLectures}/${course.totalLectures}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textHint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Resume CTA
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: isComplete ? null : AppColors.primaryGradient,
                        color: isComplete
                            ? AppColors.success.withValues(alpha: 0.1)
                            : null,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isComplete
                                ? Icons.replay_rounded
                                : Icons.play_arrow_rounded,
                            size: 13,
                            color: isComplete
                                ? AppColors.success
                                : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isComplete
                                ? 'Rewatch'
                                : course.isStarted
                                    ? 'Resume'
                                    : 'Start',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isComplete
                                  ? AppColors.success
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _Thumbnail extends StatelessWidget {
  final String? url;
  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        width: 86,
        height: 120,
        fit: BoxFit.cover,
        placeholder: (_, __) => _PlaceholderBox(),
        errorWidget: (_, __, ___) => _PlaceholderBox(),
      );
    }
    return _PlaceholderBox();
  }
}

class _PlaceholderBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 86,
        height: 120,
        color: AppColors.primary.withValues(alpha: 0.08),
        child: const Icon(
          Icons.play_lesson_rounded,
          color: AppColors.primary,
          size: 28,
        ),
      );
}
