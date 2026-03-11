// ─────────────────────────────────────────────────────────────
//  reply_doubt_screen.dart
//  Focused reply composer for a teacher.
//  Shows the original question as a read-only context card,
//  then a large text field and a Send button.
//  On success: pops back to TeacherDoubtDetailScreen.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/services/auth_service.dart';
import '../providers/teacher_doubt_providers.dart';

class ReplyDoubtScreen extends ConsumerStatefulWidget {
  final String doubtId;
  final String studentName;
  final String questionPreview;

  const ReplyDoubtScreen({
    super.key,
    required this.doubtId,
    this.studentName = 'Student',
    this.questionPreview = '',
  });

  @override
  ConsumerState<ReplyDoubtScreen> createState() =>
      _ReplyDoubtScreenState();
}

class _ReplyDoubtScreenState extends ConsumerState<ReplyDoubtScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final teacherId =
        ref.read(authServiceProvider).currentAuthUser?.id ?? '';

    await ref.read(teacherReplyProvider.notifier).postReply(
          doubtId: widget.doubtId,
          teacherId: teacherId,
          body: text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherReplyProvider);

    ref.listen(teacherReplyProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(teacherReplyProvider.notifier).reset();
        Navigator.of(context).pop(true);
      }

      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(teacherReplyProvider.notifier).reset();
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
            const Text(
              'Reply to Doubt',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              widget.studentName,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Send button in AppBar for quick access
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.success.withAlpha(60),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: state.isSending ? null : _send,
              child: state.isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Context card: original question ───────────
            if (widget.questionPreview.isNotEmpty)
              _QuestionContextCard(
                studentName: widget.studentName,
                question: widget.questionPreview,
              ),

            const SizedBox(height: 20),

            // ── Teacher identity banner ────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 15, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'Replying as Teacher',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.success),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Reply text field ───────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText:
                        'Write a clear and helpful reply to the student…',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint),
                    contentPadding: const EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Send button ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: state.isSending ? null : _send,
                icon: state.isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  state.isSending ? 'Sending…' : 'Send Reply',
                  style: AppTextStyles.button,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Context card — shows original question above the reply field
// ─────────────────────────────────────────────────────────────
class _QuestionContextCard extends StatelessWidget {
  final String studentName;
  final String question;

  const _QuestionContextCard({
    required this.studentName,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student row
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withAlpha(20),
                child: Text(
                  studentName[0].toUpperCase(),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(studentName,
                  style: AppTextStyles.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Asked',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.info, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Question preview (max 3 lines)
          Text(
            question,
            style: AppTextStyles.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
