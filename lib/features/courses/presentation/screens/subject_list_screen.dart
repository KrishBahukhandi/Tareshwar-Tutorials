// ─────────────────────────────────────────────────────────────
//  subject_list_screen.dart  –  Lists all chapters in a
//  subject.  Tapping a chapter → ChapterListScreen (lectures).
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_widgets.dart';
import '../../../../core/utils/app_router.dart';
import '../providers/course_providers.dart';
import '../widgets/chapter_tile.dart';

// ─────────────────────────────────────────────────────────────
class SubjectListScreen extends ConsumerWidget {
  final String courseId;
  final String subjectId;
  const SubjectListScreen({
    super.key,
    required this.courseId,
    required this.subjectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(subjectChaptersProvider(subjectId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Chapters'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          chaptersAsync.maybeWhen(
            data: (chapters) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${chapters.length} chapter${chapters.length != 1 ? 's' : ''}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: chaptersAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (ctx, i) => const ChapterTileShimmer(),
        ),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (chapters) => chapters.isEmpty
            ? const _EmptyView()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: chapters.length,
                itemBuilder: (ctx, i) => ChapterTile(
                  chapter: chapters[i],
                  index: i,
                  onTap: () => context.push(
                    AppRoutes.chapterDetailPath(
                        courseId, subjectId, chapters[i].id),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty & error
// ─────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.folder_open_rounded,
      title: 'No chapters yet',
      subtitle: 'Chapters will appear here once added.',
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Failed to load chapters',
      subtitle: message,
      iconColor: AppColors.error,
    );
  }
}
