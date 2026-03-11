// ─────────────────────────────────────────────────────────────
//  teacher_doubt_detail_screen.dart
//  Full doubt thread for a teacher:
//  • Doubt card with student info + image
//  • Realtime reply stream
//  • "Mark Resolved / Unresolve" action in AppBar
//  • Inline reply composer → ReplyDoubtScreen via FAB
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/models/models.dart';
import '../providers/teacher_doubt_providers.dart';

class TeacherDoubtDetailScreen extends ConsumerWidget {
  final String doubtId;
  const TeacherDoubtDetailScreen({
    super.key,
    required this.doubtId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doubtAsync = ref.watch(teacherDoubtDetailProvider(doubtId));
    final repliesAsync =
        ref.watch(teacherRepliesStreamProvider(doubtId));
    final resolveState = ref.watch(resolveDoubtProvider);

    // Show error snackbar on resolve failure
    ref.listen(resolveDoubtProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${next.error}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, ref, doubtAsync, resolveState),
      body: doubtAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.error))),
        data: (doubt) => _Body(
          doubt: doubt,
          repliesAsync: repliesAsync,
        ),
      ),

      // ── FAB: open reply screen ─────────────────────────
      floatingActionButton: doubtAsync.maybeWhen(
        data: (doubt) => FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.reply_rounded),
          label: const Text('Reply'),
          onPressed: () => context.push(
            AppRoutes.replyDoubtPath(doubtId),
            extra: {
              'studentName': doubt.studentName ?? 'Student',
              'questionPreview': doubt.question,
            },
          ),
        ),
        orElse: () => null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<DoubtModel> doubtAsync,
    AsyncValue<void> resolveState,
  ) {
    return AppBar(
      backgroundColor: const Color(0xFF1C1B2E),
      foregroundColor: Colors.white,
      title: const Text(
        'Doubt Discussion',
        style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // ── Resolve toggle ─────────────────────────────
        doubtAsync.maybeWhen(
          data: (doubt) {
            final isLoading = resolveState is AsyncLoading;
            final isResolved = doubt.isAnswered;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        ),
                      ),
                    )
                  : TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: isResolved
                            ? AppColors.warning
                            : AppColors.success,
                        backgroundColor: (isResolved
                                ? AppColors.warning
                                : AppColors.success)
                            .withAlpha(30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      icon: Icon(
                        isResolved
                            ? Icons.undo_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isResolved ? 'Unresolve' : 'Mark Resolved',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => ref
                          .read(resolveDoubtProvider.notifier)
                          .toggle(doubtId, resolved: !isResolved),
                    ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Body – doubt card + reply list
// ─────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final DoubtModel doubt;
  final AsyncValue<List<DoubtReplyModel>> repliesAsync;

  const _Body({required this.doubt, required this.repliesAsync});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Doubt card ─────────────────────────────────
        SliverToBoxAdapter(
          child: _DoubtCard(doubt: doubt),
        ),

        // ── Replies header ─────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                repliesAsync.when(
                  data: (replies) => Text(
                    '${replies.length} ${replies.length == 1 ? 'Reply' : 'Replies'}',
                    style: AppTextStyles.labelMedium,
                  ),
                  loading: () =>
                      Text('Replies', style: AppTextStyles.labelMedium),
                  error: (_, e) =>
                      Text('Replies', style: AppTextStyles.labelMedium),
                ),
              ],
            ),
          ),
        ),

        // ── Reply list (realtime) ──────────────────────
        repliesAsync.when(
          loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SliverFillRemaining(
            child: Center(
                child: Text('$e',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error))),
          ),
          data: (replies) {
            if (replies.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: _NoReplies(),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList.separated(
                itemCount: replies.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _ReplyBubble(reply: replies[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Doubt card
// ─────────────────────────────────────────────────────────────
class _DoubtCard extends StatelessWidget {
  final DoubtModel doubt;
  const _DoubtCard({required this.doubt});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        doubt.isAnswered ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student row + status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withAlpha(25),
                child: Text(
                  _initial(doubt.studentName),
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
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
              // Status pill
              _StatusPill(isAnswered: doubt.isAnswered),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Question text
          Text(doubt.question, style: AppTextStyles.bodyLarge),

          // Attached image
          if (doubt.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                doubt.imageUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, _) => const SizedBox.shrink(),
              ),
            ),
          ],

          // Lecture tag
          if (doubt.lectureId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.info.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.video_library_rounded,
                      size: 12, color: AppColors.info),
                  const SizedBox(width: 6),
                  Text('Linked to a Lecture',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.info)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _initial(String? name) =>
      (name?.isNotEmpty == true ? name![0] : 'S').toUpperCase();

  String _fmtDate(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────
//  Reply bubble (read-only, teacher-only view)
// ─────────────────────────────────────────────────────────────
class _ReplyBubble extends StatelessWidget {
  final DoubtReplyModel reply;
  const _ReplyBubble({required this.reply});

  @override
  Widget build(BuildContext context) {
    final isTeacher = reply.isTeacher;
    final bubbleColor = isTeacher
        ? AppColors.success.withAlpha(18)
        : AppColors.surfaceVariant;
    final borderColor =
        isTeacher ? AppColors.success.withAlpha(80) : AppColors.border;

    return Container(
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
                    ? AppColors.success.withAlpha(30)
                    : AppColors.primary.withAlpha(20),
                child: Text(
                  (reply.authorName?.isNotEmpty == true
                          ? reply.authorName![0]
                          : (isTeacher ? 'T' : 'S'))
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isTeacher
                        ? AppColors.success
                        : AppColors.primary,
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
                  ],
                ),
              ),
              Text(
                _relTime(reply.createdAt),
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reply.body != '[Image attached]')
            Text(reply.body, style: AppTextStyles.bodyMedium),
          if (reply.imageUrl != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                reply.imageUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Teacher badge ─────────────────────────────────────────────
class _TeacherBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded,
                size: 10, color: AppColors.success),
            const SizedBox(width: 3),
            Text('Teacher',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.success, fontSize: 9)),
          ],
        ),
      );
}

// ── Status pill ───────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final bool isAnswered;
  const _StatusPill({required this.isAnswered});

  @override
  Widget build(BuildContext context) {
    final color = isAnswered ? AppColors.success : AppColors.warning;
    final label = isAnswered ? 'Resolved' : 'Pending';
    final icon = isAnswered
        ? Icons.check_circle_rounded
        : Icons.schedule_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelMedium
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── No replies placeholder ────────────────────────────────────
class _NoReplies extends StatelessWidget {
  const _NoReplies();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 52, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text('No replies yet', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Tap the Reply button below to answer this student.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
