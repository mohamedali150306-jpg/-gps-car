import 'package:flutter/material.dart';

class AppTheme {
  // Deep navy / electric-blue palette inspired by the RoboCar dashboard mockup.
  static const Color bgPrimary   = Color(0xFF020B18);
  static const Color bgCard      = Color(0xFF061A2F);
  static const Color bgDeep      = Color(0xFF031226);
  static const Color borderColor = Color(0xFF123B60);
  static const Color borderBlue  = Color(0xFF075A96);

  static const Color textPrimary = Color(0xFFF2F8FF);
  static const Color textMuted   = Color(0xFF91B4D2);
  static const Color textDim     = Color(0xFF6E94B7);

  static const Color blue        = Color(0xFF087CF0);
  static const Color blueLight   = Color(0xFF73C5FF);
  static const Color blueDark    = Color(0xFF075BC6);
  static const Color bgBlue      = Color(0xFF082A4B);
  static const Color bgBlueDark  = Color(0xFF0A3B68);
  static const Color cyan        = Color(0xFF00C8FF);

  static const Color green       = Color(0xFF00E6A0);
  static const Color greenBg     = Color(0xFF06382F);
  static const Color greenBorder = Color(0xFF087B65);
  static const Color red         = Color(0xFFFF3B55);
  static const Color redBg       = Color(0xFF3A1422);
  static const Color redBorder   = Color(0xFF9F1C38);
  static const Color yellow      = Color(0xFFFFC857);
  static const Color skyBlue     = Color(0xFF38BDF8);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: const ColorScheme.dark(
      surface: bgPrimary,
      primary: blue,
      secondary: blueLight,
      error: red,
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
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF123453),
      contentTextStyle: const TextStyle(color: textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
