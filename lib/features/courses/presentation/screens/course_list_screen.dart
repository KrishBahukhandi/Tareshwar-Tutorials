// ─────────────────────────────────────────────────────────────
//  course_list_screen.dart  –  Browse all published courses
//  with search + category filter + grid layout.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../providers/course_providers.dart';
import '../widgets/course_card.dart';

// ── Local state providers ─────────────────────────────────────
final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final _categoryFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

// ─────────────────────────────────────────────────────────────
class CourseListScreen extends ConsumerWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(allCoursesProvider);
    final query = ref.watch(_searchQueryProvider);
    final category = ref.watch(_categoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ─────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text('All Courses'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _SearchBar(
                  onChanged: (v) =>
                      ref.read(_searchQueryProvider.notifier).state = v,
                ),
              ),
            ),
          ),

          // ── Category chips ───────────────────────────────
          SliverToBoxAdapter(
            child: coursesAsync.maybeWhen(
              data: (courses) {
                final categories = courses
                    .map((c) => c.categoryTag)
                    .whereType<String>()
                    .toSet()
                    .toList()
                  ..sort();
                if (categories.isEmpty) return const SizedBox.shrink();
                return _CategoryChips(
                  categories: categories,
                  selected: category,
                  onSelect: (cat) =>
                      ref.read(_categoryFilterProvider.notifier).state =
                          cat == category ? null : cat,
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // ── Course grid ──────────────────────────────────
          coursesAsync.when(
            loading: () => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: _gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => const CourseCardShimmer(),
                  childCount: 6,
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorView(message: e.toString()),
            ),
            data: (courses) {
              final filtered = _filter(courses, query, category);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyView(hasQuery: query.isNotEmpty),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: _gridDelegate,
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => CourseCard(
                      course: filtered[i],
                      onTap: () => context.push(
                          AppRoutes.courseDetailPath(filtered[i].id)),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.72,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  );

  List<CourseModel> _filter(
      List<CourseModel> courses, String query, String? category) {
    var list = courses;
    if (category != null) {
      list = list.where((c) => c.categoryTag == category).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where((c) =>
              c.title.toLowerCase().contains(q) ||
              (c.teacherName?.toLowerCase().contains(q) ?? false) ||
              (c.categoryTag?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }
}

// ─────────────────────────────────────────────────────────────
//  Search bar
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Search courses, teachers…',
        hintStyle:
            AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textHint, size: 20),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.border.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Category filter chips
// ─────────────────────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: categories
            .map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected == cat,
                    onSelected: (_) => onSelect(cat),
                    selectedColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: AppTextStyles.labelSmall.copyWith(
                      color: selected == cat
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    side: BorderSide(
                      color: selected == cat
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 0),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty & error states
// ─────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final bool hasQuery;
  const _EmptyView({this.hasQuery = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery
                  ? Icons.search_off_rounded
                  : Icons.library_books_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No courses found' : 'No courses available',
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term or category.'
                  : 'Check back later for new courses.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Something went wrong', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
