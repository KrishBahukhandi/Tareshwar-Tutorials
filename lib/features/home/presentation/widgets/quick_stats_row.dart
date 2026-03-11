// ─────────────────────────────────────────────────────────────
//  quick_stats_row.dart  –  A row of stat chips: streak,
//  completed lectures, score average.  Pure UI — data is passed
//  in from the parent.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class QuickStatsRow extends StatelessWidget {
  final int enrolledCount;
  final int completedLectures;
  final int testsTaken;

  const QuickStatsRow({
    super.key,
    required this.enrolledCount,
    required this.completedLectures,
    required this.testsTaken,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.library_books_rounded,
          value: '$enrolledCount',
          label: 'Courses',
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.play_circle_fill_rounded,
          value: '$completedLectures',
          label: 'Completed',
          color: AppColors.success,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.quiz_rounded,
          value: '$testsTaken',
          label: 'Tests taken',
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.headlineSmall
                  .copyWith(color: color, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
