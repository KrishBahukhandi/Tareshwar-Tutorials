// ─────────────────────────────────────────────────────────────
//  admin_teachers_screen.dart  –  Teachers management
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/admin_service.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_top_bar.dart';

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
    final teachersAsync = ref.watch(adminTeachersProvider);
    final search = ref.watch(adminTeacherSearchProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: AdminTableCard(
          title: 'Teachers',
          headerActions: [
            _SearchField(
              controller: _searchCtrl,
              onChanged: (v) => ref
                  .read(adminTeacherSearchProvider.notifier)
                  .state = v,
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.info),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Teacher'),
              onPressed: () => _showAddTeacherDialog(context, ref),
            ),
          ],
          child: teachersAsync.when(
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
            data: (teachers) {
              final filtered = search.isEmpty
                  ? teachers
                  : teachers
                      .where((t) =>
                          t.name
                              .toLowerCase()
                              .contains(search.toLowerCase()) ||
                          t.email
                              .toLowerCase()
                              .contains(search.toLowerCase()))
                      .toList();

              if (filtered.isEmpty) {
                return const _EmptyState(
                    message: 'No teachers found');
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
                      final t = e.value;
                      return DataRow(cells: [
                        DataCell(Text('${i + 1}',
                            style: AppTextStyles.labelMedium)),
                        DataCell(_TeacherName(name: t.name)),
                        DataCell(Text(t.email,
                            style: AppTextStyles.bodySmall)),
                        DataCell(_StatusBadge(active: t.isActive)),
                        DataCell(Text(
                          _fmt(t.createdAt),
                          style: AppTextStyles.bodySmall,
                        )),
                        DataCell(_TeacherActions(
                          user: t,
                          onToggle: () async {
                            await ref
                                .read(adminServiceProvider)
                                .toggleUserActive(
                                    t.id, !t.isActive);
                            ref.invalidate(adminTeachersProvider);
                          },
                          onDemote: () async {
                            await ref
                                .read(adminServiceProvider)
                                .updateUserRole(t.id, 'student');
                            ref.invalidate(adminTeachersProvider);
                          },
                          onDelete: () =>
                              _confirmDelete(context, ref, t),
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
        title: const Text('Remove Teacher'),
        content: Text(
            'Remove ${user.name} permanently? All their courses will remain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(adminServiceProvider).deleteUser(user.id);
      ref.invalidate(adminTeachersProvider);
    }
  }

  Future<void> _showAddTeacherDialog(
      BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (_) => const _PromoteUserDialog(),
    );
  }
}

// ── Promote user dialog ───────────────────────────────────────
class _PromoteUserDialog extends ConsumerStatefulWidget {
  const _PromoteUserDialog();

  @override
  ConsumerState<_PromoteUserDialog> createState() =>
      _PromoteUserDialogState();
}

class _PromoteUserDialogState
    extends ConsumerState<_PromoteUserDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(adminStudentsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Promote Student to Teacher',
                  style: AppTextStyles.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  hintText: 'Search students…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              studentsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (students) {
                  final filtered = _search.isEmpty
                      ? students
                      : students
                          .where((s) =>
                              s.name
                                  .toLowerCase()
                                  .contains(_search.toLowerCase()) ||
                              s.email
                                  .toLowerCase()
                                  .contains(_search.toLowerCase()))
                          .toList();
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary
                                .withValues(alpha: 0.15),
                            child: Text(s.name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.primary)),
                          ),
                          title: Text(s.name),
                          subtitle: Text(s.email),
                          trailing: TextButton(
                            child: const Text('Promote'),
                            onPressed: () async {
                              await ref
                                  .read(adminServiceProvider)
                                  .updateUserRole(s.id, 'teacher');
                              ref.invalidate(adminStudentsProvider);
                              ref.invalidate(adminTeachersProvider);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _TeacherName extends StatelessWidget {
  final String name;
  const _TeacherName({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.info.withValues(alpha: 0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.info),
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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

class _TeacherActions extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggle;
  final VoidCallback onDemote;
  final VoidCallback onDelete;

  const _TeacherActions({
    required this.user,
    required this.onToggle,
    required this.onDemote,
    required this.onDelete,
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
            color:
                user.isActive ? AppColors.warning : AppColors.success,
          ),
          onPressed: onToggle,
        ),
        IconButton(
          tooltip: 'Demote to Student',
          icon: const Icon(Icons.arrow_downward_rounded,
              size: 18, color: AppColors.textSecondary),
          onPressed: onDemote,
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
            Text(message,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
