import 'package:flutter/material.dart';

/// SupplyCloset brand colors and theme
/// Designed for readability under fluorescent hospital lighting
class SupplyClosetColors {
  // Primary palette
  static const teal = Color(0xFF0D9488);
  static const tealLight = Color(0xFF14B8A6);
  static const tealDark = Color(0xFF0F766E);

  // Backgrounds
  static const warmWhite = Color(0xFFFAFAF8);
  static const surfaceLight = Color(0xFFF1F5F9);

  // Accent
  static const coral = Color(0xFFF87171);
  static const coralLight = Color(0xFFFCA5A5);

  // Semantic
  static const success = Color(0xFF6EE7B7);
  static const successDark = Color(0xFF10B981);
  static const warning = Color(0xFFFBBF24);
  static const warningDark = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Text
  static const charcoal = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);
}

class SupplyClosetTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SupplyClosetColors.teal,
        primary: SupplyClosetColors.teal,
        secondary: SupplyClosetColors.coral,
        surface: SupplyClosetColors.warmWhite,
        error: SupplyClosetColors.error,
      ),
      scaffoldBackgroundColor: SupplyClosetColors.warmWhite,

      // Typography — minimum 16px body, readable under fluorescent lights
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: SupplyClosetColors.charcoal,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: SupplyClosetColors.charcoal,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: SupplyClosetColors.charcoal,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: SupplyClosetColors.charcoal,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: SupplyClosetColors.charcoal,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: SupplyClosetColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Glove-friendly touch targets — minimum 48x48dp
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SupplyClosetColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SupplyClosetColors.teal,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: SupplyClosetColors.teal, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SupplyClosetColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: SupplyClosetColors.teal,
            width: 2,
          ),
        ),
      ),

      // Bottom nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: SupplyClosetColors.teal,
        unselectedItemColor: SupplyClosetColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: SupplyClosetColors.charcoal,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: SupplyClosetColors.charcoal,
        ),
      ),
    );
  }
}
