// ─────────────────────────────────────────────────────────────
//  search_screen.dart  –  Search tab
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/course_service.dart';

// ── Search state ──────────────────────────────────────────────
final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final _selectedCategoryProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final _searchResultsProvider =
    FutureProvider.autoDispose<List<CourseModel>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  final category = ref.watch(_selectedCategoryProvider);

  if (query.isEmpty && category == null) {
    return ref.watch(courseServiceProvider).fetchCourses(publishedOnly: true);
  }

  final all =
      await ref.watch(courseServiceProvider).fetchCourses(publishedOnly: true);

  return all.where((c) {
    final matchQuery = query.isEmpty ||
        c.title.toLowerCase().contains(query.toLowerCase()) ||
        (c.teacherName?.toLowerCase().contains(query.toLowerCase()) ?? false);
    final matchCat =
        category == null || c.categoryTag?.toLowerCase() == category;
    return matchQuery && matchCat;
  }).toList();
});

const _kCategories = [
  'Physics',
  'Chemistry',
  'Maths',
  'Biology',
  'English',
  'Computer',
];

// ── Screen ────────────────────────────────────────────────────
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final selectedCat = ref.watch(_selectedCategoryProvider);
    final resultsAsync = ref.watch(_searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Courses'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _ctrl,
                  onChanged: (v) =>
                      ref.read(_searchQueryProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search courses, teachers…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _ctrl.clear();
                              ref
                                  .read(_searchQueryProvider.notifier)
                                  .state = '';
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 10),
                // Category chips
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CatChip(
                        label: 'All',
                        selected: selectedCat == null,
                        onTap: () => ref
                            .read(_selectedCategoryProvider.notifier)
                            .state = null,
                      ),
                      ..._kCategories.map(
                        (cat) => _CatChip(
                          label: cat,
                          selected: selectedCat == cat.toLowerCase(),
                          onTap: () => ref
                              .read(_selectedCategoryProvider.notifier)
                              .state = cat.toLowerCase(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Search failed', style: AppTextStyles.bodyLarge),
              TextButton(
                onPressed: () =>
                    ref.invalidate(_searchResultsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text('No results found',
                      style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    query.isNotEmpty
                        ? 'Try a different keyword'
                        : 'No courses in this category yet',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (_, i) => _SearchCourseCard(
              course: courses[i],
              onTap: () => context
                  .push(AppRoutes.courseDetailPath(courses[i].id)),
            ),
          );
        },
      ),
    );
  }
}

// ── Category Chip ─────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color:
                selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search Course Card ────────────────────────────────────────
class _SearchCourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const _SearchCourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: course.thumbnailUrl != null
                      ? DecorationImage(
                          image: NetworkImage(course.thumbnailUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: course.thumbnailUrl == null
                    ? const Icon(Icons.play_circle_rounded,
                        color: AppColors.primary, size: 32)
                    : null,
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (course.categoryTag != null)
                      Text(
                        course.categoryTag!.toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    Text(
                      course.title,
                      style: AppTextStyles.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.teacherName ?? 'Instructor',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.warning, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          course.rating?.toStringAsFixed(1) ?? '—',
                          style: AppTextStyles.labelSmall,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          course.price == 0
                              ? 'Free'
                              : '₹${course.price.toStringAsFixed(0)}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: course.price == 0
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
