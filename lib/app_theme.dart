import 'package:flutter/material.dart';

class AppTheme {
  // ── Core palette (matches HTML mockup) ──────────────────────────────────
  static const Color bgPrimary   = Color(0xFF0D1117); // darkest bg
  static const Color bgCard      = Color(0xFF111827); // card bg
  static const Color bgDeep      = Color(0xFF0D1117); // deepest / inputs
  static const Color borderColor = Color(0xFF1E293B);
  static const Color borderBlue  = Color(0xFF1E3A5F);

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textMuted   = Color(0xFF64748B);
  static const Color textDim     = Color(0xFF475569);

  // Accent – blue
  static const Color blue        = Color(0xFF3B82F6);
  static const Color blueLight   = Color(0xFF60A5FA);
  static const Color blueDark    = Color(0xFF2563EB);
  static const Color bgBlue      = Color(0xFF1A2235);
  static const Color bgBlueDark  = Color(0xFF1E3A5F);

  // State colors
  static const Color green       = Color(0xFF34D399);
  static const Color greenBg     = Color(0xFF0F3D2B);
  static const Color greenBorder = Color(0xFF065F46);
  static const Color red         = Color(0xFFF87171);
  static const Color redBg       = Color(0xFF3B1A1A);
  static const Color redBorder   = Color(0xFF7F1D1D);
  static const Color yellow      = Color(0xFFFBBF24);
  static const Color skyBlue     = Color(0xFF38BDF8);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: const ColorScheme.dark(
      surface: bgPrimary,
      primary: blue,
      secondary: blueLight,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: bgCard,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: textPrimary),
      bodySmall: TextStyle(color: textMuted),
    ),
  );
}
