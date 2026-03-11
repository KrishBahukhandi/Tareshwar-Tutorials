// ─────────────────────────────────────────────────────────────
//  admin_courses_screen.dart  –  Courses management
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/services/admin_service.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_top_bar.dart';

class AdminCoursesScreen extends ConsumerStatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  ConsumerState<AdminCoursesScreen> createState() =>
      _AdminCoursesScreenState();
}

class _AdminCoursesScreenState
    extends ConsumerState<AdminCoursesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(adminCoursesProvider);
    final search = ref.watch(adminCourseSearchProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: AdminTableCard(
          title: 'Courses',
          headerActions: [
            _SearchField(
              controller: _searchCtrl,
              onChanged: (v) => ref
                  .read(adminCourseSearchProvider.notifier)
                  .state = v,
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              onPressed: () => ref.invalidate(adminCoursesProvider),
            ),
          ],
          child: coursesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Error: $e',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.error)),
            ),
            data: (courses) {
              final filtered = search.isEmpty
                  ? courses
                  : courses
                      .where((c) =>
                          c.title
                              .toLowerCase()
                              .contains(search.toLowerCase()) ||
                          c.teacherName
                              .toLowerCase()
                              .contains(search.toLowerCase()))
                      .toList();

              if (filtered.isEmpty) {
                return const _EmptyState(
                    message: 'No courses found');
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth:
                        MediaQuery.sizeOf(context).width - 48,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        AppColors.surfaceVariant),
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 52,
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('Title')),
                      DataColumn(label: Text('Teacher')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Lectures')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Created')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered.asMap().entries.map((e) {
                      final i = e.key;
                      final c = e.value;
                      return DataRow(cells: [
                        DataCell(Text('${i + 1}',
                            style: AppTextStyles.labelMedium)),
                        DataCell(
                          Tooltip(
                            message: c.title,
                            child: SizedBox(
                              width: 180,
                              child: Text(c.title,
                                  style: AppTextStyles.labelLarge,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataCell(Text(c.teacherName,
                            style: AppTextStyles.bodySmall)),
                        DataCell(Text(
                          c.price == 0
                              ? 'Free'
                              : '₹${c.price.toStringAsFixed(0)}',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: c.price == 0
                                ? AppColors.success
                                : AppColors.textPrimary,
                          ),
                        )),
                        DataCell(Text('${c.totalLectures}',
                            style: AppTextStyles.bodySmall)),
                        DataCell(_PublishBadge(
                            published: c.isPublished)),
                        DataCell(Text(
                          _fmt(c.createdAt),
                          style: AppTextStyles.bodySmall,
                        )),
                        DataCell(_CourseActions(
                          course: c,
                          onToggle: () async {
                            await ref
                                .read(adminServiceProvider)
                                .toggleCoursePublish(
                                    c.id, !c.isPublished);
                            ref.invalidate(adminCoursesProvider);
                          },
                          onDelete: () =>
                              _confirmDelete(context, ref, c),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AdminCourseRow course) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text(
            'Delete "${course.title}"? All batches, lectures and enrollments will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(adminServiceProvider).deleteCourse(course.id);
      ref.invalidate(adminCoursesProvider);
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────
String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _PublishBadge extends StatelessWidget {
  final bool published;
  const _PublishBadge({required this.published});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: published
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.textHint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        published ? 'Published' : 'Draft',
        style: AppTextStyles.labelSmall.copyWith(
            color: published
                ? AppColors.success
                : AppColors.textSecondary,
            fontSize: 11),
      ),
    );
  }
}

class _CourseActions extends StatelessWidget {
  final AdminCourseRow course;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CourseActions({
    required this.course,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: course.isPublished ? 'Unpublish' : 'Publish',
          icon: Icon(
            course.isPublished
                ? Icons.unpublished_rounded
                : Icons.publish_rounded,
            size: 18,
            color: course.isPublished
                ? AppColors.warning
                : AppColors.success,
          ),
          onPressed: onToggle,
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded,
              size: 18, color: AppColors.error),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search…',
          hintStyle: AppTextStyles.bodySmall,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textHint),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(message,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
