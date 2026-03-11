// ─────────────────────────────────────────────────────────────
//  teacher_doubts_screen.dart  –  Full doubt management screen
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/teacher_dashboard_providers.dart';
import '../widgets/teacher_doubt_tile.dart';

class TeacherDoubtsScreen extends ConsumerStatefulWidget {
  const TeacherDoubtsScreen({super.key});

  @override
  ConsumerState<TeacherDoubtsScreen> createState() =>
      _TeacherDoubtsScreenState();
}

class _TeacherDoubtsScreenState
    extends ConsumerState<TeacherDoubtsScreen> {
  String _filter = 'all'; // all | pending | answered

  @override
  Widget build(BuildContext context) {
    final doubtsAsync = ref.watch(teacherAllDoubtsProvider);

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
                  Text('Student Doubts',
                      style: AppTextStyles.displaySmall),
                  const SizedBox(height: 2),
                  doubtsAsync.maybeWhen(
                    data: (d) {
                      final pending =
                          d.where((x) => !x.isAnswered).length;
                      return Text(
                        '$pending pending · ${d.length} total',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      );
                    },
                    orElse: () => const SizedBox(),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(teacherAllDoubtsProvider);
                  ref.invalidate(teacherPendingDoubtsProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Filter chips ────────────────────────────────
          _FilterBar(
            current: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),

          // ── List ────────────────────────────────────────
          Expanded(
            child: doubtsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('$e',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error)),
              ),
              data: (doubts) {
                final filtered = _filter == 'pending'
                    ? doubts.where((d) => !d.isAnswered).toList()
                    : _filter == 'answered'
                        ? doubts.where((d) => d.isAnswered).toList()
                        : doubts;

                if (filtered.isEmpty) {
                  return _EmptyDoubts(filter: _filter);
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      TeacherDoubtTile(doubt: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'All'),
      ('pending', 'Pending'),
      ('answered', 'Answered'),
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
            selectedColor:
                AppColors.primary.withValues(alpha: 0.12),
            labelStyle: AppTextStyles.labelMedium.copyWith(
              color: active
                  ? AppColors.primary
                  : AppColors.textSecondary,
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

class _EmptyDoubts extends StatelessWidget {
  final String filter;
  const _EmptyDoubts({required this.filter});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter == 'answered'
                  ? Icons.check_circle_outline_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              filter == 'pending'
                  ? '🎉 No pending doubts! All caught up.'
                  : filter == 'answered'
                      ? 'No answered doubts yet.'
                      : 'No student doubts yet.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}
