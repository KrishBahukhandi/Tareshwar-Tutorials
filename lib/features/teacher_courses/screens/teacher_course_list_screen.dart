// ─────────────────────────────────────────────────────────────
//  teacher_course_list_screen.dart
//  Lists all courses owned by the logged-in teacher.
//  Actions: create, edit, delete, toggle publish, view students.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/models.dart';
import '../providers/teacher_course_providers.dart';

class TeacherCourseListScreen extends ConsumerWidget {
  const TeacherCourseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(myCoursesProvider);
    ref.listen<CourseFormState>(courseFormProvider, (prev, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.error != null && next.error != prev?.error) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      } else if (next.success && !(prev?.success ?? false)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Course updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: const Text(
          'My Courses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(TeacherCourseRoutes.createCourse),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: const Text(
              'New Course',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e.toString(),
          onRetry: () => ref.invalidate(myCoursesProvider),
        ),
        data: (courses) => courses.isEmpty
            ? _EmptyState(
                onCreateTap: () =>
                    context.push(TeacherCourseRoutes.createCourse),
              )
            : _CourseGrid(courses: courses),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Course grid / list
// ─────────────────────────────────────────────────────────────
class _CourseGrid extends ConsumerWidget {
  final List<CourseModel> courses;
  const _CourseGrid({required this.courses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.of(context).size.width > 800;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myCoursesProvider),
      child: wide
          ? GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
              ),
              itemCount: courses.length,
              itemBuilder: (ctx, i) => _CourseCard(course: courses[i]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _CourseCard(course: courses[i]),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Course card
// ─────────────────────────────────────────────────────────────
class _CourseCard extends ConsumerWidget {
  final CourseModel course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final published = course.isPublished;
    final statsAsync = ref.watch(teacherCourseStatsProvider(course.id));

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title + status ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: AppTextStyles.headlineSmall.copyWith(fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(published: published),
            ],
          ),
          const SizedBox(height: 6),

          // ── Category & price ────────────────────────
          Row(
            children: [
              if (course.categoryTag != null) ...[
                const Icon(
                  Icons.label_rounded,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  course.categoryTag!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              const Icon(
                Icons.currency_rupee_rounded,
                size: 13,
                color: AppColors.textSecondary,
              ),
              Text(
                course.price.toStringAsFixed(0),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Meta ────────────────────────────────────
          Row(
            children: [
              _MetaBadge(
                icon: Icons.play_lesson_rounded,
                label: '${course.totalLectures ?? 0}',
              ),
              const SizedBox(width: 10),
              _MetaBadge(
                icon: Icons.people_rounded,
                label: '${course.totalStudents ?? 0}',
              ),
              const SizedBox(width: 10),
              Text(
                DateFormat('d MMM y').format(course.createdAt),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          statsAsync.when(
            data: (stats) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.book_outlined,
                  label: '${stats.subjectCount} subjects',
                ),
                _InfoChip(
                  icon: Icons.account_tree_outlined,
                  label: '${stats.chapterCount} chapters',
                ),
                _InfoChip(
                  icon: Icons.groups_rounded,
                  label: '${stats.enrollmentCount} enrollments',
                ),
                if (!stats.canPublish)
                  const _WarningChip(
                    label: 'Add at least 1 lecture to publish',
                  ),
                if (!stats.canDelete)
                  const _WarningChip(
                    label: 'Course has content or batch/student data',
                  ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── Actions ─────────────────────────────────
          _ActionRow(course: course),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  final CourseModel course;
  const _ActionRow({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(courseFormProvider.notifier);
    final formState = ref.watch(courseFormProvider);
    final statsAsync = ref.watch(teacherCourseStatsProvider(course.id));
    final stats = statsAsync.asData?.value;
    final publishDisabled =
        formState.isSubmitting ||
        (stats != null && !stats.canPublish && !course.isPublished);
    final deleteDisabled =
        formState.isSubmitting || (stats != null && !stats.canDelete);
    final publishTooltip = course.isPublished
        ? 'Unpublish'
        : stats != null && !stats.canPublish
        ? 'Add at least one lecture before publishing'
        : 'Publish';
    final deleteTooltip = stats != null && !stats.canDelete
        ? 'Cannot delete a course with content or student-linked batches'
        : 'Delete';

    return Row(
      children: [
        // Edit
        _IconAction(
          icon: Icons.edit_rounded,
          color: AppColors.primary,
          tooltip: 'Edit',
          onTap: () => context.push(
            TeacherCourseRoutes.editCoursePath(course.id),
            extra: course,
          ),
        ),
        const SizedBox(width: 4),

        // Students
        _IconAction(
          icon: Icons.people_rounded,
          color: AppColors.info,
          tooltip: 'Students',
          onTap: () => context.push(
            TeacherCourseRoutes.courseStudentsPath(course.id),
            extra: course.title,
          ),
        ),
        const SizedBox(width: 4),

        // Publish toggle
        _IconAction(
          icon: course.isPublished
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          color: course.isPublished ? AppColors.warning : AppColors.success,
          tooltip: publishTooltip,
          onTap: publishDisabled
              ? null
              : () async {
                  await notifier.togglePublish(
                    course.id,
                    publish: !course.isPublished,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          course.isPublished
                              ? 'Course unpublished'
                              : 'Course published',
                        ),
                      ),
                    );
                  }
                },
        ),
        const SizedBox(width: 4),

        // Delete
        _IconAction(
          icon: Icons.delete_outline_rounded,
          color: AppColors.error,
          tooltip: deleteTooltip,
          onTap: deleteDisabled
              ? null
              : () async {
                  final ok = await _confirmDelete(context, course.title);
                  if (ok == true && context.mounted) {
                    await notifier.delete(course.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Course deleted')),
                      );
                    }
                  }
                },
        ),
      ],
    );
  }

  Future<bool?> _confirmDelete(BuildContext ctx, String title) =>
      showDialog<bool>(
        context: ctx,
        builder: (dlg) => AlertDialog(
          title: const Text('Delete course?'),
          content: Text(
            'Delete "$title" and all its content? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlg, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dlg, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final bool published;
  const _StatusChip({required this.published});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _WarningChip extends StatelessWidget {
  final String label;

  const _WarningChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.warning.withAlpha(20),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.warning.withAlpha(80)),
    ),
    child: Text(
      label,
      style: AppTextStyles.bodyMedium.copyWith(
        fontSize: 11,
        color: AppColors.warning,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.border.withAlpha(40)
              : color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? AppColors.textHint : color,
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.menu_book_rounded, size: 72, color: AppColors.border),
        const SizedBox(height: 16),
        Text('No courses yet', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Create your first course to get started.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onCreateTap,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Course'),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Route path constants for this module
// ─────────────────────────────────────────────────────────────
class TeacherCourseRoutes {
  TeacherCourseRoutes._();
  static const String courseList = '/teacher/courses';
  static const String createCourse = '/teacher/courses/create';
  static const String editCourse = '/teacher/courses/:courseId/edit';
  static const String courseStudents = '/teacher/courses/:courseId/students';

  static String editCoursePath(String id) => '/teacher/courses/$id/edit';
  static String courseStudentsPath(String id) =>
      '/teacher/courses/$id/students';
}
