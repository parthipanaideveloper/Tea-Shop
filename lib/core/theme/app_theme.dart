import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Color Palette
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color primaryAccent = Color(0xFF3B82F6); // Blue 500
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceWhite = Colors.white;

  static ThemeData get enterpriseTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAccent,
        primary: primaryAccent,
        secondary: const Color(0xFF10B981), // Emerald
        surface: surfaceWhite,
        surfaceContainerLowest: backgroundLight),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineSmall: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: primaryDark),
        titleLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: primaryDark),
        titleMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: primaryDark),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF334155))),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primaryDark),
        centerTitle: true),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1), // Soft Slate border
        )),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          shadowColor: primaryAccent.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAccent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16)));
  }

  static ThemeData get masterAdminTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.amber,
        primary: Colors.amber,
        secondary: Colors.orange,
        surface: Colors.black,
        surfaceContainerLowest: const Color(0xFF111111)),
      scaffoldBackgroundColor: const Color(0xFF111111),
      textTheme: GoogleFonts.interTextTheme()
          .copyWith(
            headlineSmall: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.amber),
            titleLarge: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Colors.amber),
            titleMedium: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.amber),
            bodyLarge: GoogleFonts.inter(color: Colors.white70),
            bodyMedium: GoogleFonts.inter(color: Colors.white70))
          .apply(bodyColor: Colors.white, displayColor: Colors.amber),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.amber),
        actionsIconTheme: IconThemeData(color: Colors.amber),
        centerTitle: true),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.amber, width: 0.5))),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          shadowColor: Colors.amber.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.amber, width: 2)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16),
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white30)),
      iconTheme: const IconThemeData(color: Colors.amber));
  }
}
