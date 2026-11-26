import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../constants/app_spacing.dart';

class OrbitSectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onTapAction;
  final IconData? actionIcon;

  const OrbitSectionTitle({
    super.key,
    required this.title,
    this.actionText,
    this.onTapAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final action = actionText;
    final icon = actionIcon;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(title, style: AppTextStyles.heading2)),

        if (action != null) ...[
          const SizedBox(width: AppSpacing.sm),

          if (icon != null)
            TextButton.icon(
              onPressed: onTapAction,
              icon: Icon(icon, size: 18),
              label: Text(action),
            )
          else
            TextButton(onPressed: onTapAction, child: Text(action)),
        ],
      ],
    );
  }
}
