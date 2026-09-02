import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vibrant, ultra-fast Premium Fintech Design System
class AppTheme {
  AppTheme._();

  // Signature Brand Accents
  static const Color narutoOrange = Color(0xFFFF5F1F); // Electric Orange Primary
  static const Color electricAmber = Color(0xFFFFB300); // Warm Amber
  static const Color chakraBlue = Color(0xFF00C6FF); // Rasengan Cyan
  static const Color kuramaRed = Color(0xFFFF2A4B); // Vibrant Coral Red
  static const Color leafGreen = Color(0xFF10B981); // Emerald Mint Green
  static const Color rinneganPurple = Color(0xFFA855F7); // Purple

  // Semantic Aliases
  static const Color success = leafGreen;
  static const Color warning = electricAmber;
  static const Color error = kuramaRed;
  static const Color danger = kuramaRed;
  static const Color safe = leafGreen;
  static const Color caution = electricAmber;

  // Modern Category Colors
  static const List<Color> categoryColors = [
    narutoOrange,
    chakraBlue,
    leafGreen,
    electricAmber,
    rinneganPurple,
    kuramaRed,
    Color(0xFF38BDF8),
    Color(0xFFF472B6),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
  ];

  // Deep Space Obsidian Dark Surfaces
  static const Color bgMainDark = Color(0xFF0B0C12);
  static const Color bgSurfaceDark = Color(0xFF13151F);
  static const Color bgSurfaceElevatedDark = Color(0xFF1C1E2C);
  static const Color borderDark = Color(0x1FFFFFFF); // 12% white
  static const Color borderHoverDark = Color(0x3DFFFFFF); // 24% white
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA1A7C4);
  static const Color textMutedDark = Color(0xFF6B7294);

  // Studio Clean Light Surfaces
  static const Color bgMainLight = Color(0xFFF6F8FC);
  static const Color bgSurfaceLight = Color(0xFFFFFFFF);
  static const Color bgSurfaceElevatedLight = Color(0xFFEEF2F8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderHoverLight = Color(0xFFCBD5E1);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Vibrant Premium Gradients
  static const LinearGradient heroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF5F1F),
      Color(0xFFFF3B30),
      Color(0xFFE02B20),
    ],
  );

  static const LinearGradient neonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [narutoOrange, Color(0xFFFF8C42)],
  );

  static const LinearGradient glassGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B0C12), Color(0xFF0F1118), Color(0xFF13151F)],
  );

  static const LinearGradient glassGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF6F8FC), Color(0xFFFFFFFF), Color(0xFFEEF2F8)],
  );

  // Aliases for compatibility
  static const LinearGradient glassGradient = glassGradientDark;
  static const Color glassBackgroundDark = bgMainDark;
  static const Color glassBackgroundWhite = bgMainLight;

  /// High-Performance Light Theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: narutoOrange,
      brightness: Brightness.light,
      primary: narutoOrange,
      secondary: chakraBlue,
      tertiary: rinneganPurple,
      surface: bgSurfaceLight,
      onSurface: textPrimaryLight,
      error: kuramaRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(colorScheme),
      scaffoldBackgroundColor: bgMainLight,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimaryLight,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        color: bgSurfaceLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: narutoOrange,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: narutoOrange,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurfaceElevatedLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: narutoOrange, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: textMutedLight),
      ),
    );
  }

  /// High-Performance Midnight Space Dark Theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: narutoOrange,
      brightness: Brightness.dark,
      primary: narutoOrange,
      secondary: chakraBlue,
      tertiary: rinneganPurple,
      surface: bgSurfaceDark,
      onSurface: textPrimaryDark,
      error: kuramaRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(colorScheme),
      scaffoldBackgroundColor: bgMainDark,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimaryDark,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderDark, width: 1),
        ),
        color: bgSurfaceDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: narutoOrange,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: narutoOrange,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurfaceElevatedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: narutoOrange, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: textMutedDark),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    final baseColor = isLight ? textPrimaryLight : textPrimaryDark;

    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 54,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 42,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
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
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: baseColor.withValues(alpha: 0.9),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.normal,
        color: baseColor.withValues(alpha: 0.8),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: baseColor.withValues(alpha: 0.6),
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
        color: baseColor.withValues(alpha: 0.7),
      ),
    );
  }
}
