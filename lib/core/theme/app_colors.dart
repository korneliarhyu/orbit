
import 'package:flutter/material.dart';

class AppColors {
  // Background colors
  static const Color background = Color(0xFF0B0914);
  static const Color surface = Color(0xFF151526);
  static const Color card = Color(0xFF1C1C31);
  static const Color cardSoft = Color(0xFF23233A);

  // Main brand colors
  static const Color primaryPink = Color(0xFFFF4EB8);
  static const Color primaryPurple = Color(0xFF8A4DFF);
  static const Color softLilac = Color(0xFFD6C2FF);

  // Text colors
  static const Color textPrimary = Color(0xFFF8F6FC);
  static const Color textSecondary = Color(0xFFA8A1BD);

  // Additional colors
  static const Color border = Color(0xFF2A2340);
  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFFB7185);

  // Main gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      primaryPink,
      primaryPurple,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card gradient
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF241B3D),
      Color(0xFF151526),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Cosmic gradient
  static const LinearGradient cosmicGradient = LinearGradient(
    colors: [
      Color(0xFF1A0F3D),
      Color(0xFF632C98),
      Color(0xFFB43A92),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
