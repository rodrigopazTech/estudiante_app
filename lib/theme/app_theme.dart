import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Light Mode (Kinetic Scholar - original) ───────────────────────────────
  static const Color lightPrimary       = Color(0xFF0058BC);
  static const Color lightOnPrimary     = Colors.white;
  static const Color lightBackground    = Color(0xFFF9F9FF);
  static const Color lightSurface       = Color(0xFFF9F9FF);
  static const Color lightSurfaceCard   = Color(0xFFF1F3FE);
  static const Color lightOnSurface     = Color(0xFF181C23);
  static const Color lightOnSurfaceSub  = Color(0xFF414755);
  static const Color lightTertiary      = Color(0xFF006B27);
  static const Color lightSecondary     = Color(0xFF405E96);
  static const Color lightNavIndicator  = Color(0xFFA1BEFD);

  // ─── Dark Mode (Cobalt Depth) ───────────────────────────────────────────────
  static const Color darkBackground     = Color(0xFF0A1628);
  static const Color darkSurface        = Color(0xFF0A1628);
  static const Color darkSurfaceCard    = Color(0xFF0F2044);
  static const Color darkSurfaceCard2   = Color(0xFF152652);
  static const Color darkPrimary        = Color(0xFF00D4FF);
  static const Color darkOnPrimary      = Color(0xFF001820);
  static const Color darkOnSurface      = Color(0xFFE8F4FF);
  static const Color darkOnSurfaceSub   = Color(0xFF7BA3C4);
  static const Color darkTertiary       = Color(0xFF00E5B0);
  static const Color darkSecondary      = Color(0xFF4A90D9);
  static const Color darkNavIndicator   = Color(0xFF1A3A6B);

  // ─── Text themes ───────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color onSurface) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(color: onSurface),
      bodyMedium: GoogleFonts.inter(color: onSurface),
    );
  }

  // ─── Light ThemeData ────────────────────────────────────────────────────────
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary:            lightPrimary,
      onPrimary:          lightOnPrimary,
      secondary:          lightSecondary,
      onSecondary:        Colors.white,
      tertiary:           lightTertiary,
      onTertiary:         Colors.white,
      error:              Color(0xFFBA1A1A),
      onError:            Colors.white,
      surface:            lightSurface,
      onSurface:          lightOnSurface,
      surfaceContainerLow:    lightSurfaceCard,
      surfaceContainerLowest: Colors.white,
    ),
    scaffoldBackgroundColor: lightBackground,
    textTheme: _buildTextTheme(lightOnSurface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightBackground,
      indicatorColor: lightNavIndicator,
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: lightSurfaceCard,
      foregroundColor: lightOnSurface,
      elevation: 0,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: lightOnSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );

  // ─── Dark ThemeData (Cobalt Depth) ─────────────────────────────────────────
  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary:            darkPrimary,
      onPrimary:          darkOnPrimary,
      secondary:          darkSecondary,
      onSecondary:        Colors.white,
      tertiary:           darkTertiary,
      onTertiary:         Color(0xFF001A12),
      error:              Color(0xFFFF6B6B),
      onError:            Color(0xFF000000),
      surface:            darkSurface,
      onSurface:          darkOnSurface,
      surfaceContainerLow:    darkSurfaceCard,
      surfaceContainerLowest: darkSurfaceCard2,
    ),
    scaffoldBackgroundColor: darkBackground,
    textTheme: _buildTextTheme(darkOnSurface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurfaceCard,
      indicatorColor: darkNavIndicator,
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: darkOnSurface,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurfaceCard,
      foregroundColor: darkOnSurface,
      elevation: 0,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: darkOnSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkSurfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
