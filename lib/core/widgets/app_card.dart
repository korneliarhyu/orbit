import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

// ==========================================
// CARD VARIANTS
// ==========================================

enum OrbitCardVariant { surface, elevated, outlined, transparent }

// ==========================================
// ORBIT CARD
// ==========================================

class OrbitCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  final OrbitCardVariant variant;
  final double radius;
  final bool? showBorder;
  final double? width;

  const OrbitCard({
    super.key,
    required this.child,
    this.padding,
    this.variant = OrbitCardVariant.surface,
    this.radius = AppRadius.card,
    this.showBorder,
    this.width,
  });

  Color get _backgroundColor {
    switch (variant) {
      case OrbitCardVariant.surface:
        return AppColors.surface;

      case OrbitCardVariant.elevated:
        return AppColors.elevatedSurface;

      case OrbitCardVariant.outlined:
      case OrbitCardVariant.transparent:
        return Colors.transparent;
    }
  }

  bool get _hasBorder => showBorder ?? (variant == OrbitCardVariant.outlined);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,

      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),

      decoration: BoxDecoration(
        color: _backgroundColor,

        borderRadius: BorderRadius.circular(radius),

        border: _hasBorder
            ? Border.all(color: AppColors.border, width: 1)
            : null,
      ),

      child: child,
    );
  }
}
