// ─────────────────────────────────────────────────────────────
//  teacher_doubt_list_screen.dart
//  Teacher view: browse, search and filter all student doubts.
//  Filters: All / Pending / Resolved
//  Tap a card → TeacherDoubtDetailScreen
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/models.dart';
import '../providers/teacher_doubt_providers.dart';
import '../widgets/teacher_doubt_card.dart';

class TeacherDoubtListScreen extends ConsumerWidget {
  const TeacherDoubtListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doubtsAsync = ref.watch(teacherAllDoubtsProvider);
    final filter = ref.watch(teacherDoubtFilterProvider);
    final search = ref.watch(teacherDoubtSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // ── Search + filter ────────────────────────────
          _SearchBar(
            onChanged: (v) =>
                ref.read(teacherDoubtSearchProvider.notifier).state = v,
          ),
          _FilterRow(
            selected: filter,
            onSelected: (f) =>
                ref.read(teacherDoubtFilterProvider.notifier).state = f,
          ),

          // ── List ───────────────────────────────────────
          Expanded(
            child: doubtsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(message: e.toString()),
              data: (all) {
                final doubts = _filter(all, filter, search);

                if (doubts.isEmpty) {
                  return _EmptyState(filter: filter, search: search);
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(teacherAllDoubtsProvider),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: doubts.length,
                    separatorBuilder: (_, idx) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        TeacherDoubtCard(doubt: doubts[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DoubtModel> _filter(
    List<DoubtModel> all,
    TeacherDoubtFilter filter,
    String search,
  ) {
    var result = all;

    switch (filter) {
      case TeacherDoubtFilter.pending:
        result = result.where((d) => !d.isAnswered).toList();
        break;
      case TeacherDoubtFilter.resolved:
        result = result.where((d) => d.isAnswered).toList();
        break;
      case TeacherDoubtFilter.all:
        break;
    }

    final q = search.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((d) =>
              d.question.toLowerCase().contains(q) ||
              (d.studentName?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return result;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: const Text(
          'Student Doubts',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: TextField(
          controller: _ctrl,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: 'Search by student name or question…',
            prefixIcon:
                const Icon(Icons.search_rounded, color: AppColors.textHint),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textHint),
                    onPressed: () {
                      _ctrl.clear();
                      widget.onChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Filter chips
// ─────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final TeacherDoubtFilter selected;
  final ValueChanged<TeacherDoubtFilter> onSelected;
  const _FilterRow(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: TeacherDoubtFilter.values.map((f) {
            final active = selected == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.label),
                selected: active,
                onSelected: (_) => onSelected(f),
                selectedColor: AppColors.primary.withAlpha(25),
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  color: active
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: active
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                side: BorderSide(
                  color: active
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
            );
          }).toList(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final TeacherDoubtFilter filter;
  final String search;
  const _EmptyState({required this.filter, required this.search});

  @override
  Widget build(BuildContext context) {
    final isSearch = search.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              isSearch ? 'No results found' : _emptyTitle(filter),
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Try adjusting your search query.'
                  : _emptySubtitle(filter),
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _emptyTitle(TeacherDoubtFilter f) {
    switch (f) {
      case TeacherDoubtFilter.pending:
        return 'No pending doubts 🎉';
      case TeacherDoubtFilter.resolved:
        return 'No resolved doubts yet';
      case TeacherDoubtFilter.all:
        return 'No doubts yet';
    }
  }

  String _emptySubtitle(TeacherDoubtFilter f) {
    switch (f) {
      case TeacherDoubtFilter.pending:
        return 'All student doubts have been answered.';
      case TeacherDoubtFilter.resolved:
        return 'Start answering doubts to see them here.';
      case TeacherDoubtFilter.all:
        return 'Students haven\'t posted any doubts yet.';
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Error view
// ─────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load doubts',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 6),
              Text(message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
