import 'package:flutter/material.dart';

class VaultXColors {
  VaultXColors._();

  // Brand & Semantic Accents (10% Accent Budget)
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color sky = Color(0xFF38BDF8);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);

  // Dark Palette (60% Canvas, 30% Structural Surface)
  static const Color darkBg = Color(0xFF070B12);
  static const Color darkSurface = Color(0xFF0E1522);
  static const Color darkSurfaceElevated = Color(0xFF151F32);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
}

class VaultXTheme {
  VaultXTheme._();

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: VaultXColors.emerald,
      onPrimary: Color(0xFF042F2E),
      secondary: VaultXColors.sky,
      surface: VaultXColors.darkSurface,
      onSurface: VaultXColors.darkTextPrimary,
      error: VaultXColors.rose,
      outline: VaultXColors.darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VaultXColors.darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: VaultXColors.darkBg,
        foregroundColor: VaultXColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: VaultXColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: VaultXColors.darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VaultXColors.darkSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VaultXColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VaultXColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VaultXColors.emerald, width: 1.5),
        ),
        labelStyle: const TextStyle(color: VaultXColors.darkTextSecondary),
        hintStyle: const TextStyle(color: VaultXColors.darkTextSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VaultXColors.emerald,
          foregroundColor: const Color(0xFF03231D),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VaultXColors.darkTextPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: VaultXColors.darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VaultXColors.darkSurface,
        indicatorColor: VaultXColors.emerald.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: VaultXColors.emerald, size: 22);
          }
          return const IconThemeData(
            color: VaultXColors.darkTextSecondary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: VaultXColors.emerald,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: VaultXColors.darkTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      dividerColor: VaultXColors.darkBorder,
    );
  }

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: VaultXColors.emeraldDark,
      onPrimary: Colors.white,
      secondary: Color(0xFF0284C7),
      surface: VaultXColors.lightSurface,
      onSurface: VaultXColors.lightTextPrimary,
      error: VaultXColors.rose,
      outline: VaultXColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VaultXColors.lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: VaultXColors.lightBg,
        foregroundColor: VaultXColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: VaultXColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: VaultXColors.lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VaultXColors.lightSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VaultXColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VaultXColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VaultXColors.emeraldDark, width: 1.5),
        ),
        labelStyle: const TextStyle(color: VaultXColors.lightTextSecondary),
        hintStyle: const TextStyle(color: VaultXColors.lightTextSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VaultXColors.emeraldDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VaultXColors.lightTextPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: VaultXColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VaultXColors.lightSurface,
        indicatorColor: VaultXColors.emeraldDark.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: VaultXColors.emeraldDark, size: 22);
          }
          return const IconThemeData(
            color: VaultXColors.lightTextSecondary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: VaultXColors.emeraldDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: VaultXColors.lightTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      dividerColor: VaultXColors.lightBorder,
    );
  }
}
