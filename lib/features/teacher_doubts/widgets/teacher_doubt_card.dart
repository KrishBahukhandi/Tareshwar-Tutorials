// ─────────────────────────────────────────────────────────────
//  teacher_doubt_card.dart
//  Compact card used in TeacherDoubtListScreen.
//  Shows: student name / avatar, question preview,
//  timestamp, reply count, answered/pending badge.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/models/models.dart';

class TeacherDoubtCard extends StatelessWidget {
  final DoubtModel doubt;
  const TeacherDoubtCard({super.key, required this.doubt});

  @override
  Widget build(BuildContext context) {
    final answered = doubt.isAnswered;
    final statusColor = answered ? AppColors.success : AppColors.warning;

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.teacherDoubtDetailPath(doubt.id),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: statusColor.withAlpha(70),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: avatar + name + date + badge ──
              Row(
                children: [
                  // Student avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.primary.withAlpha(25),
                    child: Text(
                      _initial(doubt.studentName),
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doubt.studentName ?? 'Student',
                          style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _relativeTime(doubt.createdAt),
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _StatusBadge(isAnswered: answered),
                ],
              ),

              const SizedBox(height: 10),

              // ── Question preview ───────────────────────
              Text(
                doubt.question,
                style: AppTextStyles.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // ── Image indicator ────────────────────────
              if (doubt.imageUrl != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.image_rounded,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('Image attached',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textHint)),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // ── Footer: lecture tag + reply count ─────
              Row(
                children: [
                  // Lecture tag if present
                  if (doubt.lectureId != null) ...[
                    _LecturePill(),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  // Reply count
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 13,
                      color: doubt.replyCount > 0
                          ? AppColors.primary
                          : AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    '${doubt.replyCount} ${doubt.replyCount == 1 ? 'reply' : 'replies'}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: doubt.replyCount > 0
                          ? AppColors.primary
                          : AppColors.textHint,
                      fontWeight: doubt.replyCount > 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Chevron
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.textHint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(String? name) =>
      (name?.isNotEmpty == true ? name![0] : 'S').toUpperCase();

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

// ── Helpers ───────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isAnswered;
  const _StatusBadge({required this.isAnswered});

  @override
  Widget build(BuildContext context) {
    final color = isAnswered ? AppColors.success : AppColors.warning;
    final label = isAnswered ? 'Resolved' : 'Pending';
    final icon = isAnswered
        ? Icons.check_circle_rounded
        : Icons.schedule_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LecturePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.info.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.info.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_rounded,
                size: 11, color: AppColors.info),
            const SizedBox(width: 4),
            Text('Lecture',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.info)),
          ],
        ),
      );
}
