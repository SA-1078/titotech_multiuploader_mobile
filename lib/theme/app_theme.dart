import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de Colores TitoTech Signature Dark
  static const Color bgDark = Color(0xFF0C0A09);
  static const Color bgCard = Color(0xFF181310);
  static const Color bgCardLighter = Color(0xFF221B16);
  static const Color borderSubtle = Color(0x1FFFFFFF);
  static const Color borderFocused = Color(0x4DF97316);

  static const Color orangePrimary = Color(0xFFF97316);
  static const Color primaryOrange = Color(0xFFF97316);
  static const Color orangeGlow = Color(0x33F97316);
  static const Color greenSuccess = Color(0xFF10B981);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFFA855F7);
  static const Color redError = Color(0xFFEF4444);
  static const Color amberWarning = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFFFAFAF9);
  static const Color textSecondary = Color(0xFFA8A29E);
  static const Color textMuted = Color(0xFF78716C);
  static const Color borderMedium = Color(0x33FFFFFF);

  // Colores específicos por Proveedor de Video
  static const Color doodstreamColor = Color(0xFFF97316);
  static const Color colorDood = Color(0xFFF97316);
  static const Color streamtapeColor = Color(0xFFA855F7);
  static const Color colorTape = Color(0xFFA855F7);
  static const Color savefilesColor = Color(0xFF3B82F6);
  static const Color colorSavefiles = Color(0xFF3B82F6);
  static const Color earnvidsColor = Color(0xFF10B981);
  static const Color colorEarnvids = Color(0xFF10B981);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: orangePrimary,
        secondary: greenSuccess,
        surface: bgCard,
        error: redError,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: const Color(0xFFF5F5F4),
        displayColor: const Color(0xFFFAFAF9),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCardLighter,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: orangePrimary, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(color: const Color(0xFF78716C), fontSize: 14),
        labelStyle: GoogleFonts.outfit(color: const Color(0xFFA8A29E), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orangePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
