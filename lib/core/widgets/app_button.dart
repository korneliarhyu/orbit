import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

// ==========================================
// BUTTON VARIANTS
// ==========================================

enum OrbitButtonVariant { primary, secondary, outlined, special }

// ==========================================
// ORBIT BUTTON
// ==========================================

class OrbitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  final OrbitButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;

  const OrbitButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = OrbitButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = false,
  });

  bool get _isDisabled => onPressed == null || isLoading;

  Color get _foregroundColor {
    if (onPressed == null) {
      return AppColors.textSecondary.withValues(alpha: 0.5);
    }

    switch (variant) {
      case OrbitButtonVariant.primary:
      case OrbitButtonVariant.special:
        return AppColors.onPrimary;

      case OrbitButtonVariant.secondary:
        return AppColors.textPrimary;

      case OrbitButtonVariant.outlined:
        return AppColors.primary;
    }
  }

  Color get _backgroundColor {
    if (onPressed == null) {
      return AppColors.elevatedSurface.withValues(alpha: 0.5);
    }

    switch (variant) {
      case OrbitButtonVariant.primary:
      case OrbitButtonVariant.special:
        return AppColors.primary;

      case OrbitButtonVariant.secondary:
        return AppColors.elevatedSurface;

      case OrbitButtonVariant.outlined:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.button);

    final useGradient =
        variant == OrbitButtonVariant.special && onPressed != null;

    return Semantics(
      button: true,
      enabled: !_isDisabled,
      label: isLoading ? '$label, loading' : label,
      excludeSemantics: true,

      child: SizedBox(
        width: fullWidth ? double.infinity : null,

        child: DecoratedBox(
          decoration: BoxDecoration(
            color: useGradient ? null : _backgroundColor,

            gradient: useGradient ? AppColors.primaryGradient : null,

            borderRadius: radius,
          ),

          child: Material(
            color: Colors.transparent,

            shape: RoundedRectangleBorder(
              borderRadius: radius,

              side: variant == OrbitButtonVariant.outlined
                  ? BorderSide(
                      color: onPressed == null
                          ? AppColors.border.withValues(alpha: 0.5)
                          : AppColors.border,
                    )
                  : BorderSide.none,
            ),

            clipBehavior: Clip.antiAlias,

            child: InkWell(
              onTap: _isDisabled ? null : onPressed,
              borderRadius: radius,

              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),

                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.buttonHorizontal,
                    vertical: AppSpacing.buttonVertical,
                  ),

                  child: Row(
                    mainAxisSize: fullWidth
                        ? MainAxisSize.max
                        : MainAxisSize.min,

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      if (isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _foregroundColor,
                          ),
                        )
                      else ...[
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: _foregroundColor),

                          const SizedBox(width: AppSpacing.iconGap),
                        ],

                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,

                            style: AppTextStyles.button.copyWith(
                              color: _foregroundColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
