import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ==========================================
  // LUNAR EDITORIAL - DARK MODE
  // ==========================================
  static const Color background = Color(0xFF13121A);
  static const Color surface = Color(0xFF1B1924);
  static const Color elevatedSurface = Color(0xFF2A2535);
  static const Color primary = Color(0xFFCFA7F5);
  static const Color secondary = Color(0xFFE6B8E1);
  static const Color border = Color(0xFF4A4058);
  static const Color textPrimary = Color(0xFFF7F4FC);
  static const Color textSecondary = Color(0xFFB8B0C5);

  // ==========================================
  // FUNCTIONAL COLORS
  // ==========================================
  static const Color success = Color(0xFF81C9A7);
  static const Color error = Color(0xFFF29CA8);
  static const Color warning = Color(0xFFF2CE91);
  static const Color onPrimary = Color(0xFF211728);
  static const Color receiptPending = Color(0xFF81778F);
  static const Color receiptRead = primary;

  // ==========================================
  // BACKWARD COMPATIBILITY
  // ==========================================
  static const Color card = surface;
  static const Color cardSoft = elevatedSurface;

  static const Color primaryPurple = primary;
  static const Color primaryPink = secondary;
  static const Color softLilac = primary;

  static const Color danger = error;

  // ==========================================
  // PRIMARY GRADIENT
  // ==========================================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==========================================
  // CHAT BUBBLE GRADIENT
  // ==========================================
  static const LinearGradient messageGradient = LinearGradient(
    colors: [Color(0xFF9069B3), Color(0xFF76528F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==========================================
  // CARD GRADIENT
  // ==========================================
  static const LinearGradient cardGradient = LinearGradient(
    colors: [elevatedSurface, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==========================================
  // COSMIC GRADIENT
  // ==========================================
  static const LinearGradient cosmicGradient = LinearGradient(
    colors: [background, Color(0xFF24192E), Color(0xFF392344)],
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
  );
}

// ==========================================
// LUNAR DAWN - LIGHT MODE
// ==========================================
class AppLightColors {
  AppLightColors._();

  static const Color background = Color(0xFFF8F5FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color elevatedSurface = Color(0xFFF0EAF8);
  static const Color primary = Color(0xFF6945A3);
  static const Color secondary = Color(0xFF925283);
  static const Color border = Color(0xFFDED4EB);
  static const Color textPrimary = Color(0xFF241C35);
  static const Color textSecondary = Color(0xFF675A79);
  static const Color success = Color(0xFF247A53);
  static const Color error = Color(0xFFB83250);
  static const Color warning = Color(0xFF906016);
  static const Color onPrimary = Color(0xFFFFFFFF);
}
