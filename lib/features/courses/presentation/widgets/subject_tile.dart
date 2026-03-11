// ─────────────────────────────────────────────────────────────
//  subject_tile.dart  –  Tappable tile for a SubjectModel.
//  Used inside CourseDetailScreen and SubjectListScreen.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';

class SubjectTile extends StatelessWidget {
  final SubjectModel subject;
  final int index;
  final VoidCallback onTap;
  /// If true, shows chapter/lecture counts from nested data
  final bool showCounts;

  const SubjectTile({
    super.key,
    required this.subject,
    required this.index,
    required this.onTap,
    this.showCounts = true,
  });

  @override
  Widget build(BuildContext context) {
    final chapterCount = subject.chapters.length;
    final lectureCount =
        subject.chapters.fold<int>(0, (s, ch) => s + ch.lectures.length);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Index badge ──────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: AppTextStyles.headlineSmall
                      .copyWith(color: Colors.white, fontSize: 15),
                ),
              ),
              const SizedBox(width: 14),

              // ── Name + counts ────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: AppTextStyles.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showCounts && chapterCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _MetaChip(
                            icon: Icons.folder_outlined,
                            label: '$chapterCount chapter${chapterCount > 1 ? 's' : ''}',
                          ),
                          const SizedBox(width: 8),
                          if (lectureCount > 0)
                            _MetaChip(
                              icon: Icons.play_circle_outline_rounded,
                              label: '$lectureCount lecture${lectureCount > 1 ? 's' : ''}',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Arrow ────────────────────────────────────
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Shimmer
// ─────────────────────────────────────────────────────────────
class SubjectTileShimmer extends StatelessWidget {
  const SubjectTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: AppColors.shimmerBase,
                        borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Container(
                    height: 11,
                    width: 120,
                    decoration: BoxDecoration(
                        color: AppColors.shimmerBase,
                        borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
