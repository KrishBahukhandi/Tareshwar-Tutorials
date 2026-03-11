// ─────────────────────────────────────────────────────────────
//  admin_settings_screen.dart  –  Platform settings
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../admin_auth/providers/admin_auth_provider.dart';
import '../widgets/admin_top_bar.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: AppTextStyles.displaySmall),
            const SizedBox(height: 4),
            Text('Manage your platform and account settings.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 28),

            // ── Profile card ──────────────────────────────
            AdminTableCard(
              title: 'Admin Profile',
              child: userAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Error: $e'),
                ),
                data: (user) => user == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : 'A',
                                style: AppTextStyles.displaySmall
                                    .copyWith(color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(user.name,
                                    style:
                                        AppTextStyles.headlineMedium),
                                const SizedBox(height: 4),
                                Text(user.email,
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(
                                            color: AppColors
                                                .textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text('Admin',
                                      style: AppTextStyles.labelSmall
                                          .copyWith(
                                              color:
                                                  AppColors.primary)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Platform settings ──────────────────────────
            AdminTableCard(
              title: 'Platform Settings',
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.school_rounded,
                    title: 'Platform Name',
                    subtitle: 'Tareshwar Tutorials',
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    title: 'Default Language',
                    subtitle: 'English',
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _SettingsTile(
                    icon: Icons.currency_rupee_rounded,
                    title: 'Currency',
                    subtitle: 'INR (₹)',
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _SettingsTile(
                    icon: Icons.notifications_rounded,
                    title: 'Push Notifications',
                    subtitle: 'Enabled for all users',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Security ───────────────────────────────────
            AdminTableCard(
              title: 'Security',
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle: 'Update your admin password',
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _SettingsTile(
                    icon: Icons.security_rounded,
                    title: 'Two-Factor Authentication',
                    subtitle: 'Not configured',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Danger zone ────────────────────────────────
            AdminTableCard(
              title: 'Danger Zone',
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: AppColors.error),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sign Out',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: AppColors.error)),
                        Text('Sign out of the admin panel',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                    const Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.error)),
                      onPressed: () async {
                        await ref
                            .read(adminAuthProvider.notifier)
                            .signOut();
                        if (context.mounted) {
                          context.go(AppRoutes.adminLogin);
                        }
                      },
                      child: const Text('Sign Out',
                          style:
                              TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(title, style: AppTextStyles.labelLarge),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint),
      onTap: onTap,
    );
  }
}
