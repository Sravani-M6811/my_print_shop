import 'package:flutter/material.dart';

/// Central theme definitions for MY PRINT SHOP.
///
/// The app brand colour is `#6C5CE7`, which is used consistently across all
/// screens. Both light and dark themes are derived from the same seed so the
/// UI stays coherent in either mode.
class AppTheme {
  AppTheme._();

  /// Brand colour used across the app.
  static const Color brand = Color(0xFF6C5CE7);

  static ThemeData get lightTheme => _base(Brightness.light);

  static ThemeData get darkTheme => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: dark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: dark ? Colors.white : Colors.black,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
