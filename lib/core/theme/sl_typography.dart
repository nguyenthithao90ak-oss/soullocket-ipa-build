import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import '../sl_theme.dart';

@immutable
class SLTypography {
  static TextTheme textTheme(TextTheme base) {
    final themed =
        SLTheme.textThemeForKey(UiPrefs.notifier.value.fontKey, base);
    return themed.copyWith(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      headlineLarge: headlineLarge,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }

  static TextStyle get displayLarge => SLTheme.quicksand(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w900,
        color: SLColors.textPrimary,
      );

  static TextStyle get displayMedium => SLTheme.quicksand(
        fontSize: 28,
        height: 1.22,
        fontWeight: FontWeight.w800,
        color: SLColors.textPrimary,
      );

  static TextStyle get headlineLarge => SLTheme.quicksand(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w900,
        color: SLColors.textPrimary,
      );

  static TextStyle get titleLarge => SLTheme.quicksand(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w900,
        color: SLColors.textPrimary,
      );

  static TextStyle get titleMedium => SLTheme.quicksand(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w800,
        color: SLColors.textPrimary,
      );

  static TextStyle get titleSmall => SLTheme.quicksand(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w800,
        color: SLColors.textPrimary,
      );

  static TextStyle get bodyLarge => SLTheme.quicksand(
        fontSize: 15,
        height: 1.55,
        fontWeight: FontWeight.w700,
        color: SLColors.textPrimary,
      );

  static TextStyle get bodyMedium => SLTheme.quicksand(
        fontSize: 13,
        height: 1.55,
        fontWeight: FontWeight.w700,
        color: SLColors.textSecond,
      );

  static TextStyle get bodySmall => SLTheme.quicksand(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w700,
        color: SLColors.textSecond,
      );

  static TextStyle get labelLarge => SLTheme.quicksand(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w900,
        color: SLColors.textPrimary,
      );

  static TextStyle get labelMedium => SLTheme.quicksand(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w800,
        color: SLColors.textSecond,
      );

  static TextStyle get labelSmall => SLTheme.quicksand(
        fontSize: 11,
        height: 1.35,
        fontWeight: FontWeight.w800,
        color: SLColors.textSecond,
      );

  // ─── Plus Jakarta Sans (Aurora primary font) ─────────────────────────────
  // Font hiện đại, geometric, 8 weights — dùng làm primary font mới.
  // Được trigger qua UiPrefs.fontKey = 'plusJakarta'.

  static TextTheme plusJakartaSansTextTheme(TextTheme base) {
    return GoogleFonts.plusJakartaSansTextTheme(base);
  }

  static TextStyle plusJakartaSans({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.plusJakartaSans(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  // ─── Fraunces (Aurora editorial serif font) ─────────────────────────────
  // Font serif có character, dùng cho headlines brand, milestone titles.
  // Được trigger qua UiPrefs.fontKey = 'fraunces'.

  static TextTheme frauncesTextTheme(TextTheme base) {
    return GoogleFonts.frauncesTextTheme(base);
  }

  static TextStyle fraunces({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.fraunces(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }
}

class SLTextStyles {
  // Alias to SLTypography properties for cleaner code
  static TextStyle get h1 => SLTypography.displayLarge;
  static TextStyle get h2 => SLTypography.displayMedium;
  static TextStyle get h3 => SLTypography.headlineLarge;
  static TextStyle get title => SLTypography.titleLarge;
  static TextStyle get subtitle => SLTypography.titleMedium;
  static TextStyle get body => SLTypography.bodyLarge;
  static TextStyle get bodySm => SLTypography.bodyMedium;
  static TextStyle get caption => SLTypography.bodySmall;

  static TextTheme quicksandTextTheme(TextTheme base) {
    return SLTypography.textTheme(base);
  }

  // Shortcut for SLTheme.quicksand matching the theme
  // Includes decoration and fontStyle support.
  static TextStyle quicksand({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return SLTheme.quicksand(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }
}



class SLFontOption {
  final String key;
  final String label;
  final String sampleText;

  const SLFontOption({
    required this.key,
    required this.label,
    required this.sampleText,
  });
}
