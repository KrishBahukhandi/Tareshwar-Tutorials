// ─────────────────────────────────────────────────────────────
//  live_class_widgets.dart  –  Shared UI components
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/live_class_model.dart';

// ═════════════════════════════════════════════════════════════
//  LiveClassCard  –  used on both student and teacher lists
// ═════════════════════════════════════════════════════════════
class LiveClassCard extends StatelessWidget {
  final LiveClassModel liveClass;
  final VoidCallback onTap;
  final bool showTeacherName;

  const LiveClassCard({
    super.key,
    required this.liveClass,
    required this.onTap,
    this.showTeacherName = false,
  });

  @override
  Widget build(BuildContext context) {
    final lc = liveClass;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header strip ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: _gradientFor(lc.status),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  _StatusBadge(status: lc.status),
                  const Spacer(),
                  if (lc.isUpcoming)
                    _CountdownChip(minutesUntilStart: lc.minutesUntilStart),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lc.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (lc.description != null &&
                      lc.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      lc.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // ── Meta row ────────────────────────────
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: _formatDate(lc.startTime),
                      ),
                      _MetaChip(
                        icon: Icons.access_time_rounded,
                        label: _formatTime(lc.startTime),
                      ),
                      _MetaChip(
                        icon: Icons.timer_outlined,
                        label: '${lc.durationMinutes} min',
                      ),
                      if (lc.courseName != null)
                        _MetaChip(
                          icon: Icons.menu_book_rounded,
                          label: lc.courseName!,
                        ),
                      if (showTeacherName && lc.teacherName != null)
                        _MetaChip(
                          icon: Icons.person_rounded,
                          label: lc.teacherName!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          colors: [Color(0xFF9CA3AF), Color(0xFFD1D5DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  static String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]}';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final LiveClassStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LiveClassStatus.live     => ('● LIVE', Colors.red.shade200),
      LiveClassStatus.upcoming => ('Upcoming', Colors.white70),
      LiveClassStatus.ended    => ('Ended', Colors.grey.shade400),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == LiveClassStatus.live)
          _PulsingDot()
        else
          const SizedBox.shrink(),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        ),
      );
}

class _CountdownChip extends StatelessWidget {
  final int minutesUntilStart;
  const _CountdownChip({required this.minutesUntilStart});

  @override
  Widget build(BuildContext context) {
    String label;
    if (minutesUntilStart <= 0) {
      label = 'Starting…';
    } else if (minutesUntilStart < 60) {
      label = 'In $minutesUntilStart min';
    } else {
      final h = (minutesUntilStart / 60).floor();
      final m = minutesUntilStart % 60;
      label = m == 0 ? 'In ${h}h' : 'In ${h}h ${m}m';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════
//  LiveClassFilterBar  –  filter tabs for list screens
// ═════════════════════════════════════════════════════════════
class LiveClassFilterBar extends StatelessWidget {
  final String selected;
  final List<String> labels;
  final ValueChanged<String> onSelect;

  const LiveClassFilterBar({
    super.key,
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemCount: labels.length,
          itemBuilder: (_, i) {
            final label = labels[i];
            final active = label == selected;
            return GestureDetector(
              onTap: () => onSelect(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.primaryGradient : null,
                  color: active ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? Colors.transparent : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      );
}

// ═════════════════════════════════════════════════════════════
//  EmptyLiveClassState
// ═════════════════════════════════════════════════════════════
class EmptyLiveClassState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyLiveClassState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_camera_front_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}
