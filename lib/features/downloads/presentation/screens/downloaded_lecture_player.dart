// ─────────────────────────────────────────────────────────────
//  downloaded_lecture_player.dart  –  Offline video player.
//
//  Plays a locally saved .mp4 file from the device storage.
//  Features:
//    • Plays local file via VideoPlayerController.file()
//    • "Offline" badge in app bar
//    • Playback speed control (0.5× – 2×)
//    • Overview tab (title, duration, course)
//    • Graceful fallback if file is missing
// ─────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/services/auth_service.dart' show currentUserProvider;
import '../../download_providers.dart';

// ── Speed options ──────────────────────────────────────────────
const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

// ─────────────────────────────────────────────────────────────
class DownloadedLecturePlayer extends ConsumerStatefulWidget {
  /// lectureId is used to fetch the DB row when [download] is null.
  final String lectureId;

  /// Pre-passed from the downloads screen; avoids an extra DB round-trip.
  final DownloadedLecture? download;

  const DownloadedLecturePlayer({
    super.key,
    required this.lectureId,
    this.download,
  });

  @override
  ConsumerState<DownloadedLecturePlayer> createState() =>
      _DownloadedLecturePlayerState();
}

class _DownloadedLecturePlayerState
    extends ConsumerState<DownloadedLecturePlayer>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────
  VideoPlayerController? _vpc;
  ChewieController? _chewieCtrl;

  // ── State ─────────────────────────────────────────────────
  DownloadedLecture? _dl;
  bool _loading = true;
  String? _error;
  double _currentSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // ── Bootstrap: resolve DL then init video ─────────────────
  Future<void> _bootstrap() async {
    DownloadedLecture? dl = widget.download;

    // If not passed, load from DB via provider
    if (dl == null) {
      final asyncVal = await ref.read(
        lectureDownloadProvider(widget.lectureId).future,
      );
      dl = asyncVal;
    }

    if (!mounted) return;

    if (dl == null || !dl.isCompleted) {
      setState(() {
        _error = 'This lecture is not downloaded on your device.';
        _loading = false;
      });
      return;
    }

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      setState(() {
        _error = 'Please sign in again to access offline downloads.';
        _loading = false;
      });
      return;
    }

    final hasAccess =
        await ref.read(downloadServiceProvider).validateDownloadAccess(dl);
    if (!hasAccess) {
      await ref.read(downloadServiceProvider).purgeIfUnauthorized(dl);
      if (!mounted) return;
      setState(() {
        _error =
            'This download is no longer available because your institute access changed. Please contact the admin if this is unexpected.';
        _loading = false;
      });
      return;
    }

    // Validate the file still exists
    final file = File(dl.localPath);
    if (!await file.exists()) {
      await ref.read(downloadServiceProvider).deleteDownload(
            lectureId: dl.lectureId,
            studentId: dl.studentId,
          );
      if (!mounted) return;
      setState(() {
        _error =
            'The downloaded file could not be found. Please re-download the lecture.';
        _loading = false;
      });
      return;
    }

    _dl = dl;
    await _initVideo(file);
  }

  // ── Init video from local file ─────────────────────────────
  Future<void> _initVideo(File file) async {
    _vpc = VideoPlayerController.file(file);
    await _vpc!.initialize();

    if (!mounted) return;

    setState(() {
      _chewieCtrl = _buildChewie();
      _loading = false;
    });
  }

  ChewieController _buildChewie({Duration? startAt}) => ChewieController(
        videoPlayerController: _vpc!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        startAt: startAt,
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
        additionalOptions: (_) => [
          OptionItem(
            iconData: Icons.speed_rounded,
            title: 'Speed: $_currentSpeed×',
            onTap: (ctx) => _showSpeedSheet(ctx),
          ),
        ],
      );

  // ── Speed sheet ────────────────────────────────────────────
  void _showSpeedSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text('Playback Speed', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _speeds.map((s) {
                  final selected = _currentSpeed == s;
                  return GestureDetector(
                    onTap: () {
                      _vpc?.setPlaybackSpeed(s);
                      final pos = _vpc?.value.position;
                      setState(() {
                        _currentSpeed = s;
                        final old = _chewieCtrl;
                        _chewieCtrl = _buildChewie(startAt: pos);
                        old?.dispose();
                      });
                      setModal(() {});
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '$s×',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vpc?.dispose();
    _chewieCtrl?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(
                  message: _error!,
                  onBack: () => context.pop(),
                )
              : _buildPlayerContent(),
    );
  }

  Widget _buildPlayerContent() {
    final dl = _dl!;
    return Column(
      children: [
        // ── Video area ──────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _chewieCtrl != null
                  ? Chewie(controller: _chewieCtrl!)
                  : const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
            ),
          ),
        ),

        // ── Info panel ──────────────────────────────────────
        Expanded(
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildTitleRow(dl),
                const Divider(height: 1),
                Expanded(
                  child: _OverviewPanel(dl: dl, speed: _currentSpeed),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Title row ─────────────────────────────────────────────
  Widget _buildTitleRow(DownloadedLecture dl) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Text(
                dl.title,
                style: AppTextStyles.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Offline badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.offline_bolt_rounded,
                      size: 13, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text('Offline',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.success)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Overview panel
// ─────────────────────────────────────────────────────────────
class _OverviewPanel extends StatelessWidget {
  final DownloadedLecture dl;
  final double speed;

  const _OverviewPanel({required this.dl, required this.speed});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dl.title, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text(
            dl.courseTitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (dl.formattedDuration.isNotEmpty)
                _chip(Icons.timer_outlined, dl.formattedDuration,
                    AppColors.primary),
              if (dl.formattedSize.isNotEmpty)
                _chip(Icons.storage_rounded, dl.formattedSize,
                    AppColors.info),
              _chip(Icons.speed_rounded, 'Speed: $speed×', AppColors.warning),
              _chip(Icons.offline_bolt_rounded, 'Offline',
                  AppColors.success),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.offline_bolt_rounded,
                    color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are watching this lecture offline.\nInternet connection is not required, but offline access may expire if your institute enrollment changes.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: color, fontSize: 11)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Loading view
// ─────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading offline video…',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Error view
// ─────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _ErrorView({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'Cannot play video',
              style: AppTextStyles.headlineMedium
                  .copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Downloads may be removed automatically if the file becomes invalid or your institute access changes.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
