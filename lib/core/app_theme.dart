import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens ported from the original design's ACTIVE theme file,
/// `src/styles/theme.css` (the green palette). The previous version of
/// this file was ported from `default_shadcn_theme.css` instead, which
/// is an unused generic scaffold that the React app never actually
/// imports -- that's why the green theme wasn't showing up.
class AppColors {
  static const background = Color(0xFFF0F7F4);
  static const foreground = Color(0xFF0F2318);
  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF0F2318);
  static const primary = Color(0xFF16A34A); // green, matches --primary
  static const primaryForeground = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFE8F5EC);
  static const secondaryForeground = Color(0xFF14532D);
  static const muted = Color(0xFFE8F2EE);
  static const mutedForeground = Color(0xFF5A7A66);
  static const accent = Color(0xFF0D9488); // teal, matches --accent
  static const accentForeground = Color(0xFFFFFFFF);
  static const destructive = Color(0xFFDC2626);
  static const border = Color(0xFFD1E5D9);
  static const inputBackground = Color(0xFFF0F7F4);
  static const warning = Color(0xFFD97706);
  static const warningForeground = Color(0xFFFFFFFF);

  // Sidebar is its own dark-green surface with its own foreground
  // tokens -- it is NOT the same as the light `background`/`foreground`
  // pair above, so don't reuse those inside the sidebar.
  static const sidebar = Color(0xFF0F2318);
  static const sidebarForeground = Color(0xFFD1F0DE);
  static const sidebarPrimary = Color(0xFF22C55E);
  static const sidebarPrimaryForeground = Color(0xFF0F2318);
  static const sidebarAccent = Color(0xFF1A3A28);
  static const sidebarAccentForeground = Color(0xFF86EFAC);
  static const sidebarBorder = Color(0xFF1E3D2A);

  // Role accent colors (from the LoginPage role selector / chart-1,2,3)
  static const roleManager = Color(0xFF16A34A); // green
  static const roleStaff = Color(0xFF0D9488); // teal
  static const roleDonor = Color(0xFFEA580C); // orange

  // Stock-level tiers (Inventory page)
  static const stockInStock = Color(0xFF16A34A); // green
  static const stockNeedsRestock = Color(0xFFEAB308); // yellow
  static const stockLow = Color(0xFFEA580C); // orange
  static const stockOut = Color(0xFFDC2626); // red
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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