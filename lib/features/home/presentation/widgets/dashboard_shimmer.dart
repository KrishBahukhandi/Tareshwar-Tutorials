// ─────────────────────────────────────────────────────────────
//  dashboard_shimmer.dart  –  Shimmer skeleton loaders for
//  all dashboard sections while data is loading.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

// ── Generic shimmer box ───────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
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
  }
}

// ── Banner skeleton ───────────────────────────────────────────
class BannerShimmer extends StatelessWidget {
  const BannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      width: double.infinity,
      height: 140,
      radius: 20,
    );
  }
}

// ── Continue Learning card skeleton ──────────────────────────
class ContinueLearningShimmer extends StatelessWidget {
  const ContinueLearningShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: _ShimmerBox(width: 96, height: 116, radius: 0),
          ),
          // text lines
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: 60, height: 16, radius: 4),
                  const SizedBox(height: 8),
                  _ShimmerBox(width: double.infinity, height: 14, radius: 4),
                  const SizedBox(height: 6),
                  _ShimmerBox(width: 120, height: 12, radius: 4),
                  const SizedBox(height: 10),
                  _ShimmerBox(width: double.infinity, height: 5, radius: 4),
                  const SizedBox(height: 8),
                  _ShimmerBox(width: 70, height: 28, radius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recommended course card skeleton ─────────────────────────
class CourseCardShimmer extends StatelessWidget {
  const CourseCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: _ShimmerBox(
                width: double.infinity, height: 118, radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: double.infinity, height: 13, radius: 4),
                const SizedBox(height: 6),
                _ShimmerBox(width: 100, height: 12, radius: 4),
                const SizedBox(height: 10),
                _ShimmerBox(width: 80, height: 12, radius: 4),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ShimmerBox(width: 50, height: 14, radius: 4),
                    _ShimmerBox(width: 60, height: 26, radius: 8),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header skeleton ───────────────────────────────────
class SectionHeaderShimmer extends StatelessWidget {
  const SectionHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ShimmerBox(width: 140, height: 18, radius: 4),
        _ShimmerBox(width: 50, height: 14, radius: 4),
      ],
    );
  }
}
