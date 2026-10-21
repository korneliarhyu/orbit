import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OrbitAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final bool isOnline;

  const OrbitAvatar({
    super.key,
    this.size = 52,
    this.imageUrl,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryPurple,
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: AppColors.card,
              backgroundImage: imageUrl != null
                  ? NetworkImage(imageUrl!)
                  : null,
              child: imageUrl == null
                  ? Icon(
                Icons.person_rounded,
                color: AppColors.softLilac,
                size: size * 0.5,
              )
                  : null,
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
