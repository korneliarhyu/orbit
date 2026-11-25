import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../features/npc/npc_avatar_widget.dart';

/// Shared circular avatar for ORBIT.
///
/// [portraitScale] controls how zoomed-in the whole NPC portrait appears.
/// Use a lower value in the Inbox; the Chat Room keeps the default crop.
class OrbitAvatar extends StatelessWidget {
  const OrbitAvatar({
    super.key,
    this.size = 52,
    this.radius,
    this.name,
    this.imageUrl,
    this.avatarIndex,
    this.isOnline = false,
    this.highlighted = false,
    this.portraitScale = 1.9,
  });

  final double size;
  final double? radius;
  final String? name;
  final String? imageUrl;
  final int? avatarIndex;
  final bool isOnline;
  final bool highlighted;
  final double portraitScale;

  /// Reads a previously saved portrait index; never randomizes a match's face.
  static int? indexFromMatchData(Map<String, dynamic>? data) {
    if (data == null) return null;

    dynamic value = data['avatarIndex'];
    if (value == null && data['npc'] is Map) {
      value = (data['npc'] as Map)['avatarIndex'];
    }

    if (value is int) return value >= 0 ? value : null;
    if (value is num) return value >= 0 ? value.toInt() : null;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed >= 0 ? parsed : null;
    }
    return null;
  }

  Widget _fallback(double diameter) {
    final initial = name == null || name!.trim().isEmpty
        ? null
        : name!.trim()[0].toUpperCase();

    return ColoredBox(
      color: AppColors.elevatedSurface,
      child: Center(
        child: initial != null
            ? Text(
          initial,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: diameter * 0.38,
          ),
        )
            : Icon(
          Icons.person_rounded,
          color: AppColors.primary,
          size: diameter * 0.5,
        ),
      ),
    );
  }

  Widget _npcPortrait(double innerDiameter) {
    final imageWidth = innerDiameter * portraitScale;
    final imageHeight = imageWidth * (1402 / 1122);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: (innerDiameter - imageWidth) / 2,
          // Keep the facial area centered as the portrait scale changes.
          top: innerDiameter / 2 - imageHeight * 0.38,
          width: imageWidth,
          height: imageHeight,
          child: NpcAvatarWidget(
            avatarIndex: avatarIndex!,
            width: imageWidth,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final diameter = radius != null ? radius! * 2 : size;
    final innerSize = diameter - 4;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: diameter,
            height: diameter,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: highlighted ? AppColors.primary : AppColors.border,
                width: highlighted ? 1.8 : 1.2,
              ),
            ),
            child: ClipOval(
              child: avatarIndex != null
                  ? _npcPortrait(innerSize)
                  : imageUrl != null
                  ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _fallback(innerSize);
                },
              )
                  : _fallback(innerSize),
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}