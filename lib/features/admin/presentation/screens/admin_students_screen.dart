// ─────────────────────────────────────────────────────────────
//  admin_students_screen.dart  –  Students management
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/admin_service.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_top_bar.dart';

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
    final studentsAsync = ref.watch(adminStudentsProvider);
    final search = ref.watch(adminStudentSearchProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: AdminTableCard(
          title: 'Students',
          headerActions: [
            _SearchField(
              controller: _searchCtrl,
              onChanged: (v) => ref
                  .read(adminStudentSearchProvider.notifier)
                  .state = v,
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              onPressed: () =>
                  ref.invalidate(adminStudentsProvider),
            ),
          ],
          child: studentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Error: $e',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.error)),
            ),
            data: (students) {
              final filtered = search.isEmpty
                  ? students
                  : students
                      .where((s) =>
                          s.name
                              .toLowerCase()
                              .contains(search.toLowerCase()) ||
                          s.email
                              .toLowerCase()
                              .contains(search.toLowerCase()))
                      .toList();

              if (filtered.isEmpty) {
                return const _EmptyState(
                    message: 'No students found');
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth:
                        MediaQuery.sizeOf(context).width - 48,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        AppColors.surfaceVariant),
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 52,
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Joined')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered.asMap().entries.map((e) {
                      final i = e.key;
                      final s = e.value;
                      return DataRow(cells: [
                        DataCell(Text('${i + 1}',
                            style: AppTextStyles.labelMedium)),
                        DataCell(_AvatarName(
                            name: s.name, role: s.role)),
                        DataCell(Text(s.email,
                            style: AppTextStyles.bodySmall)),
                        DataCell(_StatusBadge(
                            active: s.isActive)),
                        DataCell(Text(
                          _fmt(s.createdAt),
                          style: AppTextStyles.bodySmall,
                        )),
                        DataCell(_ActionRow(
                          user: s,
                          onToggle: () async {
                            await ref
                                .read(adminServiceProvider)
                                .toggleUserActive(
                                    s.id, !s.isActive);
                            ref.invalidate(
                                adminStudentsProvider);
                          },
                          onDelete: () =>
                              _confirmDelete(context, ref, s),
                          onRoleChange: (role) async {
                            await ref
                                .read(adminServiceProvider)
                                .updateUserRole(s.id, role);
                            ref.invalidate(
                                adminStudentsProvider);
                          },
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Student'),
        content:
            Text('Remove ${user.name} permanently? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(adminServiceProvider).deleteUser(user.id);
      ref.invalidate(adminStudentsProvider);
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Admin Teachers Screen
// ─────────────────────────────────────────────────────────────
// (file: admin_teachers_screen.dart — implemented separately)

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ── Shared table helpers ──────────────────────────────────────

class _AvatarName extends StatelessWidget {
  final String name;
  final String role;
  const _AvatarName({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Text(name, style: AppTextStyles.labelLarge),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: AppTextStyles.labelSmall.copyWith(
            color: active ? AppColors.success : AppColors.error,
            fontSize: 11),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onRoleChange;

  const _ActionRow({
    required this.user,
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
          tooltip: user.isActive ? 'Deactivate' : 'Activate',
          icon: Icon(
            user.isActive
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: user.isActive ? AppColors.warning : AppColors.success,
          ),
          onPressed: onToggle,
        ),
        PopupMenuButton<String>(
          tooltip: 'Change Role',
          icon: const Icon(Icons.manage_accounts_rounded,
              size: 18, color: AppColors.info),
          onSelected: onRoleChange,
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'student', child: Text('Student')),
            const PopupMenuItem(
                value: 'teacher', child: Text('Teacher')),
            const PopupMenuItem(
                value: 'admin', child: Text('Admin')),
          ],
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded,
              size: 18, color: AppColors.error),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search…',
          hintStyle: AppTextStyles.bodySmall,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textHint),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
