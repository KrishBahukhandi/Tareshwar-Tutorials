// ─────────────────────────────────────────────────────────────
//  live_class_list_screen.dart  –  Student view
//  Shows upcoming / live / past classes for enrolled batches.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/live_class_providers.dart';
import '../widgets/live_class_widgets.dart';
import '../../../../core/utils/app_router.dart';

class LiveClassListScreen extends ConsumerStatefulWidget {
  const LiveClassListScreen({super.key});

  @override
  ConsumerState<LiveClassListScreen> createState() =>
      _LiveClassListScreenState();
}

class _LiveClassListScreenState
    extends ConsumerState<LiveClassListScreen> {
  // Filter labels
  static const _filters = ['Upcoming', 'Live', 'Ended', 'All'];
  String _selected = 'Upcoming';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentLiveClassesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
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
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () =>
                ref.invalidate(studentLiveClassesProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // ── Filter bar ────────────────────────────────
          LiveClassFilterBar(
            selected: _selected,
            labels: _filters,
            onSelect: (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: 12),

          // ── List ──────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style:
                        const TextStyle(color: AppColors.error)),
              ),
              data: (classes) {
                final filtered = _applyFilter(classes, _selected);
                if (filtered.isEmpty) {
                  return EmptyLiveClassState(
                    message: _emptyMessage(_selected),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(studentLiveClassesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => LiveClassCard(
                      liveClass: filtered[i],
                      showTeacherName: true,
                      onTap: () => context.push(
                        AppRoutes.liveClassDetailPath(filtered[i].id),
                      ),
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

  List<dynamic> _applyFilter(List<dynamic> classes, String filter) {
    switch (filter) {
      case 'Live':
        return classes
            .where((lc) => lc.status == LiveClassStatus.live)
            .toList();
      case 'Upcoming':
        return classes
            .where((lc) => lc.status == LiveClassStatus.upcoming)
            .toList();
      case 'Ended':
        return classes
            .where((lc) => lc.status == LiveClassStatus.ended)
            .toList();
      default:
        return classes;
    }
  }

  String _emptyMessage(String filter) {
    switch (filter) {
      case 'Live':
        return 'No live classes right now.\nCheck back soon!';
      case 'Upcoming':
        return 'No upcoming live classes scheduled.\nYou\'ll be notified when one is added.';
      case 'Ended':
        return 'No ended classes yet.';
      default:
        return 'No live classes found.';
    }
  }
}
