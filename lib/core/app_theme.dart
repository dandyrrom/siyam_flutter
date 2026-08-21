import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        surface: AppColors.background,
        error: AppColors.destructive,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.interTextTheme(),
    );

    return base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),

      // ======================================================================
      // APP-WIDE SNACKBAR DESIGN
      // ======================================================================
      //
      // Every normal SnackBar shown through ScaffoldMessenger now inherits the
      // same SIYAM presentation on web and mobile:
      //
      // - floating card instead of a full-width bottom strip
      // - consistent rounded corners
      // - consistent readable background
      // - white message text
      // - consistent spacing and elevation
      //
      // Default/info SnackBars use SIYAM blue.
      // Success/error/warning SnackBars should override backgroundColor at the
      // actual SnackBar call:
      //
      //   success -> AppColors.sageGreen
      //   error   -> AppColors.destructive
      //   warning -> AppColors.amberDeep
      //   info    -> AppColors.skyBlue
      //
      // Individual pages can continue using their existing:
      //
      //   ScaffoldMessenger.of(context).showSnackBar(...)
      //
      // without being rewritten just to obtain the shared shape/spacing.
      // ======================================================================

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.skyBlue,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
        actionTextColor: Colors.white,
        disabledActionTextColor: AppColors.catGrayDark,
        closeIconColor: Colors.white,
        showCloseIcon: false,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}
