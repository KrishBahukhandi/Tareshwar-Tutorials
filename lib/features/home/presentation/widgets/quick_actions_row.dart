// ─────────────────────────────────────────────────────────────
//  quick_actions_row.dart  –  Tappable action shortcuts grid.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

class QuickActionsRow extends StatelessWidget {
  final List<QuickAction> actions;
  const QuickActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actions
          .expand((a) => [
                Expanded(child: _ActionTile(action: a)),
                if (a != actions.last) const SizedBox(width: AppSpacing.xs),
              ])
          .toList(),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _ActionTile extends StatefulWidget {
  final QuickAction action;
  const _ActionTile({required this.action});

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        a.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: isDark
                ? a.color.withValues(alpha: 0.14)
                : a.color.withValues(alpha: 0.08),
            borderRadius: AppRadius.mdAll,
            border: Border.all(
                color: a.color.withValues(alpha: isDark ? 0.25 : 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                a.label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: a.color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
