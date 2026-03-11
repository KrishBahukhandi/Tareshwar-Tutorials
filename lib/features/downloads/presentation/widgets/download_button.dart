// ─────────────────────────────────────────────────────────────
//  download_button.dart  –  Compact download action button.
//
//  Renders three states:
//    • Not downloaded  → download icon
//    • Downloading     → circular progress + cancel tap
//    • Downloaded      → green check (tapping opens player)
//
//  Used by LecturePlayerScreen and LectureTile.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/auth_service.dart' show currentUserProvider;
import '../../download_providers.dart';

class DownloadButton extends ConsumerStatefulWidget {
  final LectureModel lecture;
  final String courseTitle;
  final bool compact; // true = icon-only, false = icon + label

  const DownloadButton({
    super.key,
    required this.lecture,
    required this.courseTitle,
    this.compact = true,
  });

  @override
  ConsumerState<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<DownloadButton> {
  bool _busy = false;

  Future<void> _startDownload() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (widget.lecture.videoUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No video available to download.')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(downloadServiceProvider).startDownload(
            lectureId:       widget.lecture.id,
            studentId:       user.id,
            videoUrl:        widget.lecture.videoUrl!,
            title:           widget.lecture.title,
            courseTitle:     widget.courseTitle,
            durationSeconds: widget.lecture.durationSeconds ?? 0,
          );
      // Refresh the list screen when done
      ref.invalidate(studentDownloadsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDownload() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    await ref.read(downloadServiceProvider).cancelDownload(
          lectureId: widget.lecture.id,
          studentId: user.id,
        );
    ref.invalidate(lectureDownloadProvider(widget.lecture.id));
  }

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(lectureDownloadProvider(widget.lecture.id));
    final streamAsync =
        ref.watch(downloadProgressProvider(widget.lecture.id));

    // Prefer the live stream value over the DB snapshot while active
    final dl = streamAsync.valueOrNull ?? dbAsync.valueOrNull;

    if (dl == null || dl.isFailed) {
      // ── Not downloaded ─────────────────────────────────────
      return _ActionButton(
        icon: Icons.download_rounded,
        label: 'Download',
        color: AppColors.primary,
        compact: widget.compact,
        loading: _busy,
        onTap: _startDownload,
      );
    }

    if (dl.isDownloading) {
      // ── In progress ────────────────────────────────────────
      return GestureDetector(
        onTap: _cancelDownload,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: dl.progress,
                strokeWidth: 3,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primary),
              ),
              const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    if (dl.isCompleted) {
      // ── Downloaded ─────────────────────────────────────────
      return _ActionButton(
        icon: Icons.check_circle_rounded,
        label: 'Downloaded',
        color: AppColors.success,
        compact: widget.compact,
        loading: false,
        onTap: () {}, // handled by parent (LectureTile onTap)
      );
    }

    // Paused / queued
    return _ActionButton(
      icon: Icons.download_rounded,
      label: 'Resume',
      color: AppColors.warning,
      compact: widget.compact,
      loading: _busy,
      onTap: _startDownload,
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: compact ? 28 : 80,
        height: 28,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (compact) {
      return IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onTap,
        tooltip: label,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      );
    }

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
