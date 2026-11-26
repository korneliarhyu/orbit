import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ==========================================
      // GLOBAL COLORS
      // ==========================================
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,

        onPrimary: AppColors.onPrimary,
        onSecondary: AppColors.onPrimary,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        onError: AppColors.onPrimary,

        outline: AppColors.border,
      ),

      // ==========================================
      // TYPOGRAPHY
      // ==========================================
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.display,

        headlineLarge: AppTextStyles.heading1,
        headlineMedium: AppTextStyles.heading2,

        titleLarge: AppTextStyles.heading2,
        titleMedium: AppTextStyles.title,
        titleSmall: AppTextStyles.chip,

        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,

        labelLarge: AppTextStyles.title,
        labelMedium: AppTextStyles.chip,
        labelSmall: AppTextStyles.small,
      ),

      // ==========================================
      // ICON THEME
      // ==========================================
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),

      // ==========================================
      // APP BAR
      // ==========================================
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,

        titleTextStyle: AppTextStyles.heading2,

        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
      ),

      // ==========================================
      // FILLED BUTTON
      // ==========================================
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,

          minimumSize: const Size(0, 48),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonHorizontal,
            vertical: AppSpacing.buttonVertical,
          ),

          textStyle: AppTextStyles.button,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),

      // ==========================================
      // ELEVATED BUTTON
      // ==========================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,

          minimumSize: const Size(0, 48),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonHorizontal,
            vertical: AppSpacing.buttonVertical,
          ),

          textStyle: AppTextStyles.button,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),

      // ==========================================
      // OUTLINED BUTTON
      // ==========================================
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,

          minimumSize: const Size(0, 48),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonHorizontal,
            vertical: AppSpacing.buttonVertical,
          ),

          textStyle: AppTextStyles.buttonSecondary,

          side: const BorderSide(color: AppColors.border),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),

      // ==========================================
      // TEXT BUTTON
      // ==========================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.buttonSecondary,
        ),
      ),

      // ==========================================
      // INPUT FIELDS
      // ==========================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,

        hintStyle: AppTextStyles.inputHint,
        labelStyle: AppTextStyles.bodyMuted,

        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inputHorizontal,
          vertical: AppSpacing.inputVertical,
        ),

        border: _inputBorder(AppColors.border),

        enabledBorder: _inputBorder(AppColors.border),

        focusedBorder: _inputBorder(AppColors.primary, width: 1.5),

        errorBorder: _inputBorder(AppColors.error),

        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.5),

        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
      ),

      // ==========================================
      // DIVIDER
      // ==========================================
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: AppSpacing.lg,
      ),

      // ==========================================
      // BOTTOM NAVIGATION
      // ==========================================
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        elevation: 0,

        type: BottomNavigationBarType.fixed,

        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,

        selectedLabelStyle: AppTextStyles.navigation,
        unselectedLabelStyle: AppTextStyles.navigation,

        selectedIconTheme: IconThemeData(size: 24),
        unselectedIconTheme: IconThemeData(size: 24),
      ),

      // ==========================================
      // SNACKBAR
      // ==========================================
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevatedSurface,
        contentTextStyle: AppTextStyles.body,
        actionTextColor: AppColors.primary,

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // ==========================================
      // PROGRESS INDICATOR
      // ==========================================
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      // ==========================================
      // TEXT SELECTION
      // ==========================================
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.25),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }

  // ==========================================
  // REUSABLE INPUT BORDER
  // ==========================================
  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
