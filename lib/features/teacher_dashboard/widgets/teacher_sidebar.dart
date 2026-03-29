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

  static const _sidebarBg     = Color(0xFF1C1B2E);
  static const _activeBg      = Color(0xFF6C63FF);
  static const _inactiveColor = Color(0xFF9CA3AF);

  static const _navItems = <({TeacherSection section, IconData icon})>[
    (section: TeacherSection.overview,      icon: Icons.dashboard_rounded),
    (section: TeacherSection.myCourses,     icon: Icons.menu_book_rounded),
    (section: TeacherSection.batches,       icon: Icons.group_work_rounded),
    (section: TeacherSection.liveClasses,   icon: Icons.video_camera_front_rounded),
    (section: TeacherSection.uploadContent, icon: Icons.upload_file_rounded),
    (section: TeacherSection.createTest,    icon: Icons.quiz_rounded),
    (section: TeacherSection.studentDoubts, icon: Icons.chat_bubble_outline_rounded),
    (section: TeacherSection.analytics,     icon: Icons.bar_chart_rounded),
    (section: TeacherSection.settings,      icon: Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(teacherSelectedSectionProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: collapsed ? 68 : 240,
      decoration: const BoxDecoration(
        color: _sidebarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(3, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo / Brand + collapse toggle ───────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 14),
            child: Row(
              children: [
                if (collapsed)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_rounded,
                        size: 20, color: Colors.white),
                  )
                else
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: _inactiveColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),

          // ── Navigation items ─────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              children: _navItems.map((item) {
                final isActive = current == item.section;
                return _NavTile(
                  icon: item.icon,
                  label: item.section.label,
                  isActive: isActive,
                  collapsed: collapsed,
                  activeBg: _activeBg,
                  inactiveColor: _inactiveColor,
                  onTap: () {
                    ref
                        .read(teacherSelectedSectionProvider.notifier)
                        .state = item.section;
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // ── Bottom: user profile + logout ─────────────────
          _BottomUserTile(collapsed: collapsed),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Nav Tile ──────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool collapsed;
  final Color activeBg;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.collapsed,
    required this.activeBg,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 14 : 12, vertical: 11),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 20,
                    color: isActive ? Colors.white : inactiveColor),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? Colors.white : inactiveColor,
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

// ── Bottom user tile ──────────────────────────────────────────
class _BottomUserTile extends ConsumerWidget {
  final bool collapsed;
  const _BottomUserTile({required this.collapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox(height: 48),
      data: (user) {
        if (user == null) return const SizedBox(height: 48);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                child: Text(
                  user.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text('Teacher',
                          style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: Color(0xFF9CA3AF), size: 18),
                  tooltip: 'Logout',
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
