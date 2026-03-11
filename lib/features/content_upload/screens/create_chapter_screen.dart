// ─────────────────────────────────────────────────────────────
//  create_chapter_screen.dart
//  Teacher screen to add a Chapter to a Subject.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/content_upload_providers.dart';
import '../widgets/chapter_form.dart';

class CreateChapterScreen extends ConsumerWidget {
  final String subjectId;
  final String subjectName;
  final String courseTitle;

  const CreateChapterScreen({
    super.key,
    required this.subjectId,
    this.subjectName = 'Subject',
    this.courseTitle = 'Course',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createChapterProvider);

    // ── React to success / error ──────────────────────────
    ref.listen(createChapterProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chapter created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(createChapterProvider.notifier).reset();
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
            const Text('Add Chapter',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            Text(
              '$courseTitle › $subjectName',
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
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header card ───────────────────────────
                _ModuleHeaderCard(
                  icon: Icons.bookmark_rounded,
                  color: AppColors.secondary,
                  title: 'New Chapter',
                  subtitle:
                      'Chapters break a subject into focused learning units. '
                      'You can upload lectures and tests inside each chapter.',
                ),

                const SizedBox(height: 28),

                // ── The form ──────────────────────────────
                ChapterForm(
                  isLoading: state.isSubmitting,
                  onSubmit: (name, sortOrder) async {
                    await ref
                        .read(createChapterProvider.notifier)
                        .submit(
                          subjectId: subjectId,
                          name: name,
                          sortOrder: sortOrder,
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

// ── Shared header card ────────────────────────────────────────
class _ModuleHeaderCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _ModuleHeaderCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
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
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.headlineSmall
                        .copyWith(color: color)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
