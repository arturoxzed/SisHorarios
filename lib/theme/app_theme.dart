import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF7C3AED);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarSelected = Color(0xFF1E3A5F);

  static const List<Color> subjectColors = [
    // Blues
    Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF0EA5E9), Color(0xFF06B6D4),
    // Greens
    Color(0xFF10B981), Color(0xFF059669), Color(0xFF84CC16), Color(0xFF4ADE80),
    // Yellows / Oranges
    Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFD97706),
    // Reds / Pinks
    Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFE11D48), Color(0xFFEC4899),
    Color(0xFFF472B6), Color(0xFFBE185D),
    // Purples
    Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6366F1), Color(0xFF4F46E5),
    Color(0xFFA855F7), Color(0xFF9333EA),
    // Teals / Cyans
    Color(0xFF14B8A6), Color(0xFF0D9488), Color(0xFF22D3EE),
    // Browns / Neutrals
    Color(0xFF92400E), Color(0xFF78716C), Color(0xFF475569),
  ];

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}