// ─────────────────────────────────────────────────────────────
//  admin_notifications_widgets.dart
//  Shared widgets for the Admin Announcement module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/admin_notifications_providers.dart';

// ─────────────────────────────────────────────────────────────
//  Stat card
// ─────────────────────────────────────────────────────────────
class AnnouncementStatCard extends StatelessWidget {
  final String    label;
  final String    value;
  final IconData  icon;
  final Color     color;
  final Color?    bgColor;

  const AnnouncementStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTextStyles.headlineMedium
                        .copyWith(color: color, fontSize: 20)),
                const SizedBox(height: 2),
                Text(label,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stats row (uses the AnnouncementStats object)
// ─────────────────────────────────────────────────────────────
class AnnouncementStatsRow extends StatelessWidget {
  final AnnouncementStats stats;
  const AnnouncementStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        AnnouncementStatCard(
          label: 'Total Announcements',
          value: '${stats.totalCount}',
          icon:  Icons.campaign_rounded,
          color: AppColors.primary,
        ),
        AnnouncementStatCard(
          label: 'Platform-wide',
          value: '${stats.platformWideCount}',
          icon:  Icons.public_rounded,
          color: AppColors.info,
        ),
        AnnouncementStatCard(
          label: 'Batch Targeted',
          value: '${stats.batchTargetedCount}',
          icon:  Icons.groups_rounded,
          color: AppColors.secondary,
        ),
        AnnouncementStatCard(
          label: 'Push Sent',
          value: '${stats.pushSentCount}',
          icon:  Icons.notifications_active_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Announcement card
// ─────────────────────────────────────────────────────────────
class AnnouncementCard extends StatelessWidget {
  final AnnouncementRow announcement;
  final VoidCallback?   onDelete;
  final VoidCallback?   onResendPush;
  final VoidCallback?   onTap;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onDelete,
    this.onResendPush,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = announcement.isPlatformWide;
    final accentColor = isWide ? AppColors.primary : AppColors.secondary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      isWide
                          ? Icons.campaign_rounded
                          : Icons.groups_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement.title,
                          style: AppTextStyles.labelLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Chip(
                              label: isWide
                                  ? 'Platform-wide'
                                  : announcement.batchName ?? 'Batch',
                              color: accentColor,
                              icon: isWide
                                  ? Icons.public_rounded
                                  : Icons.groups_rounded,
                            ),
                            if (announcement.pushSent)
                              _Chip(
                                label: 'Push sent',
                                color: AppColors.success,
                                icon: Icons.notifications_active_rounded,
                              ),
                            _Chip(
                              label: _formatDate(announcement.createdAt),
                              color: AppColors.textHint,
                              icon: Icons.access_time_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Actions menu
                  PopupMenuButton<_Action>(
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 20, color: AppColors.textSecondary),
                    onSelected: (action) {
                      switch (action) {
                        case _Action.delete:
                          onDelete?.call();
                        case _Action.resendPush:
                          onResendPush?.call();
                      }
                    },
                    itemBuilder: (_) => [
                      if (!announcement.pushSent)
                        const PopupMenuItem(
                          value: _Action.resendPush,
                          child: ListTile(
                            leading: Icon(Icons.notifications_active_rounded,
                                color: AppColors.info),
                            title: Text('Send Push'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      if (announcement.pushSent)
                        const PopupMenuItem(
                          value: _Action.resendPush,
                          child: ListTile(
                            leading: Icon(Icons.refresh_rounded,
                                color: AppColors.warning),
                            title: Text('Resend Push'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      const PopupMenuItem(
                        value: _Action.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded,
                              color: AppColors.error),
                          title: Text('Delete',
                              style:
                                  TextStyle(color: AppColors.error)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                announcement.body,
                style: AppTextStyles.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'By ${announcement.authorName}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

enum _Action { delete, resendPush }

// ─────────────────────────────────────────────────────────────
//  Small chip
// ─────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;

  const _Chip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────
class AnnouncementEmptyState extends StatelessWidget {
  final String    message;
  final String?   subtitle;
  final VoidCallback? onAction;
  final String?   actionLabel;

  const AnnouncementEmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.onAction,
    this.actionLabel,
  });

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
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(message, style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Search bar
// ─────────────────────────────────────────────────────────────
class AnnouncementSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>  onChanged;

  const AnnouncementSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search announcements…',
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textSecondary),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Filter chip row
// ─────────────────────────────────────────────────────────────
class AnnouncementFilterChips extends StatelessWidget {
  final bool?           platformWideOnly;
  final ValueChanged<bool?> onChanged;

  const AnnouncementFilterChips({
    super.key,
    required this.platformWideOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: platformWideOnly == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Platform-wide',
            selected: platformWideOnly == true,
            onTap: () => onChanged(true),
            icon: Icons.public_rounded,
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Batch',
            selected: platformWideOnly == false,
            onTap: () => onChanged(false),
            icon: Icons.groups_rounded,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String    label;
  final bool      selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color?    color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14,
                  color: selected ? c : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? c : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Announcement detail bottom sheet
// ─────────────────────────────────────────────────────────────
class AnnouncementDetailSheet extends StatelessWidget {
  final AnnouncementRow announcement;
  const AnnouncementDetailSheet({super.key, required this.announcement});

  static void show(BuildContext context, AnnouncementRow a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AnnouncementDetailSheet(announcement: a),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide  = announcement.isPlatformWide;
    final accent  = isWide ? AppColors.primary : AppColors.secondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isWide
                            ? Icons.campaign_rounded
                            : Icons.groups_rounded,
                        color: accent, size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(announcement.title,
                              style: AppTextStyles.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            isWide
                                ? 'Platform-wide'
                                : announcement.batchName ?? 'Batch',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: accent),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(announcement.body,
                    style: AppTextStyles.bodyLarge
                        .copyWith(height: 1.6)),
                const SizedBox(height: 20),
                // Meta
                _MetaRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Posted by',
                  value: announcement.authorName,
                ),
                const SizedBox(height: 8),
                _MetaRow(
                  icon: Icons.access_time_rounded,
                  label: 'Date',
                  value: _fullDate(announcement.createdAt),
                ),
                const SizedBox(height: 8),
                _MetaRow(
                  icon: Icons.notifications_active_rounded,
                  label: 'Push notification',
                  value: announcement.pushSent ? 'Sent ✓' : 'Not sent',
                  valueColor: announcement.pushSent
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fullDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: AppTextStyles.labelMedium),
        Expanded(
          child: Text(value,
              style: AppTextStyles.bodySmall.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
