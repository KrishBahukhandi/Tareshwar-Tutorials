// ─────────────────────────────────────────────────────────────
//  teacher_upload_screen.dart
//  Course picker → opens ContentUploadScreen
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/services/auth_service.dart';
import '../providers/teacher_dashboard_providers.dart';

class TeacherUploadScreen extends ConsumerWidget {
  const TeacherUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(teacherCoursesListProvider);
    final uid =
        ref.read(authServiceProvider).currentAuthUser?.id ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Content', style: AppTextStyles.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Upload videos, PDFs, or notes to any of your courses.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          Text('Select a Course', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 12),

          coursesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.error)),
            data: (courses) => courses.isEmpty
                ? _NoCourses()
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: courses
                        .map((c) => _CourseCard(
                              title: c.title,
                              courseId: c.id,
                              teacherId: uid,
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final String title;
  final String courseId;
  final String teacherId;
  const _CourseCard({
    required this.title,
    required this.courseId,
    required this.teacherId,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.folder_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(height: 8),
                Text(title,
                    style: AppTextStyles.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go(
                      '${AppRoutes.teacherDashboard}/upload/$courseId?teacherId=$teacherId',
                    ),
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _NoCourses extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Create a course first to upload content.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      );
}
