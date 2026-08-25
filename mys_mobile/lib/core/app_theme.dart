import 'package:flutter/material.dart';

/// Brand colors from mysglobaltechnologies.com's own stylesheet
/// (--navy-900 / --green-500 / --green-600 custom properties).
class MysColors {
  static const navy900 = Color(0xFF0F1E33);
  static const navy800 = Color(0xFF16283F);
  static const green500 = Color(0xFF10B981);
  static const green600 = Color(0xFF059669);
  static const green400 = Color(0xFF22C55E);
  static const bgLight = Color(0xFFEEF1F6);
}

ThemeData buildMysTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: MysColors.green500,
    brightness: Brightness.light,
  ).copyWith(
    primary: MysColors.green500,
    onPrimary: Colors.white,
    secondary: MysColors.navy900,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: MysColors.navy900,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: MysColors.bgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: MysColors.navy900,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MysColors.green500,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MysColors.navy900,
        side: const BorderSide(color: MysColors.navy900, width: 1.4),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MysColors.green500, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
