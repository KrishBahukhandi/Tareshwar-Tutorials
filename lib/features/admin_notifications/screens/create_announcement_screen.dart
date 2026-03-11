// ─────────────────────────────────────────────────────────────
//  create_announcement_screen.dart
//  Admin: Full-page form to create a new announcement and
//  optionally send push notifications to target students.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/services/auth_service.dart';
import '../data/admin_notifications_service.dart';
import '../providers/admin_notifications_providers.dart';

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState
    extends ConsumerState<CreateAnnouncementScreen> {
  final _form      = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();

  bool    _platformWide    = true;
  String? _selectedBatchId;
  String? _selectedBatchName;
  int?    _targetAudience;   // resolved enrolled count
  bool    _sendPush        = true;
  bool    _submitting      = false;

  // live character counts
  int get _titleLen => _titleCtrl.text.length;
  int get _bodyLen  => _bodyCtrl.text.length;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _bodyCtrl.addListener(()  => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ── Audience count ─────────────────────────────────────────
  Future<void> _resolveAudience() async {
    if (_platformWide) {
      // Approximate total active students (no direct API call needed here)
      setState(() => _targetAudience = null);
      return;
    }
    if (_selectedBatchId == null) {
      setState(() => _targetAudience = null);
      return;
    }
    final count = await ref
        .read(adminNotificationsServiceProvider)
        .fetchEnrolledCount(_selectedBatchId!);
    if (mounted) setState(() => _targetAudience = count);
  }

  // ── Submit ─────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_platformWide && _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a batch')),
      );
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // Show confirmation with push preview
    final confirmed = await _showConfirmation();
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final row = await ref
          .read(createAnnouncementProvider.notifier)
          .create(
            authorId: user.id,
            title:    _titleCtrl.text.trim(),
            body:     _bodyCtrl.text.trim(),
            batchId:  _platformWide ? null : _selectedBatchId,
            sendPush: _sendPush,
          );

      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(
            _sendPush
                ? '✓ Announcement sent${row.isPlatformWide ? ' to all students' : ' to ${row.batchName ?? 'batch'}'}'
                : '✓ Announcement created (no push)',
          ),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context, true); // return true = created
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _submitting = false);
      }
    }
  }

  Future<bool> _showConfirmation() async {
    final target = _platformWide
        ? 'all active students (platform-wide)'
        : (_selectedBatchName != null
            ? '"$_selectedBatchName"'
            : 'selected batch');

    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.campaign_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Confirm Announcement'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConfirmRow(
                  label: 'Title',
                  value: _titleCtrl.text.trim(),
                ),
                const SizedBox(height: 6),
                _ConfirmRow(
                  label: 'Target',
                  value: target,
                ),
                if (_targetAudience != null) ...[
                  const SizedBox(height: 6),
                  _ConfirmRow(
                    label: 'Recipients',
                    value: '$_targetAudience students',
                  ),
                ],
                const SizedBox(height: 6),
                _ConfirmRow(
                  label: 'Push notification',
                  value: _sendPush ? 'Yes — will be sent' : 'No',
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Send')),
            ],
          ),
        ) ??
        false;
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(batchPickerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Announcement'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label:
                  Text(_submitting ? 'Sending…' : 'Send'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Section: Content ──────────────────────────
            _SectionHeader(
              icon: Icons.edit_note_rounded,
              title: 'Announcement Content',
            ),
            const SizedBox(height: 12),

            // Title
            TextFormField(
              controller: _titleCtrl,
              maxLength: 100,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Title *',
                hintText: 'Short, descriptive headline',
                prefixIcon:
                    const Icon(Icons.title_rounded),
                counterText: '$_titleLen / 100',
                counterStyle:
                    AppTextStyles.caption.copyWith(
                  color: _titleLen > 90
                      ? AppColors.warning
                      : AppColors.textHint,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : v.trim().length < 5
                          ? 'Title too short (min 5 chars)'
                          : null,
            ),
            const SizedBox(height: 16),

            // Body
            TextFormField(
              controller: _bodyCtrl,
              maxLength: 1000,
              maxLines: 6,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Message *',
                hintText:
                    'Write your announcement message here…',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 70),
                  child: Icon(Icons.message_rounded),
                ),
                alignLabelWithHint: true,
                counterText: '$_bodyLen / 1000',
                counterStyle:
                    AppTextStyles.caption.copyWith(
                  color: _bodyLen > 900
                      ? AppColors.warning
                      : AppColors.textHint,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Message is required'
                      : v.trim().length < 10
                          ? 'Message too short (min 10 chars)'
                          : null,
            ),
            const SizedBox(height: 24),

            // ── Section: Target ───────────────────────────
            _SectionHeader(
              icon: Icons.my_location_rounded,
              title: 'Target Audience',
            ),
            const SizedBox(height: 12),

            // Platform-wide / Batch toggle
            _TargetToggle(
              platformWide: _platformWide,
              onChanged: (v) {
                setState(() {
                  _platformWide    = v;
                  _selectedBatchId = null;
                  _selectedBatchName = null;
                  _targetAudience  = null;
                });
              },
            ),
            const SizedBox(height: 14),

            // Batch picker
            if (!_platformWide) ...[
              batchesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (_, _) => const Text(
                    'Could not load batches.',
                    style: TextStyle(color: AppColors.error)),
                data: (batches) {
                  if (batches.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warning
                                .withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning),
                          const SizedBox(width: 8),
                          Text('No active batches found.',
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedBatchId,
                    decoration: const InputDecoration(
                      labelText: 'Select Batch *',
                      prefixIcon: Icon(Icons.groups_rounded),
                    ),
                    isExpanded: true,
                    items: batches
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(b.batchName,
                                      style:
                                          AppTextStyles.labelLarge,
                                      overflow:
                                          TextOverflow.ellipsis),
                                  Text(
                                    '${b.courseTitle} · '
                                    '${b.enrolledCount} students',
                                    style: AppTextStyles.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      final batch = batches
                          .firstWhere((b) => b.id == v);
                      setState(() {
                        _selectedBatchId   = v;
                        _selectedBatchName = batch.batchName;
                        _targetAudience =
                            batch.enrolledCount;
                      });
                      _resolveAudience();
                    },
                    validator: (v) =>
                        (!_platformWide && v == null)
                            ? 'Please select a batch'
                            : null,
                  );
                },
              ),
              const SizedBox(height: 14),
            ],

            // Audience preview chip
            if (!_platformWide && _targetAudience != null)
              _AudiencePreview(count: _targetAudience!),

            if (_platformWide)
              _AudiencePreviewWide(),

            const SizedBox(height: 24),

            // ── Section: Push Notification ────────────────
            _SectionHeader(
              icon: Icons.notifications_active_rounded,
              title: 'Push Notification',
            ),
            const SizedBox(height: 10),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: SwitchListTile(
                title: Text('Send Push Notification',
                    style: AppTextStyles.labelLarge),
                subtitle: Text(
                  _sendPush
                      ? 'Students will receive an in-app notification'
                      : 'Announcement created but no push sent',
                  style: AppTextStyles.bodySmall,
                ),
                secondary: Icon(
                  _sendPush
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: _sendPush
                      ? AppColors.primary
                      : AppColors.textHint,
                ),
                value: _sendPush,
                activeThumbColor: AppColors.primary,
                onChanged: (v) =>
                    setState(() => _sendPush = v),
              ),
            ),

            // Push preview box
            if (_sendPush) ...[
              const SizedBox(height: 12),
              _PushPreview(
                title: _titleCtrl.text.trim().isNotEmpty
                    ? _titleCtrl.text.trim()
                    : 'Your Title',
                body: _bodyCtrl.text.trim().isNotEmpty
                    ? _bodyCtrl.text.trim()
                    : 'Your announcement message…',
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.headlineSmall),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _TargetToggle extends StatelessWidget {
  final bool     platformWide;
  final void Function(bool) onChanged;
  const _TargetToggle(
      {required this.platformWide, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleCard(
            label: 'All Students',
            subtitle: 'Platform-wide broadcast',
            icon: Icons.public_rounded,
            selected: platformWide,
            color: AppColors.primary,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleCard(
            label: 'Specific Batch',
            subtitle: 'Target one batch only',
            icon: Icons.groups_rounded,
            selected: !platformWide,
            color: AppColors.secondary,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String   label;
  final String   subtitle;
  final IconData icon;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _ToggleCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? color : AppColors.textHint,
                size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.labelLarge.copyWith(
                    color: selected
                        ? color
                        : AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _AudiencePreview extends StatelessWidget {
  final int count;
  const _AudiencePreview({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded,
              color: AppColors.secondary, size: 18),
          const SizedBox(width: 8),
          Text(
            '$count student${count == 1 ? '' : 's'} will receive this',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _AudiencePreviewWide extends StatelessWidget {
  const _AudiencePreviewWide();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.public_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            'All active students will receive this',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Push notification preview card
// ─────────────────────────────────────────────────────────────
class _PushPreview extends StatelessWidget {
  final String title;
  final String body;
  const _PushPreview({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.smartphone_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('Push Preview',
                style: AppTextStyles.labelMedium),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Tareshwar Tutorials',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: Colors.white70)),
                        const Spacer(),
                        Text('now',
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white38)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text('$label:',
              style: AppTextStyles.labelMedium),
        ),
        Expanded(
          child: Text(value,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
