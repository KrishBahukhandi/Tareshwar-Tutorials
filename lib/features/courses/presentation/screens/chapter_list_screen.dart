// ─────────────────────────────────────────────────────────────
//  chapter_list_screen.dart  –  Lists all lectures in a
//  chapter with per-lecture progress badges and chapter summary.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/auth_service.dart';
import '../providers/course_providers.dart'
    show chapterLecturesProvider, currentStudentProgressProvider, ChapterProgress;
import '../widgets/lecture_tile.dart';
import '../widgets/progress_widgets.dart'
    show ChapterProgressIndicator, CourseProgressBar;

// ─────────────────────────────────────────────────────────────
class ChapterListScreen extends ConsumerWidget {
  final String courseId;
  final String subjectId;
  final String chapterId;
  final String? chapterName;

  const ChapterListScreen({
    super.key,
    required this.courseId,
    required this.subjectId,
    required this.chapterId,
    this.chapterName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lecturesAsync = ref.watch(chapterLecturesProvider(chapterId));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isEnrolled = user != null;

    final progressMapAsync = user != null
        ? ref.watch(currentStudentProgressProvider)
        : const AsyncValue<Map<String, LectureProgressModel>>.data({});

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(chapterName ?? 'Lectures'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          lecturesAsync.maybeWhen(
            data: (lectures) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${lectures.length} lecture${lectures.length != 1 ? 's' : ''}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: lecturesAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (ctx, i) => const LectureTileShimmer(),
        ),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (lectures) {
          if (lectures.isEmpty) return const _EmptyView();

          return progressMapAsync.when(
            data: (progressMap) {
              final lectureIds = lectures.map((l) => l.id).toList();
              final completedCount = lectureIds
                  .where((id) => progressMap[id]?.completed ?? false)
                  .length;
              final chapterPrg = ChapterProgress(
                chapterId: chapterId,
                totalLectures: lectureIds.length,
                completedLectures: completedCount,
              );

              return Column(
                children: [
                  if (isEnrolled)
                    _ChapterProgressHeader(progress: chapterPrg),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: lectures.length,
                      itemBuilder: (ctx, i) => LectureTile(
                        lecture: lectures[i],
                        index: i,
                        isEnrolled: isEnrolled,
                        progress: progressMap[lectures[i].id],
                        onTap: () => context.push(
                          AppRoutes.lecturePlayerPath(lectures[i].id),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: lectures.length,
              itemBuilder: (ctx, i) => LectureTile(
                lecture: lectures[i],
                index: i,
                isEnrolled: isEnrolled,
                onTap: () => context.push(
                  AppRoutes.lecturePlayerPath(lectures[i].id),
                ),
              ),
            ),
            error: (e, st) => ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: lectures.length,
              itemBuilder: (ctx, i) => LectureTile(
                lecture: lectures[i],
                index: i,
                isEnrolled: isEnrolled,
                onTap: () => context.push(
                  AppRoutes.lecturePlayerPath(lectures[i].id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Chapter progress header
// ─────────────────────────────────────────────────────────────
class _ChapterProgressHeader extends StatelessWidget {
  final ChapterProgress progress;
  const _ChapterProgressHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                progress.isComplete
                    ? Icons.check_circle_rounded
                    : Icons.menu_book_rounded,
                size: 16,
                color:
                    progress.isComplete ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.isComplete
                      ? 'Chapter Complete!'
                      : 'Chapter Progress',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: progress.isComplete
                        ? AppColors.success
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              ChapterProgressIndicator(progress: progress),
            ],
          ),
          const SizedBox(height: 10),
          CourseProgressBar(
            percent: progress.percent,
            showLabel: false,
            height: 5,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty & Error
// ─────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_library_outlined,
              size: 56, color: AppColors.textHint),
          const SizedBox(height: 14),
          Text('No lectures yet', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Lectures will appear here once they are uploaded.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Failed to load lectures',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
