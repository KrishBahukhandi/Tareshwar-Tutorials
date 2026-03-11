// ─────────────────────────────────────────────────────────────
//  lecture_tile.dart  –  List tile for a LectureModel.
//  Shows title, duration, free badge, notes/attachment icons.
//  Now also shows lecture completion badge and partial-progress ring.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../downloads/presentation/widgets/download_button.dart';
import 'progress_widgets.dart' show LectureCompletionBadge;

class LectureTile extends StatelessWidget {
  final LectureModel lecture;
  final int index;
  final VoidCallback onTap;
  /// Whether the student is enrolled (controls lock icon visibility)
  final bool isEnrolled;
  /// Optional progress data – when provided, shows completion badge
  final LectureProgressModel? progress;
  /// Course title – used for the download label
  final String courseTitle;

  const LectureTile({
    super.key,
    required this.lecture,
    required this.index,
    required this.onTap,
    this.isEnrolled = false,
    this.progress,
    this.courseTitle = '',
  });

  bool get _isAccessible => lecture.isFree || isEnrolled;
  bool get _completed => progress?.completed ?? false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isAccessible ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _completed
              ? AppColors.success.withValues(alpha: 0.04)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _completed
                ? AppColors.success.withValues(alpha: 0.35)
                : _isAccessible
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.border.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // ── Play / Lock icon ─────────────────────────
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _completed
                      ? AppColors.success.withValues(alpha: 0.12)
                      : _isAccessible
                          ? AppColors.primary.withValues(alpha: 0.10)
                          : AppColors.textHint.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _completed
                      ? Icons.check_rounded
                      : _isAccessible
                          ? Icons.play_arrow_rounded
                          : Icons.lock_outline_rounded,
                  size: 20,
                  color: _completed
                      ? AppColors.success
                      : _isAccessible
                          ? AppColors.primary
                          : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 12),

              // ── Title + meta ─────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lecture.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _isAccessible
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Duration
                        if (lecture.formattedDuration.isNotEmpty)
                          _MetaItem(
                            icon: Icons.timer_outlined,
                            label: lecture.formattedDuration,
                          ),
                        if (lecture.formattedDuration.isNotEmpty &&
                            (lecture.notesUrl != null ||
                                lecture.attachments.isNotEmpty))
                          const SizedBox(width: 10),
                        // Notes
                        if (lecture.notesUrl != null)
                          _MetaItem(
                            icon: Icons.description_outlined,
                            label: 'Notes',
                          ),
                        if (lecture.notesUrl != null &&
                            lecture.attachments.isNotEmpty)
                          const SizedBox(width: 10),
                        // Attachments
                        if (lecture.attachments.isNotEmpty)
                          _MetaItem(
                            icon: Icons.attach_file_rounded,
                            label:
                                '${lecture.attachments.length} file${lecture.attachments.length > 1 ? 's' : ''}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Right-side badges ────────────────────────
              const SizedBox(width: 8),
              // Download button (enrolled students only, when video exists)
              if (isEnrolled && lecture.videoUrl != null)
                DownloadButton(
                  lecture: lecture,
                  courseTitle: courseTitle,
                  compact: true,
                ),
              // Completion badge (has priority over FREE badge visually)
              if (isEnrolled && progress != null)
                LectureCompletionBadge(
                  completed: progress!.completed,
                  watchedSeconds: progress!.watchedSeconds,
                  totalSeconds: lecture.durationSeconds ?? 0,
                )
              else if (lecture.isFree)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'FREE',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.success,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
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
class LectureTileShimmer extends StatelessWidget {
  const LectureTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.shimmerBase,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 13,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: AppColors.shimmerBase,
                        borderRadius: BorderRadius.circular(5))),
                const SizedBox(height: 5),
                Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                        color: AppColors.shimmerBase,
                        borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
