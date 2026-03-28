// ─────────────────────────────────────────────────────────────
//  admin_sidebar.dart  –  Collapsible sidebar for Admin Panel
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/services/auth_service.dart';
import '../providers/admin_providers.dart';

class AdminSidebar extends ConsumerWidget {
  final bool collapsed;
  final VoidCallback onToggle;

  const AdminSidebar({
    super.key,
    required this.collapsed,
    required this.onToggle,
  });

  static const _bg         = Color(0xFF0F0E1A);
  static const _activeBg   = Color(0xFF6C63FF);
  static const _inactiveClr = Color(0xFF9CA3AF);
  static const _width       = 240.0;
  static const _collapsedW  = 68.0;

  static const _navItems = <({AdminSection section, IconData icon})>[
    (section: AdminSection.dashboard,     icon: Icons.dashboard_rounded),
    (section: AdminSection.students,      icon: Icons.people_alt_rounded),
    (section: AdminSection.teachers,      icon: Icons.school_rounded),
    (section: AdminSection.courses,       icon: Icons.menu_book_rounded),
    (section: AdminSection.batches,       icon: Icons.group_work_rounded),
    (section: AdminSection.liveClasses,   icon: Icons.video_camera_front_rounded),
    (section: AdminSection.announcements, icon: Icons.campaign_rounded),
    (section: AdminSection.analytics,     icon: Icons.bar_chart_rounded),
    (section: AdminSection.settings,      icon: Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(adminSelectedSectionProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: collapsed ? _collapsedW : _width,
      decoration: const BoxDecoration(
        color: _bg,
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(3, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      size: 20, color: Colors.white),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Panel',
                            style: AppTextStyles.headlineSmall.copyWith(
                                color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        Text('Tareshwar Tutorials',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: _inactiveClr, fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
                // collapse toggle
                GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: _inactiveClr,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),

          // ── Nav items ─────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              children: [
                for (final item in _navItems)
                  _NavTile(
                    icon: item.icon,
                    label: item.section.label,
                    isActive: current == item.section,
                    collapsed: collapsed,
                    activeColor: _activeBg,
                    inactiveColor: _inactiveClr,
                    onTap: () {
                      ref
                          .read(adminSelectedSectionProvider.notifier)
                          .state = item.section;
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // ── Bottom: current user + logout ────────────────
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
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavTile({
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? activeColor : Colors.transparent,
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
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
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
      error: (err, stack) => const SizedBox(height: 48),
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
                      Text('Admin',
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
