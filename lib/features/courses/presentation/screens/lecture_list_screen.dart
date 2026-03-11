// ─────────────────────────────────────────────────────────────
//  lecture_list_screen.dart  –  All lectures for a course
//  grouped by Subject → Chapter accordion layout.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/auth_service.dart' show currentUserProvider;
import '../../../../shared/services/app_providers.dart'
    show currentStudentProgressProvider;
import '../../../../shared/services/course_service.dart';
import '../../../../shared/services/progress_service.dart' show ChapterProgress;
import '../widgets/lecture_tile.dart';
import '../widgets/progress_widgets.dart'
    show ChapterProgressIndicator;

// ── Provider: subjects with full nested chapters + lectures ──
final _courseSubjectsFullProvider =
    FutureProvider.autoDispose.family<List<SubjectModel>, String>(
  (ref, courseId) {
    return ref.watch(courseServiceProvider).fetchSubjects(courseId);
  },
);

// ─────────────────────────────────────────────────────────────
class LectureListScreen extends ConsumerWidget {
  final String courseId;
  final String? courseTitle;

  const LectureListScreen({
    super.key,
    required this.courseId,
    this.courseTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync =
        ref.watch(_courseSubjectsFullProvider(courseId));
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
        title: Text(courseTitle ?? 'All Lectures'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: subjectsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.error)),
        ),
        data: (subjects) => subjects.isEmpty
            ? const _EmptyView()
            : progressMapAsync.when(
                data: (progressMap) => _SubjectAccordion(
                  subjects: subjects,
                  isEnrolled: isEnrolled,
                  progressMap: progressMap,
                ),
                loading: () => _SubjectAccordion(
                  subjects: subjects,
                  isEnrolled: isEnrolled,
                  progressMap: const {},
                ),
                error: (e, st) => _SubjectAccordion(
                  subjects: subjects,
                  isEnrolled: isEnrolled,
                  progressMap: const {},
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Accordion: Subject → Chapter → Lectures
// ─────────────────────────────────────────────────────────────
class _SubjectAccordion extends StatelessWidget {
  final List<SubjectModel> subjects;
  final bool isEnrolled;
  final Map<String, LectureProgressModel> progressMap;

  const _SubjectAccordion({
    required this.subjects,
    required this.isEnrolled,
    required this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: subjects.length,
      itemBuilder: (ctx, si) => _SubjectSection(
        subject: subjects[si],
        index: si,
        isEnrolled: isEnrolled,
        progressMap: progressMap,
      ),
    );
  }
}

class _SubjectSection extends StatefulWidget {
  final SubjectModel subject;
  final int index;
  final bool isEnrolled;
  final Map<String, LectureProgressModel> progressMap;

  const _SubjectSection({
    required this.subject,
    required this.index,
    required this.isEnrolled,
    required this.progressMap,
  });

  @override
  State<_SubjectSection> createState() => _SubjectSectionState();
}

class _SubjectSectionState extends State<_SubjectSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final totalLectures = widget.subject.chapters
        .fold<int>(0, (s, ch) => s + ch.lectures.length);

    // Compute subject-level completion for the badge
    final allLectureIds = widget.subject.chapters
        .expand((ch) => ch.lectures.map((l) => l.id))
        .toList();
    final completedInSubject = allLectureIds
        .where((id) => widget.progressMap[id]?.completed ?? false)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Subject header ─────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.index + 1}',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.subject.name,
                            style: AppTextStyles.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          widget.isEnrolled && totalLectures > 0
                              ? '$completedInSubject/$totalLectures done'
                              : '$totalLectures lecture${totalLectures != 1 ? 's' : ''}',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: completedInSubject == totalLectures &&
                                      totalLectures > 0 &&
                                      widget.isEnrolled
                                  ? AppColors.success
                                  : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // ── Chapters + lectures ────────────────────────
          if (_expanded)
            ...widget.subject.chapters.map((chapter) =>
                _ChapterSection(
                  chapter: chapter,
                  isEnrolled: widget.isEnrolled,
                  progressMap: widget.progressMap,
                )),
        ],
      ),
    );
  }
}

class _ChapterSection extends StatelessWidget {
  final ChapterModel chapter;
  final bool isEnrolled;
  final Map<String, LectureProgressModel> progressMap;

  const _ChapterSection({
    required this.chapter,
    required this.isEnrolled,
    required this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    final lectureIds = chapter.lectures.map((l) => l.id).toList();
    final completedCount =
        lectureIds.where((id) => progressMap[id]?.completed ?? false).length;
    final chapterPrg = ChapterProgress(
      chapterId: chapter.id,
      totalLectures: lectureIds.length,
      completedLectures: completedCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined,
                  size: 13, color: AppColors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  chapter.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isEnrolled && lectureIds.isNotEmpty) ...[
                const SizedBox(width: 8),
                ChapterProgressIndicator(progress: chapterPrg),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...chapter.lectures.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 2),
              child: LectureTile(
                lecture: entry.value,
                index: entry.key,
                isEnrolled: isEnrolled,
                progress: progressMap[entry.value.id],
                onTap: () => context.push(
                  AppRoutes.lecturePlayerPath(entry.value.id),
                ),
              ),
            )),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.video_library_outlined,
      title: 'No lectures yet',
      subtitle: 'Lectures will appear here once they are uploaded.',
    );
  }
}
