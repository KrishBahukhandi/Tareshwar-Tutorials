// ─────────────────────────────────────────────────────────────
//  course_card_widget.dart  –  Reusable course card.
//
//  Handles two variants:
//    • CourseCard        – recommended/browse (vertical card)
//    • CourseListTile    – horizontal compact card for lists
//
//  Accepts a plain CourseCardData model so it's decoupled from
//  feature-specific entities and can be used by any feature.
// ─────────────────────────────────────────────────────────────
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'app_theme.dart';
import 'app_widgets.dart';

// ── Data transfer object ──────────────────────────────────────
class CourseCardData {
  final String id;
  final String title;
  final String? teacherName;
  final String? thumbnailUrl;
  final String? categoryTag;
  final double? rating;
  final int? totalLectures;
  final bool isFree;
  final double? price;
  final double? progressPercent;   // null = not enrolled
  final int? completedLectures;

  const CourseCardData({
    required this.id,
    required this.title,
    this.teacherName,
    this.thumbnailUrl,
    this.categoryTag,
    this.rating,
    this.totalLectures,
    this.isFree = false,
    this.price,
    this.progressPercent,
    this.completedLectures,
  });

  bool get isEnrolled => progressPercent != null;
  String get formattedPrice =>
      isFree ? 'FREE' : (price != null ? '₹${price!.toStringAsFixed(0)}' : '');
  String get formattedRating =>
      rating != null ? rating!.toStringAsFixed(1) : '';
}

// ══════════════════════════════════════════════════════════════
//  CourseCard  –  vertical card (horizontal scroll lists)
// ══════════════════════════════════════════════════════════════
class CourseCard extends StatelessWidget {
  final CourseCardData data;
  final VoidCallback onTap;
  final double width;

  const CourseCard({
    super.key,
    required this.data,
    required this.onTap,
    this.width = 230,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
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
            // ── Thumbnail ─────────────────────────────────────
            _CourseThumbnail(
              url: data.thumbnailUrl,
              category: data.categoryTag,
              height: 126,
              radius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
            ),

            // ── Info ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, AppSpacing.sm,
                  AppSpacing.sm, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: AppTextStyles.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data.teacherName != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 11,
                            color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            data.teacherName!,
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
                      if (data.rating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 12, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text(
                          data.formattedRating,
                          style: AppTextStyles.labelSmall.copyWith(
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (data.totalLectures != null)
                        _MetaChip(
                          icon: Icons.play_circle_outline_rounded,
                          label: '${data.totalLectures}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress bar OR price row
                  if (data.isEnrolled) ...[
                    AppProgressBar(
                      value: (data.progressPercent ?? 0) / 100,
                      height: 5,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.progressPercent!.toStringAsFixed(0)}% complete',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ] else
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data.formattedPrice,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: data.isFree
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

// ══════════════════════════════════════════════════════════════
//  CourseListTile  –  horizontal card (enrolled courses list)
// ══════════════════════════════════════════════════════════════
class CourseListTile extends StatelessWidget {
  final CourseCardData data;
  final VoidCallback onTap;
  final Widget? trailing;

  const CourseListTile({
    super.key,
    required this.data,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : AppColors.border.withValues(alpha: 0.6),
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
              ),
              child: _CourseThumbnail(
                url: data.thumbnailUrl,
                height: 108,
                width: 90,
                radius: BorderRadius.zero,
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.sm,
                    AppSpacing.sm, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.categoryTag != null)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.xxs),
                        child: AppBadge(
                          label: data.categoryTag!.toUpperCase(),
                          color: AppColors.primary,
                        ),
                      ),
                    Text(
                      data.title,
                      style: AppTextStyles.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (data.teacherName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        data.teacherName!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (data.isEnrolled) ...[
                      const SizedBox(height: 8),
                      AppProgressBar(
                        value: (data.progressPercent ?? 0) / 100,
                        height: 4,
                        showLabel: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // CTA
                    Row(
                      children: [
                        trailing ??
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs + 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: AppRadius.smAll,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 13,
                                      color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    data.isEnrolled &&
                                            (data.progressPercent ?? 0) > 0
                                        ? 'Resume'
                                        : 'Start',
                                    style: AppTextStyles.labelSmall
                                        .copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
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
//  Shared private helpers
// ─────────────────────────────────────────────────────────────
class _CourseThumbnail extends StatelessWidget {
  final String? url;
  final String? category;
  final double height;
  final double? width;
  final BorderRadius radius;

  const _CourseThumbnail({
    this.url,
    this.category,
    required this.height,
    this.width,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: width ?? double.infinity,
            height: height,
            child: url != null && url!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _PlaceholderBg(),
                    errorWidget: (_, __, ___) => _PlaceholderBg(),
                  )
                : _PlaceholderBg(),
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
                style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white, fontSize: 9),
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
          child: Icon(
            Icons.play_lesson_rounded,
            color: AppColors.primary,
            size: 28,
          ),
        ),
      );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textHint),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
