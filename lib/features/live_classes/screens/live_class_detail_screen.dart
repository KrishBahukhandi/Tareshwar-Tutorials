// ─────────────────────────────────────────────────────────────
//  live_class_detail_screen.dart  –  Detail + Join screen
//  Works for both student and teacher views.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/services/analytics_service.dart';
import '../providers/live_class_providers.dart';

class LiveClassDetailScreen extends ConsumerWidget {
  final String liveClassId;
  const LiveClassDetailScreen({super.key, required this.liveClassId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveClassDetailProvider(liveClassId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (lc) {
          if (lc == null) {
            return const Center(child: Text('Live class not found.'));
          }
          return _DetailBody(liveClass: lc);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _DetailBody extends StatelessWidget {
  final LiveClassModel liveClass;
  const _DetailBody({required this.liveClass});

  @override
  Widget build(BuildContext context) {
    final lc = liveClass;

    return CustomScrollView(
      slivers: [
        // ── Hero app bar ─────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: _gradientFor(lc.status),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BigStatusIcon(status: lc.status),
                      const SizedBox(height: 12),
                      _StatusPill(status: lc.status),
                    ],
                  ),
                ),
              ),
            ),
          ),
          foregroundColor: Colors.white,
        ),

        // ── Content ───────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  lc.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (lc.description != null &&
                    lc.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    lc.description!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Info cards ───────────────────────────
                _InfoGrid(liveClass: lc),
                const SizedBox(height: 28),

                // ── Join / copy button ───────────────────
                if (!lc.isEnded)
                  _JoinButton(liveClass: lc)
                else
                  _EndedBanner(),

                const SizedBox(height: 16),

                // Copy link button
                _CopyLinkButton(link: lc.meetingLink),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LinearGradient _gradientFor(LiveClassStatus status) {
    switch (status) {
      case LiveClassStatus.live:
        return const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case LiveClassStatus.upcoming:
        return AppColors.primaryGradient;
      case LiveClassStatus.ended:
        return const LinearGradient(
          colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────
class _BigStatusIcon extends StatelessWidget {
  final LiveClassStatus status;
  const _BigStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          status == LiveClassStatus.live
              ? Icons.radio_button_on_rounded
              : status == LiveClassStatus.upcoming
                  ? Icons.video_camera_front_rounded
                  : Icons.video_camera_back_rounded,
          size: 40,
          color: Colors.white,
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final LiveClassStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      LiveClassStatus.live     => '● LIVE NOW',
      LiveClassStatus.upcoming => 'Upcoming',
      LiveClassStatus.ended    => 'Ended',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _InfoGrid extends StatelessWidget {
  final LiveClassModel liveClass;
  const _InfoGrid({required this.liveClass});

  @override
  Widget build(BuildContext context) {
    final lc = liveClass;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _InfoCard(
          icon: Icons.calendar_today_rounded,
          label: 'Date',
          value: _formatDate(lc.startTime),
          color: AppColors.primary,
        ),
        _InfoCard(
          icon: Icons.access_time_rounded,
          label: 'Start Time',
          value: _formatTime(lc.startTime),
          color: AppColors.info,
        ),
        _InfoCard(
          icon: Icons.timer_outlined,
          label: 'Duration',
          value: '${lc.durationMinutes} minutes',
          color: AppColors.warning,
        ),
        if (lc.teacherName != null)
          _InfoCard(
            icon: Icons.person_rounded,
            label: 'Teacher',
            value: lc.teacherName!,
            color: AppColors.secondary,
          ),
        if (lc.courseName != null)
          _InfoCard(
            icon: Icons.menu_book_rounded,
            label: 'Course',
            value: lc.courseName!,
            color: const Color(0xFF8B5CF6),
          ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdays = [
      '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    return '${weekdays[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: (MediaQuery.sizeOf(context).width - 52) / 2,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
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
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
class _JoinButton extends ConsumerWidget {
  final LiveClassModel liveClass;
  const _JoinButton({required this.liveClass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLive = liveClass.isLive;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launch(context, ref),
        icon: Icon(
          isLive
              ? Icons.radio_button_on_rounded
              : Icons.open_in_new_rounded,
          size: 20,
        ),
        label: Text(
          isLive ? 'Join Live Now' : 'Join when Live',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isLive ? AppColors.error : AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: isLive ? 4 : 0,
        ),
      ),
    );
  }

  Future<void> _launch(BuildContext ctx, WidgetRef ref) async {
    final uri = Uri.tryParse(liveClass.meetingLink);
    if (uri != null && await canLaunchUrl(uri)) {
      // ── Analytics: live_class_joined ─────────────────
      ref.read(analyticsServiceProvider).trackLiveClassJoined(
            liveClassId:    liveClass.id,
            liveClassTitle: liveClass.title,
            courseId:       liveClass.courseId,
          );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Could not open meeting link'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _CopyLinkButton extends StatelessWidget {
  final String link;
  const _CopyLinkButton({required this.link});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Meeting link copied!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy Meeting Link'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

class _EndedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: AppColors.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'This live class has ended.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
}
