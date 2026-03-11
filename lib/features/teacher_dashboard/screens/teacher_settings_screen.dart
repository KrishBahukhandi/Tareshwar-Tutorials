// ─────────────────────────────────────────────────────────────
//  teacher_settings_screen.dart  –  Profile + account settings
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../features/teacher_auth/providers/teacher_auth_provider.dart';
import '../../../shared/services/auth_service.dart';

class TeacherSettingsScreen extends ConsumerStatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  ConsumerState<TeacherSettingsScreen> createState() =>
      _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState
    extends ConsumerState<TeacherSettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text =
        ref.read(teacherUserProvider)?.name ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teacher = ref.watch(teacherUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: AppTextStyles.displaySmall),
            const SizedBox(height: 4),
            Text(
              'Update your profile and account preferences.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),

            // ── Profile card ────────────────────────────
            _Card(
              title: 'Profile',
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          teacher?.initials ?? 'T',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacher?.displayName ?? 'Teacher',
                              style: AppTextStyles.headlineMedium,
                            ),
                            Text(teacher?.email ?? '',
                                style: AppTextStyles.bodySmall),
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.10),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Teacher',
                                style: AppTextStyles.labelSmall
                                    .copyWith(
                                        color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon:
                          Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  if (_saved) ...[
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 16),
                        SizedBox(width: 6),
                        Text('Profile updated!',
                            style: TextStyle(
                                color: AppColors.success)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Account card ────────────────────────────
            _Card(
              title: 'Account',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_reset_rounded,
                        color: AppColors.warning),
                    title: Text('Change Password',
                        style: AppTextStyles.labelLarge),
                    subtitle: Text('Send a password reset link',
                        style: AppTextStyles.bodySmall),
                    trailing: OutlinedButton(
                      onPressed: _sendReset,
                      child: const Text('Send Reset Email'),
                    ),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded,
                        color: AppColors.error),
                    title: Text('Sign Out',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.error)),
                    subtitle: const Text('Log out of all sessions'),
                    trailing: OutlinedButton(
                      onPressed: () => ref
                          .read(teacherAuthProvider.notifier)
                          .signOut(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                            color: AppColors.error),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final uid =
        ref.read(authServiceProvider).currentAuthUser?.id;
    if (uid == null) return;
    try {
      await ref.read(authServiceProvider).updateProfile(
            userId: uid,
            name: _nameCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _saved = true);
      Future.delayed(
        const Duration(seconds: 2),
        () { if (mounted) setState(() => _saved = false); },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sendReset() async {
    final email = ref.read(teacherUserProvider)?.email;
    if (email == null) return;
    try {
      await ref.read(authServiceProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset link sent to your email.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}
