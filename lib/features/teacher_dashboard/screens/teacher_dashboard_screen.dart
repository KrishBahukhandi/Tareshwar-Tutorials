// ─────────────────────────────────────────────────────────────
//  teacher_dashboard_screen.dart
//  Root shell for the Teacher Web Dashboard.
//
//  Layout (desktop):
//    ┌──────────────────────────────────────────────────────┐
//    │  [Sidebar 240px]  │  [Scrollable Content Area]       │
//    └──────────────────────────────────────────────────────┘
//  On mobile (width < 640) sidebar becomes a Drawer.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/teacher_dashboard_providers.dart';
import '../widgets/teacher_sidebar.dart';
import 'teacher_overview_screen.dart';
import 'teacher_courses_screen.dart';
import '../../teacher_analytics/screens/teacher_analytics_screen.dart'
    as full_analytics;
import 'teacher_doubts_screen.dart';
import 'teacher_upload_screen.dart';
import 'teacher_create_test_screen.dart';
import 'teacher_settings_screen.dart';
import '../../live_classes/screens/teacher_live_classes_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Sidebar collapse state
// ─────────────────────────────────────────────────────────────
final _sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

// ─────────────────────────────────────────────────────────────
class TeacherDashboardShell extends ConsumerStatefulWidget {
  const TeacherDashboardShell({super.key});

  @override
  ConsumerState<TeacherDashboardShell> createState() =>
      _TeacherDashboardShellState();
}

class _TeacherDashboardShellState
    extends ConsumerState<TeacherDashboardShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(teacherSelectedSectionProvider);
    final collapsed = ref.watch(_sidebarCollapsedProvider);
    final isMobile = MediaQuery.of(context).size.width < 640;

    if (isMobile) {
      return _MobileLayout(
        scaffoldKey: _scaffoldKey,
        section: section,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FB),
      body: Row(
        children: [
          TeacherSidebar(
            collapsed: collapsed,
            onToggle: () => ref
                .read(_sidebarCollapsedProvider.notifier)
                .state = !collapsed,
          ),
          Expanded(
            child: _ContentArea(section: section),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Mobile layout – Drawer + AppBar
// ─────────────────────────────────────────────────────────────
class _MobileLayout extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final TeacherSection section;

  const _MobileLayout({
    required this.scaffoldKey,
    required this.section,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF3F4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B2E),
        foregroundColor: Colors.white,
        title: Text(
          section.label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: Drawer(
        child: TeacherSidebar(
          collapsed: false,
          onToggle: () => Navigator.pop(context),
        ),
      ),
      body: _ContentArea(section: section),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Content area – animated section switcher
// ─────────────────────────────────────────────────────────────
class _ContentArea extends StatelessWidget {
  final TeacherSection section;
  const _ContentArea({required this.section});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(section),
        child: _screenFor(section),
      ),
    );
  }

  Widget _screenFor(TeacherSection s) {
    switch (s) {
      case TeacherSection.overview:
        return const TeacherOverviewScreen();
      case TeacherSection.myCourses:
        return const TeacherCoursesScreen();
      case TeacherSection.liveClasses:
        return const TeacherLiveClassesScreen();
      case TeacherSection.uploadContent:
        return const TeacherUploadScreen();
      case TeacherSection.createTest:
        return const TeacherCreateTestScreen();
      case TeacherSection.studentDoubts:
        return const TeacherDoubtsScreen();
      case TeacherSection.analytics:
        return const full_analytics.TeacherAnalyticsScreen();
      case TeacherSection.settings:
        return const TeacherSettingsScreen();
    }
  }
}
