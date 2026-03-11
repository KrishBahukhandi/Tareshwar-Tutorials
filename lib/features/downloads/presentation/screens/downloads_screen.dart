// ─────────────────────────────────────────────────────────────
//  downloads_screen.dart  –  Student's offline downloads hub.
//
//  Features:
//    • Lists all downloaded lectures (per current student)
//    • Shows in-progress downloads with live progress bars
//    • Delete individual downloads or clear all
//    • Shows storage usage summary
//    • Opens DownloadedLecturePlayer on tap
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/services/auth_service.dart'
    show currentUserProvider;
import '../../download_providers.dart';
import '../widgets/downloaded_lecture_tile.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    if (user == null) {
      return const Scaffold(
        body: Center(
            child:
                CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return _DownloadsView(studentId: user.id);
  }
}

// ─────────────────────────────────────────────────────────────
class _DownloadsView extends ConsumerWidget {
  final String studentId;
  const _DownloadsView({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(downloadsRefreshProvider);
    final downloadsAsync = ref.watch(studentDownloadsProvider);
    final storageAsync = ref.watch(downloadStorageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title:
                Text('Downloads', style: AppTextStyles.headlineLarge),
            actions: [
              downloadsAsync.whenOrNull(
                    data: (list) => list.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              color: AppColors.error,
                            ),
                            tooltip: 'Delete all downloads',
                            onPressed: () => _confirmDeleteAll(
                                context, ref, studentId),
                          )
                        : null,
                  ) ??
                  const SizedBox.shrink(),
              const SizedBox(width: 4),
            ],
          ),

          // ── Storage summary ───────────────────────────────
          SliverToBoxAdapter(
            child: storageAsync.maybeWhen(
              data: (bytes) => bytes > 0
                  ? _StorageSummary(bytes: bytes)
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // ── Content ───────────────────────────────────────
          downloadsAsync.when(
            loading: () => _buildLoadingSliver(),
            error: (e, _) => SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load downloads',
                subtitle: e.toString(),
                iconColor: AppColors.error,
                actionLabel: 'Retry',
                onAction: () =>
                    ref.invalidate(studentDownloadsProvider),
              ),
            ),
            data: (downloads) {
              if (downloads.isEmpty) {
                return const SliverFillRemaining(
                  child: AppEmptyState(
                    icon: Icons.download_for_offline_rounded,
                    title: 'No Downloads Yet',
                    subtitle:
                        'Download lectures to watch them offline.\nTap the download icon on any lecture.',
                  ),
                );
              }

              final active = downloads
                  .where((d) =>
                      d.isDownloading ||
                      d.status == DownloadStatus.queued)
                  .toList();
              final completed =
                  downloads.where((d) => d.isCompleted).toList();
              final failed = downloads
                  .where((d) =>
                      d.isFailed ||
                      d.status == DownloadStatus.paused)
                  .toList();

              return SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (active.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.downloading_rounded,
                        label: 'Downloading',
                        count: active.length,
                        color: AppColors.primary,
                      ),
                      ...active.map((d) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs),
                            child: _LiveDownloadTile(
                              key: ValueKey('dl_${d.lectureId}'),
                              download: d,
                              onDelete: () => _deleteOne(
                                  context, ref, d, studentId),
                            ),
                          )),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (failed.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.error_outline_rounded,
                        label: 'Failed / Paused',
                        count: failed.length,
                        color: AppColors.warning,
                      ),
                      ...failed.map((d) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs),
                            child: DownloadedLectureTile(
                              key: ValueKey('fail_${d.lectureId}'),
                              download: d,
                              onTap: () {},
                              onDelete: () => _deleteOne(
                                  context, ref, d, studentId),
                            ),
                          )),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (completed.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.check_circle_rounded,
                        label: 'Downloaded',
                        count: completed.length,
                        color: AppColors.success,
                      ),
                      ...completed.map((d) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs),
                            child: DownloadedLectureTile(
                              key: ValueKey('done_${d.lectureId}'),
                              download: d,
                              onTap: () => context.push(
                                AppRoutes.downloadedPlayerPath(
                                    d.lectureId),
                                extra: d,
                              ),
                              onDelete: () => _deleteOne(
                                  context, ref, d, studentId),
                            ),
                          )),
                    ],
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Loading placeholders ───────────────────────────────────
  SliverList _buildLoadingSliver() => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DownloadedLectureTileShimmer(),
          ),
          childCount: 5,
        ),
      );

  // ── Delete one ─────────────────────────────────────────────
  Future<void> _deleteOne(
    BuildContext context,
    WidgetRef ref,
    DownloadedLecture dl,
    String studentId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll),
        title: const Text('Delete Download'),
        content: Text('Remove "${dl.title}" from your device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    await ref.read(downloadServiceProvider).deleteDownload(
          lectureId: dl.lectureId,
          studentId: studentId,
        );

    ref.invalidate(studentDownloadsProvider);
    ref.invalidate(downloadStorageProvider);
    ref.read(downloadsRefreshProvider.notifier).state++;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${dl.title}" removed from downloads.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── Delete all ─────────────────────────────────────────────
  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    String studentId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll),
        title: const Text('Delete All Downloads'),
        content: const Text(
            'This will remove all downloaded videos from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    await ref
        .read(downloadServiceProvider)
        .deleteAllDownloads(studentId);

    ref.invalidate(studentDownloadsProvider);
    ref.invalidate(downloadStorageProvider);
    ref.read(downloadsRefreshProvider.notifier).state++;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All downloads removed.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Storage summary banner
// ─────────────────────────────────────────────────────────────
class _StorageSummary extends StatelessWidget {
  final int bytes;
  const _StorageSummary({required this.bytes});

  String get _formatted {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: AppCard(
        gradient: AppColors.primaryGradient,
        hasBorder: false,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storage_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Storage Used',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: Colors.white70)),
                  Text(
                    _formatted,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            const Icon(Icons.info_outline_rounded,
                color: Colors.white60, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
                color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          AppBadge(
            label: '$count',
            color: color,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Live progress tile – rebuilds via stream
// ─────────────────────────────────────────────────────────────
class _LiveDownloadTile extends ConsumerWidget {
  final DownloadedLecture download;
  final VoidCallback onDelete;

  const _LiveDownloadTile({
    super.key,
    required this.download,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync =
        ref.watch(downloadProgressProvider(download.lectureId));
    final live = streamAsync.valueOrNull ?? download;

    return DownloadedLectureTile(
      download: live,
      onTap: () {},
      onDelete: onDelete,
    );
  }
}
