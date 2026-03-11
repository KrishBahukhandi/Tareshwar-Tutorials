// ─────────────────────────────────────────────────────────────
//  batch_list_screen.dart
//  Admin: List, search, filter, and manage all batches.
//
//  Features:
//    • Data table with all batches (name, course, teacher,
//      capacity fill bar, date range, status, actions)
//    • Search by batch name / course / teacher
//    • Filter by active/inactive + by course
//    • Sort by date / name
//    • Stat cards (total, active, enrollments)
//    • Quick actions: create, edit, toggle, delete, view students
//    • Wide layout: split-panel inline enrollment view
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../data/admin_batches_service.dart';
import '../providers/admin_batches_providers.dart';
import '../widgets/admin_batches_widgets.dart';
import 'batch_detail_screen.dart';

class BatchListScreen extends ConsumerStatefulWidget {
  const BatchListScreen({super.key});

  @override
  ConsumerState<BatchListScreen> createState() =>
      _BatchListScreenState();
}

class _BatchListScreenState extends ConsumerState<BatchListScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedBatchId; // for inline split panel

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminBatchStatsProvider);
    final batchesAsync = ref.watch(adminBatchListProvider);
    final search = ref.watch(adminBatchListSearchProvider);
    final activeFilt = ref.watch(adminBatchActiveFilterProvider);
    final courseFilt = ref.watch(adminBatchCourseFilterProvider);
    final w = MediaQuery.sizeOf(context).width;
    final isSplit = w > 1200 && _selectedBatchId != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // ── Top bar ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _Header(
                onCreateBatch: () =>
                    _navigateToCreate(context),
              ),
            ),
          ),

          // ── Stats row ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: statsAsync.when(
                loading: () => const SizedBox(height: 70),
                error: (e, s) => const SizedBox.shrink(),
                data: (stats) => _StatsRow(stats: stats),
              ),
            ),
          ),

          // ── Filter bar ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _FilterBar(
                searchCtrl: _searchCtrl,
                search: search,
                activeFilt: activeFilt,
                courseFilt: courseFilt,
                onSearchChanged: (v) => ref
                    .read(adminBatchListSearchProvider.notifier)
                    .state = v,
                onActiveFilterChanged: (v) => ref
                    .read(adminBatchActiveFilterProvider.notifier)
                    .state = v,
                onCourseFilterChanged: (v) => ref
                    .read(adminBatchCourseFilterProvider.notifier)
                    .state = v,
                onClearFilters: _clearFilters,
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: isSplit
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _BatchTable(
                            batchesAsync: batchesAsync,
                            selectedBatchId: _selectedBatchId,
                            onSelectBatch: (id) => setState(
                                () => _selectedBatchId =
                                    id == _selectedBatchId ? null : id),
                            onEdit: (b) => _navigateToEdit(context, b),
                            onDelete: (b) =>
                                _confirmDelete(context, b),
                            onToggleActive: (b) =>
                                _toggleActive(b),
                            onViewDetail: (b) =>
                                _navigateToDetail(context, b),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 3,
                          child: BatchDetailScreen(
                            batchId: _selectedBatchId!,
                            embedded: true,
                          ),
                        ),
                      ],
                    )
                  : _BatchTable(
                      batchesAsync: batchesAsync,
                      selectedBatchId: _selectedBatchId,
                      onSelectBatch: (id) => setState(
                          () => _selectedBatchId =
                              id == _selectedBatchId ? null : id),
                      onEdit: (b) => _navigateToEdit(context, b),
                      onDelete: (b) => _confirmDelete(context, b),
                      onToggleActive: (b) => _toggleActive(b),
                      onViewDetail: (b) =>
                          _navigateToDetail(context, b),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    _searchCtrl.clear();
    ref.read(adminBatchListSearchProvider.notifier).state = '';
    ref.read(adminBatchActiveFilterProvider.notifier).state = null;
    ref.read(adminBatchCourseFilterProvider.notifier).state = null;
    setState(() => _selectedBatchId = null);
  }

  void _navigateToCreate(BuildContext context) {
    context.push(AppRoutes.adminCreateBatch).then((_) {
      ref.invalidate(adminBatchListProvider);
      ref.invalidate(adminBatchStatsProvider);
    });
  }

  void _navigateToEdit(
      BuildContext context, AdminBatchListItem batch) {
    context.push(
      AppRoutes.adminEditBatchPath(batch.id),
      extra: batch,
    ).then((_) {
      ref.invalidate(adminBatchListProvider);
      if (_selectedBatchId != null) {
        ref.invalidate(adminBatchDetailProvider(_selectedBatchId!));
      }
    });
  }

  void _navigateToDetail(
      BuildContext context, AdminBatchListItem batch) {
    context.push(AppRoutes.adminBatchDetailPath(batch.id));
  }

  Future<void> _toggleActive(AdminBatchListItem batch) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminBatchesServiceProvider)
          .toggleBatchActive(batch.id, !batch.isActive);
      ref.invalidate(adminBatchListProvider);
      ref.invalidate(adminBatchStatsProvider);
      if (_selectedBatchId == batch.id) {
        ref.invalidate(adminBatchDetailProvider(batch.id));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AdminBatchListItem batch) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text(
          'Delete "${batch.batchName}"?\n\n'
          'All ${batch.enrolledCount} student enrollment(s) '
          'in this batch will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ref
            .read(adminBatchesServiceProvider)
            .deleteBatch(batch.id);
        if (_selectedBatchId == batch.id) {
          setState(() => _selectedBatchId = null);
        }
        ref.invalidate(adminBatchListProvider);
        ref.invalidate(adminBatchStatsProvider);
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text('"${batch.batchName}" deleted'),
            backgroundColor: AppColors.success,
          ));
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
              SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

// ── Page header ────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onCreateBatch;
  const _Header({required this.onCreateBatch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch Management',
                style: AppTextStyles.headlineLarge),
            const SizedBox(height: 2),
            Text('Create, manage, and assign students to batches',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12)),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Batch'),
          onPressed: onCreateBatch,
        ),
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BatchStatCard(
            icon: Icons.layers_rounded,
            label: 'Total Batches',
            value: '${stats['total'] ?? 0}',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BatchStatCard(
            icon: Icons.check_circle_outline_rounded,
            label: 'Active Batches',
            value: '${stats['active'] ?? 0}',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BatchStatCard(
            icon: Icons.people_rounded,
            label: 'Total Enrollments',
            value: '${stats['enrollments'] ?? 0}',
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────
class _FilterBar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final String   search;
  final bool?    activeFilt;
  final String?  courseFilt;
  final ValueChanged<String>  onSearchChanged;
  final ValueChanged<bool?>   onActiveFilterChanged;
  final ValueChanged<String?> onCourseFilterChanged;
  final VoidCallback          onClearFilters;

  const _FilterBar({
    required this.searchCtrl,
    required this.search,
    required this.activeFilt,
    required this.courseFilt,
    required this.onSearchChanged,
    required this.onActiveFilterChanged,
    required this.onCourseFilterChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(adminBatchCourseOptionsProvider);
    final hasFilters =
        search.isNotEmpty || activeFilt != null || courseFilt != null;

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BatchSearchField(
          controller: searchCtrl,
          onChanged: onSearchChanged,
          hintText: 'Search batches…',
        ),
        // Active filter
        _FilterChip(
          label: activeFilt == null
              ? 'All Statuses'
              : activeFilt!
                  ? 'Active'
                  : 'Inactive',
          icon: Icons.toggle_on_rounded,
          onTap: () => _showStatusMenu(context),
        ),
        // Course filter
        coursesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
          data: (courses) => _FilterChip(
            label: courseFilt == null
                ? 'All Courses'
                : courses
                        .firstWhere(
                          (c) => c.id == courseFilt,
                          orElse: () => AdminBatchCourseOption(
                              id: '', title: 'Unknown', teacherName: '',
                              isPublished: false),
                        )
                        .title,
            icon: Icons.school_rounded,
            onTap: () => _showCourseMenu(context, courses),
          ),
        ),
        if (hasFilters)
          TextButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.clear_rounded, size: 14),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary),
          ),
      ],
    );
  }

  void _showStatusMenu(BuildContext context) {
    showMenu<bool?>(
      context: context,
      position: RelativeRect.fromLTRB(200, 200, 0, 0),
      items: [
        const PopupMenuItem(value: null, child: Text('All Statuses')),
        const PopupMenuItem(value: true, child: Text('Active')),
        const PopupMenuItem(value: false, child: Text('Inactive')),
      ],
    ).then((v) {
      if (v != activeFilt) onActiveFilterChanged(v);
    });
  }

  void _showCourseMenu(
      BuildContext context, List<AdminBatchCourseOption> courses) {
    showMenu<String?>(
      context: context,
      position: RelativeRect.fromLTRB(300, 200, 0, 0),
      items: [
        const PopupMenuItem(
            value: null, child: Text('All Courses')),
        ...courses.map((c) => PopupMenuItem(
              value: c.id,
              child: Text(c.title,
                  overflow: TextOverflow.ellipsis),
            )),
      ],
    ).then((v) {
      if (v != courseFilt) onCourseFilterChanged(v);
    });
  }
}

class _FilterChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textPrimary)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Batch data table ──────────────────────────────────────────
class _BatchTable extends StatelessWidget {
  final AsyncValue<List<AdminBatchListItem>> batchesAsync;
  final String?           selectedBatchId;
  final ValueChanged<String> onSelectBatch;
  final ValueChanged<AdminBatchListItem> onEdit;
  final ValueChanged<AdminBatchListItem> onDelete;
  final ValueChanged<AdminBatchListItem> onToggleActive;
  final ValueChanged<AdminBatchListItem> onViewDetail;

  const _BatchTable({
    required this.batchesAsync,
    required this.selectedBatchId,
    required this.onSelectBatch,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return AdminBatchTableCard(
      title: 'All Batches',
      child: batchesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Error: $e',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.error)),
        ),
        data: (batches) {
          if (batches.isEmpty) {
            return BatchEmptyState(
              title: 'No batches found',
              subtitle: 'Create your first batch or clear filters.',
              icon: Icons.layers_outlined,
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width - 80,
              ),
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(AppColors.surfaceVariant),
                dataRowMinHeight: 58,
                dataRowMaxHeight: 58,
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Batch Name')),
                  DataColumn(label: Text('Course')),
                  DataColumn(label: Text('Teacher')),
                  DataColumn(label: Text('Students')),
                  DataColumn(label: Text('Dates')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: batches.asMap().entries.map((e) {
                  final idx     = e.key;
                  final batch   = e.value;
                  final isSelected = selectedBatchId == batch.id;

                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary.withValues(alpha: 0.06);
                      }
                      return null;
                    }),
                    onSelectChanged: (_) =>
                        onSelectBatch(batch.id),
                    cells: [
                      DataCell(Text('${idx + 1}',
                          style: AppTextStyles.labelMedium)),
                      DataCell(
                        GestureDetector(
                          onTap: () => onViewDetail(batch),
                          child: SizedBox(
                            width: 150,
                            child: Text(
                              batch.batchName,
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      DataCell(SizedBox(
                        width: 140,
                        child: Text(batch.courseTitle,
                            style: AppTextStyles.bodySmall,
                            overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(SizedBox(
                        width: 110,
                        child: Text(batch.teacherName,
                            style: AppTextStyles.bodySmall,
                            overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(CapacityFillBar(
                        enrolled: batch.enrolledCount,
                        max: batch.maxStudents,
                      )),
                      DataCell(Text(
                        _dateRange(batch.startDate, batch.endDate),
                        style: AppTextStyles.bodySmall,
                      )),
                      DataCell(
                        BatchStatusBadge(isActive: batch.isActive)),
                      DataCell(_ActionButtons(
                        batch: batch,
                        isSelected: isSelected,
                        onView: () => onSelectBatch(batch.id),
                        onViewDetail: () => onViewDetail(batch),
                        onEdit: () => onEdit(batch),
                        onToggle: () => onToggleActive(batch),
                        onDelete: () => onDelete(batch),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  String _dateRange(DateTime start, DateTime? end) {
    final fmt = DateFormat('d MMM yy');
    if (end == null) return 'From ${fmt.format(start)}';
    return '${fmt.format(start)} → ${fmt.format(end)}';
  }
}

class _ActionButtons extends StatelessWidget {
  final AdminBatchListItem batch;
  final bool isSelected;
  final VoidCallback onView;
  final VoidCallback onViewDetail;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ActionButtons({
    required this.batch,
    required this.isSelected,
    required this.onView,
    required this.onViewDetail,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View students (inline split)
        IconButton(
          tooltip: isSelected ? 'Hide Panel' : 'Quick View Students',
          icon: Icon(
            isSelected
                ? Icons.people_alt_rounded
                : Icons.people_outline_rounded,
            size: 18,
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          onPressed: onView,
        ),
        // Full detail page
        IconButton(
          tooltip: 'View Detail',
          icon: const Icon(Icons.open_in_new_rounded,
              size: 18, color: AppColors.info),
          onPressed: onViewDetail,
        ),
        // Edit
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_rounded,
              size: 18, color: AppColors.info),
          onPressed: onEdit,
        ),
        // Toggle active
        IconButton(
          tooltip: batch.isActive ? 'Deactivate' : 'Activate',
          icon: Icon(
            batch.isActive
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            size: 18,
            color: batch.isActive
                ? AppColors.warning
                : AppColors.success,
          ),
          onPressed: onToggle,
        ),
        // Delete
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
