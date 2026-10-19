import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Curated Fintech Palettes inspired by premier iOS finance applications
enum FintechPalette {
  credObsidian(
    id: 'cred_obsidian',
    displayName: 'CRED Obsidian',
    subtitle: 'Tactile OLED Dark Luxury',
    primaryLight: Color(0xFF111111),
    primaryDark: Color(0xFFFFFFFF),
    accentColor: Color(0xFF18181B),
    darkSurface: Color(0xFF121216),
    darkSurfaceElevated: Color(0xFF1A1A22),
    swatchColor: Color(0xFF18181B),
  ),
  growwEmerald(
    id: 'groww_emerald',
    displayName: 'Groww Emerald',
    subtitle: 'High-Clarity Mint Growth',
    primaryLight: Color(0xFF00B386),
    primaryDark: Color(0xFF00D09C),
    accentColor: Color(0xFF00D09C),
    darkSurface: Color(0xFF0E1713),
    darkSurfaceElevated: Color(0xFF15241E),
    swatchColor: Color(0xFF00D09C),
  ),
  zerodhaBlue(
    id: 'zerodha_blue',
    displayName: 'Zerodha Blue',
    subtitle: 'Kite Institutional Cobalt',
    primaryLight: Color(0xFF387ED1),
    primaryDark: Color(0xFF4790E6),
    accentColor: Color(0xFF4790E6),
    darkSurface: Color(0xFF0F1522),
    darkSurfaceElevated: Color(0xFF172033),
    swatchColor: Color(0xFF387ED1),
  ),
  jupiterIndigo(
    id: 'jupiter_indigo',
    displayName: 'Jupiter Indigo',
    subtitle: 'Modern Neo-Banking Iris',
    primaryLight: Color(0xFF5E43F3),
    primaryDark: Color(0xFF7B68EE),
    accentColor: Color(0xFF7B68EE),
    darkSurface: Color(0xFF121020),
    darkSurfaceElevated: Color(0xFF1B1830),
    swatchColor: Color(0xFF5E43F3),
  ),
  fiGold(
    id: 'fi_gold',
    displayName: 'Fi Sunset Gold',
    subtitle: 'Refined Metallic Wealth',
    primaryLight: Color(0xFFD97706),
    primaryDark: Color(0xFFF59E0B),
    accentColor: Color(0xFFF59E0B),
    darkSurface: Color(0xFF16130C),
    darkSurfaceElevated: Color(0xFF221D12),
    swatchColor: Color(0xFFF59E0B),
  );

  final String id;
  final String displayName;
  final String subtitle;
  final Color primaryLight;
  final Color primaryDark;
  final Color accentColor;
  final Color darkSurface;
  final Color darkSurfaceElevated;
  final Color swatchColor;

  const FintechPalette({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.primaryLight,
    required this.primaryDark,
    required this.accentColor,
    required this.darkSurface,
    required this.darkSurfaceElevated,
    required this.swatchColor,
  });

  static FintechPalette fromId(String? id) {
    return FintechPalette.values.firstWhere(
      (p) => p.id == id,
      orElse: () => FintechPalette.credObsidian,
    );
  }
}

/// iOS-Grade Minimalist Fintech Design System
class AppTheme {
  AppTheme._();

  // Universal Semantic Financial Indicators
  static const Color incomeGreen = Color(0xFF30D158); // Soft Apple Mint Green
  static const Color expenseRed = Color(0xFFFF453A); // Coral Crimson
  static const Color warningAmber = Color(0xFFFF9F0A); // Apple Amber

  // Aliases for compatibility
  static const Color success = incomeGreen;
  static const Color danger = expenseRed;
  static const Color error = expenseRed;
  static const Color warning = warningAmber;
  static const Color safe = incomeGreen;
  static const Color caution = warningAmber;

  // Primary Default Brand Accent (CRED Obsidian / Minimalist)
  static const Color narutoOrange = Color(0xFF007AFF); // Legacy alias mapped to iOS Blue
  static const Color electricAmber = warningAmber;
  static const Color chakraBlue = Color(0xFF4790E6);
  static const Color kuramaRed = expenseRed;
  static const Color leafGreen = incomeGreen;
  static const Color rinneganPurple = Color(0xFF7B68EE);

  // Modern Category Colors
  static const List<Color> categoryColors = [
    Color(0xFF387ED1), // Zerodha Blue
    Color(0xFF00D09C), // Groww Mint
    Color(0xFF7B68EE), // Jupiter Iris
    Color(0xFFF59E0B), // Fi Amber
    Color(0xFFFF453A), // Coral Red
    Color(0xFF30D158), // Apple Green
    Color(0xFF0A84FF), // Cobalt
    Color(0xFFA78BFA), // Lavender
    Color(0xFF38BDF8), // Sky Blue
    Color(0xFFF472B6), // Rose
  ];

  // OLED Canvas Dark Surfaces
  static const Color bgMainDark = Color(0xFF050507);
  static const Color bgSurfaceDark = Color(0xFF121216);
  static const Color bgSurfaceElevatedDark = Color(0xFF1C1C22);
  static const Color borderDark = Color(0x1FFFFFFF); // 12% white
  static const Color borderHoverDark = Color(0x33FFFFFF); // 20% white
  static const Color textPrimaryDark = Color(0xFFF5F5F7);
  static const Color textSecondaryDark = Color(0xFF9E9EA7);
  static const Color textMutedDark = Color(0xFF6B6B76);

  // Studio Clean Light Surfaces
  static const Color bgMainLight = Color(0xFFF4F5F8);
  static const Color bgSurfaceLight = Color(0xFFFFFFFF);
  static const Color bgSurfaceElevatedLight = Color(0xFFF0F1F5);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderHoverLight = Color(0xFFD1D5DB);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Clean Subtle Gradients
  static const LinearGradient glassGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF050507), Color(0xFF0D0D11), Color(0xFF121216)],
  );

  static const LinearGradient glassGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4F5F8), Color(0xFFFFFFFF), Color(0xFFEEF0F5)],
  );

  static const LinearGradient neonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient heroCardGradient = glassGradientDark;
  static const LinearGradient glassGradient = glassGradientDark;
  static const Color glassBackgroundDark = bgMainDark;
  static const Color glassBackgroundWhite = bgMainLight;

  /// Default Light Theme
  static ThemeData get lightTheme => buildTheme(FintechPalette.credObsidian, Brightness.light);

  /// Default Dark Theme
  static ThemeData get darkTheme => buildTheme(FintechPalette.credObsidian, Brightness.dark);

  /// Dynamic Theme Builder for curated Fintech Palettes
  static ThemeData buildTheme(FintechPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark ? palette.primaryDark : palette.primaryLight;
    final canvasColor = isDark ? bgMainDark : bgMainLight;
    final surfaceColor = isDark ? palette.darkSurface : bgSurfaceLight;
    final surfaceElevated = isDark ? palette.darkSurfaceElevated : bgSurfaceElevatedLight;
    final textPrimary = isDark ? textPrimaryDark : textPrimaryLight;
    final textSecondary = isDark ? textSecondaryDark : textSecondaryLight;
    final textMuted = isDark ? textMutedDark : textMutedLight;
    final borderColor = isDark ? const Color(0x1AFFFFFF) : borderLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primaryColor,
      secondary: palette.accentColor,
      surface: surfaceColor,
      onSurface: textPrimary,
      error: expenseRed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: _textTheme(colorScheme, textPrimary, textSecondary, textMuted),
      scaffoldBackgroundColor: canvasColor,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor, width: 0.8),
        ),
        color: surfaceColor,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 0.8,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: primaryColor,
          foregroundColor: (palette == FintechPalette.credObsidian && isDark)
              ? const Color(0xFF09090B)
              : Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: primaryColor,
        foregroundColor: (palette == FintechPalette.credObsidian && isDark)
            ? const Color(0xFF09090B)
            : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        hintStyle: TextStyle(color: textMuted, fontSize: 14),
      ),
    );
  }

  static TextTheme _textTheme(
    ColorScheme colorScheme,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        letterSpacing: -0.2,
        color: textPrimary.withValues(alpha: 0.9),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.normal,
        letterSpacing: -0.1,
        color: textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textMuted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: textMuted,
      ),
    );
  }
}
