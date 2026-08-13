import 'package:flutter/material.dart';

/// Brand colors sampled directly from the AMSEL logo (assets/icon/amsel_icon.png)
/// so the app's palette matches the desktop app's own branding exactly.
class AmselColors {
  static const gold = Color(0xFFFDC92A);
  static const charcoal = Color(0xFF282829);
}

ThemeData buildAmselTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AmselColors.gold,
    brightness: Brightness.light,
  ).copyWith(
    primary: AmselColors.gold,
    onPrimary: AmselColors.charcoal,
    secondary: AmselColors.charcoal,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: AmselColors.charcoal,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AmselColors.charcoal,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AmselColors.gold,
        foregroundColor: AmselColors.charcoal,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AmselColors.charcoal,
        side: const BorderSide(color: AmselColors.charcoal, width: 1.4),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AmselColors.gold, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
