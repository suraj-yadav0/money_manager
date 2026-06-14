import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Material 3 theme for Money Manager
class AppTheme {
  AppTheme._();

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color safe = narutoOrange; // Blue - safe forecast
  static const Color caution = Color(0xFFFFD700); // Minato Gold - borderline
  static const Color danger = kuramaRed; // Red - deficit

  // Category Colors for pie chart
  static const List<Color> categoryColors = [
    narutoOrange, // Naruto
    chakraBlue, // Rasengan
    kuramaRed, // Kurama
    leafGreen, // Konoha
    Color(0xFFFFD700), // Minato Gold
    Color(0xFF9D50BB), // Rinnegan Purple
    Color(0xFFFF69B4), // Sakura Pink
    Color(0xFF8B0000), // Akatsuki Red
    Color(0xFF4B0082), // Sasuke Indigo
    Color(0xFF00FA9A), // Guy Green
  ];

  // Naruto Theme Colors
  static const Color narutoOrange = Color(
    0xFFFF5F1F,
  ); // Primary - Naruto's Jacket
  static const Color chakraBlue = Color(0xFF00C6FF); // Secondary - Rasengan
  static const Color kuramaRed = Color(0xFFFF0033); // Accent - Nine Tails
  static const Color leafGreen = Color(0xFF10B981); // Success - Konoha

  // Dark Backgrounds
  static const Color glassBackgroundDark = Color(0xFF000000); // Pure Black
  static const Color glassBackgroundMedium = Color(
    0xFF1A0B05,
  ); // Dark Brownish/Orange tint
  static const Color glassBackgroundLight = Color(
    0xFF2D1606,
  ); // Lighter Orange/Brown tint

  static const Color neonBlue =
      chakraBlue; // Alias for backward compatibility if needed, but aim to replace
  static const Color neonPurple =
      narutoOrange; // Mapping purple to orange for now to switch primary feel
  static const Color neonPink = kuramaRed; // Mapping pink to red

  // Gradients
  // Light Backgrounds
  static const Color glassBackgroundWhite = Color(0xFFFFFFFF);
  static const Color glassBackgroundLightOrange = Color(
    0xFFFFF7ED,
  ); // Very light orange
  static const Color glassBackgroundCream = Color(0xFFFFF0E0); // Creamy orange

  static const LinearGradient glassGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      glassBackgroundWhite,
      glassBackgroundLightOrange,
      glassBackgroundCream,
    ],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [glassBackgroundDark, glassBackgroundMedium, glassBackgroundLight],
  );

  static const LinearGradient neonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [narutoOrange, Color(0xFFFF8C42)], // Orange gradient
  );

  /// Light Theme (Modified for Glass)
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: narutoOrange,
      brightness: Brightness.light,
      primary: narutoOrange,
      secondary: chakraBlue,
      tertiary: kuramaRed,
      surface: Colors.transparent, // Important for glass
      onSurface: Colors.black, // Dark text for light mode
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.4),
            width: 1,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        color: Colors.white.withOpacity(0.65), // Milky glass
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor:
              narutoOrange, // Solid orange for buttons in light mode
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
        backgroundColor: narutoOrange,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.05), // Dark tint for inputs
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: narutoOrange, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        selectedItemColor: narutoOrange,
        unselectedItemColor: Colors.black.withOpacity(0.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: narutoOrange,
      brightness: Brightness.dark,
      primary: narutoOrange,
      secondary: chakraBlue,
      tertiary: kuramaRed,
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
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        modalBackgroundColor: Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    final baseColor = isLight ? Colors.black : Colors.white;

    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: baseColor.withOpacity(0.9),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: baseColor.withOpacity(0.8),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: baseColor.withOpacity(0.6),
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: baseColor.withOpacity(0.7),
      ),
    );
  }
}
