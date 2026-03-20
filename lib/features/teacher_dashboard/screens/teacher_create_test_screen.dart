// ─────────────────────────────────────────────────────────────
//  teacher_create_test_screen.dart
//  Teacher test manager: pick a course, then create and manage
//  chapter-based tests from one place.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/models/models.dart';
import '../../teacher_courses/providers/teacher_course_providers.dart';
import '../../teacher_tests/providers/teacher_test_providers.dart';
import '../providers/teacher_dashboard_providers.dart';

class TeacherCreateTestScreen extends ConsumerStatefulWidget {
  const TeacherCreateTestScreen({super.key});

  @override
  ConsumerState<TeacherCreateTestScreen> createState() =>
      _TeacherCreateTestScreenState();
}

class _TeacherCreateTestScreenState
    extends ConsumerState<TeacherCreateTestScreen> {
  String? _selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(teacherCoursesListProvider);
    final selectedCourseId = _selectedCourseId;
    final outlineAsync = selectedCourseId == null
        ? const AsyncValue<List<SubjectModel>>.data([])
        : ref.watch(courseOutlineProvider(selectedCourseId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Test', style: AppTextStyles.displaySmall),
            const SizedBox(height: 4),
            Text(
              'Choose a course chapter, then create, review, and publish tests with the full question workflow.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Course'),
                  const SizedBox(height: 8),
                  coursesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e', style: AppTextStyles.bodySmall),
                    data: (courses) => DropdownButtonFormField<String>(
                      initialValue: _selectedCourseId,
                      decoration: const InputDecoration(
                        hintText: 'Select a course',
                        prefixIcon: Icon(Icons.menu_book_rounded),
                      ),
                      items: courses
                          .map(
                            (course) => DropdownMenuItem<String>(
                              value: course.id,
                              child: Text(course.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCourseId = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tests are attached to chapters, so this picker uses your actual course outline instead of a loose course-only form.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (selectedCourseId == null)
              const _PickerHint(
                icon: Icons.touch_app_rounded,
                title: 'Pick a course to continue',
                message:
                    'Once you select a course, you can create tests for any chapter and manage existing ones here.',
              )
            else
              outlineAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => _PickerHint(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load course outline',
                  message: e.toString(),
                ),
                data: (subjects) {
                  final selectedCourse = coursesAsync.valueOrNull
                      ?.where((c) => c.id == selectedCourseId)
                      .cast<CourseModel?>()
                      .firstOrNull;

                  if (subjects.isEmpty) {
                    return const _PickerHint(
                      icon: Icons.layers_clear_rounded,
                      title: 'No subjects yet',
                      message:
                          'Add subjects and chapters in course management first, then create tests here.',
                    );
                  }

                  final chapterEntries = <_ChapterEntry>[];
                  for (final subject in subjects) {
                    for (final chapter in subject.chapters) {
                      chapterEntries.add(
                        _ChapterEntry(subject: subject, chapter: chapter),
                      );
                    }
                  }

                  if (chapterEntries.isEmpty) {
                    return const _PickerHint(
                      icon: Icons.library_books_outlined,
                      title: 'No chapters yet',
                      message:
                          'This course has subjects, but no chapters available to attach tests to yet.',
                    );
                  }

                  return Column(
                    children: chapterEntries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ChapterTestCard(
                              courseId: selectedCourseId,
                              courseTitle: selectedCourse?.title ?? 'Course',
                              subject: entry.subject,
                              chapter: entry.chapter,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ChapterEntry {
  final SubjectModel subject;
  final ChapterModel chapter;

  const _ChapterEntry({required this.subject, required this.chapter});
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.labelLarge);
}

class _PickerHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PickerHint({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTestCard extends ConsumerWidget {
  final String courseId;
  final String courseTitle;
  final SubjectModel subject;
  final ChapterModel chapter;

  const _ChapterTestCard({
    required this.courseId,
    required this.courseTitle,
    required this.subject,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(teacherTestsProvider(chapter.id));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(chapter.name, style: AppTextStyles.headlineSmall),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(
                  AppRoutes.createTestPath(chapter.id),
                  extra: {
                    'courseId': courseId,
                    'courseTitle': courseTitle,
                    'chapterName': chapter.name,
                  },
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Test'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          testsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Could not load tests: $e',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
            data: (tests) {
              if (tests.isEmpty) {
                return Text(
                  'No tests yet for this chapter.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }

              return Column(
                children: tests
                    .map(
                      (test) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ExistingTestTile(
                          chapterId: chapter.id,
                          chapterName: chapter.name,
                          courseTitle: courseTitle,
                          test: test,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExistingTestTile extends ConsumerWidget {
  final String chapterId;
  final String chapterName;
  final String courseTitle;
  final TestModel test;

  const _ExistingTestTile({
    required this.chapterId,
    required this.chapterName,
    required this.courseTitle,
    required this.test,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teacherTestStatsProvider(test.id));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test.title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.timer_outlined,
                      label: '${test.durationMinutes} min',
                    ),
                    _InfoChip(
                      icon: Icons.star_border_rounded,
                      label: '${test.totalMarks} marks',
                    ),
                    ...statsAsync.maybeWhen(
                      data: (stats) => [
                        _InfoChip(
                          icon: Icons.format_list_numbered_rounded,
                          label: '${stats.questionCount} questions',
                        ),
                        _InfoChip(
                          icon: Icons.people_alt_outlined,
                          label: '${stats.attemptCount} attempts',
                          color: stats.hasAttempts
                              ? AppColors.info
                              : AppColors.textSecondary,
                        ),
                      ],
                      orElse: () => const [],
                    ),
                    _InfoChip(
                      icon: test.isPublished
                          ? Icons.public_rounded
                          : Icons.edit_note_rounded,
                      label: test.isPublished ? 'Published' : 'Draft',
                      color: test.isPublished
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => context.push(
              AppRoutes.testPreviewPath(test.id),
              extra: {
                'chapterId': chapterId,
                'chapterName': chapterName,
                'courseTitle': courseTitle,
              },
            ),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolved),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: resolved,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
