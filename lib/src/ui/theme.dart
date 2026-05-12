import 'package:flutter/material.dart';

class LedgerColors {
  static const paper = Color(0xFFF8F1E7);
  static const surface = Color(0xFFFFFCF6);
  static const surfaceSoft = Color(0xFFEFE2D1);
  static const surfaceRaised = Color(0xFFFFF8EE);
  static const hairline = Color(0xFFDFD1BF);
  static const hairlineStrong = Color(0xFFCDBBA7);
  static const ink = Color(0xFF17130F);
  static const charcoal = Color(0xFF273C35);
  static const muted = Color(0xFF6F665C);
  static const stone = Color(0xFFA99B8B);
  static const workAmber = Color(0xFFB8652F);
  static const workAmberSoft = Color(0xFFE9C29B);
  static const overtimeMoss = Color(0xFF2F765C);
  static const overtimeMossSoft = Color(0xFF98C7AC);
  static const nightSlate = Color(0xFF273C35);
  static const nightSlateSoft = Color(0xFF8EA39A);
  static const warningCopper = Color(0xFF8F4D18);
  static const errorBrick = Color(0xFF9D3D32);
  static const infoBlue = Color(0xFF5D7182);
}

ThemeData buildLedgerTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: LedgerColors.workAmber,
    brightness: Brightness.light,
    surface: LedgerColors.surface,
    primary: LedgerColors.warningCopper,
    secondary: LedgerColors.overtimeMoss,
    error: LedgerColors.errorBrick,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LedgerColors.paper,
    fontFamily: null,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: LedgerColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: LedgerColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: LedgerColors.ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: LedgerColors.ink,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: LedgerColors.muted,
      ),
    ),
    cardTheme: CardThemeData(
      color: LedgerColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: LedgerColors.hairline),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LedgerColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LedgerColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LedgerColors.warningCopper, width: 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: LedgerColors.charcoal,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
