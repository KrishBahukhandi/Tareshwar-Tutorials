// ─────────────────────────────────────────────────────────────
//  app_scaffold.dart  –  Student app shell with 6-tab
//  BottomNavigationBar powered by GoRouter + Riverpod.
//
//  Tabs:   0 Home  |  1 Search  |  2 My Courses  |  3 Tests  |  4 Downloads  |  5 Profile
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../../shared/services/app_providers.dart';
import 'app_router.dart';

/// Calculates the active tab index from the current router location.
int studentTabIndex(String location) {
  if (location.startsWith(AppRoutes.search)) return 1;
  if (location.startsWith(AppRoutes.myCourses)) return 2;
  if (location.startsWith(AppRoutes.testsTab)) return 3;
  if (location.startsWith(AppRoutes.downloads)) return 4;
  if (location.startsWith(AppRoutes.profile)) return 5;
  // Default → Home (covers /student/home and legacy /student)
  return 0;
}

// ─────────────────────────────────────────────────────────────
class AppScaffold extends ConsumerWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  // Routes where the bottom nav should be hidden.
  static const _hideNavContains = [
    '/student/lecture/',
    '/student/test/',
  ];
  static const _neverHideSuffixes = ['result'];

  bool _shouldHideNav(String location) {
    for (final fragment in _hideNavContains) {
      if (location.contains(fragment)) {
        if (_neverHideSuffixes.any(location.contains)) return false;
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = studentTabIndex(location);
    final hideNav = _shouldHideNav(location);

    // Keep Riverpod provider in sync with the router location.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(studentNavIndexProvider) != currentIndex) {
        ref.read(studentNavIndexProvider.notifier).state = currentIndex;
      }
    });

    return Scaffold(
      body: child,
      bottomNavigationBar:
          hideNav ? null : _StudentNavBar(currentIndex: currentIndex),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _StudentNavBar
// ─────────────────────────────────────────────────────────────
class _StudentNavBar extends StatelessWidget {
  final int currentIndex;
  const _StudentNavBar({required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.homeTab);
      case 1:
        context.go(AppRoutes.search);
      case 2:
        context.go(AppRoutes.myCourses);
      case 3:
        context.go(AppRoutes.testsTab);
      case 4:
        context.go(AppRoutes.downloads);
      case 5:
        context.go(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _onTap(context, i),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search_rounded, color: AppColors.primary),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(Icons.library_books_outlined),
          selectedIcon:
              Icon(Icons.library_books_rounded, color: AppColors.primary),
          label: 'My Courses',
        ),
        NavigationDestination(
          icon: Icon(Icons.quiz_outlined),
          selectedIcon: Icon(Icons.quiz_rounded, color: AppColors.primary),
          label: 'Tests',
        ),
        NavigationDestination(
          icon: Icon(Icons.download_for_offline_outlined),
          selectedIcon: Icon(Icons.download_for_offline_rounded,
              color: AppColors.primary),
          label: 'Downloads',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
          label: 'Profile',
        ),
      ],
    );
  }
}
