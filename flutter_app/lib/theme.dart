import 'package:flutter/material.dart';

/// Mandi Mate palette — warm, grounded, Maharashtra-rural.
/// Deliberately *not* Silicon Valley blue-or-purple.
class MMColors {
  static const bg          = Color(0xFFF4EBD6);
  static const bgWarm      = Color(0xFFFAF4E8);
  static const ink         = Color(0xFF2B1810);
  static const inkSoft     = Color(0xFF5A4530);
  static const line        = Color(0xFFD9C79F);
  static const lineSoft    = Color(0xFFEADFBE);
  static const turmeric    = Color(0xFFD49B26);
  static const turmericDk  = Color(0xFFA87813);
  static const terracotta  = Color(0xFFB54C20);
  static const terracottaDk= Color(0xFF8B3812);
  static const sage        = Color(0xFF6B7F4C);
  static const crimson     = Color(0xFF8B2218);
  static const card        = Color(0xFFFFFFFF);
}

final mandiMateTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: MMColors.bg,
  colorScheme: ColorScheme.light(
    primary: MMColors.terracotta,
    secondary: MMColors.turmeric,
    surface: MMColors.card,
    background: MMColors.bg,
    onPrimary: Colors.white,
    onSurface: MMColors.ink,
    error: MMColors.crimson,
  ),
  fontFamily: 'Hind',
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Fraunces', fontSize: 32, fontWeight: FontWeight.w500,
      color: MMColors.ink, letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontFamily: 'TiroDevanagariMarathi', fontSize: 28,
      color: MMColors.terracottaDk, height: 1.25,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w500,
      color: MMColors.ink, letterSpacing: -0.3,
    ),
    titleMedium: TextStyle(
      fontSize: 15, fontWeight: FontWeight.w600, color: MMColors.ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: MMColors.ink, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: MMColors.inkSoft),
    labelSmall: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, color: MMColors.inkSoft,
      letterSpacing: 1.4,
    ),
  ),
  cardTheme: CardTheme(
    color: MMColors.card,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: MMColors.lineSoft),
      borderRadius: BorderRadius.circular(18),
    ),
  ),
);
