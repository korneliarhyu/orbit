import 'package:flutter/material.dart';

class OrbitLogo extends StatelessWidget {
  final double size;

  const OrbitLogo({
    super.key,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/core/assets/orbit_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
