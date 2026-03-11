// ─────────────────────────────────────────────────────────────
//  admin_shell.dart  –  Root responsive shell for Admin Panel
//
//  Desktop (≥ 1024px):  Sidebar + Content side-by-side
//  Tablet  (≥ 600px):   Collapsed sidebar + Content
//  Mobile  (< 600px):   Drawer + AppBar
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_top_bar.dart';
import 'admin_overview_screen.dart';
import '../../../../features/admin_users/screens/admin_students_screen.dart'
    as admin_users show AdminStudentsScreen;
import '../../../../features/admin_users/screens/admin_teachers_screen.dart'
    as admin_users_teachers show AdminTeachersScreen;
import '../../../../features/admin_courses/screens/admin_course_list_screen.dart';
import '../../../../features/admin_batches/screens/batch_list_screen.dart';
import '../../../../features/admin_payments/screens/payments_dashboard_screen.dart';
import '../../../../features/admin_notifications/screens/announcement_list_screen.dart';
import 'admin_settings_screen.dart';
import '../../../../features/admin_analytics/screens/admin_analytics_screen.dart'
    as new_analytics;
import 'admin_live_classes_screen.dart';

// ─────────────────────────────────────────────────────────────
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;
    final isTablet = w >= 600 && w < 1024;
    final collapsed = ref.watch(adminSidebarCollapsedProvider);

    // Auto-collapse on tablet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isTablet && !collapsed) {
        ref.read(adminSidebarCollapsedProvider.notifier).state = true;
      }
    });

    if (isMobile) {
      return _MobileShell(scaffoldKey: _scaffoldKey);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      body: Row(
        children: [
          AdminSidebar(
            collapsed: collapsed,
            onToggle: () => ref
                .read(adminSidebarCollapsedProvider.notifier)
                .state = !collapsed,
          ),
          Expanded(
            child: Column(
              children: [
                const AdminTopBar(),
                const Expanded(child: _AdminContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile layout ─────────────────────────────────────────────
class _MobileShell extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const _MobileShell({required this.scaffoldKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(adminSelectedSectionProvider);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E1A),
        foregroundColor: Colors.white,
        title: Text(section.label,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: Drawer(
        child: AdminSidebar(
          collapsed: false,
          onToggle: () => Navigator.pop(context),
        ),
      ),
      body: const _AdminContent(),
    );
  }
}

// ── Content switcher ──────────────────────────────────────────
class _AdminContent extends ConsumerWidget {
  const _AdminContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(adminSelectedSectionProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey(section),
        child: _screenFor(section),
      ),
    );
  }

  Widget _screenFor(AdminSection s) {
    switch (s) {
      case AdminSection.dashboard:      return const AdminOverviewScreen();
      case AdminSection.students:       return const admin_users.AdminStudentsScreen();
      case AdminSection.teachers:       return const admin_users_teachers.AdminTeachersScreen();
      case AdminSection.courses:        return const AdminCourseListScreen();
      case AdminSection.batches:        return const BatchListScreen();
      case AdminSection.liveClasses:    return const AdminLiveClassesScreen();
      case AdminSection.payments:       return const PaymentsDashboardScreen();
      case AdminSection.announcements:  return const AnnouncementListScreen();
      case AdminSection.analytics:      return const new_analytics.AdminAnalyticsDashboardScreen();
      case AdminSection.settings:       return const AdminSettingsScreen();
    }
  }
}
