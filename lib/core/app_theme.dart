import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens ported from the original design's
/// default_shadcn_theme.css so the Flutter app keeps the same look.
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF0A0A0A);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF030213); // near-black navy, matches --primary
  static const primaryForeground = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFF1F0F5);
  static const muted = Color(0xFFECECF0);
  static const mutedForeground = Color(0xFF717182);
  static const accent = Color(0xFFE9EBEF);
  static const destructive = Color(0xFFD4183D);
  static const border = Color(0x1A000000);
  static const inputBackground = Color(0xFFF3F3F5);

  static const sidebar = Color(0xFFFCFCFC);
  static const sidebarBorder = Color(0xFFE9E9E9);

  // Role accent colors (from the LoginPage role selector)
  static const roleManager = Color(0xFF16A34A); // green
  static const roleStaff = Color(0xFF0D9488); // teal
  static const roleDonor = Color(0xFFEA580C); // orange
}

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
        fillColor: AppColors.inputBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}