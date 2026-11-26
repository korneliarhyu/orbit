import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

class OrbitLogo extends StatelessWidget {
  final double size;
  final double? height;
  final bool wordmark;
  final Alignment alignment;

  const OrbitLogo({
    super.key,
    this.size = 32,
    this.height,
    this.wordmark = false,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) => Image.asset(
    wordmark
        ? 'lib/core/assets/orbit_wordmark.png'
        : 'lib/core/assets/orbit_logo.png',
    width: size,
    height: height ?? (wordmark ? null : size),
    alignment: alignment,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) =>
        Text('ORBIT', style: AppTextStyles.title, textAlign: TextAlign.center),
  );
}
