import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_avatar.dart';

class OrbitNotificationBanner extends StatelessWidget {
  final String name;
  final String message;
  final int? avatarIndex;
  final String? imageUrl;
  final VoidCallback? onTap;

  const OrbitNotificationBanner({
    super.key,
    required this.name,
    required this.message,
    this.avatarIndex,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: AppColors.elevatedSurface,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),

        clipBehavior: Clip.antiAlias,

        child: InkWell(
          onTap: onTap,

          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                // NPC AVATAR
                OrbitAvatar(
                  name: name,
                  avatarIndex: avatarIndex,
                  imageUrl: imageUrl,
                  size: 44,
                ),

                const SizedBox(width: AppSpacing.avatarGap),

                // NOTIFICATION CONTENT
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // NAME & TIME
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppTextStyles.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: AppSpacing.sm),

                          const Text('now', style: AppTextStyles.timestamp),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // MESSAGE PREVIEW
                      Text(
                        message,
                        style: AppTextStyles.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
