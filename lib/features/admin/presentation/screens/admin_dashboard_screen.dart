// ─────────────────────────────────────────────────────────────
//  admin_dashboard_screen.dart  –  Full Admin Control Panel
//  Tabs: Overview · Users · Courses · Batches · Doubts · Announcements
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/admin_service.dart';
import 'admin_announcements_screen.dart'
    show AdminAnnouncementsScreen;

// ── Async providers ────────────────────────────────────────────
final _adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) =>
    ref.watch(adminServiceProvider).fetchStats());

final _adminUsersProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) =>
        ref.watch(adminServiceProvider).fetchUsers(limit: 100));

final _adminCoursesProvider =
    FutureProvider.autoDispose<List<AdminCourseRow>>((ref) =>
        ref.watch(adminServiceProvider).fetchAllCourses());

final _adminBatchesProvider =
    FutureProvider.autoDispose<List<AdminBatchRow>>((ref) =>
        ref.watch(adminServiceProvider).fetchAllBatches());

final _adminDoubtsProvider =
    FutureProvider.autoDispose<List<AdminDoubtRow>>((ref) =>
        ref.watch(adminServiceProvider).fetchDoubts(limit: 100));

// ── Screen ─────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(_adminStatsProvider);
    ref.invalidate(_adminUsersProvider);
    ref.invalidate(_adminCoursesProvider);
    ref.invalidate(_adminBatchesProvider);
    ref.invalidate(_adminDoubtsProvider);
  }  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Admin Panel'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Users'),
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Courses'),
            Tab(icon: Icon(Icons.groups_rounded, size: 18), text: 'Batches'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: 'Doubts'),
            Tab(icon: Icon(Icons.campaign_rounded, size: 18), text: 'Announce'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(onNavigate: (i) => _tab.animateTo(i)),
          const _UsersTab(),
          const _CoursesTab(),
          const _BatchesTab(),
          const _DoubtsTab(),
          const AdminAnnouncementsScreen(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 0 — OVERVIEW
// ══════════════════════════════════════════════════════════════
class _OverviewTab extends ConsumerWidget {
  final void Function(int) onNavigate;
  const _OverviewTab({required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Platform Overview', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text('Live data from Supabase',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          statsAsync.when(
            loading: () => const _StatsShimmer(),
            error: (e, _) => _ErrorBanner(message: e.toString()),
            data: (stats) => Column(
              children: [
                _StatGrid(stats: stats),
                const SizedBox(height: 20),
                _DoubtResolutionCard(stats: stats),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Quick Actions', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 12),            Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickAction(
                label: 'Manage Users',
                icon: Icons.person_add_outlined,
                color: AppColors.primary,
                onTap: () => onNavigate(1),
              ),
              _QuickAction(
                label: 'Manage Courses',
                icon: Icons.menu_book_outlined,
                color: AppColors.success,
                onTap: () => onNavigate(2),
              ),
              _QuickAction(
                label: 'Manage Batches',
                icon: Icons.group_add_outlined,
                color: AppColors.warning,
                onTap: () => onNavigate(3),
              ),
              _QuickAction(
                label: 'Review Doubts',
                icon: Icons.quiz_outlined,
                color: AppColors.secondary,
                onTap: () => onNavigate(4),
              ),
              _QuickAction(
                label: 'Announcements',
                icon: Icons.campaign_outlined,
                color: AppColors.info,
                onTap: () => onNavigate(5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final AdminStats stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Students', '${stats.totalStudents}',
          Icons.school_rounded, AppColors.primary),
      _StatItem('Teachers', '${stats.totalTeachers}',
          Icons.person_outline_rounded, AppColors.secondary),
      _StatItem('Courses', '${stats.totalCourses}',
          Icons.menu_book_rounded, AppColors.success),
      _StatItem('Active Batches', '${stats.activeBatches}',
          Icons.groups_rounded, AppColors.warning),
      _StatItem('Enrollments', '${stats.totalEnrollments}',
          Icons.how_to_reg_rounded, AppColors.info),
      _StatItem('Open Doubts',
          '${stats.totalDoubts - stats.resolvedDoubts}',
          Icons.quiz_rounded, AppColors.error),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _StatCard(item: items[i]),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(item.icon, color: item.color, size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.value,
                  style: AppTextStyles.headlineLarge
                      .copyWith(color: item.color)),
              Text(item.label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoubtResolutionCard extends StatelessWidget {
  final AdminStats stats;
  const _DoubtResolutionCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pct = stats.doubtResolutionRate;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text('Doubt Resolution Rate',
                  style: AppTextStyles.labelLarge),
              const Spacer(),
              Text('${pct.toStringAsFixed(1)}%',
                  style: AppTextStyles.headlineSmall
                      .copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation(
                  AppColors.success),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.resolvedDoubts} resolved · '
            '${stats.totalDoubts - stats.resolvedDoubts} pending',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      onPressed: onTap,
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 1 — USERS
// ══════════════════════════════════════════════════════════════
class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  String _search = '';
  String? _roleFilter; // null = all

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_adminUsersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                  ),
                  onChanged: (v) =>
                      setState(() => _search = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String?>(
                icon: Icon(
                  Icons.filter_list_rounded,
                  color: _roleFilter != null
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                onSelected: (v) =>
                    setState(() => _roleFilter = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: null, child: Text('All roles')),
                  const PopupMenuItem(
                      value: 'student', child: Text('Students')),
                  const PopupMenuItem(
                      value: 'teacher', child: Text('Teachers')),
                  const PopupMenuItem(
                      value: 'admin', child: Text('Admins')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: usersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorBanner(message: e.toString()),
            data: (all) {
              var users = all;
              if (_roleFilter != null) {
                users =
                    users.where((u) => u.role == _roleFilter).toList();
              }
              if (_search.isNotEmpty) {
                users = users
                    .where((u) =>
                        u.name.toLowerCase().contains(_search) ||
                        u.email.toLowerCase().contains(_search))
                    .toList();
              }
              if (users.isEmpty) {
                return const Center(
                    child: Text('No users found'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: users.length,
                separatorBuilder: (_, i) =>
                    const SizedBox(height: 4),
                itemBuilder: (_, i) =>
                    _UserTile(user: users[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends ConsumerWidget {
  final UserModel user;
  const _UserTile({required this.user});

  Color get _roleColor {
    if (user.isAdmin) return AppColors.secondary;
    if (user.isTeacher) return AppColors.warning;
    return AppColors.primary;
  }

  IconData get _roleIcon {
    if (user.isAdmin) return Icons.admin_panel_settings_rounded;
    if (user.isTeacher) return Icons.person_pin_rounded;
    return Icons.school_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _roleColor.withValues(alpha: 0.12),
          child: Icon(_roleIcon, color: _roleColor, size: 20),
        ),
        title: Text(user.name, style: AppTextStyles.labelLarge),
        subtitle: Text(user.email,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleBadge(role: user.role),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'promote_teacher',
                    child: Text('Make Teacher')),
                const PopupMenuItem(
                    value: 'promote_admin',
                    child: Text('Make Admin')),
                const PopupMenuItem(
                    value: 'make_student',
                    child: Text('Make Student')),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: user.isActive ? 'suspend' : 'activate',
                  child: Text(
                    user.isActive ? 'Suspend' : 'Activate',
                    style: TextStyle(
                      color: user.isActive
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
              onSelected: (action) async {
                final svc = ref.read(adminServiceProvider);
                try {
                  switch (action) {
                    case 'promote_teacher':
                      await svc.updateUserRole(user.id, 'teacher');
                      break;
                    case 'promote_admin':
                      await svc.updateUserRole(user.id, 'admin');
                      break;
                    case 'make_student':
                      await svc.updateUserRole(user.id, 'student');
                      break;
                    case 'suspend':
                      await svc.toggleUserActive(user.id, false);
                      break;
                    case 'activate':
                      await svc.toggleUserActive(user.id, true);
                      break;
                    case 'delete':
                      await _confirmDelete(context, svc, user.id);
                      return;
                  }
                  ref.invalidate(_adminUsersProvider);
                  ref.invalidate(_adminStatsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AdminService svc, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text(
            'This will permanently delete the account and all associated data. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) await svc.deleteUser(userId);
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  Color get _color {
    switch (role) {
      case 'admin':
        return AppColors.secondary;
      case 'teacher':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role,
        style:
            AppTextStyles.labelSmall.copyWith(color: _color),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 2 — COURSES
// ══════════════════════════════════════════════════════════════
class _CoursesTab extends ConsumerWidget {
  const _CoursesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminCoursesProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBanner(message: e.toString()),
      data: (courses) => courses.isEmpty
          ? const Center(child: Text('No courses yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              separatorBuilder: (_, i) =>
                  const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _CourseAdminTile(course: courses[i]),
            ),
    );
  }
}

class _CourseAdminTile extends ConsumerWidget {
  final AdminCourseRow course;
  const _CourseAdminTile({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.menu_book_rounded,
              color: Colors.white, size: 20),
        ),
        title: Text(course.title,
            style: AppTextStyles.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${course.teacherName} · ₹${course.price.toStringAsFixed(0)}',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PublishedBadge(isPublished: course.isPublished),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(course.isPublished
                      ? 'Unpublish'
                      : 'Publish'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style:
                          TextStyle(color: AppColors.error)),
                ),
              ],
              onSelected: (action) async {
                final svc = ref.read(adminServiceProvider);
                try {
                  if (action == 'toggle') {
                    await svc.toggleCoursePublish(
                        course.id, !course.isPublished);
                  } else if (action == 'delete') {
                    await svc.deleteCourse(course.id);
                  }
                  ref.invalidate(_adminCoursesProvider);
                  ref.invalidate(_adminStatsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedBadge extends StatelessWidget {
  final bool isPublished;
  const _PublishedBadge({required this.isPublished});

  @override
  Widget build(BuildContext context) {
    final color =
        isPublished ? AppColors.success : AppColors.warning;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPublished ? 'Live' : 'Draft',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 3 — BATCHES
// ══════════════════════════════════════════════════════════════
class _BatchesTab extends ConsumerWidget {
  const _BatchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminBatchesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon:
            const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Batch',
            style: TextStyle(color: Colors.white)),
        onPressed: () =>
            _showBatchDialog(context, ref, null),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBanner(message: e.toString()),
        data: (batches) => batches.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_outlined,
                        size: 64, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text('No batches yet',
                        style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          _showBatchDialog(context, ref, null),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create First Batch'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    16, 12, 16, 80),
                itemCount: batches.length,
                separatorBuilder: (_, i) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) => _BatchAdminTile(
                  batch: batches[i],
                  onEdit: () =>
                      _showBatchDialog(context, ref, batches[i]),
                  onDelete: () =>
                      _confirmDeleteBatch(context, ref, batches[i].id),
                ),
              ),
      ),
    );
  }

  void _showBatchDialog(
      BuildContext context, WidgetRef ref, AdminBatchRow? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _BatchFormDialog(
        existing: existing,
        onSave: (data) async {
          final svc = ref.read(adminServiceProvider);
          if (existing == null) {
            await svc.createBatch(
              courseId: data['course_id'] as String,
              batchName: data['batch_name'] as String,
              description: data['description'] as String?,
              startDate: data['start_date'] as DateTime,
              endDate: data['end_date'] as DateTime?,
              maxStudents: data['max_students'] as int,
            );
          } else {
            await svc.updateBatch(
              batchId: existing.id,
              batchName: data['batch_name'] as String?,
              description: data['description'] as String?,
              startDate: data['start_date'] as DateTime?,
              endDate: data['end_date'] as DateTime?,
              maxStudents: data['max_students'] as int?,
              isActive: data['is_active'] as bool?,
            );
          }
          ref.invalidate(_adminBatchesProvider);
          ref.invalidate(_adminStatsProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _confirmDeleteBatch(
      BuildContext context, WidgetRef ref, String batchId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch'),
        content: const Text(
            'This will remove all enrolled students from this batch. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () async {
              await ref
                  .read(adminServiceProvider)
                  .deleteBatch(batchId);
              ref.invalidate(_adminBatchesProvider);
              ref.invalidate(_adminStatsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _BatchAdminTile extends StatelessWidget {
  final AdminBatchRow batch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BatchAdminTile(
      {required this.batch,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(batch.batchName,
                          style: AppTextStyles.headlineSmall),
                      const SizedBox(height: 2),
                      Text(batch.courseTitle,
                          style: AppTextStyles.bodySmall
                              .copyWith(
                                  color:
                                      AppColors.textSecondary)),
                    ],
                  ),
                ),
                _ActiveBadge(isActive: batch.isActive),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'students',
                        child: Row(children: [
                          Icon(Icons.people_alt_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('View Students'),
                        ])),
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(
                                  color: AppColors.error)),
                        ])),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                    if (v == 'students') {
                      context.go(
                          AppRoutes.adminBatchEnrollmentsPath(batch.id));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoPill(
                    icon: Icons.people_rounded,
                    label:
                        '${batch.enrolledCount}/${batch.maxStudents}',
                    color: AppColors.primary),
                const SizedBox(width: 8),
                _InfoPill(
                    icon: Icons.calendar_today_rounded,
                    label:
                        '${batch.startDate.day}/${batch.startDate.month}/${batch.startDate.year}',
                    color: AppColors.secondary),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: batch.fillPercent,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(
                  batch.fillPercent > 0.9
                      ? AppColors.error
                      : batch.fillPercent > 0.7
                          ? AppColors.warning
                          : AppColors.success,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final bool isActive;
  const _ActiveBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? AppColors.success : AppColors.textHint;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoPill(
      {required this.icon,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// Batch form dialog
class _BatchFormDialog extends ConsumerStatefulWidget {
  final AdminBatchRow? existing;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _BatchFormDialog({this.existing, required this.onSave});

  @override
  ConsumerState<_BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends ConsumerState<_BatchFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _maxCtrl;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  bool _saving = false;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.batchName ?? '');
    _descCtrl = TextEditingController(text: '');
    _maxCtrl =
        TextEditingController(text: '${e?.maxStudents ?? 50}');
    _selectedCourseId = e?.courseId;
    if (e != null) {
      _startDate = e.startDate;
      _endDate = e.endDate;
      _isActive = e.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_endDate ?? _startDate) : _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _endDate = picked;
      } else {
        _startDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final coursesAsync = ref.watch(_adminCoursesProvider);

    return AlertDialog(
      title: Text(isEdit ? 'Edit Batch' : 'Create Batch'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Batch Name *'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Course dropdown
              coursesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (_, e) => TextFormField(
                  initialValue: _selectedCourseId ?? '',
                  decoration: const InputDecoration(
                      labelText: 'Course ID *'),
                  onChanged: (v) => _selectedCourseId = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                data: (courses) =>
                    DropdownButtonFormField<String>(
                  initialValue: _selectedCourseId,
                  decoration: const InputDecoration(
                      labelText: 'Course *'),
                  isExpanded: true,
                  items: courses
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.title,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCourseId = v),
                  validator: (v) =>
                      v == null ? 'Select a course' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxCtrl,
                decoration: const InputDecoration(
                    labelText: 'Max Students'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(
                    '${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                trailing: const Icon(Icons.calendar_today_rounded,
                    size: 18),
                onTap: () => _pickDate(isEnd: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date (optional)'),
                subtitle: Text(_endDate != null
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                    : 'Not set'),
                trailing: const Icon(Icons.calendar_today_rounded,
                    size: 18),
                onTap: () => _pickDate(isEnd: true),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) =>
                    setState(() => _isActive = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() => _saving = true);
                  try {
                    await widget.onSave({
                      'batch_name': _nameCtrl.text.trim(),
                      'description': _descCtrl.text.trim().isEmpty
                          ? null
                          : _descCtrl.text.trim(),
                      'course_id': _selectedCourseId!,
                      'max_students':
                          int.tryParse(_maxCtrl.text) ?? 50,
                      'start_date': _startDate,
                      'end_date': _endDate,
                      'is_active': _isActive,
                    });
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 4 — DOUBTS
// ══════════════════════════════════════════════════════════════
class _DoubtsTab extends ConsumerStatefulWidget {
  const _DoubtsTab();

  @override
  ConsumerState<_DoubtsTab> createState() => _DoubtsTabState();
}

class _DoubtsTabState extends ConsumerState<_DoubtsTab> {
  bool? _answeredFilter; // null = all, true = answered, false = unanswered

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminDoubtsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('Filter:', style: AppTextStyles.labelLarge),
              const SizedBox(width: 10),
              _FilterChip(
                  label: 'All',
                  selected: _answeredFilter == null,
                  onTap: () =>
                      setState(() => _answeredFilter = null)),
              const SizedBox(width: 6),
              _FilterChip(
                  label: 'Pending',
                  selected: _answeredFilter == false,
                  color: AppColors.error,
                  onTap: () =>
                      setState(() => _answeredFilter = false)),
              const SizedBox(width: 6),
              _FilterChip(
                  label: 'Resolved',
                  selected: _answeredFilter == true,
                  color: AppColors.success,
                  onTap: () =>
                      setState(() => _answeredFilter = true)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorBanner(message: e.toString()),
            data: (all) {
              final doubts = _answeredFilter == null
                  ? all
                  : all
                      .where((d) =>
                          d.isAnswered == _answeredFilter)
                      .toList();
              if (doubts.isEmpty) {
                return const Center(
                    child: Text('No doubts found'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: doubts.length,
                separatorBuilder: (_, i) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _DoubtAdminTile(doubt: doubts[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DoubtAdminTile extends StatelessWidget {
  final AdminDoubtRow doubt;
  const _DoubtAdminTile({required this.doubt});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doubt.studentName,
                          style: AppTextStyles.labelLarge),
                      Text(doubt.lectureTitle,
                          style: AppTextStyles.bodySmall
                              .copyWith(
                                  color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: doubt.isAnswered
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    doubt.isAnswered ? 'Resolved' : 'Pending',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: doubt.isAnswered
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              doubt.question,
              style: AppTextStyles.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${doubt.createdAt.day}/${doubt.createdAt.month}/${doubt.createdAt.year}',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
              color: selected ? color : AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Shared error banner ────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Something went wrong',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
