import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _primary = Color(0xFF6C63FF);
  static const _secondary = Color(0xFF43E97B);
  static const _tertiary = Color(0xFFFF6584);
  static const _surfaceLight = Color(0xFFF6F5FF);
  static const _surfaceDark = Color(0xFF0F0E1A);
  static const _cardLight = Colors.white;
  static const _cardDark = Color(0xFF1A1830);

  static ThemeData get light => _build(
        brightness: Brightness.light,
        surface: _surfaceLight,
        card: _cardLight,
        onSurface: const Color(0xFF1A1A2E),
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        surface: _surfaceDark,
        card: _cardDark,
        onSurface: const Color(0xFFF0EEFF),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color surface,
    required Color card,
    required Color onSurface,
  }) {
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(
      seedColor: _primary,
      secondary: _secondary,
      tertiary: _tertiary,
      surface: surface,
      brightness: brightness,
    );

    final textTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: surface,

      // ── App Bar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),

      // ── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Navigation Bar ───────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        elevation: 0,
        height: 68,
        indicatorColor: _primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _primary : onSurface.withOpacity(0.5),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _primary : onSurface.withOpacity(0.45),
            size: 22,
          );
        }),
      ),

      // ── Input Decoration ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
            color: onSurface.withOpacity(0.4),
            fontSize: 14,
            fontWeight: FontWeight.w400),
      ),

      // ── Filled Button ────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Slider ───────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: _primary,
        thumbColor: _primary,
        inactiveTrackColor: _primary.withOpacity(0.2),
        overlayColor: _primary.withOpacity(0.1),
        trackHeight: 4,
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withOpacity(0.08)
            : _primary.withOpacity(0.08),
        labelStyle: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500, color: _primary),
        side: BorderSide(color: _primary.withOpacity(0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
