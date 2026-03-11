// ─────────────────────────────────────────────────────────────
//  admin_live_classes_screen.dart
//  Admin view: read-only list of all live classes across all
//  batches and teachers, with filter and stats.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../live_classes/providers/live_class_providers.dart';
import '../../../live_classes/widgets/live_class_widgets.dart';
class AdminLiveClassesScreen extends ConsumerStatefulWidget {
  const AdminLiveClassesScreen({super.key});

  @override
  ConsumerState<AdminLiveClassesScreen> createState() =>
      _AdminLiveClassesScreenState();
}

class _AdminLiveClassesScreenState
    extends ConsumerState<AdminLiveClassesScreen> {
  static const _filters = ['All', 'Live', 'Upcoming', 'Ended'];
  String _selected = 'All';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminLiveClassesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Live Classes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => ref.invalidate(adminLiveClassesProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (all) {
          final live     = all.where((lc) => lc.isLive).length;
          final upcoming = all.where((lc) => lc.isUpcoming).length;
          final ended    = all.where((lc) => lc.isEnded).length;

          final filtered = _applyFilter(all, _selected);

          return Column(
            children: [
              // ── Stats strip ───────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    _StatChip(label: 'Total', value: all.length, color: AppColors.primary),
                    const SizedBox(width: 10),
                    _StatChip(label: 'Live', value: live, color: AppColors.error),
                    const SizedBox(width: 10),
                    _StatChip(label: 'Upcoming', value: upcoming, color: AppColors.info),
                    const SizedBox(width: 10),
                    _StatChip(label: 'Ended', value: ended, color: AppColors.textSecondary),
                  ],
                ),
              ),

              // ── Filter bar ────────────────────────────
              const SizedBox(height: 10),
              LiveClassFilterBar(
                selected: _selected,
                labels: _filters,
                onSelect: (v) => setState(() => _selected = v),
              ),
              const SizedBox(height: 8),

              // ── List ──────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyLiveClassState(
                        message: 'No live classes in this category.')
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(adminLiveClassesProvider),
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.only(bottom: 24),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => LiveClassCard(
                            liveClass: filtered[i],
                            showTeacherName: true,
                            onTap: () {},
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<LiveClassModel> _applyFilter(
      List<LiveClassModel> all, String filter) {
    switch (filter) {
      case 'Live':
        return all.where((lc) => lc.isLive).toList();
      case 'Upcoming':
        return all.where((lc) => lc.isUpcoming).toList();
      case 'Ended':
        return all.where((lc) => lc.isEnded).toList();
      default:
        return all;
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}
