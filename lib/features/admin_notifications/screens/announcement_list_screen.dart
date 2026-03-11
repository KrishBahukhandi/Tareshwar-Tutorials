// ─────────────────────────────────────────────────────────────
//  announcement_list_screen.dart
//  Admin: Browse, search, filter and manage all announcements.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../providers/admin_notifications_providers.dart';
import '../widgets/admin_notifications_widgets.dart';

class AnnouncementListScreen extends ConsumerStatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  ConsumerState<AnnouncementListScreen> createState() =>
      _AnnouncementListScreenState();
}

class _AnnouncementListScreenState
    extends ConsumerState<AnnouncementListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(announcementsListProvider);
    ref.invalidate(announcementStatsProvider);
  }

  Future<void> _deleteAnnouncement(AnnouncementRow row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text(
          'Delete "${row.title}"?\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(deleteAnnouncementProvider.notifier)
          .delete(row.id);
      messenger.showSnackBar(const SnackBar(
        content: Text('Announcement deleted'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _resendPush(AnnouncementRow row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resend Push Notification'),
        content: Text(
          'Re-send push for "${row.title}"?\n\n'
          'All target students will receive the notification again.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Resend')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(resendPushProvider.notifier)
          .resend(row);
      messenger.showSnackBar(const SnackBar(
        content: Text('Push notification re-sent'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter            = ref.watch(announcementFilterProvider);
    final announcementsAsync = ref.watch(announcementsListProvider);
    final statsAsync         = ref.watch(announcementStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Announcements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Announcement',
            style: TextStyle(color: Colors.white)),
        onPressed: () async {
          await Navigator.of(context).pushNamed(
            AppRoutes.adminCreateAnnouncement,
          );
          _refresh();
        },
      ),
      body: Column(
        children: [
          // ── Stats header ─────────────────────────────────
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) => Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: AnnouncementStatsRow(stats: stats),
            ),
          ),

          // ── Search + filter toolbar ──────────────────────
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                AnnouncementSearchBar(
                  controller: _searchCtrl,
                  onChanged: (v) => ref
                      .read(announcementFilterProvider.notifier)
                      .state = filter.copyWith(search: v),
                ),
                const SizedBox(height: 10),
                AnnouncementFilterChips(
                  platformWideOnly: filter.platformWideOnly,
                  onChanged: (v) => ref
                      .read(announcementFilterProvider.notifier)
                      .state = filter.copyWith(platformWideOnly: v),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── List ─────────────────────────────────────────
          Expanded(
            child: announcementsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load announcements',
                        style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry')),
                  ],
                ),
              ),
              data: (announcements) {
                if (announcements.isEmpty) {
                  return AnnouncementEmptyState(
                    message: filter.hasActiveFilter
                        ? 'No results found'
                        : 'No Announcements Yet',
                    subtitle: filter.hasActiveFilter
                        ? 'Try adjusting your search or filters.'
                        : 'Create an announcement to broadcast to students.',
                    onAction: filter.hasActiveFilter
                        ? null
                        : () => Navigator.of(context)
                            .pushNamed(AppRoutes.adminCreateAnnouncement),
                    actionLabel: 'Create First Announcement',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: announcements.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final a = announcements[i];
                      return AnnouncementCard(
                        announcement: a,
                        onTap: () =>
                            AnnouncementDetailSheet.show(context, a),
                        onDelete: () => _deleteAnnouncement(a),
                        onResendPush: () => _resendPush(a),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
