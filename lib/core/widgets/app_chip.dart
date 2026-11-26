import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

// ==========================================
// CHIP VARIANTS
// ==========================================

enum OrbitChipVariant { standard, outlined, accent }

// ==========================================
// ORBIT CHIP
// ==========================================

class OrbitChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  final OrbitChipVariant variant;
  final bool selected;

  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDeleted;

  const OrbitChip({
    super.key,
    required this.label,
    this.icon,
    this.variant = OrbitChipVariant.standard,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
  });

  Color get _backgroundColor {
    if (selected) return AppColors.primary;

    switch (variant) {
      case OrbitChipVariant.standard:
        return AppColors.elevatedSurface;

      case OrbitChipVariant.outlined:
        return Colors.transparent;

      case OrbitChipVariant.accent:
        return AppColors.primary.withValues(alpha: 0.12);
    }
  }

  Color get _foregroundColor {
    if (selected) return AppColors.onPrimary;

    if (variant == OrbitChipVariant.accent) {
      return AppColors.primary;
    }

    return AppColors.textPrimary;
  }

  BorderSide get _borderSide {
    if (selected) return BorderSide.none;

    return variant == OrbitChipVariant.outlined
        ? const BorderSide(color: AppColors.border)
        : BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.chip),
    );

    final labelStyle = AppTextStyles.chip.copyWith(color: _foregroundColor);

    final avatar = icon == null
        ? null
        : Icon(icon, size: 14, color: _foregroundColor);

    const padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    );

    // REMOVABLE CHIP
    if (onDeleted != null) {
      return InputChip(
        label: Text(label),
        avatar: avatar,
        labelStyle: labelStyle,

        backgroundColor: _backgroundColor,
        selectedColor: AppColors.primary,
        selected: selected,

        onDeleted: onDeleted,
        onSelected: onSelected,
        showCheckmark: false,

        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        deleteIconColor: _foregroundColor,

        padding: padding,
        shape: shape,
        side: _borderSide,

        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
      );
    }

    // SELECTABLE CHIP
    if (onSelected != null) {
      return ChoiceChip(
        label: Text(label),
        avatar: avatar,

        selected: selected,
        onSelected: onSelected,

        labelStyle: labelStyle,
        backgroundColor: _backgroundColor,
        selectedColor: AppColors.primary,

        showCheckmark: false,

        padding: padding,
        shape: shape,
        side: _borderSide,

        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
      );
    }

    // STATIC CHIP / BADGE
    return Chip(
      label: Text(label),
      avatar: avatar,
      labelStyle: labelStyle,

      backgroundColor: _backgroundColor,

      padding: padding,
      shape: shape,
      side: _borderSide,

      elevation: 0,
      surfaceTintColor: Colors.transparent,

      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
