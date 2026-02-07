import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Material 3 theme for Money Manager
class AppTheme {
  AppTheme._();

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color safe = Color(0xFF10B981); // Green - safe forecast
  static const Color caution = Color(0xFFF59E0B); // Yellow - borderline
  static const Color danger = Color(0xFFEF4444); // Red - deficit

  // Category Colors for pie chart
  static const List<Color> categoryColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFF84CC16), // Lime
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Teal
  ];

  // Glassmorphism Colors
  static const Color glassBackgroundDark = Color(0xFF0F2027);
  static const Color glassBackgroundMedium = Color(0xFF203A43);
  static const Color glassBackgroundLight = Color(0xFF2C5364);

  static const Color neonBlue = Color(0xFF00C6FF);
  static const Color neonPurple = Color(0xFF9D50BB);
  static const Color neonPink = Color(0xFFFF00CC);
  static const Color neonGreen = Color(0xFF33FF00);

  // Gradients
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [glassBackgroundDark, glassBackgroundMedium, glassBackgroundLight],
  );

  static const LinearGradient neonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonBlue, neonPurple],
  );

  /// Light Theme (Modified for Glass)
  static ThemeData get lightTheme {
    // For glassmorphism, we might want to stick to a dark-ish theme even in "light" mode
    // to make the glass effect visible, or carefuly tune white glass.
    // For now, let's keep it consistent with the glass aesthetic (usually dark mode).
    return darkTheme;
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: neonBlue,
      brightness: Brightness.dark,
      primary: neonBlue,
      secondary: neonPurple,
      surface: Colors.transparent, // Important for glass
      onSurface: Colors.white,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(colorScheme),
      scaffoldBackgroundColor: Colors.transparent, // Handled by GlassScaffold
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white.withOpacity(0.1), // Default glass card
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: neonBlue.withOpacity(0.2),
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: neonBlue,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: neonBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        selectedItemColor: neonBlue,
        unselectedItemColor: Colors.white.withOpacity(0.5),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.white.withOpacity(0.9),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.white.withOpacity(0.8),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Colors.white.withOpacity(0.6),
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.7),
      ),
    );
  }
}
