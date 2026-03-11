// ─────────────────────────────────────────────────────────────
//  admin_courses_widgets.dart
//  Shared widgets for the admin_courses module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/admin_courses_service.dart';

// ─────────────────────────────────────────────────────────────
//  Published badge
// ─────────────────────────────────────────────────────────────
class CourseStatusBadge extends StatelessWidget {
  final bool published;
  const CourseStatusBadge({super.key, required this.published});

  @override
  Widget build(BuildContext context) {
    final color = published ? AppColors.success : AppColors.textHint;
    final label = published ? 'Published' : 'Draft';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Category badge
// ─────────────────────────────────────────────────────────────
class CategoryBadge extends StatelessWidget {
  final String? category;
  const CategoryBadge({super.key, this.category});

  @override
  Widget build(BuildContext context) {
    if (category == null || category!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category!,
        style: AppTextStyles.labelSmall
            .copyWith(color: AppColors.primary, fontSize: 11),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Price chip
// ─────────────────────────────────────────────────────────────
class PriceChip extends StatelessWidget {
  final double price;
  const PriceChip({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    final isFree = price == 0;
    return Text(
      isFree ? 'Free' : '₹${price.toStringAsFixed(0)}',
      style: AppTextStyles.labelMedium.copyWith(
        color: isFree ? AppColors.success : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stat chip (used in detail header)
// ─────────────────────────────────────────────────────────────
class CourseStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const CourseStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.headlineSmall
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Course thumbnail
// ─────────────────────────────────────────────────────────────
class CourseThumbnail extends StatelessWidget {
  final String? url;
  final double size;

  const CourseThumbnail({super.key, this.url, this.size = 42});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.menu_book_rounded,
            color: AppColors.primary, size: 22),
      );
}

// ─────────────────────────────────────────────────────────────
//  Section card (detail page)
// ─────────────────────────────────────────────────────────────
class CourseSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final List<Widget>? actions;
  final Widget child;

  const CourseSectionCard({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.headlineSmall
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────
class AdminCoursesEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const AdminCoursesEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.menu_book_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              message,
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

// ─────────────────────────────────────────────────────────────
//  Search bar
// ─────────────────────────────────────────────────────────────
class AdminCourseSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const AdminCourseSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search courses…',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodySmall,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textHint),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textHint),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Teacher picker dropdown
// ─────────────────────────────────────────────────────────────
class TeacherPickerDropdown extends StatelessWidget {
  final List<AdminTeacherOption> teachers;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const TeacherPickerDropdown({
    super.key,
    required this.teachers,
    required this.selectedId,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Assign Teacher *',
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedId,
          validator: validator ??
              (v) => v == null || v.isEmpty ? 'Please assign a teacher' : null,
          decoration: const InputDecoration(),
          hint: const Text('Select teacher'),
          isExpanded: true,
          items: teachers.map((t) {
            return DropdownMenuItem(
              value: t.id,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        AppColors.info.withValues(alpha: 0.15),
                    child: Text(
                      t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.info),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.name, style: AppTextStyles.labelMedium),
                        Text(t.email,
                            style: AppTextStyles.bodySmall
                                .copyWith(fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Category dropdown (standalone for admin forms)
// ─────────────────────────────────────────────────────────────
class AdminCategoryDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const AdminCategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _categories = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'History',
    'Geography',
    'Computer Science',
    'Economics',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Category',
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(),
          hint: const Text('Select category'),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Labeled text field (standalone)
// ─────────────────────────────────────────────────────────────
class AdminLabeledTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;

  const AdminLabeledTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.inputFormatters,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label,
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────────────────────
class AdminFormSectionHeader extends StatelessWidget {
  final String title;
  const AdminFormSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          title,
          style: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.primary, fontSize: 13),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Submit button
// ─────────────────────────────────────────────────────────────
class AdminFormSubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? color;

  const AdminFormSubmitButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Confirm action dialog
// ─────────────────────────────────────────────────────────────
Future<bool> confirmCourseAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color confirmColor = AppColors.error,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: AppTextStyles.headlineMedium),
      content: Text(message, style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────
//  Date formatter
// ─────────────────────────────────────────────────────────────
String fmtCourseDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} '
    '${_months[d.month - 1]} '
    '${d.year}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
