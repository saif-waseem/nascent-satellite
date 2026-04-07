import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE91E63), // Pink seed for User App (Shopping vibe)
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.tajawalTextTheme(), // Tajawal is great for modern Arabic UI
    );
  }
}
