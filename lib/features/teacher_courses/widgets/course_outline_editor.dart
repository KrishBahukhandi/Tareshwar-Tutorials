// ─────────────────────────────────────────────────────────────
//  course_outline_editor.dart
//  Expandable Subject → Chapter → Lecture tree editor widget.
//  Used inside EditCourseScreen to manage course structure.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/models.dart';
import '../providers/teacher_course_providers.dart';

class CourseOutlineEditor extends ConsumerWidget {
  final String courseId;
  const CourseOutlineEditor({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlineAsync = ref.watch(courseOutlineProvider(courseId));

    return outlineAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.error)),
      data: (subjects) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Add subject ───────────────────────────────
          _AddItemButton(
            label: '+ Add Subject',
            color: AppColors.primary,
            onTap: () => _showSubjectDialog(context, ref,
                courseId: courseId),
          ),
          const SizedBox(height: 8),

          if (subjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No subjects yet. Add one above.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ),

          // ── Subject list ──────────────────────────────
          ...subjects.map((subject) => _SubjectTile(
                subject: subject,
                courseId: courseId,
                onRefresh: () => ref
                    .invalidate(courseOutlineProvider(courseId)),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Subject tile (expandable)
// ─────────────────────────────────────────────────────────────
class _SubjectTile extends ConsumerStatefulWidget {
  final SubjectModel subject;
  final String courseId;
  final VoidCallback onRefresh;

  const _SubjectTile({
    required this.subject,
    required this.courseId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_SubjectTile> createState() => _SubjectTileState();
}

class _SubjectTileState extends ConsumerState<_SubjectTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────
          InkWell(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.book_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(subject.name,
                        style: AppTextStyles.headlineSmall
                            .copyWith(fontSize: 14)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        size: 16, color: AppColors.textSecondary),
                    onPressed: () => _showSubjectDialog(context, ref,
                        courseId: widget.courseId, subject: subject),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.error),
                    onPressed: () => _confirmDelete(
                      context,
                      label: 'subject "${subject.name}"',
                      onConfirm: () async {
                        await ref
                            .read(subjectFormProvider.notifier)
                            .delete(
                              subjectId: subject.id,
                              courseId: widget.courseId,
                            );
                        widget.onRefresh();
                      },
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Chapters ────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AddItemButton(
                    label: '+ Add Chapter',
                    color: AppColors.secondary,
                    onTap: () => _showChapterDialog(context, ref,
                        subjectId: subject.id,
                        courseId: widget.courseId),
                  ),
                  const SizedBox(height: 6),
                  ...subject.chapters.map((chapter) =>
                      _ChapterTile(
                        chapter: chapter,
                        subjectId: subject.id,
                        courseId: widget.courseId,
                        onRefresh: widget.onRefresh,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Chapter tile (expandable)
// ─────────────────────────────────────────────────────────────
class _ChapterTile extends ConsumerStatefulWidget {
  final ChapterModel chapter;
  final String subjectId;
  final String courseId;
  final VoidCallback onRefresh;

  const _ChapterTile({
    required this.chapter,
    required this.subjectId,
    required this.courseId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_ChapterTile> createState() => _ChapterTileState();
}

class _ChapterTileState extends ConsumerState<_ChapterTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(chapter.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    '${chapter.lectures.length} lec',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        size: 15, color: AppColors.textSecondary),
                    onPressed: () => _showChapterDialog(context, ref,
                        subjectId: widget.subjectId,
                        courseId: widget.courseId,
                        chapter: chapter),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 15, color: AppColors.error),
                    onPressed: () => _confirmDelete(
                      context,
                      label: 'chapter "${chapter.name}"',
                      onConfirm: () async {
                        await ref
                            .read(chapterFormProvider.notifier)
                            .delete(
                              chapterId: chapter.id,
                              subjectId: widget.subjectId,
                              courseId: widget.courseId,
                            );
                        widget.onRefresh();
                      },
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AddItemButton(
                    label: '+ Add Lecture',
                    color: AppColors.info,
                    onTap: () => _showLectureDialog(context, ref,
                        chapterId: chapter.id,
                        courseId: widget.courseId),
                  ),
                  const SizedBox(height: 4),
                  ...chapter.lectures.map((lec) => _LectureTile(
                        lecture: lec,
                        chapterId: chapter.id,
                        courseId: widget.courseId,
                        onRefresh: widget.onRefresh,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Lecture tile (leaf)
// ─────────────────────────────────────────────────────────────
class _LectureTile extends ConsumerWidget {
  final LectureModel lecture;
  final String chapterId;
  final String courseId;
  final VoidCallback onRefresh;

  const _LectureTile({
    required this.lecture,
    required this.chapterId,
    required this.courseId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            lecture.videoUrl != null
                ? Icons.play_circle_rounded
                : Icons.text_snippet_rounded,
            size: 16,
            color: lecture.isFree
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lecture.title,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontSize: 13),
            ),
          ),
          if (lecture.isFree)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('FREE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success)),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_rounded,
                size: 14, color: AppColors.textSecondary),
            onPressed: () => _showLectureDialog(context, ref,
                chapterId: chapterId,
                courseId: courseId,
                lecture: lecture),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 14, color: AppColors.error),
            onPressed: () => _confirmDelete(
              context,
              label: 'lecture "${lecture.title}"',
              onConfirm: () async {
                await ref.read(lectureFormProvider.notifier).delete(
                      lectureId: lecture.id,
                      chapterId: chapterId,
                      courseId: courseId,
                    );
                onRefresh();
              },
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Small "+" button
// ─────────────────────────────────────────────────────────────
class _AddItemButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AddItemButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child:
            Text(label, style: TextStyle(fontSize: 13, color: color)),
      );
}

// ═════════════════════════════════════════════════════════════
//  Dialogs
// ═════════════════════════════════════════════════════════════

Future<void> _showSubjectDialog(
  BuildContext context,
  WidgetRef ref, {
  required String courseId,
  SubjectModel? subject,
}) async {
  final ctrl = TextEditingController(text: subject?.name ?? '');
  final orderCtrl = TextEditingController(
      text: subject?.sortOrder.toString() ?? '0');
  final isEdit = subject != null;
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Subject' : 'Add Subject'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Subject name'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: orderCtrl,
              decoration:
                  const InputDecoration(labelText: 'Sort order'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx);
            if (isEdit) {
              await ref.read(subjectFormProvider.notifier).update(
                    subjectId: subject.id,
                    courseId: courseId,
                    name: ctrl.text.trim(),
                    sortOrder:
                        int.tryParse(orderCtrl.text) ?? 0,
                  );
            } else {
              await ref.read(subjectFormProvider.notifier).create(
                    courseId: courseId,
                    name: ctrl.text.trim(),
                    sortOrder:
                        int.tryParse(orderCtrl.text) ?? 0,
                  );
            }
          },
          child: Text(isEdit ? 'Update' : 'Add'),
        ),
      ],
    ),
  );
}

Future<void> _showChapterDialog(
  BuildContext context,
  WidgetRef ref, {
  required String subjectId,
  required String courseId,
  ChapterModel? chapter,
}) async {
  final ctrl = TextEditingController(text: chapter?.name ?? '');
  final orderCtrl = TextEditingController(
      text: chapter?.sortOrder.toString() ?? '0');
  final isEdit = chapter != null;
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Chapter' : 'Add Chapter'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: ctrl,
              decoration:
                  const InputDecoration(labelText: 'Chapter name'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: orderCtrl,
              decoration:
                  const InputDecoration(labelText: 'Sort order'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx);
            if (isEdit) {
              await ref.read(chapterFormProvider.notifier).update(
                    chapterId: chapter.id,
                    subjectId: subjectId,
                    courseId: courseId,
                    name: ctrl.text.trim(),
                    sortOrder:
                        int.tryParse(orderCtrl.text) ?? 0,
                  );
            } else {
              await ref.read(chapterFormProvider.notifier).create(
                    subjectId: subjectId,
                    courseId: courseId,
                    name: ctrl.text.trim(),
                    sortOrder:
                        int.tryParse(orderCtrl.text) ?? 0,
                  );
            }
          },
          child: Text(isEdit ? 'Update' : 'Add'),
        ),
      ],
    ),
  );
}

Future<void> _showLectureDialog(
  BuildContext context,
  WidgetRef ref, {
  required String chapterId,
  required String courseId,
  LectureModel? lecture,
}) async {
  final titleCtrl = TextEditingController(text: lecture?.title ?? '');
  final descCtrl =
      TextEditingController(text: lecture?.description ?? '');
  final videoCtrl =
      TextEditingController(text: lecture?.videoUrl ?? '');
  final notesCtrl =
      TextEditingController(text: lecture?.notesUrl ?? '');
  final durCtrl = TextEditingController(
      text: lecture?.durationSeconds?.toString() ?? '');
  final orderCtrl = TextEditingController(
      text: lecture?.sortOrder.toString() ?? '0');
  bool isFree = lecture?.isFree ?? false;
  final isEdit = lecture != null;
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setDlgState) => AlertDialog(
        title: Text(isEdit ? 'Edit Lecture' : 'Add Lecture'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Lecture title'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: videoCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Video URL'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Notes URL'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: durCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Duration (seconds)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: orderCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Sort order'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isFree,
                        onChanged: (v) =>
                            setDlgState(() => isFree = v ?? false),
                      ),
                      const Text('Free preview lecture'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              if (isEdit) {
                await ref
                    .read(lectureFormProvider.notifier)
                    .update(
                      lectureId: lecture.id,
                      chapterId: chapterId,
                      courseId: courseId,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      videoUrl: videoCtrl.text.trim().isEmpty
                          ? null
                          : videoCtrl.text.trim(),
                      notesUrl: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      durationSeconds:
                          int.tryParse(durCtrl.text),
                      isFree: isFree,
                      sortOrder:
                          int.tryParse(orderCtrl.text) ?? 0,
                    );
              } else {
                await ref
                    .read(lectureFormProvider.notifier)
                    .create(
                      chapterId: chapterId,
                      courseId: courseId,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      videoUrl: videoCtrl.text.trim().isEmpty
                          ? null
                          : videoCtrl.text.trim(),
                      notesUrl: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      durationSeconds:
                          int.tryParse(durCtrl.text),
                      isFree: isFree,
                      sortOrder:
                          int.tryParse(orderCtrl.text) ?? 0,
                    );
              }
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Generic confirm delete dialog
// ─────────────────────────────────────────────────────────────
Future<void> _confirmDelete(
  BuildContext context, {
  required String label,
  required VoidCallback onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm delete'),
      content:
          Text('Are you sure you want to delete $label? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) onConfirm();
}
