import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OrbitIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isPrimary;

  const OrbitIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isPrimary
            ? AppColors.primaryGradient
            : null,
        color: isPrimary ? null : AppColors.card,
        border: isPrimary
            ? null
            : Border.all(color: AppColors.border),
        boxShadow: isPrimary
            ? const [
          BoxShadow(
            color: Color(0x55FF4EB8),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
