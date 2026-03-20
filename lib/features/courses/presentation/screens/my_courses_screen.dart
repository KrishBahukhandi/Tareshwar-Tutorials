// ─────────────────────────────────────────────────────────────
//  my_courses_screen.dart  –  "My Courses" tab
//  Shows enrolled courses with per-course progress and quick
//  navigation to the lecture player / course detail.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart';
import '../../../../shared/services/progress_service.dart';

// ── Local state: tab filter ───────────────────────────────────
enum _MyCoursesFilter { all, inProgress, completed }

final _myCoursesFilterProvider = StateProvider.autoDispose<_MyCoursesFilter>(
  (_) => _MyCoursesFilter.all,
);

// ─────────────────────────────────────────────────────────────
class MyCoursesScreen extends ConsumerWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolledAsync = ref.watch(enrolledCoursesProvider);
    final filter = ref.watch(_myCoursesFilterProvider);
    final progressMapAsync = ref.watch(studentAllCourseProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            title: const Text('My Courses'),
            centerTitle: false,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _FilterChips(
                selected: filter,
                onSelected: (f) =>
                    ref.read(_myCoursesFilterProvider.notifier).state = f,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search',
                onPressed: () => context.go(AppRoutes.search),
              ),
            ],
          ),

          // ── Course list ────────────────────────────────────
          enrolledAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                subtitle: e.toString(),
                iconColor: AppColors.error,
              ),
            ),
            data: (courses) {
              final progressMap =
                  progressMapAsync.valueOrNull ??
                  const <String, CourseProgress>{};
              final filtered = _applyFilter(courses, filter, progressMap);
              if (filtered.isEmpty) {
                return SliverFillRemaining(child: _EmptyState(filter: filter));
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CourseProgressCard(
                    course: filtered[i],
                    progress: progressMap[filtered[i].id]?.percent ?? 0,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // FAB to explore more courses
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.search),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Explore More'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  List<CourseModel> _applyFilter(
    List<CourseModel> courses,
    _MyCoursesFilter f,
    Map<String, CourseProgress> progressMap,
  ) {
    switch (f) {
      case _MyCoursesFilter.all:
        return courses;
      case _MyCoursesFilter.inProgress:
        return courses.where((c) {
          final progress = progressMap[c.id]?.percent ?? 0;
          return progress > 0 && progress < 1.0;
        }).toList();
      case _MyCoursesFilter.completed:
        return courses
            .where((c) => (progressMap[c.id]?.percent ?? 0) >= 1.0)
            .toList();
    }
  }
}

// ── Filter chips row ──────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final _MyCoursesFilter selected;
  final ValueChanged<_MyCoursesFilter> onSelected;
  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _MyCoursesFilter.values.map((f) {
            final label = switch (f) {
              _MyCoursesFilter.all => 'All',
              _MyCoursesFilter.inProgress => 'In Progress',
              _MyCoursesFilter.completed => 'Completed',
            };
            final isSelected = selected == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => onSelected(f),
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundColor: AppColors.surface,
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Course Progress Card ──────────────────────────────────────
class _CourseProgressCard extends StatelessWidget {
  final CourseModel course;
  final double progress; // 0.0–1.0

  const _CourseProgressCard({required this.course, required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    final isCompleted = progress >= 1.0;
    final progressColor = isCompleted ? AppColors.success : AppColors.primary;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.courseDetailPath(course.id)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / Icon
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: course.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        course.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + completed badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          course.title,
                          style: AppTextStyles.labelLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 6),
                        AppBadge(
                          label: '✓ Done',
                          color: AppColors.success,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Teacher name
                  if (course.teacherName != null)
                    Text(
                      course.teacherName!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 10),

                  // Progress bar
                  LinearPercentIndicator(
                    padding: EdgeInsets.zero,
                    lineHeight: 7,
                    percent: progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.surfaceVariant,
                    progressColor: progressColor,
                    barRadius: const Radius.circular(4),
                    animation: true,
                    animationDuration: 700,
                  ),
                  const SizedBox(height: 6),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$pct% complete',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isCompleted
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isCompleted ? 'Review →' : 'Continue →',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _MyCoursesFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isAll = filter == _MyCoursesFilter.all;
    return AppEmptyState(
      icon: Icons.library_books_outlined,
      title: isAll ? 'No courses yet' : 'None found',
      subtitle: isAll
          ? 'Enroll in a course to start learning!'
          : 'Try a different filter.',
      actionLabel: isAll ? 'Browse Courses' : null,
      onAction: isAll ? () => context.go(AppRoutes.search) : null,
    );
  }
}
