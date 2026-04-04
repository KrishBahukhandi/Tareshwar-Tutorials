// ─────────────────────────────────────────────────────────────
//  student_dashboard_screen.dart  –  Main student home
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/services/app_providers.dart';
import '../../widgets/course_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/section_header.dart';
import '../../../courses/presentation/widgets/progress_widgets.dart'
    show ContinueLearningCard;

// ── Screen ─────────────────────────────────────────────────────
class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final enrolledAsync = ref.watch(enrolledCoursesProvider);
    final allAsync = ref.watch(allCoursesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ─────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Tareshwar', style: AppTextStyles.headlineMedium),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.go(AppRoutes.notifications),
              ),
              userAsync.when(
                data: (user) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: user?.avatarUrl != null
                        ? CachedNetworkImageProvider(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            (user?.name ?? 'S').substring(0, 1).toUpperCase(),
                            style: AppTextStyles.labelLarge
                                .copyWith(color: AppColors.primary),
                          )
                        : null,
                  ),
                ),
                loading: () => const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, e) => const SizedBox.shrink(),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Greeting ────────────────────────────
                  userAsync.when(
                    data: (user) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.name.split(' ').first ?? 'Student'} 👋',
                          style: AppTextStyles.displaySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Let\'s learn something new today!',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(height: 40),
                    error: (_, e) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  // ── Promo Banner ─────────────────────────
                  _PromoBanner(),
                  const SizedBox(height: 28),

                  // ── Stats Row ────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.play_circle_outline_rounded,
                          color: AppColors.primary,
                          label: 'Courses',
                          value: enrolledAsync.when(
                            data: (l) => '${l.length}',
                            loading: () => '...',
                            error: (_, e) => '0',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: Icons.task_alt_rounded,
                          color: AppColors.success,
                          label: 'Completed',
                          value: ref.watch(completedCoursesCountProvider).when(
                                data: (n) => '$n',
                                loading: () => '...',
                                error: (e, st) => '0',
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: StatCard(
                          icon: Icons.emoji_events_rounded,
                          color: AppColors.warning,
                          label: 'Points',
                          value: '0',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Continue Learning ───────────────────────────────────
          SliverToBoxAdapter(
            child: userAsync.when(
              data: (user) {
                if (user == null) return const SizedBox.shrink();
                return _ContinueLearningSection(userId: user.id);
              },
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),
          ),

          // ── My Courses ─────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'My Courses',
                actionLabel: 'See All',
                onAction: () => context.go(AppRoutes.myCourses),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: enrolledAsync.when(
              data: (courses) => courses.isEmpty
                  ? _EmptyCourseBanner(
                      onBrowse: () => context.go(AppRoutes.myCourses))
                  : SizedBox(
                      height: 210,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: courses.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: CourseCard(
                            course: courses[i],
                            onTap: () => context.go(
                              AppRoutes.courseDetailPath(courses[i].id),
                            ),
                          ),
                        ),
                      ),
                    ),
              loading: () => const SizedBox(
                height: 210,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, e) => const SizedBox.shrink(),
            ),
          ),

          // ── Explore ────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Explore Courses',
                actionLabel: 'All',
                onAction: () => context.go(AppRoutes.myCourses),
              ),
            ),
          ),

          allAsync.when(
            data: (courses) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => CourseCard(
                    course: courses[i],
                    onTap: () => context
                        .go(AppRoutes.courseDetailPath(courses[i].id)),
                  ),
                  childCount: courses.take(6).length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, e) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

// ── Promo Banner ───────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔥  Limited Offer',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upgrade to\nPremium',
                  style: AppTextStyles.headlineMedium
                      .copyWith(color: Colors.white, height: 1.2),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.star_rounded,
            color: Colors.white,
            size: 72,
          ),
        ],
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────
class _EmptyCourseBanner extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyCourseBanner({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.school_outlined,
                size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              'No courses enrolled yet',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Browse our courses and start\nyour learning journey.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onBrowse,
              child: const Text('Browse Courses'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Continue Learning Section ──────────────────────────────────
class _ContinueLearningSection extends ConsumerWidget {
  final String userId;
  const _ContinueLearningSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolledAsync = ref.watch(enrolledCoursesProvider);
    final progressMapAsync = ref.watch(studentAllCourseProgressProvider);

    return enrolledAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (courses) {
        if (courses.isEmpty) return const SizedBox.shrink();

        return progressMapAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (progressMap) {
            // Only show courses that have been started (not yet 100%)
            final inProgress = courses
                .where((c) =>
                    progressMap.containsKey(c.id) &&
                    progressMap[c.id]!.hasStarted &&
                    !progressMap[c.id]!.isComplete)
                .toList();

            if (inProgress.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: SectionHeader(
                    title: 'Continue Learning',
                    actionLabel: 'See All',
                    onAction: () => context.go(AppRoutes.myCourses),
                  ),
                ),
                SizedBox(
                  height: 218,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: inProgress.length,
                    itemBuilder: (_, i) {
                      final course = inProgress[i];
                      final progress = progressMap[course.id]!;
                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: ContinueLearningCard(
                          course: course,
                          progress: progress,
                          onTap: () => context.go(
                            AppRoutes.courseDetailPath(course.id),
                          ),
                          onContinueLecture:
                              progress.lastWatchedLecture != null
                                  ? () => context.push(
                                        AppRoutes.lecturePlayerPath(
                                          progress.lastWatchedLecture!.id,
                                        ),
                                      )
                                  : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }
}

