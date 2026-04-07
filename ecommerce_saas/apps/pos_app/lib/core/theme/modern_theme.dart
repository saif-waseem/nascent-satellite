import 'package:flutter/material.dart';
import 'dart:ui';

class ModernTheme {
  // Colors from the "WOW" mockup
  static const Color primaryIndigo = Color(0xFF1E1E2C);
  static const Color accentIndigo = Color(0xFF3F51B5);
  static const Color neonCyan = Color(0xFF00BCD4);
  static const Color cardColor = Color(0xFF2C2C3E);
  static const Color glassBackground = Color(0x33FFFFFF);

  // Gradient for the main dashboard background
  static const LinearGradient dashboardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
      Color(0xFF0F3460),
    ],
  );

  // Glassmorphism Decoration
  static BoxDecoration glassDecoration({BorderRadius? borderRadius}) {
    return BoxDecoration(
      color: glassBackground,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
    );
  }

  // Modern Shadow
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 15,
      offset: const Offset(0, 8),
    ),
  ];

  // Modern Text Theme
  static TextTheme textTheme(BuildContext context) {
    return Theme.of(context).textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
      fontFamily: 'Cairo', // Respecting the user's font
    );
  }
}

// Extension to help with Glassmorphism blur
extension GlassEffect on Widget {
  Widget withGlassBlur({double blur = 10, BorderRadius? borderRadius}) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: this,
      ),
    );
  }
}
