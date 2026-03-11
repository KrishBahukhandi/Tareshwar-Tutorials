// ─────────────────────────────────────────────────────────────
//  admin_course_list_screen.dart
//  Admin course management: search, filter, create, edit,
//  delete, toggle published, and tap-to-detail.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../data/admin_courses_service.dart';
import '../providers/admin_courses_providers.dart';
import '../widgets/admin_courses_widgets.dart';

// ─────────────────────────────────────────────────────────────
class AdminCourseListScreen extends ConsumerStatefulWidget {
  const AdminCourseListScreen({super.key});

  @override
  ConsumerState<AdminCourseListScreen> createState() =>
      _AdminCourseListScreenState();
}

class _AdminCourseListScreenState
    extends ConsumerState<AdminCourseListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync  = ref.watch(adminCourseListProvider);
    final filter        = ref.watch(adminCoursePublishedFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            _Header(
              searchCtrl: _searchCtrl,
              publishFilter: filter,
              onSearch: (v) => ref
                  .read(adminCourseListSearchProvider.notifier)
                  .state = v,
              onFilterChanged: (v) => ref
                  .read(adminCoursePublishedFilterProvider.notifier)
                  .state = v,
              onRefresh: () =>
                  ref.invalidate(adminCourseListProvider),
              onCreateCourse: () =>
                  context.push(AppRoutes.adminCreateCourse),
            ),
            const SizedBox(height: 20),

            // ── Table card ───────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: coursesAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => _ErrorView(
                      message: e.toString(),
                      onRetry: () =>
                          ref.invalidate(adminCourseListProvider),
                    ),
                    data: (courses) => courses.isEmpty
                        ? AdminCoursesEmptyState(
                            message: filter == null
                                ? 'No courses yet.\nCreate your first course to get started.'
                                : filter
                                    ? 'No published courses found.'
                                    : 'No draft courses found.',
                          )
                        : _CourseTable(
                            courses: courses,
                            onTap: (c) => context.push(
                              AppRoutes.adminCourseDetailPath(c.id),
                            ),
                            onEdit: (c) => context.push(
                              AppRoutes.adminEditCoursePath(c.id),
                              extra: c,
                            ),
                            onTogglePublish: (c) =>
                                _togglePublish(context, ref, c),
                            onDelete: (c) =>
                                _deleteCourse(context, ref, c),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────
  Future<void> _togglePublish(
    BuildContext ctx,
    WidgetRef ref,
    AdminCourseListItem c,
  ) async {
    final action = c.isPublished ? 'Unpublish' : 'Publish';
    final confirmed = await confirmCourseAction(
      ctx,
      title: '$action Course',
      message: c.isPublished
          ? '"${c.title}" will be hidden from students.'
          : 'Make "${c.title}" visible to students?',
      confirmLabel: action,
      confirmColor:
          c.isPublished ? AppColors.warning : AppColors.success,
    );
    if (!confirmed) return;
    await ref
        .read(adminCoursesServiceProvider)
        .togglePublished(c.id, publish: !c.isPublished);
    ref.invalidate(adminCourseListProvider);
  }

  Future<void> _deleteCourse(
    BuildContext ctx,
    WidgetRef ref,
    AdminCourseListItem c,
  ) async {
    final confirmed = await confirmCourseAction(
      ctx,
      title: 'Delete Course',
      message:
          'Permanently delete "${c.title}"?\n'
          'All batches, enrollments, and content will be removed. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await ref
        .read(adminCoursesServiceProvider)
        .deleteCourse(c.id);
    ref.invalidate(adminCourseListProvider);
  }
}

// ─────────────────────────────────────────────────────────────
//  Course data table
// ─────────────────────────────────────────────────────────────
class _CourseTable extends StatelessWidget {
  final List<AdminCourseListItem> courses;
  final ValueChanged<AdminCourseListItem> onTap;
  final ValueChanged<AdminCourseListItem> onEdit;
  final ValueChanged<AdminCourseListItem> onTogglePublish;
  final ValueChanged<AdminCourseListItem> onDelete;

  const _CourseTable({
    required this.courses,
    required this.onTap,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 48,
          ),
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(AppColors.surfaceVariant),
            headingTextStyle: AppTextStyles.labelMedium
                .copyWith(fontWeight: FontWeight.w600),
            dataRowMinHeight: 64,
            dataRowMaxHeight: 64,
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Course')),
              DataColumn(label: Text('Teacher')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Batches')),
              DataColumn(label: Text('Students')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('Actions')),
            ],
            rows: courses.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return DataRow(
                onSelectChanged: (_) => onTap(c),
                cells: [
                  DataCell(Text('${i + 1}',
                      style: AppTextStyles.labelMedium)),
                  // Course title + thumbnail + category
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CourseThumbnail(url: c.thumbnailUrl),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 180,
                              child: Text(
                                c.title,
                                style: AppTextStyles.labelLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (c.categoryTag != null)
                              CategoryBadge(category: c.categoryTag),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              AppColors.info.withValues(alpha: 0.15),
                          child: Text(
                            c.teacherName.isNotEmpty
                                ? c.teacherName[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.info),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(c.teacherName,
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  DataCell(PriceChip(price: c.price)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_rounded,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text('${c.totalBatches}',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline_rounded,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text('${c.totalEnrollments}',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  DataCell(
                      CourseStatusBadge(published: c.isPublished)),
                  DataCell(Text(fmtCourseDate(c.createdAt),
                      style: AppTextStyles.bodySmall)),
                  DataCell(_CourseActionMenu(
                    course: c,
                    onTap: () => onTap(c),
                    onEdit: () => onEdit(c),
                    onTogglePublish: () => onTogglePublish(c),
                    onDelete: () => onDelete(c),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Action menu for each row
// ─────────────────────────────────────────────────────────────
class _CourseActionMenu extends StatelessWidget {
  final AdminCourseListItem course;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onDelete;

  const _CourseActionMenu({
    required this.course,
    required this.onTap,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View detail
        IconButton(
          tooltip: 'View Details',
          icon: const Icon(Icons.open_in_new_rounded,
              size: 17, color: AppColors.info),
          onPressed: onTap,
        ),
        // Edit
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined,
              size: 17, color: AppColors.primary),
          onPressed: onEdit,
        ),
        // Publish / Unpublish
        IconButton(
          tooltip: course.isPublished ? 'Unpublish' : 'Publish',
          icon: Icon(
            course.isPublished
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 17,
            color: course.isPublished
                ? AppColors.warning
                : AppColors.success,
          ),
          onPressed: onTogglePublish,
        ),
        // Delete
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded,
              size: 17, color: AppColors.error),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Header row (title + search + filters + create button)
// ─────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final TextEditingController searchCtrl;
  final bool? publishFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<bool?> onFilterChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCreateCourse;

  const _Header({
    required this.searchCtrl,
    required this.publishFilter,
    required this.onSearch,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onCreateCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon badge
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book_rounded,
              color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Courses',
                  style: AppTextStyles.headlineLarge),
              Text('Manage all platform courses',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),

        // Filter chips
        _FilterChip(
          label: 'All',
          selected: publishFilter == null,
          onTap: () => onFilterChanged(null),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: 'Published',
          selected: publishFilter == true,
          color: AppColors.success,
          onTap: () => onFilterChanged(true),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: 'Drafts',
          selected: publishFilter == false,
          color: AppColors.warning,
          onTap: () => onFilterChanged(false),
        ),
        const SizedBox(width: 16),

        // Search
        AdminCourseSearchBar(
          controller: searchCtrl,
          onChanged: onSearch,
        ),
        const SizedBox(width: 12),

        // Refresh
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          onPressed: onRefresh,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side:
                const BorderSide(color: AppColors.surfaceVariant),
          ),
        ),
        const SizedBox(width: 10),

        // Create course
        FilledButton.icon(
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Course'),
          onPressed: onCreateCourse,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? c : AppColors.textSecondary,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Error view
// ─────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 40),
        const SizedBox(height: 12),
        Text('Failed to load courses',
            style: AppTextStyles.headlineSmall),
        const SizedBox(height: 6),
        Text(message,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          onPressed: onRetry,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary),
        ),
      ],
    );
  }
}
