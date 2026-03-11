// ─────────────────────────────────────────────────────────────
//  teacher_doubt_tile.dart
//  A tile representing a student doubt with inline answer support.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/doubt_service.dart';

class TeacherDoubtTile extends ConsumerStatefulWidget {
  final DoubtModel doubt;

  const TeacherDoubtTile({super.key, required this.doubt});

  @override
  ConsumerState<TeacherDoubtTile> createState() =>
      _TeacherDoubtTileState();
}

class _TeacherDoubtTileState extends ConsumerState<TeacherDoubtTile> {
  bool _expanded = false;
  bool _submitting = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final uid =
          ref.read(authServiceProvider).currentAuthUser?.id ?? '';
      await ref.read(doubtServiceProvider).answerDoubt(
            doubtId: widget.doubt.id,
            answer: text,
            teacherId: uid,
          );
      if (mounted) {
        _controller.clear();
        setState(() => _expanded = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doubt = widget.doubt;
    final answered = doubt.isAnswered;
    final dateStr = DateFormat('d MMM y').format(doubt.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: answered
              ? AppColors.success.withAlpha(80)
              : AppColors.warning.withAlpha(80),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withAlpha(25),
                  child: Text(
                    (doubt.studentName ?? 'S')[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student name + date
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doubt.studentName ?? 'Student',
                              style:
                                  AppTextStyles.headlineSmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Question
                      Text(
                        doubt.question,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: _expanded ? null : 3,
                        overflow: _expanded
                            ? null
                            : TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Status + Actions ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _StatusBadge(answered: answered),
                const Spacer(),
                // ── View full thread ─────────────────────
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(
                          color: AppColors.info, width: 1),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('View', style: TextStyle(fontSize: 12)),
                  onPressed: () => context
                      .push(AppRoutes.teacherDoubtDetailPath(doubt.id)),
                ),
                const SizedBox(width: 8),
                if (!answered)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(
                            color: AppColors.primary, width: 1),
                      ),
                    ),
                    icon: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.reply_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _expanded ? 'Cancel' : 'Answer',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () =>
                        setState(() => _expanded = !_expanded),
                  ),
              ],
            ),
          ),

          // ── Existing answer ──────────────────────────────
          if (answered && doubt.answer != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doubt.answer!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Inline answer form ──────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Type your answer…',
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Answer',
                            style: TextStyle(fontSize: 13),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool answered;
  const _StatusBadge({required this.answered});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: answered
              ? AppColors.success.withAlpha(25)
              : AppColors.warning.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              answered
                  ? Icons.check_circle_rounded
                  : Icons.hourglass_top_rounded,
              size: 12,
              color: answered ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              answered ? 'Answered' : 'Pending',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    answered ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      );
}
