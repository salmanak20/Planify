import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Planify Design System — "The Mindful Architect"
/// Based on Material 3 (Material You) with the stitch color palette.
///
/// Color coding:
///   Primary (Blue  #435f92) → Tasks
///   Secondary (Green #57634c) → Notes
///   Tertiary (Orange #7c5831) → Calendar
class AppTheme {
  AppTheme._();

  // ── Core palette ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF435F92);
  static const Color primaryContainer = Color(0xFFA5C1FB);
  static const Color onPrimary = Color(0xFFF9F8FF);
  static const Color onPrimaryContainer = Color(0xFF1D3C6D);
  static const Color primaryDim = Color(0xFF365385);
  static const Color primaryFixedDim = Color(0xFF98B4EC);

  static const Color secondary = Color(0xFF57634C);
  static const Color secondaryContainer = Color(0xFFDAE7CA);
  static const Color onSecondary = Color(0xFFF0FEDF);
  static const Color onSecondaryContainer = Color(0xFF4A553F);

  static const Color tertiary = Color(0xFF7C5831);
  static const Color tertiaryContainer = Color(0xFFFDCB9C);
  static const Color onTertiary = Color(0xFFFFF7F3);
  static const Color onTertiaryContainer = Color(0xFF63421E);

  // Surface layers (light mode — tonal layering, no borders)
  static const Color surface = Color(0xFFF8F9FA);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F4F5);
  static const Color surfaceContainer = Color(0xFFEBEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE5E9EB);
  static const Color surfaceContainerHighest = Color(0xFFDEE3E6);
  static const Color surfaceDim = Color(0xFFD5DBDD);

  static const Color onSurface = Color(0xFF2D3335);
  static const Color onSurfaceVariant = Color(0xFF5A6062);
  static const Color outline = Color(0xFF767C7E);
  static const Color outlineVariant = Color(0xFFADB3B5);

  static const Color error = Color(0xFFA83836);
  static const Color errorContainer = Color(0xFFFA746F);
  static const Color onError = Color(0xFFFFF7F6);
  static const Color onErrorContainer = Color(0xFF6E0A12);

  // Dark mode surfaces
  static const Color surfaceDark = Color(0xFF0C0F10);
  static const Color surfaceContainerDark = Color(0xFF1A1F21);
  static const Color surfaceContainerLowDark = Color(0xFF141819);
  static const Color onSurfaceDark = Color(0xFFE2E5E6);

  // Special — Focus Mode gradient
  static const Color focusBg1 = Color(0xFF0C0F10);
  static const Color focusBg2 = Color(0xFF1D3C6D);

  // ── Light theme ─────────────────────────────────────────────────────────────
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: _buildTextTheme(onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: onSurface,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryContainer,
        foregroundColor: onPrimaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceContainerLowest.withAlpha(230),
        indicatorColor: secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerHigh,
        labelStyle:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: const DividerThemeData(
          space: 0, thickness: 0, color: Colors.transparent),
      extensions: const [PlanifyColors()],
    );
  }

  // ── Dark theme ──────────────────────────────────────────────────────────────
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryFixedDim,
      onPrimary: focusBg2,
      primaryContainer: primaryDim,
      onPrimaryContainer: primaryFixedDim,
      secondary: Color(0xFFCCD9BC),
      onSecondary: Color(0xFF2E3A25),
      secondaryContainer: Color(0xFF404E35),
      onSecondaryContainer: Color(0xFFDAE7CA),
      tertiary: Color(0xFFEDBD8F),
      onTertiary: Color(0xFF3E2508),
      tertiaryContainer: Color(0xFF5C3C18),
      onTertiaryContainer: Color(0xFFFDCB9C),
      error: Color(0xFFFA746F),
      onError: Color(0xFF4A0007),
      errorContainer: Color(0xFF6E0A12),
      onErrorContainer: Color(0xFFFA746F),
      surface: surfaceDark,
      onSurface: onSurfaceDark,
      surfaceContainerLowest: Color(0xFF080B0C),
      surfaceContainerLow: surfaceContainerLowDark,
      surfaceContainer: surfaceContainerDark,
      surfaceContainerHigh: Color(0xFF212628),
      surfaceContainerHighest: Color(0xFF2B3032),
      onSurfaceVariant: Color(0xFFBEC5C7),
      outline: Color(0xFF8A9092),
      outlineVariant: Color(0xFF3F4547),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceDark,
      textTheme: _buildTextTheme(onSurfaceDark),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: onSurfaceDark,
        ),
        iconTheme: const IconThemeData(color: onSurfaceDark),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF141819),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryDim,
        foregroundColor: primaryFixedDim,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      extensions: const [PlanifyColors()],
    );
  }

  // ── Typography ───────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      // Manrope for display & headlines
      displayLarge: GoogleFonts.manrope(
          fontSize: 57,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -1.5),
      displayMedium: GoogleFonts.manrope(
          fontSize: 45,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -1),
      displaySmall: GoogleFonts.manrope(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.5),
      headlineLarge: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.5),
      headlineMedium: GoogleFonts.manrope(
          fontSize: 28, fontWeight: FontWeight.w700, color: color),
      headlineSmall: GoogleFonts.manrope(
          fontSize: 24, fontWeight: FontWeight.w700, color: color),
      titleLarge: GoogleFonts.manrope(
          fontSize: 22, fontWeight: FontWeight.w600, color: color),
      titleMedium: GoogleFonts.manrope(
          fontSize: 16, fontWeight: FontWeight.w600, color: color),
      titleSmall: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w600, color: color),
      // Inter for body & labels
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: color),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: color),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: color),
      labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: color),
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: color),
      labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5),
    );
  }
}

/// Custom theme extension for Planify-specific color tokens.
@immutable
class PlanifyColors extends ThemeExtension<PlanifyColors> {
  const PlanifyColors({
    this.focusBg1 = AppTheme.focusBg1,
    this.focusBg2 = AppTheme.focusBg2,
    this.surfaceContainerLowest = AppTheme.surfaceContainerLowest,
    this.primaryDim = AppTheme.primaryDim,
  });

  final Color focusBg1;
  final Color focusBg2;
  final Color surfaceContainerLowest;
  final Color primaryDim;

  @override
  PlanifyColors copyWith({
    Color? focusBg1,
    Color? focusBg2,
    Color? surfaceContainerLowest,
    Color? primaryDim,
  }) =>
      PlanifyColors(
        focusBg1: focusBg1 ?? this.focusBg1,
        focusBg2: focusBg2 ?? this.focusBg2,
        surfaceContainerLowest:
            surfaceContainerLowest ?? this.surfaceContainerLowest,
        primaryDim: primaryDim ?? this.primaryDim,
      );

  @override
  PlanifyColors lerp(PlanifyColors? other, double t) {
    if (other == null) return this;
    return PlanifyColors(
      focusBg1: Color.lerp(focusBg1, other.focusBg1, t)!,
      focusBg2: Color.lerp(focusBg2, other.focusBg2, t)!,
      surfaceContainerLowest:
          Color.lerp(surfaceContainerLowest, other.surfaceContainerLowest, t)!,
      primaryDim: Color.lerp(primaryDim, other.primaryDim, t)!,
    );
  }
}
