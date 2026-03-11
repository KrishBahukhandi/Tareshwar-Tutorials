// ─────────────────────────────────────────────────────────────
//  course_card.dart  –  Recommended/browse course card.
//  Used in horizontal scroll list on the student dashboard.
// ─────────────────────────────────────────────────────────────
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/recommended_course_entity.dart';

/// Shimmer placeholder
class CourseCardShimmer extends StatelessWidget {
  const CourseCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase.withValues(alpha: 0.35),
        borderRadius: AppRadius.lgAll,
      ),
    );
  }
}

class CourseCard extends StatelessWidget {
  final RecommendedCourseEntity course;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 222,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : AppColors.border.withValues(alpha: 0.6),
          ),
          boxShadow: AppShadows.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ─────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
              child: _Thumbnail(
                  url: course.thumbnailUrl,
                  category: course.categoryTag),
            ),

            // ── Info ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, AppSpacing.sm,
                  AppSpacing.sm, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: AppTextStyles.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Meta row
                  Row(
                    children: [
                      if (course.rating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 12, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text(
                          course.formattedRating,
                          style: AppTextStyles.labelSmall.copyWith(
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (course.totalLectures != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.play_circle_outline_rounded,
                                size: 11,
                                color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              '${course.totalLectures} lectures',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Price row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        course.formattedPrice,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: course.isFree
                              ? AppColors.success
                              : AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs + 2),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: AppRadius.smAll,
                          boxShadow: AppShadows.glow(AppColors.primary,
                              intensity: 0.2),
                        ),
                        child: Text(
                          'Enroll',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ],
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
class _Thumbnail extends StatelessWidget {
  final String? url;
  final String? category;
  const _Thumbnail({this.url, this.category});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 122,
          width: double.infinity,
          child: url != null && url!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _PlaceholderBg(),
                  errorWidget: (_, __, ___) => _PlaceholderBg(),
                )
              : _PlaceholderBg(),
        ),
        // Bottom gradient scrim
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ),
        if (category != null)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.xsAll,
              ),
              child: Text(
                category!,
                style: AppTextStyles.labelSmall
                    .copyWith(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaceholderBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primary.withValues(alpha: 0.08),
        child: const Center(
          child: Icon(Icons.book_rounded,
              color: AppColors.primary, size: 36),
        ),
      );
}
