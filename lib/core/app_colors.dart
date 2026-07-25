import 'package:flutter/material.dart';

/// Color palette extracted from the pet-care illustrations:
/// golden dog fur, sage green, cool cat gray, coral-red hearts,
/// and a sky-blue accent from the pet house roof.
class AppColors {
  AppColors._();

  // Core palette swatches (sampled directly from the artwork)
  static const Color goldenDog = Color(0xFFE8A93D);   // dog fur / warm accent
  static const Color amberDeep = Color(0xFFC97C1F);   // dog ear shading
  static const Color sageGreen = Color(0xFF93B873);   // shirt green
  static const Color coralRed = Color(0xFFE5445C);    // heart icons
  static const Color catGray = Color(0xFFD6D6D6);     // cat fur light
  static const Color catGrayDark = Color(0xFFA8A8A8); // cat fur shading
  static const Color skyBlue = Color(0xFF2D82C4);     // house roof
  static const Color skinTone = Color(0xFFEEB48C);    // warm skin/arms
  static const Color chestnutBrown = Color(0xFF8B5A2B); // hair / trim
  static const Color deepBrown = Color(0xFF3E2723);   // dark hair / text
  static const Color cream = Color(0xFFFFF8F0);       // background base

  /// Light theme color scheme
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: sageGreen,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE1EFD4),
    onPrimaryContainer: Color(0xFF3D5A2C),
    secondary: goldenDog,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFE0B0),
    onSecondaryContainer: amberDeep,
    tertiary: coralRed,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFDADE),
    onTertiaryContainer: Color(0xFF7A1428),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: cream,
    onSurface: deepBrown,
    surfaceContainerHighest: catGray,
    onSurfaceVariant: Color(0xFF5C5750),
    outline: catGrayDark,
    shadow: Colors.black,
    inverseSurface: deepBrown,
    onInverseSurface: cream,
    inversePrimary: Color(0xFFB7D4A0),
  );

  /// Dark theme color scheme
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFB7D4A0),
    onPrimary: Color(0xFF23380F),
    primaryContainer: Color(0xFF3D5A2C),
    onPrimaryContainer: Color(0xFFE1EFD4),
    secondary: Color(0xFFFFD48A),
    onSecondary: Color(0xFF4A2F00),
    secondaryContainer: amberDeep,
    onSecondaryContainer: Color(0xFFFFE9C7),
    tertiary: Color(0xFFFFB3BC),
    onTertiary: Color(0xFF67101F),
    tertiaryContainer: Color(0xFF7A1428),
    onTertiaryContainer: Color(0xFFFFDADE),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1E1B18),
    onSurface: Color(0xFFEAE1D9),
    surfaceContainerHighest: Color(0xFF4A453F),
    onSurfaceVariant: catGray,
    outline: catGrayDark,
    shadow: Colors.black,
    inverseSurface: cream,
    onInverseSurface: deepBrown,
    inversePrimary: sageGreen,
  );

  static ThemeData lightTheme() => ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: lightScheme.surface,
      );

  static ThemeData darkTheme() => ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: darkScheme.surface,
      );
}
