// ─────────────────────────────────────────────────────────────
//  admin_teachers_screen.dart  (admin_users module)
//  Full teacher management list with search, suspend, delete,
//  role-change and tap-to-detail navigation.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_router.dart';
import '../../../shared/models/models.dart';
import '../data/admin_users_service.dart';
import '../providers/admin_users_providers.dart';
import '../widgets/admin_users_widgets.dart';

// ─────────────────────────────────────────────────────────────
class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  ConsumerState<AdminTeachersScreen> createState() =>
      _AdminTeachersScreenState();
}

class _AdminTeachersScreenState
    extends ConsumerState<AdminTeachersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(adminTeacherListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            _ListHeader(
              title: 'Teachers',
              subtitle: 'Manage all registered teacher accounts',
              icon: Icons.school_rounded,
              color: AppColors.info,
              searchCtrl: _searchCtrl,
              searchHint: 'Search by name, email…',
              onSearch: (v) => ref
                  .read(adminUsersTeacherSearchProvider.notifier)
                  .state = v,
              onRefresh: () =>
                  ref.invalidate(adminTeacherListProvider),
              onAddTeacher: () =>
                  _showCreateTeacherDialog(context, ref),
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
                  child: teachersAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: _ErrorView(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(adminTeacherListProvider),
                      ),
                    ),
                    data: (teachers) => teachers.isEmpty
                        ? const AdminUsersEmptyState(
                            icon: Icons.school_rounded,
                            message: 'No teachers found.\n'
                                'Teachers will appear here once they register.',
                          )
                        : _TeacherTable(
                            teachers: teachers,
                            onToggle: (t) =>
                                _toggleUser(context, ref, t),
                            onDelete: (t) =>
                                _deleteUser(context, ref, t),
                            onRoleChange: (t, role) =>
                                _changeRole(context, ref, t, role),
                            onTap: (t) => context.push(
                              AppRoutes.adminUserTeacherDetail
                                  .replaceFirst(':userId', t.id),
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
      title: '$action Teacher',
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
    ref.invalidate(adminTeacherListProvider);
  }

  Future<void> _deleteUser(
      BuildContext ctx, WidgetRef ref, UserModel user) async {
    final confirmed = await confirmAdminAction(
      ctx,
      title: 'Delete Teacher',
      message:
          'Permanently remove ${user.name}? '
          'All their courses and content will be deleted. '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await ref
        .read(adminUsersServiceProvider)
        .deleteUser(user.id);
    ref.invalidate(adminTeacherListProvider);
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
    ref.invalidate(adminTeacherListProvider);
  }

  Future<void> _showCreateTeacherDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateTeacherDialog(),
    );
    if (created == true) {
      ref.invalidate(adminTeacherListProvider);
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Teacher data table
// ─────────────────────────────────────────────────────────────
class _TeacherTable extends StatelessWidget {
  final List<UserModel> teachers;
  final ValueChanged<UserModel> onToggle;
  final ValueChanged<UserModel> onDelete;
  final void Function(UserModel, String) onRoleChange;
  final ValueChanged<UserModel> onTap;

  const _TeacherTable({
    required this.teachers,
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
              DataColumn(label: Text('Teacher')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Joined')),
              DataColumn(label: Text('Actions')),
            ],
            rows: teachers.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              return DataRow(
                onSelectChanged: (_) => onTap(t),
                cells: [
                  DataCell(Text('${i + 1}',
                      style: AppTextStyles.labelMedium)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(
                          name: t.name,
                          avatarUrl: t.avatarUrl,
                          radius: 17,
                          backgroundColor:
                              AppColors.info.withValues(alpha: 0.15),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                style: AppTextStyles.labelLarge),
                            Text('ID: ${t.id.substring(0, 8)}…',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(t.email,
                      style: AppTextStyles.bodySmall)),
                  DataCell(Text(t.phone ?? '—',
                      style: AppTextStyles.bodySmall)),
                  DataCell(UserStatusBadge(active: t.isActive)),
                  DataCell(Text(fmtDate(t.createdAt),
                      style: AppTextStyles.bodySmall)),
                  DataCell(_TeacherActionMenu(
                    user: t,
                    onToggle: () => onToggle(t),
                    onDelete: () => onDelete(t),
                    onRoleChange: (role) => onRoleChange(t, role),
                    onViewDetail: () => onTap(t),
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
//  Header
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
  final VoidCallback onAddTeacher;

  const _ListHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.searchCtrl,
    required this.searchHint,
    required this.onSearch,
    required this.onRefresh,
    required this.onAddTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
        AdminUserSearchBar(
          controller: searchCtrl,
          hint: searchHint,
          onChanged: onSearch,
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          onPressed: onRefresh,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.surfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
          label: const Text('Add Teacher'),
          onPressed: onAddTeacher,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _CreateTeacherDialog extends ConsumerStatefulWidget {
  const _CreateTeacherDialog();

  @override
  ConsumerState<_CreateTeacherDialog> createState() =>
      _CreateTeacherDialogState();
}

class _CreateTeacherDialogState
    extends ConsumerState<_CreateTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(adminUsersServiceProvider).createTeacher(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Teacher account created for ${result.email}. Login credentials were emailed successfully.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on FunctionException catch (e) {
      setState(() {
        _errorMessage = e.details?.toString().isNotEmpty == true
            ? e.details.toString()
            : 'Could not create the teacher account right now.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Teacher Account',
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'The teacher will receive their login email and can later reset the password from the login screen.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Teacher Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Teacher name is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Enter a valid teacher name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Teacher Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'Teacher email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Temporary Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) {
                      return 'Temporary password is required';
                    }
                    if (password.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _submitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.info,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create & Email'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Action menu
// ─────────────────────────────────────────────────────────────
class _TeacherActionMenu extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onViewDetail;
  final ValueChanged<String> onRoleChange;

  const _TeacherActionMenu({
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
        IconButton(
          tooltip: 'View Profile',
          icon: const Icon(Icons.open_in_new_rounded,
              size: 17, color: AppColors.info),
          onPressed: onViewDetail,
        ),
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

// ─────────────────────────────────────────────────────────────
//  Error view
// ─────────────────────────────────────────────────────────────
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
