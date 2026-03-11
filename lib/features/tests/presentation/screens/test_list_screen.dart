// ─────────────────────────────────────────────────────────────
//  test_list_screen.dart  –  Browse & filter all MCQ tests
//  • Search by title
//  • Filter by status (all / attempted / not-attempted)
//  • Tap → TestInstructionScreen
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart';
import '../../../../shared/services/test_service.dart';

// ── Local state ───────────────────────────────────────────────
enum _TLFilter { all, notAttempted, attempted }

final _tlFilterProvider =
    StateProvider.autoDispose<_TLFilter>((_) => _TLFilter.all);

final _tlSearchProvider = StateProvider.autoDispose<String>((_) => '');

/// Optional: filter by courseId when navigated-to with one
final _tlCourseIdProvider = StateProvider.autoDispose<String?>((_) => null);

final _tlTestsProvider =
    FutureProvider.autoDispose<List<TestModel>>((ref) async {
  final courseId = ref.watch(_tlCourseIdProvider);
  return ref
      .watch(testServiceProvider)
      .fetchTests(courseId: courseId);
});

// ─────────────────────────────────────────────────────────────
class TestListScreen extends ConsumerWidget {
  final String? courseId;
  const TestListScreen({super.key, this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inject courseId if provided
    if (courseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_tlCourseIdProvider.notifier).state = courseId;
      });
    }

    final filter = ref.watch(_tlFilterProvider);
    final search = ref.watch(_tlSearchProvider);
    final testsAsync = ref.watch(_tlTestsProvider);
    final attemptsAsync = ref.watch(studentAttemptsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tests'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'My Performance',
            onPressed: () =>
                context.push(AppRoutes.performanceAnalysisPath()),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────
          _SearchBar(
            onChanged: (v) =>
                ref.read(_tlSearchProvider.notifier).state = v,
          ),

          // ── Filter chips ─────────────────────────────────
          _FilterRow(
            selected: filter,
            onSelected: (f) =>
                ref.read(_tlFilterProvider.notifier).state = f,
          ),

          // ── List ─────────────────────────────────────────
          Expanded(
            child: testsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                subtitle: e.toString(),
                iconColor: AppColors.error,
              ),
              data: (tests) {
                final attempted = attemptsAsync.maybeWhen(
                  data: (list) => list.map((a) => a.testId).toSet(),
                  orElse: () => <String>{},
                );

                final filtered = _applyFilters(
                  tests: tests,
                  attempted: attempted,
                  filter: filter,
                  search: search,
                );

                if (filtered.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'No tests found',
                    subtitle: 'Try a different filter or check back later.',
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: 12),
                  itemBuilder: (_, i) => _TestListCard(
                    test: filtered[i],
                    isAttempted: attempted.contains(filtered[i].id),
                    attemptModel: attemptsAsync.maybeWhen(
                      data: (list) {
                        try {
                          return list.firstWhere(
                              (a) => a.testId == filtered[i].id);
                        } catch (_) {
                          return null;
                        }
                      },
                      orElse: () => null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TestModel> _applyFilters({
    required List<TestModel> tests,
    required Set<String> attempted,
    required _TLFilter filter,
    required String search,
  }) {
    var result = tests;

    // Status filter
    switch (filter) {
      case _TLFilter.attempted:
        result = result.where((t) => attempted.contains(t.id)).toList();
        break;
      case _TLFilter.notAttempted:
        result = result.where((t) => !attempted.contains(t.id)).toList();
        break;
      case _TLFilter.all:
        break;
    }

    // Search
    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      result =
          result.where((t) => t.title.toLowerCase().contains(q)).toList();
    }

    return result;
  }
}

// ── Search bar ────────────────────────────────────────────────
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: TextField(
        controller: _ctrl,
        onChanged: (v) {
          setState(() {});
          widget.onChanged(v);
        },
        decoration: InputDecoration(
          hintText: 'Search tests…',
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textHint, size: 20),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textHint, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: AppRadius.lgAll,
            borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.lgAll,
            borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.lgAll,
            borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final _TLFilter selected;
  final ValueChanged<_TLFilter> onSelected;
  const _FilterRow(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const labels = {
      _TLFilter.all: 'All',
      _TLFilter.notAttempted: 'Not Attempted',
      _TLFilter.attempted: 'Attempted',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _TLFilter.values.map((f) {
            final isSelected = selected == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ChoiceChip(
                  label: Text(labels[f]!),
                  selected: isSelected,
                  onSelected: (_) => onSelected(f),
                  selectedColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  backgroundColor: AppColors.surface,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Test card ─────────────────────────────────────────────────
class _TestListCard extends StatelessWidget {
  final TestModel test;
  final bool isAttempted;
  final TestAttemptModel? attemptModel;

  const _TestListCard({
    required this.test,
    required this.isAttempted,
    this.attemptModel,
  });

  @override
  Widget build(BuildContext context) {
    final pct = attemptModel?.percentage;
    final statusColor =
        isAttempted ? AppColors.success : AppColors.warning;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          context.push(AppRoutes.testInstructionPath(test.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isAttempted
                        ? Icons.check_circle_rounded
                        : Icons.quiz_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Title + status badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.title,
                        style: AppTextStyles.labelLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      AppBadge(
                        label: isAttempted
                            ? 'Attempted'
                            : 'Not Attempted',
                        color: statusColor,
                        icon: isAttempted
                            ? Icons.check_rounded
                            : Icons.radio_button_unchecked_rounded,
                      ),
                    ],
                  ),
                ),

                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.5),
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),

          // Meta chips row
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 10, AppSpacing.md, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: Icons.timer_outlined,
                      label: '${test.durationMinutes} min',
                    ),
                    _MetaChip(
                      icon: Icons.help_outline_rounded,
                      label: '${test.totalMarks} marks',
                    ),
                    if (test.negativeMarks > 0)
                      _MetaChip(
                        icon: Icons.remove_circle_outline_rounded,
                        label: '-${test.negativeMarks} neg',
                        color: AppColors.error,
                      ),
                    if (pct != null)
                      _MetaChip(
                        icon: Icons.analytics_outlined,
                        label:
                            'Score: ${pct.toStringAsFixed(1)}%',
                        color: pct >= 60
                            ? AppColors.success
                            : AppColors.error,
                      ),
                  ],
                ),

                // Previous score bar
                if (pct != null) ...[
                  const SizedBox(height: 10),
                  AppProgressBar(
                    value: (pct / 100).clamp(0.0, 1.0),
                    color: pct >= 60
                        ? AppColors.success
                        : AppColors.error,
                    height: 6,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MetaChip(
      {required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.bodySmall.copyWith(color: c)),
      ],
    );
  }
}
