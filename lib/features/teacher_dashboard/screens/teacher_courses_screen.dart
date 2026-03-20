// ─────────────────────────────────────────────────────────────
//  teacher_courses_screen.dart
//  Teacher: list own courses, create new, toggle publish/draft,
//  navigate to upload content.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/course_service.dart';
import '../../teacher_courses/providers/teacher_course_providers.dart';
import '../providers/teacher_dashboard_providers.dart';
import '../widgets/teacher_course_tile.dart';

class TeacherCoursesScreen extends ConsumerStatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  ConsumerState<TeacherCoursesScreen> createState() =>
      _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends ConsumerState<TeacherCoursesScreen> {
  String _filter = 'all'; // all | published | draft

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(teacherCoursesListProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Courses', style: AppTextStyles.displaySmall),
                  const SizedBox(height: 2),
                  Text(
                    'Manage and publish your course catalogue.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Course'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Filter tabs ─────────────────────────────────
          _FilterBar(
            current: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),

          // ── List ────────────────────────────────────────
          Expanded(
            child: coursesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '$e',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              data: (courses) {
                final filtered = _applyFilter(courses);
                if (filtered.isEmpty) {
                  return _EmptyState(filter: _filter);
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => TeacherCourseTile(
                    course: filtered[i],
                    onUpload: () =>
                        ref
                                .read(teacherSelectedSectionProvider.notifier)
                                .state =
                            TeacherSection.uploadContent,
                    onTogglePublish: () => _togglePublish(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CourseModel> _applyFilter(List<CourseModel> courses) {
    switch (_filter) {
      case 'published':
        return courses.where((c) => c.isPublished).toList();
      case 'draft':
        return courses.where((c) => !c.isPublished).toList();
      default:
        return courses;
    }
  }

  Future<void> _togglePublish(CourseModel course) async {
    try {
      await ref
          .read(courseFormProvider.notifier)
          .togglePublish(course.id, publish: !course.isPublished);
      ref.invalidate(teacherCoursesListProvider);
      ref.invalidate(teacherDashboardStatsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCreateDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    final tagCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Course'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Course Title *',
                    prefixIcon: Icon(Icons.menu_book_rounded),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Price (₹)',
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: tagCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category Tag',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _createCourse(
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text) ?? 0,
                categoryTag: tagCtrl.text.trim().isNotEmpty
                    ? tagCtrl.text.trim()
                    : null,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCourse({
    required String title,
    required String description,
    required double price,
    String? categoryTag,
  }) async {
    try {
      final uid = ref.read(authServiceProvider).currentAuthUser?.id;
      if (uid == null) return;
      await ref
          .read(courseServiceProvider)
          .createCourse(
            title: title,
            description: description,
            teacherId: uid,
            price: price,
            categoryTag: categoryTag,
          );
      ref.invalidate(teacherCoursesListProvider);
      ref.invalidate(teacherDashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('all', 'All Courses'),
      ('published', 'Published'),
      ('draft', 'Drafts'),
    ];
    return Row(
      children: filters.map((f) {
        final active = current == f.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(f.$2),
            selected: active,
            onSelected: (_) => onChanged(f.$1),
            selectedColor: AppColors.primary.withValues(alpha: 0.12),
            labelStyle: AppTextStyles.labelMedium.copyWith(
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            showCheckmark: false,
            side: BorderSide(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.menu_book_outlined,
          size: 64,
          color: AppColors.textHint,
        ),
        const SizedBox(height: 12),
        Text(
          filter == 'all'
              ? 'No courses yet.\nTap "New Course" to get started.'
              : 'No ${filter == "published" ? "published" : "draft"} courses.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
