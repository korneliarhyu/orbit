import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ==========================================
// ICON BUTTON VARIANTS
// ==========================================

enum OrbitIconButtonVariant { primary, secondary, ghost, destructive }

// ==========================================
// ORBIT ICON BUTTON
// ==========================================

class OrbitIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  // Backward compatibility
  final bool isPrimary;

  final OrbitIconButtonVariant? variant;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool isLoading;

  const OrbitIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.isPrimary = false,
    this.variant,
    this.size = 56,
    this.iconSize = 24,
    this.tooltip,
    this.isLoading = false,
  });

  OrbitIconButtonVariant get _variant =>
      variant ??
      (isPrimary
          ? OrbitIconButtonVariant.primary
          : OrbitIconButtonVariant.secondary);

  bool get _isDisabled => onTap == null || isLoading;

  Color get _backgroundColor {
    if (onTap == null && !isLoading) {
      return _variant == OrbitIconButtonVariant.ghost
          ? Colors.transparent
          : AppColors.elevatedSurface.withValues(alpha: 0.5);
    }

    switch (_variant) {
      case OrbitIconButtonVariant.primary:
        return AppColors.primary;

      case OrbitIconButtonVariant.secondary:
      case OrbitIconButtonVariant.destructive:
        return AppColors.surface;

      case OrbitIconButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _iconColor {
    if (onTap == null && !isLoading) {
      return AppColors.textSecondary.withValues(alpha: 0.5);
    }

    switch (_variant) {
      case OrbitIconButtonVariant.primary:
        return AppColors.onPrimary;

      case OrbitIconButtonVariant.secondary:
        return AppColors.primary;

      case OrbitIconButtonVariant.ghost:
        return AppColors.textSecondary;

      case OrbitIconButtonVariant.destructive:
        return AppColors.error;
    }
  }

  BorderSide get _borderSide {
    switch (_variant) {
      case OrbitIconButtonVariant.secondary:
      case OrbitIconButtonVariant.destructive:
        return BorderSide(
          color: AppColors.border.withValues(
            alpha: onTap == null && !isLoading ? 0.5 : 1,
          ),
        );

      default:
        return BorderSide.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: _isDisabled ? null : onTap,
      tooltip: tooltip,
      iconSize: iconSize,

      style: IconButton.styleFrom(
        backgroundColor: _backgroundColor,
        disabledBackgroundColor: _backgroundColor,
        foregroundColor: _iconColor,
        disabledForegroundColor: _iconColor,
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
        side: _borderSide,
        shape: const CircleBorder(),
      ),

      icon: isLoading
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _iconColor,
              ),
            )
          : Icon(icon),
    );

    return button;
  }
}
