import 'package:flutter/material.dart';

/// Blues from the SOftiX logo, the same palette as the admin panel.
class AppColors {
  static const primary = Color(0xFF1D5FA8);
  static const primaryDark = Color(0xFF0E3F7A);
  static const primarySoft = Color(0xFFEEF4FB);
  static const ink = Color(0xFF0E2A4D);
  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7482);
  static const line = Color(0xFFE3E7ED);
  static const surface = Color(0xFFF5F7FA);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFB42318);
}

ThemeData buildTheme() {
  const font = 'IBMPlexSansArabic';
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: font,
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(side: BorderSide(color: AppColors.line)),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primarySoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: font, fontSize: 12)),
    ),
  );
}
