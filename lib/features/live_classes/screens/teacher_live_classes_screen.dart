// ─────────────────────────────────────────────────────────────
//  teacher_live_classes_screen.dart
//  Teacher-side management view inside the Teacher Dashboard Shell.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/live_class_providers.dart';
import '../widgets/live_class_widgets.dart';
import 'schedule_live_class_screen.dart';

class TeacherLiveClassesScreen extends ConsumerWidget {
  const TeacherLiveClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherLiveClassesProvider);

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
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => ref.invalidate(teacherLiveClassesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSchedule(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return EmptyLiveClassState(
              message:
                  'No live classes scheduled yet.\nTap "+ Schedule" to create one.',
              actionLabel: 'Schedule Now',
              onAction: () => _openSchedule(context, ref),
            );
          }

          // Separate into upcoming/live and past
          final active = classes
              .where((lc) => !lc.isEnded)
              .toList();
          final ended = classes.where((lc) => lc.isEnded).toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(teacherLiveClassesProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (active.isNotEmpty) ...[
                  _ListHeader(
                    title: 'Active & Upcoming',
                    count: active.length,
                    color: AppColors.primary,
                  ),
                  for (final lc in active)
                    _TeacherLiveClassCard(
                      liveClass: lc,
                      onEdit: () => _openSchedule(context, ref, lc),
                      onDelete: () => _confirmDelete(context, ref, lc),
                      onNotify: () =>
                          _sendNotification(context, ref, lc),
                    ),
                ],
                if (ended.isNotEmpty) ...[
                  _ListHeader(
                    title: 'Past Classes',
                    count: ended.length,
                    color: AppColors.textSecondary,
                  ),
                  for (final lc in ended)
                    _TeacherLiveClassCard(
                      liveClass: lc,
                      onEdit: null, // can't edit ended classes
                      onDelete: () => _confirmDelete(context, ref, lc),
                      onNotify: null,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSchedule(
    BuildContext context,
    WidgetRef ref, [
    LiveClassModel? existing,
  ]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleLiveClassScreen(existing: existing),
      ),
    );
    if (result == true) ref.invalidate(teacherLiveClassesProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LiveClassModel lc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Live Class?'),
        content: Text(
            'Are you sure you want to delete "${lc.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(liveClassServiceProvider).deleteLiveClass(lc.id);
        ref.invalidate(teacherLiveClassesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Live class deleted'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _sendNotification(
    BuildContext context,
    WidgetRef ref,
    LiveClassModel lc,
  ) async {
    try {
      await ref.read(liveClassServiceProvider).sendLiveClassNotification(
            liveClassId: lc.id,
            batchId: lc.batchId,
            title: lc.title,
            startTime: lc.startTime,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications sent to all students!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(teacherLiveClassesProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
class _ListHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _ListHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
class _TeacherLiveClassCard extends StatelessWidget {
  final LiveClassModel liveClass;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onNotify;

  const _TeacherLiveClassCard({
    required this.liveClass,
    required this.onEdit,
    required this.onDelete,
    required this.onNotify,
  });

  @override
  Widget build(BuildContext context) {
    final lc = liveClass;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Color bar ─────────────────────────────────
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: lc.isLive
                  ? const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFFF6B6B)])
                  : lc.isUpcoming
                      ? AppColors.primaryGradient
                      : const LinearGradient(colors: [
                          Color(0xFFD1D5DB),
                          Color(0xFFE5E7EB)
                        ]),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lc.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _StatusTag(status: lc.status),
                  ],
                ),
                const SizedBox(height: 8),

                // Meta info
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _Meta(
                        icon: Icons.calendar_today_rounded,
                        text: _formatDate(lc.startTime)),
                    _Meta(
                        icon: Icons.access_time_rounded,
                        text: _formatTime(lc.startTime)),
                    _Meta(
                        icon: Icons.timer_outlined,
                        text: '${lc.durationMinutes} min'),
                    if (lc.batchName != null)
                      _Meta(
                          icon: Icons.group_work_rounded,
                          text: lc.batchName!),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // ── Action row ───────────────────────────
                Row(
                  children: [
                    if (onNotify != null)
                      _ActionBtn(
                        icon: Icons.notifications_active_rounded,
                        label: lc.notificationSent ? 'Re-notify' : 'Notify',
                        color: AppColors.warning,
                        onTap: onNotify!,
                      ),
                    const Spacer(),
                    if (onEdit != null) ...[
                      _ActionBtn(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        color: AppColors.primary,
                        onTap: onEdit!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: AppColors.error,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _StatusTag extends StatelessWidget {
  final LiveClassStatus status;
  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      LiveClassStatus.live =>
        ('LIVE', const Color(0xFFEF4444), Colors.white),
      LiveClassStatus.upcoming =>
        ('Upcoming', AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary),
      LiveClassStatus.ended =>
        ('Ended', const Color(0xFFF3F4F6), AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}
