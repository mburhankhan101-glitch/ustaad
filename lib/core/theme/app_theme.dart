import 'package:flutter/material.dart';

class UstaadColors {
  static const background = Color(0xFFF5F7FF);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color.fromARGB(255, 42, 38, 126);
  static const primaryLight = Color(0xFFEEECFF);
  static const accent = Color(0xFFFF6B6B);
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFFF6B6B);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textLight = Color(0xFFFFFFFF);
  static const gold = Color(0xFFFFD700);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: UstaadColors.background,
      colorScheme: ColorScheme.light(
        primary: UstaadColors.primary,
        surface: UstaadColors.surface,
        error: UstaadColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: UstaadColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: UstaadColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: UstaadColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: UstaadColors.primary,
          foregroundColor: UstaadColors.textLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: UstaadColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: UstaadColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: UstaadColors.textSecondary,
        ),
      ),
    );
  }
}
