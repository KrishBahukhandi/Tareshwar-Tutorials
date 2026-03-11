// ─────────────────────────────────────────────────────────────
//  lecture_player_screen.dart  –  Full-featured video player
//  Features:
//    • Video streaming via video_player + Chewie
//    • Playback speed control (0.5× – 2×)
//    • Resume from last watched position (Supabase watch_progress)
//    • Progress saved every 10 s (or on dispose)
//    • Tab panel: Overview | Notes | Attachments | Doubts
//    • Download lecture notes (PDF)
// ─────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/theme_barrel.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/course_service.dart';
import '../../../../shared/services/doubt_service.dart';
import '../../../../shared/services/app_providers.dart'
    show watchProgressProvider;
import '../../../downloads/presentation/widgets/download_button.dart';
import '../../../../shared/services/analytics_service.dart';
import '../../../../shared/services/progress_service.dart';

// ─────────────────────────────────────────────────────────────
//  Feature-level providers
// ─────────────────────────────────────────────────────────────

final _lectureDetailProvider =
    FutureProvider.autoDispose.family<LectureModel, String>((ref, id) {
  return ref.watch(courseServiceProvider).fetchLecture(id);
});

final _doubtsStreamProvider =
    StreamProvider.autoDispose.family<List<DoubtModel>, String>(
        (ref, lectureId) {
  return ref.watch(doubtServiceProvider).doubtsStream(lectureId);
});

// ─────────────────────────────────────────────────────────────
//  Speed options
// ─────────────────────────────────────────────────────────────
const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

// ─────────────────────────────────────────────────────────────
//  LecturePlayerScreen
// ─────────────────────────────────────────────────────────────
class LecturePlayerScreen extends ConsumerStatefulWidget {
  final String lectureId;
  const LecturePlayerScreen({super.key, required this.lectureId});

  @override
  ConsumerState<LecturePlayerScreen> createState() =>
      _LecturePlayerScreenState();
}

class _LecturePlayerScreenState extends ConsumerState<LecturePlayerScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────
  VideoPlayerController? _vpc;
  ChewieController? _chewieCtrl;
  late TabController _tabCtrl;
  final _doubtCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────
  bool _videoInitDone = false;
  double _currentSpeed = 1.0;
  Timer? _progressTimer;
  int _lastSavedSeconds = -1;
  bool _completionTracked = false; // analytics: fire lecture_completed once
  String? _resolvedCourseId;       // resolved lazily via chapter → subject → course

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  // ── Video initialisation ──────────────────────────────────
  Future<void> _initVideo(String url, int resumeSeconds) async {
    if (_videoInitDone) return;
    _videoInitDone = true;

    _vpc = VideoPlayerController.networkUrl(Uri.parse(url));
    await _vpc!.initialize();

    if (resumeSeconds > 5) {
      await _vpc!.seekTo(Duration(seconds: resumeSeconds));
    }

    if (!mounted) return;
    setState(() {
      _chewieCtrl = _buildChewieCtrl();
    });

    // Save progress every 10 s
    _progressTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  // ── Analytics: track lecture started + resolve courseId ──
  Future<void> _trackLectureStarted(LectureModel lecture) async {
    // Resolve courseId: chapter → subject → course
    if (_resolvedCourseId == null) {
      try {
        final chapter = await ref
            .read(courseServiceProvider)
            .fetchChapterById(lecture.chapterId);
        if (chapter != null) {
          final subject = await ref
              .read(courseServiceProvider)
              .fetchSubjectById(chapter.subjectId);
          _resolvedCourseId = subject?.courseId;
        }
      } catch (_) {}
    }
    ref.read(analyticsServiceProvider).trackLectureStarted(
          lectureId:    lecture.id,
          lectureTitle: lecture.title,
          courseId:     _resolvedCourseId,
        );
  }

  ChewieController _buildChewieCtrl({Duration? startAt}) =>
      ChewieController(
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

  // ── Save progress ─────────────────────────────────────────
  void _saveProgress() {
    final pos = _vpc?.value.position.inSeconds ?? 0;
    final dur = _vpc?.value.duration.inSeconds ?? 0;
    if (pos == _lastSavedSeconds || pos == 0) return;
    _lastSavedSeconds = pos;

    final userId = ref.read(authServiceProvider).currentAuthUser?.id;
    if (userId == null) return;

    final isCompleted = dur > 0 && pos >= dur - 5;

    // Use progressService so course_completed analytics fires automatically
    ref.read(progressServiceProvider).saveProgress(
          studentId:   userId,
          lectureId:   widget.lectureId,
          watchedSeconds: pos,
          completed:   isCompleted,
          courseId:    _resolvedCourseId,
          courseTitle: _currentCourseTitle,
        );

    // Analytics: fire lecture_completed exactly once
    if (isCompleted && !_completionTracked) {
      _completionTracked = true;
      ref.read(analyticsServiceProvider).trackLectureCompleted(
            lectureId:       widget.lectureId,
            lectureTitle:    _currentLectureTitle ?? widget.lectureId,
            watchedSeconds:  pos,
            durationSeconds: dur,
            courseId:        _resolvedCourseId,
          );
    }
  }

  String? _currentLectureTitle;
  String? _currentCourseTitle;

  // ── Speed bottom sheet ────────────────────────────────────
  void _showSpeedSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModal) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl)),
            boxShadow: AppShadows.lg,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.circle,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: const Icon(Icons.speed_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Playback Speed',
                      style: AppTextStyles.headlineSmall),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
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
                        _chewieCtrl = _buildChewieCtrl(startAt: pos);
                        old?.dispose();
                      });
                      setModal(() {});
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: AppRadius.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        boxShadow: selected ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ] : null,
                      ),
                      child: Text(
                        s == 1.0 ? 'Normal' : '$s×',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _progressTimer?.cancel();
    _vpc?.dispose();
    _chewieCtrl?.dispose();
    _tabCtrl.dispose();
    _doubtCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lectureAsync =
        ref.watch(_lectureDetailProvider(widget.lectureId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: lectureAsync.when(
        data: (lecture) => _buildWithProgress(lecture),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _buildError(e),
      ),
    );
  }

  Widget _buildError(Object e) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text('$e',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.invalidate(_lectureDetailProvider(widget.lectureId)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll),
              ),
            ),
          ],
        ),
      );

  Widget _buildWithProgress(LectureModel lecture) {
    final userId = ref.read(authServiceProvider).currentAuthUser?.id;
    final progressKey = userId != null
        ? (studentId: userId, lectureId: widget.lectureId)
        : null;

    final progressAsync = progressKey != null
        ? ref.watch(watchProgressProvider(progressKey))
        : const AsyncValue<LectureProgressModel?>.data(null);

    return progressAsync.when(
      data: (progress) {
        final resumeSeconds = progress?.watchedSeconds ?? 0;
        if (!_videoInitDone && lecture.videoUrl != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _currentLectureTitle = lecture.title; // store for completion tracking
            _initVideo(lecture.videoUrl!, resumeSeconds);
            _trackLectureStarted(lecture);        // analytics: lecture started
          });
        }
        return _buildScaffoldContent(lecture, resumeSeconds);
      },
      loading: () {
        return Column(children: [
          _buildVideoPanel(lecture),
          const Expanded(
            child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary)),
          ),
        ]);
      },
      error: (_, _) {
        if (!_videoInitDone && lecture.videoUrl != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initVideo(lecture.videoUrl!, 0);
          });
        }
        return _buildScaffoldContent(lecture, 0);
      },
    );
  }

  Widget _buildScaffoldContent(LectureModel lecture, int resumeSeconds) {
    return Column(
      children: [
        _buildVideoPanel(lecture),
        Expanded(
          child: Container(
            color: AppColors.background,
            child: Column(
              children: [
                _buildTitleRow(lecture),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _OverviewTab(
                        lecture: lecture,
                        resumeSeconds: resumeSeconds,
                        speed: _currentSpeed,
                      ),
                      _NotesTab(
                        notesUrl: lecture.notesUrl,
                        lectureTitle: lecture.title,
                        lectureId: widget.lectureId,
                      ),
                      _AttachmentsTab(attachments: lecture.attachments),
                      _DoubtsTab(
                        lectureId: widget.lectureId,
                        doubtCtrl: _doubtCtrl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Video area ────────────────────────────────────────────
  Widget _buildVideoPanel(LectureModel lecture) => SafeArea(
        bottom: false,
        child: Container(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _chewieCtrl != null
                ? Chewie(controller: _chewieCtrl!)
                : lecture.videoUrl == null
                    ? _noVideoPlaceholder()
                    : _videoLoadingPlaceholder(),
          ),
        ),
      );

  Widget _noVideoPlaceholder() => Container(
        color: const Color(0xFF0D0D0D),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_rounded,
                  size: 40, color: Colors.white38),
            ),
            const SizedBox(height: 14),
            Text('No video available',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: Colors.white38)),
          ],
        ),
      );

  Widget _videoLoadingPlaceholder() => Container(
        color: const Color(0xFF0D0D0D),
        child: const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        ),
      );

  // ── Title row ─────────────────────────────────────────────
  Widget _buildTitleRow(LectureModel lecture) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
              color: AppColors.textPrimary,
            ),
            Expanded(
              child: Text(
                lecture.title,
                style: AppTextStyles.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // ── Download button ────────────────────────────
            if (lecture.videoUrl != null)
              DownloadButton(
                lecture: lecture,
                courseTitle: '',
                compact: true,
              ),
            const SizedBox(width: 6),
            // ── Speed pill ─────────────────────────────────
            GestureDetector(
              onTap: () => _showSpeedSheet(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.circle,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _currentSpeed == 1.0
                          ? '1×'
                          : '$_currentSpeed×',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // ── Tab bar ───────────────────────────────────────────────
  Widget _buildTabBar() => Container(
        color: AppColors.surface,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: AppTextStyles.labelMedium
              .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTextStyles.labelMedium,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: AppColors.border.withValues(alpha: 0.5),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Notes'),
            Tab(text: 'Attachments'),
            Tab(text: 'Doubts'),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Overview Tab
// ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final LectureModel lecture;
  final int resumeSeconds;
  final double speed;

  const _OverviewTab({
    required this.lecture,
    required this.resumeSeconds,
    required this.speed,
  });

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return sec > 0 ? '${m}m ${sec}s' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Lecture title ────────────────────────────
          Text(lecture.title, style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.sm),

          // ── Meta chips ───────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (lecture.durationSeconds != null)
                _MetaChip(
                  icon: Icons.timer_outlined,
                  label: lecture.formattedDuration,
                  color: AppColors.primary,
                ),
              if (resumeSeconds > 0)
                _MetaChip(
                  icon: Icons.bookmark_rounded,
                  label: 'Resume at ${_fmt(resumeSeconds)}',
                  color: AppColors.warning,
                ),
              _MetaChip(
                icon: Icons.speed_rounded,
                label: speed == 1.0 ? 'Normal speed' : '$speed× speed',
                color: AppColors.info,
              ),
              if (lecture.isFree)
                _MetaChip(
                  icon: Icons.lock_open_rounded,
                  label: 'Free',
                  color: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Description ──────────────────────────────
          if (lecture.description != null &&
              lecture.description!.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              hasBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('About this Lecture',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    lecture.description!,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary, height: 1.65),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Tip card ─────────────────────────────────
          AppCard(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.secondary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            hasBorder: false,
            shadows: [],
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(Icons.tips_and_updates_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pro tip',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.primary)),
                      const SizedBox(height: 3),
                      Text(
                        'View lecture notes in the Notes tab. Post questions in the Doubts tab.',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Meta chip
// ─────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: AppRadius.circle,
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
}

// ─────────────────────────────────────────────────────────────
//  Notes Tab
// ─────────────────────────────────────────────────────────────
class _NotesTab extends StatelessWidget {
  final String? notesUrl;
  final String lectureTitle;
  final String lectureId;

  const _NotesTab({
    this.notesUrl,
    required this.lectureTitle,
    required this.lectureId,
  });

  @override
  Widget build(BuildContext context) {
    if (notesUrl == null || notesUrl!.isEmpty) {
      return AppEmptyState(
        icon: Icons.note_outlined,
        title: 'No notes available',
        subtitle: 'Notes for this lecture haven\'t been uploaded yet.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── PDF preview card ─────────────────────────
          AppCard(
            padding: EdgeInsets.zero,
            hasBorder: false,
            shadows: AppShadows.md,
            gradient: AppColors.primaryGradient,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text('Lecture Notes',
                      style: AppTextStyles.headlineSmall
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('PDF Document',
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.white60)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── View in-app ───────────────────────────────
          PrimaryButton(
            label: 'View Notes',
            icon: Icons.open_in_new_rounded,
            onTap: () => context.push(
              AppRoutes.lectureNotesPath(
                lectureId,
                notesUrl: notesUrl!,
                title: lectureTitle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Open in browser ───────────────────────────
          SecondaryButton(
            label: 'Open in Browser',
            icon: Icons.launch_rounded,
            onTap: () => launchUrl(
              Uri.parse(notesUrl!),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Attachments Tab
// ─────────────────────────────────────────────────────────────
class _AttachmentsTab extends StatelessWidget {
  final List<LectureAttachment> attachments;
  const _AttachmentsTab({required this.attachments});

  IconData _iconFor(String? type) {
    switch (type?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.attach_file_rounded;
    }
  }

  Color _colorFor(String? type) {
    switch (type?.toLowerCase()) {
      case 'pdf':
        return AppColors.error;
      case 'doc':
      case 'docx':
        return AppColors.info;
      case 'zip':
      case 'rar':
        return AppColors.warning;
      case 'xls':
      case 'xlsx':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return AppEmptyState(
        icon: Icons.attach_file_rounded,
        title: 'No attachments',
        subtitle: 'No supplementary files have been added.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: attachments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, i) {
        final att = attachments[i];
        final color = _colorFor(att.fileType);
        return AppCard(
          padding: EdgeInsets.zero,
          onTap: () => launchUrl(
            Uri.parse(att.url),
            mode: LaunchMode.externalApplication,
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(_iconFor(att.fileType), color: color, size: 22),
            ),
            title: Text(att.name,
                style: AppTextStyles.labelLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            subtitle: att.fileType != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        AppBadge(
                          label: att.fileType!.toUpperCase(),
                          color: color,
                        ),
                      ],
                    ),
                  )
                : null,
            trailing: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: IconButton(
                icon: const Icon(Icons.download_rounded,
                    color: AppColors.primary, size: 20),
                tooltip: 'Download',
                onPressed: () => launchUrl(
                  Uri.parse(att.url),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Doubts Tab
// ─────────────────────────────────────────────────────────────
class _DoubtsTab extends ConsumerStatefulWidget {
  final String lectureId;
  final TextEditingController doubtCtrl;
  const _DoubtsTab({required this.lectureId, required this.doubtCtrl});

  @override
  ConsumerState<_DoubtsTab> createState() => _DoubtsTabState();
}

class _DoubtsTabState extends ConsumerState<_DoubtsTab> {
  bool _submitting = false;

  Future<void> _postDoubt() async {
    final q = widget.doubtCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final userId = ref.read(authServiceProvider).currentAuthUser?.id;
      if (userId == null) return;
      await ref.read(doubtServiceProvider).postDoubt(
            studentId: userId,
            question: q,
            lectureId: widget.lectureId,
          );
      widget.doubtCtrl.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doubtsAsync =
        ref.watch(_doubtsStreamProvider(widget.lectureId));

    return Column(
      children: [
        // ── Input bar ─────────────────────────────────
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.doubtCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ask a doubt…',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.circle,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.circle,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.circle,
                      borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1.5),
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _postDoubt(),
                ),
              ),
              const SizedBox(width: 8),
              _submitting
                  ? const SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: AppRadius.smAll,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                        onPressed: _postDoubt,
                      ),
                    ),
            ],
          ),
        ),

        // ── Doubts list ───────────────────────────────
        Expanded(
          child: doubtsAsync.when(
            data: (doubts) => doubts.isEmpty
                ? AppEmptyState(
                    icon: Icons.question_answer_outlined,
                    title: 'No doubts yet',
                    subtitle: 'Be the first to ask a question!',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: doubts.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) =>
                        _DoubtCard(doubt: doubts[i]),
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Doubt card
// ─────────────────────────────────────────────────────────────
class _DoubtCard extends StatelessWidget {
  final DoubtModel doubt;
  const _DoubtCard({required this.doubt});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar row ───────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  (doubt.studentName ?? 'S')[0].toUpperCase(),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary,
                          fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doubt.studentName ?? 'Student',
                        style: AppTextStyles.labelLarge),
                  ],
                ),
              ),
              if (doubt.isAnswered)
                AppBadge(
                  label: 'Answered',
                  color: AppColors.success,
                  icon: Icons.check_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Question ─────────────────────────────────
          Text(doubt.question,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.55)),

          // ── Answer ───────────────────────────────────
          if (doubt.answer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.06),
                borderRadius: AppRadius.smAll,
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded,
                          size: 13, color: AppColors.success),
                      const SizedBox(width: 5),
                      Text("Teacher's Answer",
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.success,
                                  fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(doubt.answer!,
                      style: AppTextStyles.bodySmall
                          .copyWith(height: 1.55)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
