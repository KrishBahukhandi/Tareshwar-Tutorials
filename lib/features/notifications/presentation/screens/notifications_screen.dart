// ─────────────────────────────────────────────────────────────
//  notifications_screen.dart  –  Full notification inbox
//
//  Features:
//  ▸ Grouped by date (Today / Yesterday / Earlier)
//  ▸ Type icon + colour coding  (lecture / test / announcement)
//  ▸ Unread dot + highlighted card background
//  ▸ Tap to mark as read
//  ▸ "Mark all read" action button
//  ▸ Slide-to-dismiss (swipe left) per notification
//  ▸ Empty state & error state
//  ▸ Pull-to-refresh
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  // Local copy of notifications so we can animate dismissals
  List<NotificationModel>? _notifications;
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Fetch ─────────────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final userId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (userId == null) {
        setState(() { _notifications = []; _loading = false; });
        return;
      }
      final list = await ref
          .read(notificationServiceProvider)
          .fetchNotifications(userId);
      if (mounted) setState(() { _notifications = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Failed to load notifications. Tap to retry.';
          _loading = false;
        });
      }
    }
  }

  // ── Mark single as read ───────────────────────────────────
  Future<void> _markRead(NotificationModel n) async {
    if (n.isRead) return;
    await ref.read(notificationServiceProvider).markAsRead(n.id);
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          ?.map((x) => x.id == n.id ? _copyRead(x) : x)
          .toList();
    });
  }

  // ── Mark all read ─────────────────────────────────────────
  Future<void> _markAllRead() async {
    final userId = ref.read(authServiceProvider).currentAuthUser?.id;
    if (userId == null) return;
    await ref
        .read(notificationServiceProvider)
        .markAllAsRead(userId);
    if (!mounted) return;
    setState(() {
      _notifications =
          _notifications?.map(_copyRead).toList();
    });
  }

  // ── Dismiss (remove locally) ──────────────────────────────
  void _dismiss(NotificationModel n) {
    setState(() {
      _notifications = _notifications?.where((x) => x.id != n.id).toList();
    });
  }

  NotificationModel _copyRead(NotificationModel n) =>
      NotificationModel(
        id: n.id,
        title: n.title,
        body: n.body,
        type: n.type,
        targetId: n.targetId,
        isRead: true,
        createdAt: n.createdAt,
      );

  // ── Grouping ──────────────────────────────────────────────
  Map<String, List<NotificationModel>> _group(
      List<NotificationModel> list) {
    final today = DateTime.now();
    final groups = <String, List<NotificationModel>>{};
    for (final n in list) {
      final diff = today.difference(n.createdAt).inDays;
      final String key;
      if (diff == 0) {
        key = 'Today';
      } else if (diff == 1) {
        key = 'Yesterday';
      } else if (diff < 7) {
        key = 'This Week';
      } else {
        key = 'Earlier';
      }
      groups.putIfAbsent(key, () => []).add(n);
    }
    // Preserve order: Today → Yesterday → This Week → Earlier
    const order = ['Today', 'Yesterday', 'This Week', 'Earlier'];
    return {
      for (final k in order)
        if (groups.containsKey(k)) k: groups[k]!,
    };
  }

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasUnread =
        _notifications?.any((n) => !n.isRead) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (ctx, i) => const _NotificationShimmer(),
      );
    }

    // Error
    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _errorMsg!,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final list = _notifications ?? [];

    // Empty
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('All caught up!',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              "You have no notifications yet.\nWe'll let you know when something arrives.",
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Grouped list
    final grouped = _group(list);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          for (final entry in grouped.entries) ...[
            _GroupHeader(label: entry.key),
            const SizedBox(height: 8),
            for (final n in entry.value)
              _DismissibleTile(
                key: ValueKey(n.id),
                notification: n,
                onTap: () => _markRead(n),
                onDismiss: () => _dismiss(n),
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Group header
// ─────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dismissible notification tile wrapper
// ─────────────────────────────────────────────────────────────
class _DismissibleTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _DismissibleTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 24),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _NotificationTile(
          n: notification,
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Single notification tile
// ─────────────────────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  final NotificationModel n;
  final VoidCallback onTap;
  const _NotificationTile({required this.n, required this.onTap});

  // Icon + colour by type
  IconData get _icon => switch (n.type) {
        'lecture'      => Icons.play_circle_outline_rounded,
        'test'         => Icons.quiz_outlined,
        'announcement' => Icons.campaign_outlined,
        _              => Icons.info_outline_rounded,
      };

  Color get _color => switch (n.type) {
        'lecture'      => AppColors.primary,
        'test'         => AppColors.warning,
        'announcement' => AppColors.secondary,
        _              => AppColors.info,
      };

  String get _typeLabel => switch (n.type) {
        'lecture'      => 'Lecture',
        'test'         => 'Test',
        'announcement' => 'Announcement',
        _              => 'General',
      };

  @override
  Widget build(BuildContext context) {
    final bg = n.isRead
        ? Theme.of(context).colorScheme.surface
        : AppColors.primary.withValues(alpha: 0.04);
    final borderColor = n.isRead
        ? AppColors.border.withValues(alpha: 0.5)
        : AppColors.primary.withValues(alpha: 0.18);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: n.isRead
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Type icon ────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _color, size: 22),
            ),
            const SizedBox(width: 12),

            // ── Content ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _typeLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: _color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Unread dot
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.title,
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeago.format(n.createdAt),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Shimmer loading skeleton
// ─────────────────────────────────────────────────────────────
class _NotificationShimmer extends StatefulWidget {
  const _NotificationShimmer();

  @override
  State<_NotificationShimmer> createState() =>
      _NotificationShimmerState();
}

class _NotificationShimmerState extends State<_NotificationShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h) => AnimatedBuilder(
        animation: _anim,
        builder: (ctx, child) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                AppColors.shimmerBase,
                AppColors.shimmerHighlight,
                AppColors.shimmerBase,
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(44, 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(60, 16),
                  const SizedBox(height: 8),
                  _box(double.infinity, 14),
                  const SizedBox(height: 6),
                  _box(double.infinity, 12),
                  const SizedBox(height: 6),
                  _box(80, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
