// ─────────────────────────────────────────────────────────────
//  question_card.dart
//  Read-only MCQ question card used in TestPreviewScreen and
//  the question list inside CreateTestScreen.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/models.dart';

class QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final int index;          // 1-based display number
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  /// When true the correct answer highlight is shown (preview mode).
  final bool showAnswer;

  const QuestionCard({
    super.key,
    required this.question,
    required this.index,
    this.onEdit,
    this.onDelete,
    this.showAnswer = false,
  });

  // Option label: A, B, C, D
  static String _label(int i) => String.fromCharCode(65 + i);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                // Question number badge
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.question,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                // Marks chip
                _MarksBadge(marks: question.marks),
                // Actions
                if (onEdit != null || onDelete != null) ...[
                  const SizedBox(width: 6),
                  _ActionMenu(onEdit: onEdit, onDelete: onDelete),
                ],
              ],
            ),
          ),

          // ── Options ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: List.generate(question.options.length, (i) {
                final isCorrect = i == question.correctOptionIndex;
                final highlight = showAnswer && isCorrect;
                return _OptionTile(
                  label: _label(i),
                  text: question.options[i],
                  isCorrect: highlight,
                );
              }),
            ),
          ),

          // ── Explanation (if present) ──────────────────
          if (question.explanation != null &&
              question.explanation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.info.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: AppColors.info),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        question.explanation!,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.info,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool isCorrect;

  const _OptionTile({
    required this.label,
    required this.text,
    this.isCorrect = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isCorrect
        ? AppColors.success.withAlpha(25)
        : AppColors.surfaceVariant;
    final border = isCorrect ? AppColors.success : AppColors.border;
    final labelColor =
        isCorrect ? AppColors.success : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCorrect ? AppColors.success : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: Text(label,
                style: TextStyle(
                    color: isCorrect
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: labelColor))),
          if (isCorrect)
            const Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.success),
        ],
      ),
    );
  }
}

// ── Marks badge ───────────────────────────────────────────────
class _MarksBadge extends StatelessWidget {
  final int marks;
  const _MarksBadge({required this.marks});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warning.withAlpha(80)),
        ),
        child: Text(
          '+$marks',
          style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.warning, fontWeight: FontWeight.w700),
        ),
      );
}

// ── Action popup menu ─────────────────────────────────────────
class _ActionMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _ActionMenu({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded,
            size: 20, color: AppColors.textSecondary),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (v) {
          if (v == 'edit') onEdit?.call();
          if (v == 'delete') onDelete?.call();
        },
        itemBuilder: (_) => [
          if (onEdit != null)
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_rounded, size: 16),
                SizedBox(width: 8),
                Text('Edit'),
              ]),
            ),
          if (onDelete != null)
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.error),
                SizedBox(width: 8),
                Text('Delete',
                    style: TextStyle(color: AppColors.error)),
              ]),
            ),
        ],
      );
}
