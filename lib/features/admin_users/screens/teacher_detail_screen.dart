// ─────────────────────────────────────────────────────────────
//  teacher_detail_screen.dart  (admin_users module)
//  Full teacher profile: bio, status, courses taught,
//  batch count, student count, and admin actions.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/admin_users_service.dart';
import '../providers/admin_users_providers.dart';
import '../widgets/admin_users_widgets.dart';

// ─────────────────────────────────────────────────────────────
class TeacherDetailScreen extends ConsumerWidget {
  final String userId;
  const TeacherDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminTeacherDetailProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        title: Text('Teacher Profile',
            style: AppTextStyles.headlineMedium),
        actions: [
          if (detailAsync.value != null)
            _HeaderActions(
              detail: detailAsync.value!,
              onToggle: () =>
                  _toggleStatus(context, ref, detailAsync.value!),
              onDelete: () =>
                  _deleteUser(context, ref, detailAsync.value!),
              onRoleChange: (r) =>
                  _changeRole(context, ref, detailAsync.value!, r),
            ),
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
              Text('Could not load teacher profile',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 6),
              Text(e.toString(),
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(adminTeacherDetailProvider(userId)),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (detail) => _TeacherDetailBody(
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
      BuildContext ctx, WidgetRef ref, AdminTeacherDetail d) async {
    final user   = d.user;
    final action = user.isActive ? 'Suspend' : 'Activate';
    final confirmed = await confirmAdminAction(
      ctx,
      title: '$action Teacher',
      message: user.isActive
          ? 'Suspending ${user.name} will prevent them from logging in '
              'and hide their courses from students.'
          : 'Restore login access for ${user.name}?',
      confirmLabel: action,
      confirmColor:
          user.isActive ? AppColors.warning : AppColors.success,
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .setUserActive(user.id, active: !user.isActive);
    ref.invalidate(adminTeacherDetailProvider(userId));
    ref.invalidate(adminTeacherListProvider);
  }

  Future<void> _deleteUser(
      BuildContext ctx, WidgetRef ref, AdminTeacherDetail d) async {
    final user = d.user;
    final confirmed = await confirmAdminAction(
      ctx,
      title: 'Delete Teacher',
      message:
          'Permanently delete ${user.name}? '
          'All their courses, batches and content will be removed. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .deleteUser(user.id);
    ref.invalidate(adminTeacherListProvider);
    if (ctx.mounted) Navigator.pop(ctx);
  }

  Future<void> _changeRole(
    BuildContext ctx,
    WidgetRef ref,
    AdminTeacherDetail d,
    String newRole,
  ) async {
    if (newRole == d.user.role) return;
    final confirmed = await confirmAdminAction(
      ctx,
      title: 'Change Role',
      message:
          'Change ${d.user.name}\'s role to "$newRole"? '
          'They will lose teacher access.',
      confirmLabel: 'Change',
      confirmColor: AppColors.info,
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .updateUserRole(d.user.id, newRole);
    ref.invalidate(adminTeacherDetailProvider(userId));
    ref.invalidate(adminTeacherListProvider);
  }
}

// ─────────────────────────────────────────────────────────────
//  AppBar action buttons
// ─────────────────────────────────────────────────────────────
class _HeaderActions extends StatelessWidget {
  final AdminTeacherDetail detail;
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
    final user = detail.user;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Suspend / Activate
        TextButton.icon(
          icon: Icon(
            user.isActive
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
          ),
          label: Text(user.isActive ? 'Suspend' : 'Activate'),
          style: TextButton.styleFrom(
            foregroundColor:
                user.isActive ? AppColors.warning : AppColors.success,
          ),
          onPressed: onToggle,
        ),
        // Role change
        PopupMenuButton<String>(
          tooltip: 'Change Role',
          onSelected: onRoleChange,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'student', child: Text('→ Student')),
            PopupMenuItem(value: 'teacher', child: Text('→ Teacher')),
            PopupMenuItem(value: 'admin',   child: Text('→ Admin')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.manage_accounts_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Role',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        // Delete
        IconButton(
          tooltip: 'Delete Teacher',
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.error),
          onPressed: onDelete,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Main body
// ─────────────────────────────────────────────────────────────
class _TeacherDetailBody extends StatelessWidget {
  final AdminTeacherDetail detail;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onRoleChange;

  const _TeacherDetailBody({
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
                  Expanded(
                    child: _CoursesSection(
                        courses: detail.coursesTaught),
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
                  _CoursesSection(courses: detail.coursesTaught),
                ],
              );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Profile card (left column)
// ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final AdminTeacherDetail detail;
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // ── Avatar + name ───────────────────────────────
          UserAvatar(
            name: user.name,
            avatarUrl: user.avatarUrl,
            radius: 42,
            backgroundColor: AppColors.info.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 14),
          Text(user.name,
              style: AppTextStyles.headlineLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoleBadge(role: user.role),
              const SizedBox(width: 8),
              UserStatusBadge(active: user.isActive),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // ── Info rows ────────────────────────────────────
          ProfileInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
          ),
          if (user.phone != null && user.phone!.isNotEmpty)
            ProfileInfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phone!,
            ),
          ProfileInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Member Since',
            value: fmtDate(user.createdAt),
          ),
          ProfileInfoRow(
            icon: Icons.fingerprint_rounded,
            label: 'User ID',
            value: user.id,
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // ── Actions ──────────────────────────────────────
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
                  label: Text(user.isActive ? 'Suspend' : 'Activate'),
                  onPressed: onToggle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: user.isActive
                        ? AppColors.warning
                        : AppColors.success,
                    side: BorderSide(
                      color: user.isActive
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16),
                  label: const Text('Delete'),
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PopupMenuButton<String>(
            onSelected: onRoleChange,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'student', child: Text('Change to Student')),
              PopupMenuItem(
                  value: 'teacher', child: Text('Change to Teacher')),
              PopupMenuItem(
                  value: 'admin', child: Text('Change to Admin')),
            ],
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.manage_accounts_rounded,
                    size: 16),
                label: const Text('Change Role'),
                onPressed: null, // handled by PopupMenuButton tap
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                ),
              ),
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
  final AdminTeacherDetail detail;
  const _StatsRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatChip(
            label: 'Courses',
            value: '${detail.coursesTaught.length}',
            icon: Icons.menu_book_rounded,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatChip(
            label: 'Batches',
            value: '${detail.totalBatches}',
            icon: Icons.groups_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatChip(
            label: 'Students',
            value: '${detail.totalStudents}',
            icon: Icons.people_alt_rounded,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Courses taught section
// ─────────────────────────────────────────────────────────────
class _CoursesSection extends StatelessWidget {
  final List<AdminUserCourse> courses;
  const _CoursesSection({required this.courses});

  @override
  Widget build(BuildContext context) {
    return DetailSectionCard(
      title: 'Courses Taught',
      icon: Icons.menu_book_rounded,
      iconColor: AppColors.info,
      child: courses.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: AdminUsersEmptyState(
                message: 'No courses yet.',
                icon: Icons.menu_book_rounded,
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: courses.length,
              separatorBuilder: (_, _) =>
                  const Divider(indent: 20, endIndent: 20),
              itemBuilder: (_, i) {
                final c = courses[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: AppColors.info, size: 20),
                  ),
                  title: Text(c.courseTitle,
                      style: AppTextStyles.labelLarge),
                  subtitle: Text(
                    'Created ${fmtDate(c.enrolledAt)}',
                    style: AppTextStyles.caption,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Course',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.info)),
                  ),
                );
              },
            ),
    );
  }
}
