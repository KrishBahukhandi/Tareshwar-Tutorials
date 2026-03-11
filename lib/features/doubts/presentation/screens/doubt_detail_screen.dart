// ─────────────────────────────────────────────────────────────
//  doubt_detail_screen.dart  –  Doubt thread + replies
//  Features:
//    • Doubt card with image
//    • Realtime reply stream
//    • Reply composer with image
//    • Teacher replies highlighted with badge
//    • Delete own doubt / own reply (long-press)
//    • Mark as resolved (student)
// ─────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/app_providers.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/doubt_service.dart';

// ─────────────────────────────────────────────────────────────
class DoubtDetailScreen extends ConsumerStatefulWidget {
  final String doubtId;
  const DoubtDetailScreen({super.key, required this.doubtId});

  @override
  ConsumerState<DoubtDetailScreen> createState() =>
      _DoubtDetailScreenState();
}

class _DoubtDetailScreenState
    extends ConsumerState<DoubtDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  File? _replyImage;
  bool _isSending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked != null && mounted) {
      setState(() => _replyImage = File(picked.path));
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.photo_library_rounded,
                      color: Colors.white, size: 20),
                ),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  child: Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 20),
                ),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Post reply ────────────────────────────────────────────
  Future<void> _postReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty && _replyImage == null) return;

    final auth = ref.read(authServiceProvider);
    final userId = auth.currentAuthUser?.id;
    final role = auth.currentRole ?? 'student';
    if (userId == null) return;

    setState(() => _isSending = true);
    try {
      await ref.read(doubtServiceProvider).postReply(
            doubtId: widget.doubtId,
            authorId: userId,
            body: text.isEmpty ? '[Image attached]' : text,
            role: role,
            image: _replyImage,
          );
      _replyCtrl.clear();
      setState(() => _replyImage = null);
      // Scroll to bottom after a brief delay
      await Future.delayed(const Duration(milliseconds: 300));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
      // Refresh doubt header to update isAnswered / replyCount
      ref.invalidate(doubtDetailProvider(widget.doubtId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Delete reply ──────────────────────────────────────────
  Future<void> _deleteReply(DoubtReplyModel reply) async {
    final confirmed = await _confirmDialog(
      title: 'Delete Reply?',
      body: 'This reply will be permanently removed.',
    );
    if (!confirmed) return;
    try {
      await ref.read(doubtServiceProvider).deleteReply(reply.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  // ── Delete doubt ──────────────────────────────────────────
  Future<void> _deleteDoubt() async {
    final confirmed = await _confirmDialog(
      title: 'Delete Doubt?',
      body: 'This will delete the doubt and all replies.',
    );
    if (!confirmed) return;
    try {
      await ref.read(doubtServiceProvider).deleteDoubt(widget.doubtId);
      ref.invalidate(myDoubtsProvider);
      ref.invalidate(doubtsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<bool> _confirmDialog(
      {required String title, required String body}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final doubtAsync =
        ref.watch(doubtDetailProvider(widget.doubtId));
    final repliesStream =
        ref.watch(doubtRepliesStreamProvider(widget.doubtId));
    final currentUserId =
        ref.read(authServiceProvider).currentAuthUser?.id ?? '';
    final currentRole =
        ref.read(authServiceProvider).currentRole ?? 'student';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(doubtAsync, currentUserId),
      body: Column(
        children: [
          // ── Main content ─────────────────────────────
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // Doubt card
                SliverToBoxAdapter(
                  child: doubtAsync.when(
                    loading: () => const SizedBox(
                        height: 120,
                        child: Center(
                            child: CircularProgressIndicator())),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (doubt) =>
                        _DoubtCard(doubt: doubt),
                  ),
                ),

                // Divider + section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        repliesStream.when(
                          data: (replies) => Text(
                            '${replies.length} ${replies.length == 1 ? 'Reply' : 'Replies'}',
                            style: AppTextStyles.labelMedium,
                          ),
                          loading: () => Text('Replies',
                              style: AppTextStyles.labelMedium),
                          error: (_, _) => Text('Replies',
                              style: AppTextStyles.labelMedium),
                        ),
                      ],
                    ),
                  ),
                ),

                // Replies list
                repliesStream.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    child: Center(child: Text('$e')),
                  ),
                  data: (replies) {
                    if (replies.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoRepliesView(),
                      );
                    }
                    return SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList.separated(
                        itemCount: replies.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ReplyBubble(
                          reply: replies[i],
                          isOwn:
                              replies[i].authorId == currentUserId,
                          onDeleteRequest: () =>
                              _deleteReply(replies[i]),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Reply composer ───────────────────────────
          _ReplyComposer(
            controller: _replyCtrl,
            image: _replyImage,
            isSending: _isSending,
            isTeacher: currentRole == 'teacher',
            onPickImage: _showImagePicker,
            onRemoveImage: () => setState(() => _replyImage = null),
            onSend: _postReply,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    AsyncValue<DoubtModel> doubtAsync,
    String currentUserId,
  ) {
    return AppBar(
      title: const Text('Discussion'),
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      actions: [
        // Only doubt owner sees delete option
        doubtAsync.maybeWhen(
          data: (doubt) => doubt.studentId == currentUserId
              ? IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete Doubt',
                  color: AppColors.error,
                  onPressed: _deleteDoubt,
                )
              : const SizedBox.shrink(),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Doubt card header
// ─────────────────────────────────────────────────────────────
class _DoubtCard extends StatelessWidget {
  final DoubtModel doubt;
  const _DoubtCard({required this.doubt});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        doubt.isAnswered ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row + status
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  (doubt.studentName?.isNotEmpty == true
                          ? doubt.studentName![0]
                          : 'S')
                      .toUpperCase(),
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doubt.studentName ?? 'Student',
                      style: AppTextStyles.labelLarge,
                    ),
                    Text(
                      _fmtDate(doubt.createdAt),
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
              _StatusChip(isAnswered: doubt.isAnswered),
            ],
          ),

          const SizedBox(height: 14),

          // Question
          Text(doubt.question, style: AppTextStyles.bodyLarge),

          // Image
          if (doubt.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                doubt.imageUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],

          // Lecture tag
          if (doubt.lectureId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.video_library_rounded,
                          size: 12, color: AppColors.info),
                      const SizedBox(width: 4),
                      Text('Lecture',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.info)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────
//  Reply bubble
// ─────────────────────────────────────────────────────────────
class _ReplyBubble extends StatelessWidget {
  final DoubtReplyModel reply;
  final bool isOwn;
  final VoidCallback onDeleteRequest;
  const _ReplyBubble({
    required this.reply,
    required this.isOwn,
    required this.onDeleteRequest,
  });

  @override
  Widget build(BuildContext context) {
    final isTeacher = reply.isTeacher;
    final bubbleColor = isTeacher
        ? AppColors.success.withValues(alpha: 0.07)
        : isOwn
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.white;
    final borderColor = isTeacher
        ? AppColors.success.withValues(alpha: 0.3)
        : AppColors.border;

    return GestureDetector(
      onLongPress: isOwn ? onDeleteRequest : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isTeacher
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    (reply.authorName?.isNotEmpty == true
                            ? reply.authorName![0]
                            : (isTeacher ? 'T' : 'S'))
                        .toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isTeacher
                          ? AppColors.success
                          : AppColors.primary,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        reply.authorName ??
                            (isTeacher ? 'Teacher' : 'Student'),
                        style: AppTextStyles.labelMedium,
                      ),
                      if (isTeacher) ...[
                        const SizedBox(width: 6),
                        _TeacherBadge(),
                      ],
                      if (isOwn && !isTeacher) ...[
                        const SizedBox(width: 6),
                        _YouBadge(),
                      ],
                    ],
                  ),
                ),
                Text(
                  _fmtTime(reply.createdAt),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Body
            if (reply.body != '[Image attached]')
              Text(reply.body, style: AppTextStyles.bodyMedium),

            // Image
            if (reply.imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  reply.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],

            // Long-press hint for own replies
            if (isOwn) ...[
              const SizedBox(height: 6),
              Text(
                'Hold to delete',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textHint, fontSize: 9),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────
//  Reply composer
// ─────────────────────────────────────────────────────────────
class _ReplyComposer extends StatelessWidget {
  final TextEditingController controller;
  final File? image;
  final bool isSending;
  final bool isTeacher;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSend;

  const _ReplyComposer({
    required this.controller,
    required this.image,
    required this.isSending,
    required this.isTeacher,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview strip
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(image!,
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: onRemoveImage,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Teacher banner
          if (isTeacher)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text('Replying as Teacher',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.success)),
                ],
              ),
            ),

          // Input row
          Row(
            children: [
              // Image button
              IconButton(
                icon: const Icon(Icons.image_outlined,
                    color: AppColors.textSecondary),
                onPressed: onPickImage,
                tooltip: 'Attach image',
              ),

              // Text field
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: isTeacher
                        ? 'Write your answer...'
                        : 'Add a reply...',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                  onPressed: isSending ? null : onSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Small utility widgets
// ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final bool isAnswered;
  const _StatusChip({required this.isAnswered});

  @override
  Widget build(BuildContext context) {
    final color = isAnswered ? AppColors.success : AppColors.warning;
    final label = isAnswered ? 'Answered' : 'Pending';
    final icon =
        isAnswered ? Icons.check_circle_rounded : Icons.schedule_rounded;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: color)),
        ],
      ),
    );
  }
}

class _TeacherBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded,
                size: 10, color: AppColors.success),
            const SizedBox(width: 3),
            Text('Teacher',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.success, fontSize: 9)),
          ],
        ),
      );
}

class _YouBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'You',
          style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary, fontSize: 9),
        ),
      );
}

class _NoRepliesView extends StatelessWidget {
  const _NoRepliesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No replies yet',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Be the first to reply or wait for a teacher response.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
