import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class OrbitSectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onTapAction;

  const OrbitSectionTitle({
    super.key,
    required this.title,
    this.actionText,
    this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.heading2,
          ),
        ),

        if (actionText != null)
          TextButton(
            onPressed: onTapAction,
            child: Text(
              actionText!,
              style: AppTextStyles.body.copyWith(
                color: AppColors.primaryPink,
              ),
            ),
          ),
      ],
    );
  }
}
