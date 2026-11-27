import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_spacing.dart';
import 'app_avatar.dart';

enum OrbitMessageReceipt { sent, delivered, read }

class OrbitChatTile extends StatelessWidget {
  const OrbitChatTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    this.unreadCount = 0,
    this.receipt,
    this.isOnline = false,
    this.isGroup = false,
    this.avatarColor = AppColors.primary,
    this.avatarIndex,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onTap,
  });

  final String name, message, time;
  final int unreadCount;
  final OrbitMessageReceipt? receipt;
  final bool isOnline, isGroup, isFavorite;
  final Color avatarColor;
  final int? avatarIndex;
  final VoidCallback? onToggleFavorite, onTap;

  @override
  Widget build(BuildContext context) {
    final unread = unreadCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.conversationVertical,
          ),
          child: Row(
            children: [
              if (isGroup)
                CircleAvatar(
                  radius: 29,
                  backgroundColor: avatarColor,
                  child: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.onPrimary,
                  ),
                )
              else
                OrbitAvatar(
                  name: name,
                  radius: 29,
                  avatarIndex: avatarIndex,
                  highlighted: unread,
                  isOnline: isOnline,
                ),
              const SizedBox(width: AppSpacing.avatarGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(time, style: AppTextStyles.timestamp),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMuted.copyWith(
                              color: unread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 21,
                              minHeight: 21,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ] else if (receipt != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 21,
                            height: 21,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                receipt == OrbitMessageReceipt.sent
                                    ? Icons.done_rounded
                                    : Icons.done_all_rounded,
                                size: 18,
                                color: receipt == OrbitMessageReceipt.read
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                semanticLabel:
                                    receipt == OrbitMessageReceipt.read
                                    ? 'Read by NPC'
                                    : receipt == OrbitMessageReceipt.delivered
                                    ? 'Delivered'
                                    : 'Sent',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onToggleFavorite != null) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  tooltip: isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: onToggleFavorite,
                  iconSize: 19,
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavorite
                        ? AppColors.secondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
