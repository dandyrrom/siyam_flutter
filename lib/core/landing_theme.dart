import 'package:flutter/material.dart';

/// Color palette for the public-facing pages only (landing, login, register,
/// about, donate-info, FAQs) -- sourced from the brand illustrations
/// (`assets/dog-human-cat.png`, `assets/girl-carry-dog.png`) and the
/// `assets/branding/pet-house.png` logo. Deliberately kept separate from
/// [AppColors] in `app_theme.dart`, which is the green theme used by the
/// authenticated app shell (dashboard, inventory, etc.) and is out of scope
/// for this palette swap.
class LandingColors {
  static const background = Color(0xFFFFF7EA);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B2118);
  static const mutedInk = Color(0xFF8A7A68);
  static const border = Color(0xFFEFE0C4);

  // Mustard/gold -- the dog's coat in both illustrations and the logo.
  static const gold = Color(0xFFE8A33D);
  static const goldDark = Color(0xFFC97F1E);
  static const goldForeground = Color(0xFF2B2118);

  // Teal -- the scarf in girl-carry-dog.png.
  static const teal = Color(0xFF2FB6AE);

  // Purple -- the sweater in girl-carry-dog.png.
  static const purple = Color(0xFF7C6FCE);

  // Blue -- the house shape in the logo.
  static const blue = Color(0xFF2B8FD1);

  // Red -- the hearts in both illustrations.
  static const red = Color(0xFFE2445C);
}
