// ─────────────────────────────────────────────────────────────
//  teacher_course_tile.dart
//  A list tile for a course on the Teacher Courses screen.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/models.dart';

class TeacherCourseTile extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onUpload;
  final VoidCallback onTogglePublish;

  const TeacherCourseTile({
    super.key,
    required this.course,
    required this.onUpload,
    required this.onTogglePublish,
  });

  @override
  Widget build(BuildContext context) {
    final published = course.isPublished;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: course.thumbnailUrl != null
                ? Image.network(
                    course.thumbnailUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _PlaceholderThumb(
                      color: published
                          ? AppColors.primary
                          : AppColors.textHint,
                    ),
                  )
                : _PlaceholderThumb(
                    color:
                        published ? AppColors.primary : AppColors.textHint,
                  ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status chip
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(published: published),
                  ],
                ),
                const SizedBox(height: 6),

                // Meta row
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.play_lesson_rounded,
                      label:
                          '${course.totalLectures ?? 0} lectures',
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.people_rounded,
                      label:
                          '${course.totalStudents ?? 0} students',
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Action buttons
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.upload_file_rounded,
                      label: 'Upload',
                      color: AppColors.primary,
                      onTap: onUpload,
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: published
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      label: published ? 'Unpublish' : 'Publish',
                      color: published
                          ? AppColors.warning
                          : AppColors.success,
                      onTap: onTogglePublish,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────

class _PlaceholderThumb extends StatelessWidget {
  final Color color;
  const _PlaceholderThumb({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        color: color.withAlpha(30),
        child: Icon(Icons.menu_book_rounded, color: color, size: 28),
      );
}

class _StatusChip extends StatelessWidget {
  final bool published;
  const _StatusChip({required this.published});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: published
              ? AppColors.success.withAlpha(25)
              : AppColors.warning.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          published ? 'Published' : 'Draft',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: published ? AppColors.success : AppColors.warning,
          ),
        ),
      );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
}
