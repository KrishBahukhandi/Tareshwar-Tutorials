// ─────────────────────────────────────────────────────────────
//  course_detail_screen.dart  –  Full course detail with
//  hero header, metadata, and subjects list.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/theme_barrel.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/auth_service.dart' show currentUserProvider;
import '../../../../shared/services/app_providers.dart' show enrolledCoursesProvider;
import '../../../../shared/services/course_service.dart' show courseServiceProvider;
import '../providers/course_providers.dart'
    show courseDetailProvider, courseSubjectsProvider, courseProgressProvider, CourseProgress;
import '../widgets/subject_tile.dart';
import '../widgets/progress_widgets.dart' show CourseProgressBar;

// ─────────────────────────────────────────────────────────────
class CourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    final subjectsAsync = ref.watch(courseSubjectsProvider(courseId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    final progressAsync = user != null
        ? ref.watch(courseProgressProvider(
            (studentId: user.id, courseId: courseId)))
        : const AsyncValue<CourseProgress?>.data(null);

    final enrolledAsync = ref.watch(enrolledCoursesProvider);
    final isEnrolled = enrolledAsync.valueOrNull
            ?.any((c) => c.id == courseId) ??
        false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: courseAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => _ErrorScaffold(message: e.toString()),
          data: (course) {
            if (course == null) {
              return const _ErrorScaffold(message: 'Course not found.');
            }
            return _CourseBody(
              course: course,
              subjectsAsync: subjectsAsync,
              courseId: courseId,
              progress: progressAsync.valueOrNull,
              isEnrolled: isEnrolled,
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Main scrollable body
// ─────────────────────────────────────────────────────────────
class _CourseBody extends StatelessWidget {
  final CourseModel course;
  final AsyncValue<List<SubjectModel>> subjectsAsync;
  final String courseId;
  final CourseProgress? progress;
  final bool isEnrolled;

  const _CourseBody({
    required this.course,
    required this.subjectsAsync,
    required this.courseId,
    this.progress,
    required this.isEnrolled,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Hero App Bar ─────────────────────────────
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          stretch: true,
          backgroundColor: AppColors.primaryDark,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => context.pop(),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: _CourseHero(course: course),
          ),
        ),

        // ── Course Info Card ─────────────────────────
        SliverToBoxAdapter(
          child: _CourseInfoCard(
            course: course,
            progress: progress,
            isEnrolled: isEnrolled,
            courseId: courseId,
          ),
        ),

        // ── Content Header ───────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
            child: Row(
              children: [
                Text('Course Content',
                    style: AppTextStyles.headlineMedium),
                const Spacer(),
                subjectsAsync.maybeWhen(
                  data: (subjects) => AppBadge(
                    label:
                        '${subjects.length} subject${subjects.length != 1 ? 's' : ''}',
                    color: AppColors.primary,
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),

        // ── Subjects List ────────────────────────────
        subjectsAsync.when(
          loading: () => SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => const SubjectTileShimmer(),
                childCount: 4,
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Error: $e',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.error)),
            ),
          ),
          data: (subjects) => subjects.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyContent())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xxxl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => SubjectTile(
                        subject: subjects[i],
                        index: i,
                        showCounts: false,
                        onTap: () => context.push(
                          AppRoutes.subjectDetailPath(
                              courseId, subjects[i].id),
                        ),
                      ),
                      childCount: subjects.length,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Hero thumbnail
// ─────────────────────────────────────────────────────────────
class _CourseHero extends StatelessWidget {
  final CourseModel course;
  const _CourseHero({required this.course});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image / gradient
        course.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: course.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                    decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient)),
                errorWidget: (context, url, error) => Container(
                    decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient)),
              )
            : Container(
                decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient)),

        // Gradient scrim
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.8),
              ],
              stops: const [0.35, 1.0],
            ),
          ),
        ),

        // Course info at bottom
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (course.categoryTag != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AppBadge(
                    label: course.categoryTag!,
                    color: AppColors.primary,
                  ),
                ),
              Text(
                course.title,
                style: AppTextStyles.headlineLarge
                    .copyWith(color: Colors.white, height: 1.2),
              ),
              if (course.teacherName != null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 13, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text('by ${course.teacherName}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Info card: stats + description + enroll CTA
// ─────────────────────────────────────────────────────────────
class _CourseInfoCard extends ConsumerStatefulWidget {
  final CourseModel course;
  final CourseProgress? progress;
  final bool isEnrolled;
  final String courseId;
  const _CourseInfoCard({
    required this.course,
    required this.isEnrolled,
    required this.courseId,
    this.progress,
  });

  @override
  ConsumerState<_CourseInfoCard> createState() => _CourseInfoCardState();
}

class _CourseInfoCardState extends ConsumerState<_CourseInfoCard> {
  bool _enrolling = false;

  Future<void> _enrollFree() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _enrolling = true);
    try {
      await ref.read(courseServiceProvider).enrollStudent(
            studentId: user.id,
            courseId: widget.courseId,
          );
      ref.invalidate(enrolledCoursesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now enrolled in ${widget.course.title}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enrollment failed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadows: AppShadows.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats chips ───────────────────────────
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (widget.course.totalLectures != null)
                _StatChip(
                  icon: Icons.play_lesson_outlined,
                  label: '${widget.course.totalLectures} Lectures',
                ),
              if (widget.course.totalStudents != null)
                _StatChip(
                  icon: Icons.people_outline_rounded,
                  label: '${widget.course.totalStudents} Students',
                ),
              if (widget.course.rating != null)
                _StatChip(
                  icon: Icons.star_rounded,
                  label: widget.course.rating!.toStringAsFixed(1),
                  iconColor: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── About section ─────────────────────────
          Text('About this Course', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.course.description,
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.65),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Progress bar ──────────────────────────
          if (widget.progress != null && widget.progress!.totalLectures > 0) ...[
            CourseProgressBar(
              percent: widget.progress!.percent,
              completedLectures: widget.progress!.completedLectures,
              totalLectures: widget.progress!.totalLectures,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Enroll / Continue CTA ─────────────────
          if (widget.isEnrolled)
            PrimaryButton(
              label: 'Continue Learning',
              icon: Icons.play_circle_outline_rounded,
              onTap: () => context.push(
                AppRoutes.lectureListPath(widget.courseId),
              ),
            )
          else if (widget.course.price == 0)
            PrimaryButton(
              label: _enrolling ? 'Enrolling...' : 'Enroll for FREE',
              icon: Icons.school_rounded,
              onTap: _enrolling ? null : _enrollFree,
            )
          else
            PrimaryButton(
              label: 'Enroll — ₹${widget.course.price.toStringAsFixed(0)}',
              icon: Icons.school_rounded,
              onTap: () => _showEnrollSheet(context, widget.course),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Enrollment enquiry bottom sheet
// ─────────────────────────────────────────────────────────────
void _showEnrollSheet(BuildContext context, CourseModel course) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Enroll in ${course.title}',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Text(
            course.price == 0
                ? 'This course is free. Contact us to get enrolled.'
                : 'Course fee: ₹${course.price.toStringAsFixed(0)}. Contact us to complete your enrollment.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _EnrollOption(
            icon: Icons.phone_rounded,
            label: 'Call Us',
            subtitle: '+91 62805 54348',
            onTap: () => launchUrl(Uri.parse('tel:+916280554348')),
          ),
          const SizedBox(height: 12),
          _EnrollOption(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'WhatsApp',
            subtitle: 'Chat with us instantly',
            onTap: () => launchUrl(
              Uri.parse(
                  'https://wa.me/916280554348?text=Hi%2C%20I%20want%20to%20enroll%20in%20${Uri.encodeComponent(course.title)}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 12),
          _EnrollOption(
            icon: Icons.email_outlined,
            label: 'Email Us',
            subtitle: 'support@tareshwartutorials.com',
            onTap: () => launchUrl(
              Uri.parse(
                  'mailto:support@tareshwartutorials.com?subject=Enrollment%20-%20${Uri.encodeComponent(course.title)}'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EnrollOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _EnrollOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  const _StatChip(
      {required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: iconColor ?? AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.folder_open_rounded,
      title: 'No content yet',
      subtitle: 'Course content will appear here once it is added.',
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: AppColors.background,
      body: AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: message,
        iconColor: AppColors.error,
      ),
    );
  }
}
