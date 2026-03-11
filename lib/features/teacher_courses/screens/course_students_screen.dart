// ─────────────────────────────────────────────────────────────
//  course_students_screen.dart
//  Lists all students enrolled in a given course (via batches).
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/teacher_course_repository.dart';
import '../providers/teacher_course_providers.dart';

class CourseStudentsScreen extends ConsumerWidget {
  final String courseId;
  final String courseTitle;

  const CourseStudentsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync =
        ref.watch(enrolledStudentsProvider(courseId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enrolled Students',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text(courseTitle,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white),
            onPressed: () =>
                ref.invalidate(enrolledStudentsProvider(courseId)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
            error: '$e',
            onRetry: () =>
                ref.invalidate(enrolledStudentsProvider(courseId))),
        data: (students) => students.isEmpty
            ? _EmptyState(courseTitle: courseTitle)
            : _StudentList(students: students),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Student list
// ─────────────────────────────────────────────────────────────
class _StudentList extends StatelessWidget {
  final List<EnrolledStudentInfo> students;
  const _StudentList({required this.students});

  @override
  Widget build(BuildContext context) {
    // Group by batch
    final batches = <String, List<EnrolledStudentInfo>>{};
    for (final s in students) {
      batches.putIfAbsent(s.batchName, () => []).add(s);
    }

    return Column(
      children: [
        // ── Summary bar ─────────────────────────────
        _SummaryBar(total: students.length, batches: batches.length),

        // ── List ─────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (ctx, i) {
              final batchName = batches.keys.elementAt(i);
              final batchStudents = batches[batchName]!;
              return _BatchSection(
                batchName: batchName,
                students: batchStudents,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int total;
  final int batches;
  const _SummaryBar({required this.total, required this.batches});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            _SumCard(
                icon: Icons.people_rounded,
                label: 'Total Students',
                value: '$total',
                color: AppColors.primary),
            const SizedBox(width: 16),
            _SumCard(
                icon: Icons.group_work_rounded,
                label: 'Batches',
                value: '$batches',
                color: AppColors.secondary),
          ],
        ),
      );
}

class _SumCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SumCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      );
}

class _BatchSection extends StatelessWidget {
  final String batchName;
  final List<EnrolledStudentInfo> students;
  const _BatchSection(
      {required this.batchName, required this.students});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 16),
            child: Row(
              children: [
                const Icon(Icons.group_work_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  batchName.isEmpty ? 'Default Batch' : batchName,
                  style: AppTextStyles.headlineSmall.copyWith(
                      fontSize: 13,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text('(${students.length})',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12)),
              ],
            ),
          ),
          ...students.map((s) => _StudentTile(student: s)),
        ],
      );
}

class _StudentTile extends StatelessWidget {
  final EnrolledStudentInfo student;
  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withAlpha(25),
              backgroundImage: student.avatarUrl != null
                  ? NetworkImage(student.avatarUrl!)
                  : null,
              child: student.avatarUrl == null
                  ? Text(
                      student.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      style: AppTextStyles.headlineSmall
                          .copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(student.email,
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),

            // Enrolment date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Enrolled',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM y').format(student.enrolledAt),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  States
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String courseTitle;
  const _EmptyState({required this.courseTitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded,
                size: 72, color: AppColors.border),
            const SizedBox(height: 16),
            Text('No students yet',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text('No one is enrolled in "$courseTitle" yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry')),
          ],
        ),
      );
}
