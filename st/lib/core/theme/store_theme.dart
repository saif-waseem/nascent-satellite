import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StoreTheme {
  static ThemeData getLightTheme(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.cairoTextTheme(),
      appBarTheme: const AppBarTheme(
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData getDarkTheme(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
        surface: const Color(0xFF121212),
        surfaceContainer: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: const Color(0xFF2C2C2C),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // Legacy fallback
  static final lightTheme = getLightTheme(const Color(0xFF006C4C));
  static final darkTheme = getDarkTheme(const Color(0xFF006C4C));
}

