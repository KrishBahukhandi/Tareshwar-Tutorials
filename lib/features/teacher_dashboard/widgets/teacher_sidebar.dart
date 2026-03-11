// ─────────────────────────────────────────────────────────────
//  teacher_sidebar.dart
//  Collapsible sidebar for the Teacher Dashboard.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/services/auth_service.dart';
import '../providers/teacher_dashboard_providers.dart';

class TeacherSidebar extends ConsumerWidget {
  final bool collapsed;
  final VoidCallback onToggle;

  const TeacherSidebar({
    super.key,
    required this.collapsed,
    required this.onToggle,
  });

  static const _sidebarBg = Color(0xFF1C1B2E);
  static const _activeColor = AppColors.primary;
  static const _inactiveColor = Color(0xFF9CA3AF);

  static const _navItems = <({TeacherSection section, IconData icon})>[
    (section: TeacherSection.overview, icon: Icons.dashboard_rounded),
    (section: TeacherSection.myCourses, icon: Icons.menu_book_rounded),
    (section: TeacherSection.batches, icon: Icons.group_work_rounded),
    (section: TeacherSection.liveClasses, icon: Icons.video_camera_front_rounded),
    (section: TeacherSection.uploadContent, icon: Icons.upload_file_rounded),
    (section: TeacherSection.createTest, icon: Icons.quiz_rounded),
    (section: TeacherSection.studentDoubts, icon: Icons.chat_bubble_outline_rounded),
    (section: TeacherSection.analytics, icon: Icons.bar_chart_rounded),
    (section: TeacherSection.settings, icon: Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(teacherSelectedSectionProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: collapsed ? 64 : 240,
      decoration: const BoxDecoration(
        color: _sidebarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo / Brand ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded,
                      size: 20, color: Colors.white),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Teacher Panel',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // ── Navigation items ─────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: _navItems.map((item) {
                final isActive = current == item.section;
                return _NavItem(
                  icon: item.icon,
                  label: item.section.label,
                  isActive: isActive,
                  collapsed: collapsed,
                  activeColor: _activeColor,
                  inactiveColor: _inactiveColor,
                  onTap: () {
                    ref
                        .read(teacherSelectedSectionProvider.notifier)
                        .state = item.section;
                    // Close drawer on mobile
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── Logout ───────────────────────────────────────
          _NavItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            isActive: false,
            collapsed: collapsed,
            activeColor: _activeColor,
            inactiveColor: _inactiveColor,
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),

          const SizedBox(height: 8),

          // ── Collapse toggle (desktop only) ───────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  color: _inactiveColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool collapsed;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.collapsed,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive
            ? activeColor.withAlpha(30)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 10 : 12,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? activeColor : inactiveColor,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isActive ? activeColor : inactiveColor,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
