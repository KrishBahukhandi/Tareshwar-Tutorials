// ─────────────────────────────────────────────────────────────
//  home_screen.dart  –  Student Dashboard (Home tab)
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_widgets.dart'
    hide SectionHeader;
import '../../../../core/utils/app_router.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/models/models.dart';
import '../../domain/entities/enrolled_course_entity.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/continue_learning_card.dart';
import '../widgets/course_card.dart' hide CourseCardShimmer;
import '../widgets/announcement_banner.dart';
import '../widgets/dashboard_shimmer.dart';
import '../widgets/section_header.dart';
import '../widgets/quick_actions_row.dart';

// ─────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const _DashboardLoadingScaffold(),
      error: (e, _) => const _DashboardErrorScaffold(),
      data: (user) => _DashboardBody(user: user, greeting: _greeting()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Main body
// ─────────────────────────────────────────────────────────────
class _DashboardBody extends ConsumerWidget {
  final UserModel? user;
  final String greeting;
  const _DashboardBody({required this.user, required this.greeting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = user?.id ?? '';

    final enrolledAsync = ref.watch(enrolledCoursesProvider(uid));
    final recommendedAsync =
        ref.watch(recommendedCoursesProvider(uid));
    final announcementsAsync =
        ref.watch(announcementsProvider(uid));
    final unreadAsync =
        ref.watch(dashboardUnreadCountProvider(uid));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ════════════════════════════════════════
            //  Sticky App Bar
            // ════════════════════════════════════════
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 2,
              automaticallyImplyLeading: false,
              titleSpacing: AppSpacing.lg,
              title: _GreetingTitle(
                greeting: greeting,
                name: user?.name.split(' ').first ?? 'Student',
              ),
              actions: [
                _NotificationBell(
                  unreadAsync: unreadAsync,
                  onTap: () =>
                      context.push(AppRoutes.notifications),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.profile),
                    child: _UserAvatar(user: user),
                  ),
                ),
              ],
            ),

            // ════════════════════════════════════════
            //  Announcements banner
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: announcementsAsync.when(
                  loading: () => const BannerShimmer(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (list) => list.isEmpty
                      ? _WelcomeBanner(
                          name: user?.name.split(' ').first ??
                              'Student',
                          onResume: () =>
                              context.go(AppRoutes.myCourses),
                        )
                      : AnnouncementBanner(announcements: list),
                ),
              ),
            ),

            // ════════════════════════════════════════
            //  Stats row
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                child: enrolledAsync.when(
                  loading: () => _statsRowShimmer(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (courses) => _StatsRow(courses: courses),
                ),
              ),
            ),

            // ════════════════════════════════════════
            //  Continue Learning
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xxl, AppSpacing.md,
                    AppSpacing.sm),
                child: SectionHeader(
                  title: 'Continue Learning',
                  actionLabel: 'See All',
                  onAction: () => context.go(AppRoutes.myCourses),
                ),
              ),
            ),

            enrolledAsync.when(
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xxs),
                    child: ContinueLearningShimmer(),
                  ),
                  childCount: 2,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: AppEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Could not load courses',
                    subtitle: 'Check your connection and pull down to refresh.',
                    iconColor: AppColors.textHint,
                  ),
                ),
              ),
              data: (courses) => courses.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: _EmptyLearningCard(
                          onBrowse: () =>
                              context.go(AppRoutes.search),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xxs + 2),
                          child: ContinueLearningCard(
                            course: courses[i],
                            onTap: () => context.go(
                              AppRoutes.courseDetailPath(
                                  courses[i].courseId),
                            ),
                          ),
                        ),
                        childCount: courses.take(3).length,
                      ),
                    ),
            ),

            // ════════════════════════════════════════
            //  Quick Actions
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xxl, AppSpacing.md,
                    AppSpacing.sm),
                child: SectionHeader(title: 'Quick Actions'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md),
                child: QuickActionsRow(
                  actions: [
                    QuickAction(
                      icon: Icons.quiz_rounded,
                      label: 'Tests',
                      color: AppColors.warning,
                      onTap: () => context.go(AppRoutes.testsTab),
                    ),
                    QuickAction(
                      icon: Icons.video_camera_front_rounded,
                      label: 'Live',
                      color: AppColors.error,
                      onTap: () =>
                          context.go(AppRoutes.liveClasses),
                    ),
                    QuickAction(
                      icon: Icons.help_outline_rounded,
                      label: 'Doubts',
                      color: AppColors.secondary,
                      onTap: () => context.go(AppRoutes.doubts),
                    ),
                    QuickAction(
                      icon: Icons.search_rounded,
                      label: 'Browse',
                      color: AppColors.success,
                      onTap: () => context.go(AppRoutes.search),
                    ),
                    QuickAction(
                      icon: Icons.leaderboard_rounded,
                      label: 'Progress',
                      color: AppColors.info,
                      onTap: () => context.go(AppRoutes.profile),
                    ),
                  ],
                ),
              ),
            ),

            // ════════════════════════════════════════
            //  Recommended Courses
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xxl, AppSpacing.md,
                    AppSpacing.sm),
                child: SectionHeader(
                  title: 'Recommended For You',
                  actionLabel: 'See All',
                  onAction: () => context.go(AppRoutes.search),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 296,
                child: recommendedAsync.when(
                  loading: () => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    itemCount: 3,
                    itemBuilder: (ctx, i) => const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: CourseCardShimmer(),
                    ),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (courses) => courses.isEmpty
                      ? _EmptyRecommendedCard(
                          onBrowse: () =>
                              context.go(AppRoutes.search),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          itemCount: courses.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(
                                right: AppSpacing.sm),
                            child: CourseCard(
                              course: courses[i],
                              onTap: () => context.go(
                                AppRoutes.courseDetailPath(
                                    courses[i].courseId),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  App bar sub-widgets
// ─────────────────────────────────────────────────────────────

class _GreetingTitle extends StatelessWidget {
  final String greeting;
  final String name;
  const _GreetingTitle({required this.greeting, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$greeting 👋',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        Text(name,
            style: AppTextStyles.headlineMedium
                .copyWith(height: 1.2)),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final AsyncValue<int> unreadAsync;
  final VoidCallback onTap;
  const _NotificationBell(
      {required this.unreadAsync, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = unreadAsync.valueOrNull ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.smAll,
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: onTap,
            tooltip: 'Notifications',
          ),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppColors.errorGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final UserModel? user;
  const _UserAvatar({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 19,
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        backgroundImage: user?.avatarUrl != null
            ? CachedNetworkImageProvider(user!.avatarUrl!)
            : null,
        child: user?.avatarUrl == null
            ? Text(
                user?.name.isNotEmpty == true
                    ? user!.name[0].toUpperCase()
                    : 'S',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.primary,
                        fontWeight: FontWeight.w700),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Welcome banner (when no announcements)
// ─────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  final String name;
  final VoidCallback onResume;
  const _WelcomeBanner({required this.name, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.32),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ready to learn today?',
                  style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 5),
                Text(
                  'Pick up where you left off',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.circle),
                      elevation: 0,
                    ),
                    onPressed: onResume,
                    child: Text(
                      'Resume →',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Opacity(
            opacity: 0.15,
            child: const Icon(Icons.school_rounded,
                size: 88, color: Colors.white),
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
  final List<EnrolledCourseEntity> courses;
  const _StatsRow({required this.courses});

  @override
  Widget build(BuildContext context) {
    final completed =
        courses.where((c) => c.progressPercent >= 100).length;
    final avgProgress = courses.isEmpty
        ? 0.0
        : courses
                .map((c) => c.progressPercent)
                .reduce((a, b) => a + b) /
            courses.length;

    return Row(
      children: [
        _StatTile(
          icon: Icons.library_books_rounded,
          color: AppColors.primary,
          label: 'Enrolled',
          value: '${courses.length}',
        ),
        const SizedBox(width: AppSpacing.xs),
        _StatTile(
          icon: Icons.task_alt_rounded,
          color: AppColors.success,
          label: 'Completed',
          value: '$completed',
        ),
        const SizedBox(width: AppSpacing.xs),
        _StatTile(
          icon: Icons.trending_up_rounded,
          color: AppColors.warning,
          label: 'Avg. Progress',
          value: '${avgProgress.toStringAsFixed(0)}%',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + 2, horizontal: AppSpacing.xs),
        shadows: AppShadows.sm,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTextStyles.headlineSmall.copyWith(color: color),
            ),
            Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _statsRowShimmer() {
  return Row(
    children: List.generate(
      3,
      (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i < 2 ? AppSpacing.xs : 0),
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase.withValues(alpha: 0.4),
              borderRadius: AppRadius.mdAll,
            ),
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Empty states
// ─────────────────────────────────────────────────────────────
class _EmptyLearningCard extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyLearningCard({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      shadows: AppShadows.sm,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.library_books_outlined,
                size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No courses enrolled yet',
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Browse our catalogue and enroll in a course to get started.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Browse Courses',
            icon: Icons.search_rounded,
            onTap: onBrowse,
            fullWidth: false,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecommendedCard extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyRecommendedCard({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.explore_outlined,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: AppSpacing.sm),
          Text('No recommendations yet',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          GhostButton(
            label: 'Browse all courses',
            onTap: onBrowse,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Full-screen loading / error scaffolds
// ─────────────────────────────────────────────────────────────
class _DashboardLoadingScaffold extends StatelessWidget {
  const _DashboardLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DashboardErrorScaffold extends StatelessWidget {
  const _DashboardErrorScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load dashboard',
        subtitle:
            'Check your internet connection and try again.',
        iconColor: AppColors.error,
      ),
    );
  }
}
