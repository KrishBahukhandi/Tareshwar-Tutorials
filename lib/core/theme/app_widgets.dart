// ─────────────────────────────────────────────────────────────
//  app_widgets.dart  –  Design-system reusable widgets
//
//  Exports:
//    AppCard           – surface card with shadow + border
//    PrimaryButton     – full-width gradient CTA button
//    SecondaryButton   – outlined variant
//    GhostButton       – text-only
//    AppBadge          – small coloured label chip
//    AppTag            – rounded pill chip
//    AppDivider        – styled horizontal rule
//    AppEmptyState     – centered empty / error illustration
//    AppLoadingOverlay – translucent spinner overlay
//    SectionHeader     – title row with optional action
//    AppProgressBar    – branded linear progress bar
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

// ══════════════════════════════════════════════════════════════
//  AppCard
// ══════════════════════════════════════════════════════════════
/// A surface card with Material 3 soft elevation, consistent
/// border-radius and optional gradient overlay.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final BorderRadius? radius;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final bool hasBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.radius,
    this.shadows,
    this.onTap,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ??
        (isDark ? AppColors.cardBackgroundDark : AppColors.surface);
    final effectiveRadius = radius ?? AppRadius.lgAll;

    Widget body = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: effectiveRadius,
        border: hasBorder
            ? Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : AppColors.border.withValues(alpha: 0.6),
              )
            : null,
        boxShadow: shadows ?? AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      body = GestureDetector(onTap: onTap, child: body);
    }
    return body;
  }
}

// ══════════════════════════════════════════════════════════════
//  PrimaryButton
// ══════════════════════════════════════════════════════════════
/// Full-width (or fixed-width) gradient CTA button with
/// loading state and disabled state baked in.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || loading;

    Widget child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.labelLarge
                    .copyWith(color: Colors.white, letterSpacing: 0.2),
              ),
            ],
          );

    return AnimatedOpacity(
      opacity: disabled ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          height: height ?? 50,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : AppColors.primaryGradient,
            color: disabled ? AppColors.primary.withValues(alpha: 0.5) : null,
            borderRadius: AppRadius.mdAll,
            boxShadow: disabled ? null : AppShadows.glow(AppColors.primary),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SecondaryButton
// ══════════════════════════════════════════════════════════════
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final Color? color;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final disabled = onTap == null || loading;

    return AnimatedOpacity(
      opacity: disabled ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: c),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: c),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: AppTextStyles.labelLarge.copyWith(color: c),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  GhostButton
// ══════════════════════════════════════════════════════════════
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  const GhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: c),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(color: c),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AppBadge
// ══════════════════════════════════════════════════════════════
/// Small coloured label – e.g. "FREE", "NEW", "LIVE"
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 10,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontSize: fontSize,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AppTag  (pill chip)
// ══════════════════════════════════════════════════════════════
class AppTag extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const AppTag({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : c.withValues(alpha: 0.08),
          borderRadius: AppRadius.circle,
          border: Border.all(
              color: selected
                  ? c
                  : c.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12,
                  color: selected ? Colors.white : c),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? Colors.white : c,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AppDivider
// ══════════════════════════════════════════════════════════════
class AppDivider extends StatelessWidget {
  final String? label;
  final EdgeInsetsGeometry? margin;

  const AppDivider({super.key, this.label, this.margin});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: const Divider(),
      );
    }
    return Padding(
      padding: margin ??
          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label!,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textHint),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SectionHeader
// ══════════════════════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: subtitle != null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AppTextStyles.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            GhostButton(label: actionLabel!, onTap: onAction),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AppProgressBar
// ══════════════════════════════════════════════════════════════
class AppProgressBar extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final BorderRadius? radius;
  final bool showLabel;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 6,
    this.radius,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final bg = backgroundColor ?? c.withValues(alpha: 0.12);
    final r = radius ?? AppRadius.circle;

    final bar = ClipRRect(
      borderRadius: r,
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: bg,
        valueColor: AlwaysStoppedAnimation(c),
      ),
    );

    if (!showLabel) return bar;

    return Row(
      children: [
        Expanded(child: bar),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).toStringAsFixed(0)}%',
          style: AppTextStyles.labelSmall.copyWith(color: c),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AppEmptyState
// ══════════════════════════════════════════════════════════════
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = iconColor ?? AppColors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: c),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(
                label: actionLabel!,
                onTap: onAction,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AppLoadingOverlay
// ══════════════════════════════════════════════════════════════
class AppLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool loading;
  final String? message;

  const AppLoadingOverlay({
    super.key,
    required this.child,
    required this.loading,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (loading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  hasBorder: false,
                  shadows: AppShadows.lg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: AppColors.primary),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Text(message!,
                            style: AppTextStyles.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AppKpiCard  –  admin / stats tile
// ══════════════════════════════════════════════════════════════
class AppKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const AppKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      shadows: AppShadows.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppColors.textHint),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.headlineLarge.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TestQuestionWidget  –  MCQ question card
// ══════════════════════════════════════════════════════════════
class TestQuestionWidget extends StatelessWidget {
  final int questionNumber;
  final int totalQuestions;
  final String questionText;
  final List<String> options;
  final String? selectedOption;
  final String? correctOption; // only shown in review mode
  final bool reviewMode;
  final bool isMarkedForReview;
  final ValueChanged<String>? onOptionSelected;
  final VoidCallback? onMarkForReview;

  const TestQuestionWidget({
    super.key,
    required this.questionNumber,
    required this.totalQuestions,
    required this.questionText,
    required this.options,
    this.selectedOption,
    this.correctOption,
    this.reviewMode = false,
    this.isMarkedForReview = false,
    this.onOptionSelected,
    this.onMarkForReview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                'Q$questionNumber/$totalQuestions',
                style: AppTextStyles.labelMedium
                    .copyWith(color: Colors.white),
              ),
            ),
            const Spacer(),
            if (onMarkForReview != null)
              GestureDetector(
                onTap: onMarkForReview,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: isMarkedForReview
                        ? AppColors.warning.withValues(alpha: 0.12)
                        : AppColors.surfaceVariant,
                    borderRadius: AppRadius.smAll,
                    border: Border.all(
                      color: isMarkedForReview
                          ? AppColors.warning.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMarkedForReview
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 13,
                        color: isMarkedForReview
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMarkedForReview ? 'Marked' : 'Mark',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isMarkedForReview
                              ? AppColors.warning
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Question text
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: AppColors.primary.withValues(alpha: 0.04),
          hasBorder: false,
          shadows: const [],
          child: Text(
            questionText,
            style: AppTextStyles.bodyLarge
                .copyWith(fontWeight: FontWeight.w500, height: 1.55),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Options
        ...List.generate(options.length, (i) {
          final opt = options[i];
          final isSelected = selectedOption == opt;
          final isCorrect = reviewMode && correctOption == opt;
          final isWrong =
              reviewMode && isSelected && correctOption != opt;

          Color cardColor = Colors.transparent;
          Color borderColor =
              AppColors.border.withValues(alpha: 0.5);
          Color textColor = AppColors.textPrimary;
          IconData? trailingIcon;

          if (isCorrect) {
            cardColor = AppColors.success.withValues(alpha: 0.08);
            borderColor = AppColors.success.withValues(alpha: 0.5);
            textColor = AppColors.success;
            trailingIcon = Icons.check_circle_rounded;
          } else if (isWrong) {
            cardColor = AppColors.error.withValues(alpha: 0.08);
            borderColor = AppColors.error.withValues(alpha: 0.5);
            textColor = AppColors.error;
            trailingIcon = Icons.cancel_rounded;
          } else if (isSelected) {
            cardColor =
                AppColors.primary.withValues(alpha: 0.08);
            borderColor =
                AppColors.primary.withValues(alpha: 0.6);
            textColor = AppColors.primary;
          }

          return GestureDetector(
            onTap: reviewMode
                ? null
                : () => onOptionSelected?.call(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  // Option letter
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected || isCorrect
                          ? (isWrong
                              ? AppColors.error
                              : isCorrect
                                  ? AppColors.success
                                  : AppColors.primary)
                          : AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      String.fromCharCode(65 + i), // A B C D
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isSelected || isCorrect
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      opt,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: textColor),
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(trailingIcon, size: 18, color: textColor),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
