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
  static const background = Color(0xFFF9FAFB);
  static const canvas = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFAFAFA);
  static const surfaceSoft = Color(0xFFF3F4F6);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFE5E7EB);
  static const hairlineStrong = Color(0xFFD1D5DB);
  static const ink = Color(0xFF111827);
  static const charcoal = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const stone = Color(0xFF9CA3AF);
  static const primaryBlue = Color(0xFF0066CC);
  static const primaryBlueSoft = Color(0xFFE5F1FF);
  static const successGreen = Color(0xFF34C759);
  static const successGreenSoft = Color(0xFFDCFCE7);
  static const nightIndigo = Color(0xFF5856D6);
  static const nightIndigoSoft = Color(0xFFEDE9FE);
  static const warningOrange = Color(0xFFFF9500);
  static const warningOrangeSoft = Color(0xFFFFF7ED);
  static const errorRed = Color(0xFFFF3B30);
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFamily: ledgerFontFamily,
          fontFamilyFallback: ledgerFontFallback,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LedgerColors.primaryBlue,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: const BorderSide(color: LedgerColors.hairlineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: ledgerFontFamily,
          fontFamilyFallback: ledgerFontFallback,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LedgerColors.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 14,
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
