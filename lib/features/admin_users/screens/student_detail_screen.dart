// ─────────────────────────────────────────────────────────────
//  student_detail_screen.dart  (admin_users module)
//  Full student profile: bio, status, enrolled courses,
//  batch memberships, test attempts.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/admin_users_service.dart';
import '../providers/admin_users_providers.dart';
import '../widgets/admin_users_widgets.dart';

// ─────────────────────────────────────────────────────────────
class StudentDetailScreen extends ConsumerWidget {
  final String userId;
  const StudentDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminStudentDetailProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        title: Text('Student Profile',
            style: AppTextStyles.headlineMedium),
        actions: [
          detailAsync.whenData((d) => d).valueOrNull != null
              ? _HeaderActions(
                  detail: detailAsync.value!,
                  onToggle: () =>
                      _toggleStatus(context, ref, detailAsync.value!),
                  onDelete: () =>
                      _deleteUser(context, ref, detailAsync.value!),
                  onRoleChange: (r) =>
                      _changeRole(context, ref, detailAsync.value!, r),
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text('Could not load student profile',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 6),
              Text(e.toString(),
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(adminStudentDetailProvider(userId)),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (detail) => _StudentDetailBody(
          detail: detail,
          onToggle: () => _toggleStatus(context, ref, detail),
          onDelete: () => _deleteUser(context, ref, detail),
          onRoleChange: (r) => _changeRole(context, ref, detail, r),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────
  Future<void> _toggleStatus(
      BuildContext ctx, WidgetRef ref, AdminUserDetail d) async {
    final user    = d.user;
    final action  = user.isActive ? 'Suspend' : 'Activate';
    final confirmed = await confirmAdminAction(
      ctx,
      title: '$action Student',
      message: user.isActive
          ? 'Suspending ${user.name} will prevent them from logging in.'
          : 'Restore login access for ${user.name}?',
      confirmLabel: action,
      confirmColor:
          user.isActive ? AppColors.warning : AppColors.success,
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .setUserActive(user.id, active: !user.isActive);
    ref.invalidate(adminStudentDetailProvider(userId));
    ref.invalidate(adminStudentListProvider);
  }

  Future<void> _deleteUser(
      BuildContext ctx, WidgetRef ref, AdminUserDetail d) async {
    final user = d.user;
    final confirmed = await confirmAdminAction(
      ctx,
      title: 'Delete Student',
      message:
          'Permanently delete ${user.name}? '
          'All enrollments, progress and test attempts will be removed. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .deleteUser(user.id);
    ref.invalidate(adminStudentListProvider);
    if (ctx.mounted) Navigator.pop(ctx);
  }

  Future<void> _changeRole(
    BuildContext ctx,
    WidgetRef ref,
    AdminUserDetail d,
    String newRole,
  ) async {
    if (newRole == d.user.role) return;
    final confirmed = await confirmAdminAction(
      ctx,
      title: 'Change Role',
      message:
          'Change ${d.user.name}\'s role to "$newRole"? '
          'They will lose student access.',
      confirmLabel: 'Change',
      confirmColor: AppColors.info,
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .updateUserRole(d.user.id, newRole);
    ref.invalidate(adminStudentDetailProvider(userId));
    ref.invalidate(adminStudentListProvider);
  }
}

// ─────────────────────────────────────────────────────────────
//  Main body
// ─────────────────────────────────────────────────────────────
class _StudentDetailBody extends StatelessWidget {
  final AdminUserDetail detail;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onRoleChange;

  const _StudentDetailBody({
    required this.detail,
    required this.onToggle,
    required this.onDelete,
    required this.onRoleChange,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: profile + stats
                  SizedBox(
                    width: 320,
                    child: Column(
                      children: [
                        _ProfileCard(
                          detail: detail,
                          onToggle: onToggle,
                          onDelete: onDelete,
                          onRoleChange: onRoleChange,
                        ),
                        const SizedBox(height: 16),
                        _StatsRow(detail: detail),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right column: courses + batches
                  Expanded(
                    child: Column(
                      children: [
                        _CoursesSection(courses: detail.enrolledCourses),
                        const SizedBox(height: 16),
                        _BatchesSection(
                            batches: detail.batchMemberships),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _ProfileCard(
                    detail: detail,
                    onToggle: onToggle,
                    onDelete: onDelete,
                    onRoleChange: onRoleChange,
                  ),
                  const SizedBox(height: 16),
                  _StatsRow(detail: detail),
                  const SizedBox(height: 16),
                  _CoursesSection(courses: detail.enrolledCourses),
                  const SizedBox(height: 16),
                  _BatchesSection(batches: detail.batchMemberships),
                ],
              );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Profile card
// ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final AdminUserDetail detail;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onRoleChange;

  const _ProfileCard({
    required this.detail,
    required this.onToggle,
    required this.onDelete,
    required this.onRoleChange,
  });

  @override
  Widget build(BuildContext context) {
    final user = detail.user;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gradient header
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.8),
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
          ),
          // Avatar overlapping header
          Transform.translate(
            offset: const Offset(0, -36),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white, width: 3),
                  ),
                  child: UserAvatar(
                    name: user.name,
                    avatarUrl: user.avatarUrl,
                    radius: 36,
                  ),
                ),
                const SizedBox(height: 8),
                Text(user.name,
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                RoleBadge(role: user.role),
                const SizedBox(height: 4),
                UserStatusBadge(active: user.isActive),
              ],
            ),
          ),

          // Info rows
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 14),
                ProfileInfoRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: user.email,
                ),
                if (user.phone != null && user.phone!.isNotEmpty)
                  ProfileInfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: user.phone!,
                  ),
                ProfileInfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Joined',
                  value: fmtDate(user.createdAt),
                ),
                ProfileInfoRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'User ID',
                  value: user.id,
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          user.isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 16,
                        ),
                        label: Text(
                            user.isActive ? 'Suspend' : 'Activate'),
                        onPressed: onToggle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: user.isActive
                              ? AppColors.warning
                              : AppColors.success,
                          side: BorderSide(
                              color: user.isActive
                                  ? AppColors.warning
                                  : AppColors.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16),
                        label: const Text('Delete'),
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                              color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Role change
                SizedBox(
                  width: double.infinity,
                  child: PopupMenuButton<String>(
                    onSelected: onRoleChange,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'student',
                          child: Text('Set as Student')),
                      PopupMenuItem(
                          value: 'teacher',
                          child: Text('Promote to Teacher')),
                      PopupMenuItem(
                          value: 'admin',
                          child: Text('Promote to Admin')),
                    ],
                    child: OutlinedButton.icon(
                      icon: const Icon(
                          Icons.manage_accounts_rounded,
                          size: 16),
                      label: const Text('Change Role'),
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side:
                            const BorderSide(color: AppColors.info),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────
//  Stats row
// ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final AdminUserDetail detail;
  const _StatsRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatChip(
            label: 'Courses',
            value: '${detail.enrolledCourses.length}',
            icon: Icons.menu_book_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatChip(
            label: 'Batches',
            value: '${detail.batchMemberships.length}',
            icon: Icons.groups_rounded,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatChip(
            label: 'Tests',
            value: '${detail.testAttemptCount}',
            icon: Icons.quiz_rounded,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Enrolled courses section
// ─────────────────────────────────────────────────────────────
class _CoursesSection extends StatelessWidget {
  final List<AdminUserCourse> courses;
  const _CoursesSection({required this.courses});

  @override
  Widget build(BuildContext context) {
    return DetailSectionCard(
      title: 'Enrolled Courses (${courses.length})',
      icon: Icons.menu_book_rounded,
      iconColor: AppColors.primary,
      child: courses.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: AdminUsersEmptyState(
                  message: 'Not enrolled in any course yet.',
                  icon: Icons.menu_book_outlined),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: courses.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 20),
              itemBuilder: (_, i) {
                final c = courses[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 6),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_circle_outline_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(c.courseTitle,
                      style: AppTextStyles.labelLarge),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.teacherName != null)
                        Text('Teacher: ${c.teacherName}',
                            style: AppTextStyles.caption),
                      Text('Enrolled: ${fmtDate(c.enrolledAt)}',
                          style: AppTextStyles.caption),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${c.progressPercent.toStringAsFixed(0)}%',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: c.progressPercent / 100,
                            backgroundColor: AppColors.surfaceVariant,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                    AppColors.primary),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Batch memberships section
// ─────────────────────────────────────────────────────────────
class _BatchesSection extends StatelessWidget {
  final List<AdminUserBatch> batches;
  const _BatchesSection({required this.batches});

  @override
  Widget build(BuildContext context) {
    return DetailSectionCard(
      title: 'Batch Memberships (${batches.length})',
      icon: Icons.groups_rounded,
      iconColor: AppColors.info,
      child: batches.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: AdminUsersEmptyState(
                  message: 'Not a member of any batch.',
                  icon: Icons.groups_outlined),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: batches.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 20),
              itemBuilder: (_, i) {
                final b = batches[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 6),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.group_rounded,
                        color: AppColors.info, size: 20),
                  ),
                  title: Text(b.batchName,
                      style: AppTextStyles.labelLarge),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Course: ${b.courseTitle}',
                          style: AppTextStyles.caption),
                      Text('Joined: ${fmtDate(b.enrolledAt)}',
                          style: AppTextStyles.caption),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: b.isActive
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.textHint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      b.isActive ? 'Active' : 'Ended',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: b.isActive
                            ? AppColors.success
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  AppBar trailing actions
// ─────────────────────────────────────────────────────────────
class _HeaderActions extends StatelessWidget {
  final AdminUserDetail detail;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onRoleChange;

  const _HeaderActions({
    required this.detail,
    required this.onToggle,
    required this.onDelete,
    required this.onRoleChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip:
              detail.user.isActive ? 'Suspend User' : 'Activate User',
          icon: Icon(
            detail.user.isActive
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            color: detail.user.isActive
                ? AppColors.warning
                : AppColors.success,
          ),
          onPressed: onToggle,
        ),
        PopupMenuButton<String>(
          tooltip: 'More Options',
          icon: const Icon(Icons.more_vert_rounded,
              color: AppColors.textSecondary),
          onSelected: (val) {
            if (val == 'delete') {
              onDelete();
            } else {
              onRoleChange(val);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'teacher',
                child: Text('Promote to Teacher')),
            const PopupMenuItem(
                value: 'admin',
                child: Text('Promote to Admin')),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete User',
                  style:
                      TextStyle(color: AppColors.error)),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
