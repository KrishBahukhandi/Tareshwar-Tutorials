// ─────────────────────────────────────────────────────────────
//  teacher_overview_screen.dart
//  Dashboard overview: stats grid + quick actions + activity feed
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../features/teacher_auth/providers/teacher_auth_provider.dart';
import '../providers/teacher_dashboard_providers.dart';
import '../widgets/teacher_stat_card.dart';

class TeacherOverviewScreen extends ConsumerWidget {
  const TeacherOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teacherDashboardStatsProvider);
    final activityAsync = ref.watch(teacherRecentActivityProvider);
    final teacher = ref.watch(teacherUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ─────────────────────────────────────
          Text(
            'Welcome back, ${teacher?.displayName ?? "Teacher"} 👋',
            style: AppTextStyles.displaySmall,
          ),
          const SizedBox(height: 4),
          Text(
            "Here's what's happening with your courses today.",
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          // ── Stats grid ────────────────────────────────────
          statsAsync.when(
            loading: () => const _StatsShimmer(),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (stats) => _StatsGrid(stats: stats),
          ),

          const SizedBox(height: 32),

          // ── Quick actions ─────────────────────────────────
          _QuickActions(
            onSectionTap: (s) => ref
                .read(teacherSelectedSectionProvider.notifier)
                .state = s,
          ),

          const SizedBox(height: 32),

          // ── Recent activity ───────────────────────────────
          Row(
            children: [
              Text('Recent Activity', style: AppTextStyles.headlineMedium),
              const Spacer(),
              TextButton(
                onPressed: () => ref
                    .read(teacherSelectedSectionProvider.notifier)
                    .state = TeacherSection.studentDoubts,
                child: Text(
                  'View Doubts',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          activityAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (events) => events.isEmpty
                ? const _EmptyActivity()
                : Column(
                    children: events
                        .map((e) => _ActivityTile(event: e))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Responsive stats grid (4 cols desktop, 2 tablet, 1 mobile)
// ─────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final TeacherDashboardStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      TeacherStatCard(
        label: 'Total Courses',
        value: '${stats.totalCourses}',
        icon: Icons.menu_book_rounded,
        color: AppColors.primary,
      ),
      TeacherStatCard(
        label: 'Total Students',
        value: '${stats.totalStudents}',
        icon: Icons.people_rounded,
        color: const Color(0xFF10B981),
      ),
      TeacherStatCard(
        label: 'Pending Doubts',
        value: '${stats.pendingDoubts}',
        icon: Icons.chat_bubble_outline_rounded,
        color: AppColors.warning,
      ),
      TeacherStatCard(
        label: 'Total Lectures',
        value: '${stats.totalLectures}',
        icon: Icons.play_lesson_rounded,
        color: AppColors.secondary,
      ),
    ];

    final w = MediaQuery.of(context).size.width;
    final cols = w > 1100 ? 4 : (w > 700 ? 2 : 1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (_, i) => cards[i],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Quick action chips
// ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final void Function(TeacherSection) onSectionTap;
  const _QuickActions({required this.onSectionTap});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.upload_rounded,
        label: 'Upload Content',
        color: AppColors.primary,
        section: TeacherSection.uploadContent,
      ),
      (
        icon: Icons.quiz_rounded,
        label: 'Create Test',
        color: AppColors.secondary,
        section: TeacherSection.createTest,
      ),
      (
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Answer Doubts',
        color: AppColors.warning,
        section: TeacherSection.studentDoubts,
      ),
      (
        icon: Icons.bar_chart_rounded,
        label: 'View Analytics',
        color: const Color(0xFF10B981),
        section: TeacherSection.analytics,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map((a) => ElevatedButton.icon(
                    onPressed: () => onSectionTap(a.section),
                    icon: Icon(a.icon, size: 18, color: a.color),
                    label: Text(a.label),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: a.color,
                      backgroundColor:
                          a.color.withValues(alpha: 0.08),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle:
                          AppTextStyles.labelLarge.copyWith(color: a.color),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Activity tile
// ─────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final TeacherActivityEvent event;
  const _ActivityTile({required this.event});

  static const _colors = <ActivityEventType, Color>{
    ActivityEventType.doubt:      AppColors.warning,
    ActivityEventType.enrollment: Color(0xFF10B981),
    ActivityEventType.upload:     AppColors.primary,
    ActivityEventType.test:       AppColors.secondary,
  };
  static const _icons = <ActivityEventType, IconData>{
    ActivityEventType.doubt:      Icons.chat_bubble_outline_rounded,
    ActivityEventType.enrollment: Icons.person_add_outlined,
    ActivityEventType.upload:     Icons.upload_rounded,
    ActivityEventType.test:       Icons.quiz_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[event.type] ?? AppColors.primary;
    final icon = _icons[event.type] ?? Icons.circle;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  event.subtitle,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(_fmt(event.time), style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────
class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.4,
        ),
        itemBuilder: (ctx, idx) => Container(
          decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_rounded,
                  size: 48, color: AppColors.textHint),
              const SizedBox(height: 10),
              Text('No recent activity.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.error)),
            ),
          ],
        ),
      );
}
