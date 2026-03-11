// ─────────────────────────────────────────────────────────────
//  doubt_list_screen.dart  –  Browse & filter all doubts
//  • Filter: My Doubts / All / Answered / Pending
//  • Search
//  • FAB → AskDoubtScreen
//  • Tap doubt card → DoubtDetailScreen
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart';

// ── Local state ───────────────────────────────────────────────
enum _DLFilter { mine, all, answered, pending }

final _dlFilterProvider =
    StateProvider.autoDispose<_DLFilter>((_) => _DLFilter.mine);

final _dlSearchProvider =
    StateProvider.autoDispose<String>((_) => '');

// ─────────────────────────────────────────────────────────────
class DoubtListScreen extends ConsumerWidget {
  const DoubtListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_dlFilterProvider);
    final search = ref.watch(_dlSearchProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    // Use correct provider based on filter
    final doubtsAsync = filter == _DLFilter.mine
        ? ref.watch(myDoubtsProvider)
        : ref.watch(doubtsProvider(null));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Doubts'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ask Doubt'),
        onPressed: () => context.push(AppRoutes.askDoubtPath()),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────
          _SearchBar(
            onChanged: (v) =>
                ref.read(_dlSearchProvider.notifier).state = v,
          ),

          // ── Filter chips ────────────────────────────────
          _FilterRow(
            selected: filter,
            isTeacher: user?.role == 'teacher',
            onSelected: (f) =>
                ref.read(_dlFilterProvider.notifier).state = f,
          ),

          // ── List ────────────────────────────────────────
          Expanded(
            child: doubtsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(message: e.toString()),
              data: (doubts) {
                final filtered =
                    _applyFilters(doubts, filter, search);
                if (filtered.isEmpty) {
                  return _EmptyView(filter: filter);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    if (filter == _DLFilter.mine) {
                      ref.invalidate(myDoubtsProvider);
                    } else {
                      ref.invalidate(doubtsProvider);
                    }
                  },
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _DoubtCard(doubt: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DoubtModel> _applyFilters(
    List<DoubtModel> doubts,
    _DLFilter filter,
    String search,
  ) {
    var result = doubts;

    switch (filter) {
      case _DLFilter.answered:
        result = result.where((d) => d.isAnswered).toList();
        break;
      case _DLFilter.pending:
        result = result.where((d) => !d.isAnswered).toList();
        break;
      default:
        break;
    }

    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where((d) => d.question.toLowerCase().contains(q))
          .toList();
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search doubts...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textHint),
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
}

// ── Filter chips row ──────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final _DLFilter selected;
  final bool isTeacher;
  final ValueChanged<_DLFilter> onSelected;
  const _FilterRow({
    required this.selected,
    required this.isTeacher,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final labels = {
      if (!isTeacher) _DLFilter.mine: 'My Doubts',
      _DLFilter.all: 'All',
      _DLFilter.answered: 'Answered',
      _DLFilter.pending: 'Pending',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: labels.entries.map((e) {
          final isSelected = selected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: isSelected,
              onSelected: (_) => onSelected(e.key),
              selectedColor:
                  AppColors.primary.withValues(alpha: 0.12),
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
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Doubt card ────────────────────────────────────────────────
class _DoubtCard extends StatelessWidget {
  final DoubtModel doubt;
  const _DoubtCard({required this.doubt});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        doubt.isAnswered ? AppColors.success : AppColors.warning;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: statusColor.withValues(alpha: 0.25), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push(AppRoutes.doubtDetailPath(doubt.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      (doubt.studentName?.isNotEmpty == true
                              ? doubt.studentName![0]
                              : 'S')
                          .toUpperCase(),
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doubt.studentName ?? 'Student',
                          style: AppTextStyles.labelLarge,
                        ),
                        Text(
                          _fmtDate(doubt.createdAt),
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  _StatusBadge(isAnswered: doubt.isAnswered),
                ],
              ),

              const SizedBox(height: 12),

              // ── Question ────────────────────────────────
              Text(
                doubt.question,
                style: AppTextStyles.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // ── Image thumbnail ─────────────────────────
              if (doubt.imageUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    doubt.imageUrl!,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 8),

              // ── Footer ──────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${doubt.replyCount} ${doubt.replyCount == 1 ? 'reply' : 'replies'}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    'View Discussion →',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

// ── Status badge ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isAnswered;
  const _StatusBadge({required this.isAnswered});

  @override
  Widget build(BuildContext context) {
    final color = isAnswered ? AppColors.success : AppColors.warning;
    final label = isAnswered ? 'Answered' : 'Pending';
    final icon = isAnswered
        ? Icons.check_circle_rounded
        : Icons.schedule_rounded;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style:
                  AppTextStyles.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final _DLFilter filter;
  const _EmptyView({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isMine = filter == _DLFilter.mine;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.question_answer_outlined,
                size: 72, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              isMine ? 'No doubts posted yet' : 'No doubts found',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isMine
                  ? 'Tap the button below to post your first doubt.'
                  : 'Try a different filter.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (isMine) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ask a Doubt'),
                onPressed: () =>
                    context.push(AppRoutes.askDoubtPath()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────
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
            const SizedBox(height: 12),
            Text('Something went wrong',
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
}
