// ─────────────────────────────────────────────────────────────
//  teacher_dashboard_screen.dart  –  Teacher web dashboard
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/course_service.dart';
import '../../../../shared/services/doubt_service.dart';
import '../../../../shared/models/models.dart';
import '../../../../features/teacher_auth/providers/teacher_auth_provider.dart';

final teacherCoursesProvider =
    FutureProvider.autoDispose<List<CourseModel>>((ref) async {
  final uid = ref.watch(authServiceProvider).currentAuthUser?.id;
  if (uid == null) return [];
  final client = ref.watch(courseServiceProvider);
  final all = await client.fetchCourses();
  return all.where((c) => c.teacherId == uid).toList();
});

final pendingDoubtsProvider =
    FutureProvider.autoDispose<List<DoubtModel>>((ref) async {
  final doubts = await ref.watch(doubtServiceProvider).fetchDoubts();
  return doubts.where((d) => !d.isAnswered).toList();
});

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends ConsumerState<TeacherDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final coursesAsync = ref.watch(teacherCoursesProvider);
    final doubtsAsync = ref.watch(pendingDoubtsProvider);
    final teacherUser = ref.watch(teacherUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'My Courses'),
            Tab(text: 'Pending Doubts'),
            Tab(text: 'Analytics'),
          ],
        ),
        actions: [
          // Teacher name + avatar
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                teacherUser?.displayName ??
                    userAsync.maybeWhen(
                      data: (u) => u?.name ?? 'Teacher',
                      orElse: () => 'Teacher',
                    ),
                style: AppTextStyles.labelMedium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                (teacherUser?.initials ??
                    userAsync.maybeWhen(
                      data: (u) => (u?.name ?? 'T')[0].toUpperCase(),
                      orElse: () => 'T',
                    )),
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(teacherAuthProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.teacherLogin);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── My Courses tab ──────────────────────────
          coursesAsync.when(
            data: (courses) => courses.isEmpty
                ? _EmptyState(
                    icon: Icons.video_library_outlined,
                    message: 'No courses yet.\nCreate your first course.')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: courses.length,
                    separatorBuilder: (_, e) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _TeacherCourseCard(course: courses[i]),
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),

          // ── Pending Doubts tab ──────────────────────
          doubtsAsync.when(
            data: (doubts) => doubts.isEmpty
                ? _EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    message: 'No pending doubts!\nAll caught up.')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: doubts.length,
                    separatorBuilder: (_, e) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _TeacherDoubtCard(doubt: doubts[i]),
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),

          // ── Analytics tab ───────────────────────────
          const _AnalyticsPlaceholder(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCourseDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Course',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showCreateCourseDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    final outerContext = context;

    showDialog(
      context: outerContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Course Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Price (₹)', prefixText: '₹ '),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid =
                  ref.read(authServiceProvider).currentAuthUser?.id;
              if (uid == null) return;
              await ref.read(courseServiceProvider).createCourse(
                    title: titleCtrl.text,
                    description: descCtrl.text,
                    teacherId: uid,
                    price: double.tryParse(priceCtrl.text) ?? 0,
                  );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ref.invalidate(teacherCoursesProvider);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _TeacherCourseCard extends StatelessWidget {
  final CourseModel course;
  const _TeacherCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title,
                          style: AppTextStyles.headlineSmall),
                      Text(
                        '${course.totalStudents ?? 0} students enrolled',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: course.isPublished
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    course.isPublished ? 'Published' : 'Draft',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: course.isPublished
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Manage Content'),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.quiz_outlined, size: 16),
                  label: const Text('Add Test'),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherDoubtCard extends ConsumerWidget {
  final DoubtModel doubt;
  const _TeacherDoubtCard({required this.doubt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answerCtrl = TextEditingController();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(doubt.studentName ?? 'Student',
                    style: AppTextStyles.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(doubt.question, style: AppTextStyles.bodyMedium),
            if (doubt.imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(doubt.imageUrl!,
                    height: 120, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: answerCtrl,
              decoration: const InputDecoration(
                hintText: 'Type your answer…',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final ans = answerCtrl.text.trim();
                if (ans.isEmpty) return;
                final uid =
                    ref.read(authServiceProvider).currentAuthUser?.id;
                if (uid == null) return;
                await ref.read(doubtServiceProvider).answerDoubt(
                      doubtId: doubt.id,
                      answer: ans,
                      teacherId: uid,
                    );
                if (context.mounted) {
                  ref.invalidate(pendingDoubtsProvider);
                }
              },
              child: const Text('Post Answer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _AnalyticsPlaceholder extends StatelessWidget {
  const _AnalyticsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student Analytics', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                '📊 Detailed analytics coming soon.\nConnect fl_chart for real-time data.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
