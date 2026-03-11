// ─────────────────────────────────────────────────────────────
//  lecture_tile_widget.dart  –  Reusable lecture row tile.
//
//  Used by course detail, lecture lists, and downloads.
//
//  Variants:
//    LectureTileWidget  – standard list item
//    LockOverlay        – shown when content is locked
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'app_theme.dart';
import 'app_widgets.dart';

// ── Data ──────────────────────────────────────────────────────
class LectureTileData {
  final String id;
  final int index;
  final String title;
  final String? duration;
  final bool isFree;
  final bool isCompleted;
  final bool isLocked;
  final bool hasNotes;
  final bool hasAttachments;
  final double? progressPercent; // 0–100, null = not started

  const LectureTileData({
    required this.id,
    required this.index,
    required this.title,
    this.duration,
    this.isFree = false,
    this.isCompleted = false,
    this.isLocked = false,
    this.hasNotes = false,
    this.hasAttachments = false,
    this.progressPercent,
  });
}

// ══════════════════════════════════════════════════════════════
//  LectureTileWidget
// ══════════════════════════════════════════════════════════════
class LectureTileWidget extends StatelessWidget {
  final LectureTileData data;
  final VoidCallback? onTap;
  final Widget? trailing; // e.g. DownloadButton

  const LectureTileWidget({
    super.key,
    required this.data,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPlay = !data.isLocked;
    final started = (data.progressPercent ?? 0) > 0;
    final progress = (data.progressPercent ?? 0) / 100;

    // Leading circle
    Widget leading;
    if (data.isCompleted) {
      leading = Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            size: 16, color: Colors.white),
      );
    } else if (data.isLocked) {
      leading = Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.lock_outline_rounded,
            size: 15, color: AppColors.textHint),
      );
    } else {
      leading = Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: started ? AppColors.primaryGradient : null,
          color: started
              ? null
              : AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '${data.index + 1}',
          style: AppTextStyles.labelSmall.copyWith(
            color: started ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: canPlay ? onTap : null,
      child: AnimatedOpacity(
        opacity: data.isLocked ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: data.isCompleted
                  ? AppColors.success.withValues(alpha: 0.25)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.border.withValues(alpha: 0.5),
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  leading,
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: data.isLocked
                                ? AppColors.textHint
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (data.duration != null ||
                            data.hasNotes ||
                            data.hasAttachments) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (data.duration != null)
                                _MetaItem(
                                  icon: Icons.timer_outlined,
                                  label: data.duration!,
                                ),
                              if (data.duration != null &&
                                  (data.hasNotes || data.hasAttachments))
                                const SizedBox(width: 8),
                              if (data.hasNotes)
                                _MetaItem(
                                  icon: Icons.description_outlined,
                                  label: 'Notes',
                                ),
                              if (data.hasAttachments) ...[
                                if (data.hasNotes)
                                  const SizedBox(width: 8),
                                _MetaItem(
                                  icon: Icons.attach_file_rounded,
                                  label: 'Attachments',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // Right-side badges
                  if (data.isFree && !data.isLocked)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: AppBadge(
                          label: 'FREE',
                          color: AppColors.success),
                    ),
                  if (trailing != null) trailing!,
                  if (!data.isLocked)
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                ],
              ),
              // Partial progress bar
              if (started && !data.isCompleted) ...[
                const SizedBox(height: AppSpacing.xs),
                AppProgressBar(
                  value: progress,
                  height: 3,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textHint),
        const SizedBox(width: 3),
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
