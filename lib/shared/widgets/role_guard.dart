// ─────────────────────────────────────────────────────────────
//  role_guard.dart  –  Widget-level role-based access control
//
//  Usage:
//    RoleGuard(
//      allowedRoles: ['admin', 'teacher'],
//      child: AdminOnlyWidget(),
//    )
//
//  If the current user's role is not in allowedRoles, a
//  permission-denied placeholder is shown instead.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
class RoleGuard extends ConsumerWidget {
  /// Roles that are allowed to see [child].
  final List<String> allowedRoles;

  /// Widget to display when the user has the required role.
  final Widget child;

  /// Optional: custom widget when access is denied.
  final Widget? deniedWidget;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.deniedWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => deniedWidget ?? const _AccessDenied(),
      data: (user) {
        if (user == null || !allowedRoles.contains(user.role)) {
          return deniedWidget ?? const _AccessDenied();
        }
        return child;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Inline role-guard — wraps any widget conditionally.
//  Use this for hiding buttons / menu items, not full screens.
// ─────────────────────────────────────────────────────────────
class RoleVisible extends ConsumerWidget {
  final List<String> allowedRoles;
  final Widget child;

  const RoleVisible({
    super.key,
    required this.allowedRoles,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (user) {
        if (user == null || !allowedRoles.contains(user.role)) {
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Default access denied placeholder
// ─────────────────────────────────────────────────────────────
class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Access Denied',
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 10),
            Text(
              'You don\'t have permission to view this content.\n'
              'Please contact your administrator.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
