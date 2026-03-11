// ─────────────────────────────────────────────────────────────
//  tests_tab_screen.dart  –  "Tests" tab
//  Displays all available tests grouped by status, with quick
//  launch and history access.
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

// ── Local state providers ──────────────────────────────────────
enum _TestsFilter { all, upcoming, attempted }

final _testsFilterProvider =
    StateProvider.autoDispose<_TestsFilter>((_) => _TestsFilter.all);

/// All tests regardless of courseId (pass null to fetch everything)
final _allTestsProvider =
    FutureProvider.autoDispose<List<TestModel>>((ref) async {
  return ref.watch(testServiceProvider).fetchTests();
});

// ─────────────────────────────────────────────────────────────
class TestsTabScreen extends ConsumerWidget {
  const TestsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_testsFilterProvider);
    final testsAsync = ref.watch(_allTestsProvider);
    final attemptsAsync = ref.watch(studentAttemptsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            title: const Text('Tests'),
            centerTitle: false,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.bar_chart_rounded),
                tooltip: 'My Performance',
                onPressed: () =>
                    context.push(AppRoutes.performanceAnalysisPath()),
              ),
              IconButton(
                icon: const Icon(Icons.list_rounded),
                tooltip: 'All Tests',
                onPressed: () => context.push(AppRoutes.testListPath()),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _FilterChips(
                selected: filter,
                onSelected: (f) =>
                    ref.read(_testsFilterProvider.notifier).state = f,
              ),
            ),
          ),

          // ── Summary cards row ──────────────────────────────
          SliverToBoxAdapter(
            child: attemptsAsync.maybeWhen(
              data: (attempts) => _SummaryRow(
                attempted: attempts.length,
                bestScore: attempts.isEmpty
                    ? null
                    : attempts
                        .map((a) => a.percentage)
                        .reduce((a, b) => a > b ? a : b),
                avgScore: attempts.isEmpty
                    ? null
                    : attempts
                            .map((a) => a.percentage)
                            .reduce((a, b) => a + b) /
                        attempts.length,
              ),
              orElse: () => const _SummaryRow(
                  attempted: 0,
                  bestScore: null,
                  avgScore: null),
            ),
          ),

          // ── Test list ──────────────────────────────────────
          testsAsync.when(
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
            data: (tests) {
              final attempted = attemptsAsync.maybeWhen(
                data: (list) =>
                    list.map((a) => a.testId).toSet(),
                orElse: () => <String>{},
              );

              final filtered = _applyFilter(tests, attempted, filter);
              if (filtered.isEmpty) {
                return const SliverFillRemaining(
                  child: AppEmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'No tests available',
                    subtitle:
                        'Tests linked to your courses will appear here.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (_, i) => _TestCard(
                    test: filtered[i],
                    isAttempted: attempted.contains(filtered[i].id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<TestModel> _applyFilter(
    List<TestModel> tests,
    Set<String> attempted,
    _TestsFilter f,
  ) {
    switch (f) {
      case _TestsFilter.all:
        return tests;
      case _TestsFilter.attempted:
        return tests.where((t) => attempted.contains(t.id)).toList();
      case _TestsFilter.upcoming:
        return tests.where((t) => !attempted.contains(t.id)).toList();
    }
  }
}

// ── Filter chips ──────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final _TestsFilter selected;
  final ValueChanged<_TestsFilter> onSelected;
  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _TestsFilter.values.map((f) {
            final label = switch (f) {
              _TestsFilter.all => 'All',
              _TestsFilter.upcoming => 'Not Attempted',
              _TestsFilter.attempted => 'Attempted',
            };
            final isSelected = selected == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => onSelected(f),
                selectedColor:
                    AppColors.primary.withValues(alpha: 0.12),
                backgroundColor: AppColors.surface,
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color:
                      isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final int attempted;
  final double? bestScore;
  final double? avgScore;
  const _SummaryRow({
    required this.attempted,
    required this.bestScore,
    required this.avgScore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.check_circle_outline_rounded,
            label: 'Attempted',
            value: '$attempted',
            gradient: AppColors.successGradient,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.emoji_events_outlined,
            label: 'Best',
            value: bestScore != null
                ? '${bestScore!.toStringAsFixed(0)}%'
                : '—',
            gradient: AppColors.primaryGradient,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.bar_chart_rounded,
            label: 'Average',
            value: avgScore != null
                ? '${avgScore!.toStringAsFixed(0)}%'
                : '—',
            gradient: AppColors.warningGradient,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final LinearGradient gradient;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        hasBorder: false,
        gradient: LinearGradient(
          colors: gradient.colors
              .map((c) => c.withValues(alpha: 0.12))
              .toList(),
          begin: gradient.begin,
          end: gradient.end,
        ),
        child: Column(
          children: [
            Icon(icon, color: gradient.colors.first, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: AppTextStyles.headlineMedium
                    .copyWith(color: gradient.colors.first)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Test card ─────────────────────────────────────────────────
class _TestCard extends StatelessWidget {
  final TestModel test;
  final bool isAttempted;
  const _TestCard({required this.test, required this.isAttempted});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isAttempted ? AppColors.success : AppColors.primary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => isAttempted
          ? context.push(AppRoutes.testResultPath(test.id))
          : context.push(AppRoutes.testInstructionPath(test.id)),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isAttempted
                  ? Icons.check_circle_rounded
                  : Icons.quiz_rounded,
              color: statusColor,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Content
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                      icon: Icons.timer_outlined,
                      label: '${test.durationMinutes} min',
                    ),
                    _InfoChip(
                      icon: Icons.star_outline_rounded,
                      label: '${test.totalMarks} marks',
                    ),
                    if (test.negativeMarks > 0)
                      _InfoChip(
                        icon: Icons.remove_circle_outline_rounded,
                        label: '-${test.negativeMarks}',
                        color: AppColors.error,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),
          // CTA pill
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isAttempted ? 'View' : 'Start',
              style: AppTextStyles.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip(
      {required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: AppTextStyles.bodySmall.copyWith(color: c)),
      ],
    );
  }
}
