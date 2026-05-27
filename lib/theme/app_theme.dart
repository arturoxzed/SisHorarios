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
    // Azules
    Color(0xFF93C5FD), Color(0xFF60A5FA), Color(0xFF3B82F6),
    Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E3A8A),
    // Cielos / Celestes
    Color(0xFF7DD3FC), Color(0xFF38BDF8), Color(0xFF0EA5E9),
    Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF075985),
    // Turquesas / Cianos
    Color(0xFF67E8F9), Color(0xFF22D3EE), Color(0xFF06B6D4),
    Color(0xFF0891B2), Color(0xFF14B8A6), Color(0xFF0D9488),
    // Verdes claros
    Color(0xFFA7F3D0), Color(0xFF6EE7B7), Color(0xFF34D399),
    Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857),
    // Verdes oscuros / Lima
    Color(0xFFBEF264), Color(0xFFA3E635), Color(0xFF84CC16),
    Color(0xFF65A30D), Color(0xFF4ADE80), Color(0xFF22C55E),
    // Amarillos
    Color(0xFFFDE68A), Color(0xFFFCD34D), Color(0xFFFBBF24),
    Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309),
    // Naranjas
    Color(0xFFFDBA74), Color(0xFFFB923C), Color(0xFFF97316),
    Color(0xFFEA580C),
    // Rojos / Rosas
    Color(0xFFFCA5A5), Color(0xFFF87171), Color(0xFFEF4444),
    Color(0xFFDC2626), Color(0xFFE11D48), Color(0xFF9F1239),
    // Rosas / Fucsia
    Color(0xFFF9A8D4), Color(0xFFF472B6), Color(0xFFEC4899),
    Color(0xFFDB2777), Color(0xFFBE185D), Color(0xFF9D174D),
    // Morados claros
    Color(0xFFDDD6FE), Color(0xFFC4B5FD), Color(0xFFA78BFA),
    Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6D28D9),
    // Índigos
    Color(0xFFA5B4FC), Color(0xFF818CF8), Color(0xFF6366F1),
    Color(0xFF4F46E5), Color(0xFF4338CA), Color(0xFF3730A3),
    // Neutros cálidos / Grises
    Color(0xFFA855F7), Color(0xFF9333EA), Color(0xFF92400E),
    Color(0xFF94A3B8), Color(0xFF64748B), Color(0xFF475569),
    Color(0xFF78716C), Color(0xFF57534E),
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