// ─────────────────────────────────────────────────────────────
//  admin_students_screen.dart  (admin_users module)
//  Full student management list with search, suspend, delete,
//  role-change and tap-to-detail navigation.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/models/models.dart';
import '../data/admin_users_service.dart';
import '../providers/admin_users_providers.dart';
import '../widgets/admin_users_widgets.dart';

// ─────────────────────────────────────────────────────────────
class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() =>
      _AdminStudentsScreenState();
}

class _AdminStudentsScreenState
    extends ConsumerState<AdminStudentsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(adminStudentListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            _ListHeader(
              title: 'Students',
              subtitle: 'Manage all registered student accounts',
              icon: Icons.people_alt_rounded,
              color: AppColors.primary,
              searchCtrl: _searchCtrl,
              searchHint: 'Search by name, email…',
              onSearch: (v) => ref
                  .read(adminUsersStudentSearchProvider.notifier)
                  .state = v,
              onRefresh: () =>
                  ref.invalidate(adminStudentListProvider),
            ),
            const SizedBox(height: 20),

            // ── Table ────────────────────────────────────────
            Expanded(
              child: Container(
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: studentsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: _ErrorView(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(adminStudentListProvider),
                      ),
                    ),
                    data: (students) => students.isEmpty
                        ? const AdminUsersEmptyState(
                            message: 'No students found.\n'
                                'Students will appear here once they register.',
                          )
                        : _StudentTable(
                            students: students,
                            onToggle: (s) =>
                                _toggleUser(context, ref, s),
                            onDelete: (s) =>
                                _deleteUser(context, ref, s),
                            onRoleChange: (s, role) =>
                                _changeRole(context, ref, s, role),
                            onTap: (s) => context.push(
                              AppRoutes.adminUserStudentDetail
                                  .replaceFirst(':userId', s.id),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────
  Future<void> _toggleUser(
      BuildContext ctx, WidgetRef ref, UserModel user) async {
    final action = user.isActive ? 'Suspend' : 'Activate';
    final confirmed = await confirmAdminAction(
      ctx,
      title: '$action Student',
      message: user.isActive
          ? '${user.name} will be prevented from logging in.'
          : 'Restore access for ${user.name}?',
      confirmLabel: action,
      confirmColor:
          user.isActive ? AppColors.warning : AppColors.success,
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .setUserActive(user.id, active: !user.isActive);
    ref.invalidate(adminStudentListProvider);
  }

  Future<void> _deleteUser(
      BuildContext ctx, WidgetRef ref, UserModel user) async {
    final confirmed = await confirmAdminAction(
      ctx,
      title: 'Delete Student',
      message:
          'Permanently remove ${user.name}? '
          'All their enrollments and progress will be deleted. '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .deleteUser(user.id);
    ref.invalidate(adminStudentListProvider);
  }

  Future<void> _changeRole(
    BuildContext ctx,
    WidgetRef ref,
    UserModel user,
    String newRole,
  ) async {
    if (newRole == user.role) return;
    final confirmed = await confirmAdminAction(
      ctx,
      title: 'Change Role',
      message:
          'Change ${user.name}\'s role from "${user.role}" to "$newRole"?',
      confirmLabel: 'Change',
      confirmColor: AppColors.info,
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .updateUserRole(user.id, newRole);
    ref.invalidate(adminStudentListProvider);
  }
}

// ─────────────────────────────────────────────────────────────
//  Student data table
// ─────────────────────────────────────────────────────────────
class _StudentTable extends StatelessWidget {
  final List<UserModel> students;
  final ValueChanged<UserModel> onToggle;
  final ValueChanged<UserModel> onDelete;
  final void Function(UserModel, String) onRoleChange;
  final ValueChanged<UserModel> onTap;

  const _StudentTable({
    required this.students,
    required this.onToggle,
    required this.onDelete,
    required this.onRoleChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 48,
          ),
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(AppColors.surfaceVariant),
            headingTextStyle: AppTextStyles.labelMedium
                .copyWith(fontWeight: FontWeight.w600),
            dataRowMinHeight: 58,
            dataRowMaxHeight: 58,
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Joined')),
              DataColumn(label: Text('Actions')),
            ],
            rows: students.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return DataRow(
                onSelectChanged: (_) => onTap(s),
                cells: [
                  DataCell(Text('${i + 1}',
                      style: AppTextStyles.labelMedium)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(
                          name: s.name,
                          avatarUrl: s.avatarUrl,
                          radius: 17,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: AppTextStyles.labelLarge),
                            Text('ID: ${s.id.substring(0, 8)}…',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(s.email,
                      style: AppTextStyles.bodySmall)),
                  DataCell(Text(s.phone ?? '—',
                      style: AppTextStyles.bodySmall)),
                  DataCell(UserStatusBadge(active: s.isActive)),
                  DataCell(Text(fmtDate(s.createdAt),
                      style: AppTextStyles.bodySmall)),
                  DataCell(_UserActionMenu(
                    user: s,
                    onToggle: () => onToggle(s),
                    onDelete: () => onDelete(s),
                    onRoleChange: (role) => onRoleChange(s, role),
                    onViewDetail: () => onTap(s),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Shared sub-widgets
// ─────────────────────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final TextEditingController searchCtrl;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final VoidCallback onRefresh;

  const _ListHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.searchCtrl,
    required this.searchHint,
    required this.onSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon badge
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headlineLarge),
              Text(subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        // Search
        AdminUserSearchBar(
          controller: searchCtrl,
          hint: searchHint,
          onChanged: onSearch,
        ),
        const SizedBox(width: 12),
        // Refresh
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          onPressed: onRefresh,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.surfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _UserActionMenu extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onViewDetail;
  final ValueChanged<String> onRoleChange;

  const _UserActionMenu({
    required this.user,
    required this.onToggle,
    required this.onDelete,
    required this.onViewDetail,
    required this.onRoleChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View detail
        IconButton(
          tooltip: 'View Profile',
          icon: const Icon(Icons.open_in_new_rounded,
              size: 17, color: AppColors.info),
          onPressed: onViewDetail,
        ),
        // Suspend / Activate
        IconButton(
          tooltip: user.isActive ? 'Suspend' : 'Activate',
          icon: Icon(
            user.isActive
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            size: 17,
            color:
                user.isActive ? AppColors.warning : AppColors.success,
          ),
          onPressed: onToggle,
        ),
        // Role change popup
        PopupMenuButton<String>(
          tooltip: 'Change Role',
          icon: const Icon(Icons.manage_accounts_rounded,
              size: 17, color: AppColors.textSecondary),
          onSelected: onRoleChange,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'student', child: Text('→ Student')),
            PopupMenuItem(value: 'teacher', child: Text('→ Teacher')),
            PopupMenuItem(value: 'admin',   child: Text('→ Admin')),
          ],
        ),
        // Delete
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded,
              size: 17, color: AppColors.error),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 40),
        const SizedBox(height: 12),
        Text('Failed to load data',
            style: AppTextStyles.headlineSmall),
        const SizedBox(height: 6),
        Text(message,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          onPressed: onRetry,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary),
        ),
      ],
    );
  }
}
