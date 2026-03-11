// ─────────────────────────────────────────────────────────────
//  upload_lecture_screen.dart
//  Teacher screen to upload a Lecture (video + optional PDF)
//  into a specific Chapter.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/content_upload_providers.dart';
import '../widgets/lecture_upload_form.dart';

class UploadLectureScreen extends ConsumerWidget {
  final String chapterId;
  final String courseId;
  final String chapterName;
  final String courseTitle;

  const UploadLectureScreen({
    super.key,
    required this.chapterId,
    required this.courseId,
    this.chapterName = 'Chapter',
    this.courseTitle = 'Course',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadLectureProvider);

    // ── React to success / error ──────────────────────────
    ref.listen(uploadLectureProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lecture uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(uploadLectureProvider.notifier).reset();
        Navigator.of(context).pop(true);
      }

      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upload Lecture',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            Text(
              '$courseTitle › $chapterName',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header card ───────────────────────────
                _UploadHeaderCard(
                  courseTitle: courseTitle,
                  chapterName: chapterName,
                ),

                const SizedBox(height: 28),

                // ── Upload form ───────────────────────────
                LectureUploadForm(
                  isLoading: state.isSubmitting,
                  uploadProgress: state.uploadProgress,
                  onSubmit: (data) async {
                    await ref
                        .read(uploadLectureProvider.notifier)
                        .submit(
                          chapterId: chapterId,
                          courseId: courseId,
                          title: data.title,
                          description: data.description,
                          videoBytes: data.videoBytes,
                          videoFileName: data.videoFileName,
                          pdfBytes: data.pdfBytes,
                          pdfFileName: data.pdfFileName,
                          durationSeconds: data.durationSeconds,
                          isFree: data.isFree,
                          sortOrder: data.sortOrder,
                        );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Header card for context breadcrumb
// ─────────────────────────────────────────────────────────────
class _UploadHeaderCard extends StatelessWidget {
  final String courseTitle;
  final String chapterName;

  const _UploadHeaderCard({
    required this.courseTitle,
    required this.chapterName,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_upload_rounded,
                color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upload a Lecture',
                    style: AppTextStyles.headlineSmall
                        .copyWith(color: color)),
                const SizedBox(height: 4),
                Text(
                  'Videos and PDFs are stored securely in Supabase Storage. '
                  'Accepted video formats: MP4, MOV, MKV.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 10),
                // ── Breadcrumb pills ──────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _BreadcrumbPill(
                        icon: Icons.school_rounded,
                        label: courseTitle),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.textHint),
                    _BreadcrumbPill(
                        icon: Icons.bookmark_rounded,
                        label: chapterName),
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

class _BreadcrumbPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BreadcrumbPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label,
                style: AppTextStyles.labelMedium,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}
