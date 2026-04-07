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
      textTheme: GoogleFonts.almaraiTextTheme(),
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
      ),
      textTheme: GoogleFonts.almaraiTextTheme(),
    );
  }

  // Legacy fallback
  static final lightTheme = getLightTheme(const Color(0xFF006C4C));
  static final darkTheme = getDarkTheme(const Color(0xFF006C4C));
}

