// ─────────────────────────────────────────────────────────────
//  downloaded_lecture_tile.dart  –  Card for a single
//  downloaded lecture shown in DownloadsScreen.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../data/download_model.dart';

class DownloadedLectureTile extends StatelessWidget {
  final DownloadedLecture download;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DownloadedLectureTile({
    super.key,
    required this.download,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = download.isCompleted;

    return GestureDetector(
      onTap: isReady ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isReady
                ? AppColors.border.withValues(alpha: 0.5)
                : AppColors.warning.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Thumbnail placeholder ──────────────────────
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: isReady
                      ? AppColors.primaryGradient
                      : const LinearGradient(
                          colors: [Color(0xFFFFC107), Color(0xFFFF9800)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReady
                      ? Icons.play_arrow_rounded
                      : download.isDownloading
                          ? Icons.downloading_rounded
                          : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // ── Info ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      download.courseTitle,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Meta row
                    Row(
                      children: [
                        if (download.formattedDuration.isNotEmpty) ...[
                          const Icon(Icons.timer_outlined,
                              size: 11, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(download.formattedDuration,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textHint)),
                          const SizedBox(width: 10),
                        ],
                        if (download.formattedSize.isNotEmpty) ...[
                          const Icon(Icons.storage_rounded,
                              size: 11, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(download.formattedSize,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textHint)),
                        ],
                        if (download.isDownloading) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${(download.progress * 100).toStringAsFixed(0)}%',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                    // Progress bar while downloading
                    if (download.isDownloading) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: download.progress,
                          minHeight: 3,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Status badge + delete ──────────────────────
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isReady)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Offline',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.success, fontSize: 10),
                      ),
                    ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shimmer placeholder
class DownloadedLectureTileShimmer extends StatelessWidget {
  const DownloadedLectureTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 13,
                    color: AppColors.shimmerBase,
                    width: double.infinity),
                const SizedBox(height: 6),
                Container(
                    height: 10, color: AppColors.shimmerBase, width: 120),
                const SizedBox(height: 8),
                Container(
                    height: 9, color: AppColors.shimmerBase, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
