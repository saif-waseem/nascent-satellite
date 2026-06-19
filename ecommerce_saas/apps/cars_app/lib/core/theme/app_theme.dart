import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const lapis = Color(0xFF1e3d59);
  static const lapisDark = Color(0xFF122536);
  static const gold = Color(0xFFd4af37);
  static const goldLight = Color(0xFFf3e5ab);
  static const clay = Color(0xFFf5f1e6);
  static const clayDark = Color(0xFFe0d8c3);
  static const terracotta = Color(0xFFc04000);
  static const textMain = Color(0xFF2b2b2b);
  static const textLight = Color(0xFFf5f1e6);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.lapis,
          primary: AppColors.lapis,
          secondary: AppColors.gold,
          surface: AppColors.clay,
        ),
        scaffoldBackgroundColor: AppColors.clay,
        textTheme: GoogleFonts.cairoTextTheme().copyWith(
          displayLarge: GoogleFonts.amiri(fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: GoogleFonts.amiri(fontSize: 24, fontWeight: FontWeight.bold),
          titleLarge: GoogleFonts.amiri(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.lapis),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.gold, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.lapisDark, fontWeight: FontWeight.w600, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lapis,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      );
}
