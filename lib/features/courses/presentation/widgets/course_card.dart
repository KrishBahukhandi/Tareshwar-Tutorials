// ─────────────────────────────────────────────────────────────
//  course_card.dart  –  Grid / list card for a CourseModel.
//  Used in CourseListScreen and search results.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: course.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: course.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => _Placeholder(
                          category: course.categoryTag,
                        ),
                        errorWidget: (ctx, url, err) => _Placeholder(
                          category: course.categoryTag,
                        ),
                      )
                    : _Placeholder(category: course.categoryTag),
              ),
            ),

            // ── Info ───────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category tag
                    if (course.categoryTag != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          course.categoryTag!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Title
                    Text(
                      course.title,
                      style: AppTextStyles.headlineSmall
                          .copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Teacher
                    if (course.teacherName != null)
                      Text(
                        course.teacherName!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const Spacer(),

                    // Footer: price + lectures
                    Row(
                      children: [
                        Text(
                          course.price == 0
                              ? 'FREE'
                              : '₹${course.price.toStringAsFixed(0)}',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: course.price == 0
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        if (course.totalLectures != null)
                          Row(
                            children: [
                              const Icon(Icons.play_lesson_outlined,
                                  size: 13,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text(
                                '${course.totalLectures}',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                      ],
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
//  Horizontal list variant (narrower, fixed width)
// ─────────────────────────────────────────────────────────────
class CourseCardHorizontal extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const CourseCardHorizontal({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: course.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: course.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) =>
                            _Placeholder(category: course.categoryTag),
                        errorWidget: (ctx, url, err) =>
                            _Placeholder(category: course.categoryTag),
                      )
                    : _Placeholder(category: course.categoryTag),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style:
                          AppTextStyles.headlineSmall.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (course.teacherName != null)
                      Text(
                        course.teacherName!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary,
                                fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Text(
                      course.price == 0
                          ? 'FREE'
                          : '₹${course.price.toStringAsFixed(0)}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: course.price == 0
                            ? AppColors.success
                            : AppColors.primary,
                        fontSize: 13,
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
//  Shimmer skeleton
// ─────────────────────────────────────────────────────────────
class CourseCardShimmer extends StatelessWidget {
  const CourseCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.shimmerBase.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(color: AppColors.shimmerBase),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(double.infinity, 14),
                  const SizedBox(height: 6),
                  _shimmerBox(120, 12),
                  const Spacer(),
                  _shimmerBox(60, 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Internal: placeholder thumbnail
// ─────────────────────────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  final String? category;
  const _Placeholder({this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded,
                size: 32,
                color: AppColors.primary.withValues(alpha: 0.5)),
            if (category != null) ...[
              const SizedBox(height: 4),
              Text(
                category!,
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.6)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
