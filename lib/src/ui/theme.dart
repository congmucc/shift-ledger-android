import 'package:flutter/material.dart';

const double ledgerContentMaxWidth = 960;
const String ledgerFontFamily = 'ShiftLedgerCJK';
const List<String> ledgerFontFallback = [
  'PingFang SC',
  'Hiragino Sans GB',
  'Heiti SC',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Microsoft YaHei',
  'Arial Unicode MS',
  'sans-serif',
];

class LedgerColors {
  static const background = Color(0xFFFCFDFF);
  static const canvas = Color(0xFFEEF2F6);
  static const surface = Color(0xFFFAFAFA);
  static const surfaceSoft = Color(0xFFF7F9FC);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFE5E8EE);
  static const hairlineStrong = Color(0xFFD2D8E2);
  static const ink = Color(0xFF0F172A);
  static const charcoal = Color(0xFF0F172A);
  static const muted = Color(0xFF667085);
  static const stone = Color(0xFF98A2B3);
  static const primaryBlue = Color(0xFF0B66D0);
  static const primaryBlueSoft = Color(0xFFE5F1FF);
  static const successGreen = Color(0xFF22A65A);
  static const successGreenSoft = Color(0xFFE6F8EC);
  static const nightIndigo = Color(0xFF5B57D6);
  static const nightIndigoSoft = Color(0xFFEEEAFF);
  static const warningOrange = Color(0xFFF79009);
  static const warningOrangeSoft = Color(0xFFFFF4DF);
  static const errorRed = Color(0xFFE5484D);
  static const errorRedSoft = Color(0xFFFEE2E2);
  static const paper = background;
  static const workAmber = primaryBlue;
  static const workAmberSoft = primaryBlueSoft;
  static const overtimeMoss = successGreen;
  static const overtimeMossSoft = successGreenSoft;
  static const nightSlate = nightIndigo;
  static const nightSlateSoft = nightIndigoSoft;
  static const warningCopper = warningOrange;
  static const errorBrick = errorRed;
  static const infoBlue = primaryBlue;
}

ThemeData buildLedgerTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: LedgerColors.primaryBlue,
    brightness: Brightness.light,
    surface: LedgerColors.surfaceRaised,
    primary: LedgerColors.primaryBlue,
    secondary: LedgerColors.successGreen,
    error: LedgerColors.errorRed,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LedgerColors.background,
    fontFamily: ledgerFontFamily,
    fontFamilyFallback: ledgerFontFallback,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        color: LedgerColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: LedgerColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: LedgerColors.ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: LedgerColors.ink,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: LedgerColors.muted,
      ),
    ),
    cardTheme: CardThemeData(
      color: LedgerColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LedgerColors.hairline),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LedgerColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      helperMaxLines: 2,
      labelStyle: const TextStyle(color: LedgerColors.muted),
      helperStyle: const TextStyle(
        color: LedgerColors.muted,
        fontSize: 12,
        height: 1.35,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LedgerColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LedgerColors.hairline),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LedgerColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LedgerColors.primaryBlue, width: 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: LedgerColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LedgerColors.primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: ledgerFontFamily,
          fontFamilyFallback: ledgerFontFallback,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LedgerColors.primaryBlue,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        side: const BorderSide(color: LedgerColors.hairlineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: ledgerFontFamily,
          fontFamilyFallback: ledgerFontFallback,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LedgerColors.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: ledgerFontFamily,
          fontFamilyFallback: ledgerFontFallback,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: LedgerColors.muted,
        selectedForegroundColor: LedgerColors.primaryBlue,
        backgroundColor: LedgerColors.surfaceRaised,
        selectedBackgroundColor: LedgerColors.primaryBlueSoft,
        side: const BorderSide(color: LedgerColors.hairlineStrong),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: ledgerFontFamily,
          fontFamilyFallback: ledgerFontFallback,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LedgerColors.paper,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
