import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

/// ============================================================
/// SoulLocket Design System 2026
/// Dịch 1:1 từ design-system-2026.css + modern-ui.css + screens.css
/// Inspired by Apple HIG & Material Design 3
/// ============================================================

extension SLCurves on Curves {
  static const Curve easeOutQuicksand = Cubic(0.23, 1, 0.32, 1);
  static const Curve easeInQuicksand = Cubic(0.755, 0.05, 0.855, 0.06);
}

class SLColors {
  // ─── Primary Brand (Love Journal: berry ink & warm peach) ──────────
  static const primary = Color(0xFFE65372);
  static const primaryHover = Color(0xFFD94766);
  static const primaryActive = Color(0xFFC93B59);
  static const primaryLight = Color(0xFFFFF3F5);
  static const secondary = Color(0xFFF4A37A);
  static const primarySoft = Color(0xFFFFE4E9);
  static const secondarySoft = Color(0xFFFFEBDD);
  static const tertiarySoft = Color(0xFFF0EAFB);
  static const surfaceWarm = Color(0xFFFFF8F0);
  static const textInverse = Color(0xFFFCFCFD);

  // Love Journal surfaces. These tokens intentionally avoid the blue-white
  // glass palette that makes many generated interfaces look interchangeable.
  static const paperCanvas = Color(0xFFF8EEE3);
  static const paper = Color(0xFFFFFDF8);
  static const paperBlush = Color(0xFFFFF1F1);
  static const paperPeach = Color(0xFFFFE9D7);
  static const ink = Color(0xFF3B2830);
  static const thread = Color(0xFFD96B7C);
  static const washi = Color(0xFFFFD2B8);

  // Cute accent palette
  static const accentPink = Color(0xFFED7F93);
  static const accentPurple = Color(0xFFB7A1E6);
  static const accentPurpleDark = Color(0xFF8066B8);
  static const accentBlueSoft = Color(0xFFC7E4EA);
  static const accent = accentPink;

  // ─── Semantic (Pastel Cute) ───────────────────────────────────
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFECFDF5);
  static const warning = Color(0xFFFFB020);
  static const warningLight = Color(0xFFFFFBEB);
  static const warningGold = Color(0xFFFFD166);
  static const danger = Color(0xFFFF5E7E);
  static const dangerLight = Color(0xFFFFF1F2);
  static const info = Color(0xFF38BDF8);
  static const infoLight = Color(0xFFF0F9FF);

  // ─── Neutral (Cute Warm Milk Tone) ────────────────────────────
  static const bgMain = surfaceWarm;
  static const bgCard = paper;
  static const bgElevated = paper;
  static const bgMuted = Color(0xFFF3E9DF);
  static const bgSubtle = Color(0xFFFBF4EC);
  static const textPrimary = ink;
  static const textSecond = Color(0xFF79646D);
  static const textSecondary = textSecond;
  static const textTertiary = Color(0xFFA28F96);
  static const border = Color(0xFFE8D7CE);
  static const borderLight = Color(0xFFF2E7DF);

  // ─── Dark Mode ────────────────────────────────────────────────
  static const darkBgMain = Color(0xFF1E1A22);
  static const darkBgCard = Color(0xFF2A2430);
  static const darkBgElevated = Color(0xFF383040);
  static const darkTextPrimary = Color(0xFFFAF5F8);
  static const darkTextSecond = Color(0xFFB5A8B2);
  static const darkBorder = Color(0xFF403648);

  // ─── Brand Legacy ──
  static const brandPink = primary;
  static const darkNavy = Color(0xFF1E1A22);
  static const textMuted = Color(0xFFB5A8B2);
  static const textMedium = Color(0xFF5E5056);

  // ─── Gradients (Cute Soft Transitions) ────────────────────────
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFFFF5E7E), Color(0xFFFF85A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFFF6D6), Color(0xFFFFE699)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SLRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 9999.0;

  static BorderRadius smAll = BorderRadius.circular(sm);
  static BorderRadius mdAll = BorderRadius.circular(md);
  static BorderRadius lgAll = BorderRadius.circular(lg);
  static BorderRadius xlAll = BorderRadius.circular(xl);
  static BorderRadius pillAll = BorderRadius.circular(pill);
}

class SLSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const all4 = EdgeInsets.all(xxs);
  static const all8 = EdgeInsets.all(xs);
  static const all12 = EdgeInsets.all(sm);
  static const all16 = EdgeInsets.all(md);
  static const all20 = EdgeInsets.all(lg);
  static const all24 = EdgeInsets.all(xl);
  static const all32 = EdgeInsets.all(xxl);

  static const h4 = SizedBox(height: xxs);
  static const h6 = SizedBox(height: 6);
  static const h8 = SizedBox(height: xs);
  static const h10 = SizedBox(height: 10);
  static const h12 = SizedBox(height: sm);
  static const h16 = SizedBox(height: md);
  static const h20 = SizedBox(height: lg);
  static const h24 = SizedBox(height: xl);
  static const h32 = SizedBox(height: xxl);

  static const w4 = SizedBox(width: xxs);
  static const w8 = SizedBox(width: xs);
  static const w10 = SizedBox(width: 10);
  static const w12 = SizedBox(width: sm);
  static const w16 = SizedBox(width: md);
  static const w20 = SizedBox(width: lg);
  static const w24 = SizedBox(width: xl);
  static const w32 = SizedBox(width: xxl);

  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);
  }

  static EdgeInsets symmetric({double horizontal = 0, double vertical = 0}) {
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static EdgeInsets fromLTRB(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  static SizedBox gapH(double value) => SizedBox(height: value);
  static SizedBox gapW(double value) => SizedBox(width: value);
}

class SLDurations {
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 150);
  static const quick = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 250);
  static const moderate = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const verySlow = Duration(milliseconds: 1500);

  static const second = Duration(seconds: 1);
  static const twoSeconds = Duration(seconds: 2);
  static const threeSeconds = Duration(seconds: 3);
  static const fourSeconds = Duration(seconds: 4);
  static const fiveSeconds = Duration(seconds: 5);
  static const eightSeconds = Duration(seconds: 8);
  static const tenSeconds = Duration(seconds: 10);
  static const twelveSeconds = Duration(seconds: 12);
  static const fifteenSeconds = Duration(seconds: 15);
  static const twentySeconds = Duration(seconds: 20);

  static const minute = Duration(minutes: 1);
  static const fiveMinutes = Duration(minutes: 5);
}

class SLResponsive {
  static const double compact = 380;
  static const double handset = 600;
  static const double tablet = 840;
  static const double desktop = 1200;
  static const double _designWidth = 390;

  static bool isCompactWidth(double width) => width < compact;
  static bool isTabletWidth(double width) => width >= tablet;

  static double scaleForWidth(
    double width, {
    double min = 0.88,
    double max = 1.12,
  }) {
    if (width <= 0) return 1;
    return (width / _designWidth).clamp(min, max).toDouble();
  }

  static double dp(
    double value,
    double width, {
    double min = 0.88,
    double max = 1.12,
  }) {
    return value * scaleForWidth(width, min: min, max: max);
  }

  static double sp(
    double value,
    double width, {
    double min = 0.92,
    double max = 1.10,
  }) {
    return value * scaleForWidth(width, min: min, max: max);
  }

  static TextScaler textScalerFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scaled = scaler.scale(1);
    return TextScaler.linear(scaled.clamp(0.9, 1.18).toDouble());
  }

  static double horizontalPaddingForWidth(
    double width, {
    double compactPadding = 14,
    double handsetPadding = 18,
    double tabletPadding = 24,
    double desktopPadding = 32,
  }) {
    if (width >= desktop) return desktopPadding;
    if (width >= tablet) return tabletPadding;
    if (width >= handset) return handsetPadding;
    return compactPadding;
  }

  static double maxContentWidthForWidth(
    double width, {
    double handsetMax = 520,
    double tabletMax = 860,
    double desktopMax = 1080,
  }) {
    if (width >= desktop) return desktopMax;
    if (width >= tablet) return tabletMax;
    return handsetMax;
  }

  static double clampPanelWidth(
    double width, {
    double max = 520,
    double compactGutter = 20,
    double gutter = 32,
  }) {
    final available = math.max(
      280.0,
      width - (isCompactWidth(width) ? compactGutter : gutter),
    );
    return math.min(available, max).toDouble();
  }

  /// Scroll physics adaptive theo nền tảng:
  /// - iOS: BouncingScrollPhysics (kéo over-scroll)
  /// - Android/web: ClampingScrollPhysics (kẹt cứng)
  static ScrollPhysics scrollPhysicsForPlatform() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const BouncingScrollPhysics();
    }
    return const ClampingScrollPhysics();
  }
}

@immutable
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

class SLTypography {
  static TextTheme textTheme(TextTheme base) {
    final themed = SLTheme.textThemeForKey(
      UiPrefs.notifier.value.fontKey,
      base,
    );
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
}

class SLShadow {
  static List<BoxShadow> sm = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> md = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> lg = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 15,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glass = [
    BoxShadow(
      color: const Color(0xFF1F2687).withValues(alpha: 0.08),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> primary = [
    BoxShadow(
      color: SLColors.primary.withValues(alpha: 0.30),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> subtle = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> paper = [
    BoxShadow(
      color: const Color(0xFF6E3E45).withValues(alpha: 0.08),
      blurRadius: 22,
      spreadRadius: -8,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.84),
      blurRadius: 0,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> gold = [
    BoxShadow(
      color: SLColors.warningGold.withValues(alpha: 0.35),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];
}

/// ─── Main Theme Class ─────────────────────────────────────────
class SLTheme {
  static final ValueNotifier<bool> isTabSwiping = ValueNotifier<bool>(false);
  static final ValueNotifier<int?> globalTabRequest = ValueNotifier<int?>(null);
  static const String defaultFontKey = 'quicksand';
  static List<SLFontOption> get fontOptions => [
    SLFontOption(
      key: defaultFontKey,
      label: L10nService().translate('core_theme_font_quicksand'),
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
    SLFontOption(
      key: 'nunito',
      label: 'Nunito',
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
    SLFontOption(
      key: 'comfortaa',
      label: 'Comfortaa',
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
    SLFontOption(
      key: 'playfair',
      label: 'Playfair Display',
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
    SLFontOption(
      key: 'beVietnam',
      label: 'Be Vietnam Pro',
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
    SLFontOption(
      key: 'patrickHand',
      label: 'Patrick Hand',
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
    SLFontOption(
      key: 'dancingScript',
      label: 'Dancing Script',
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
    SLFontOption(
      key: 'caveat',
      label: 'Caveat',
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
    SLFontOption(
      key: 'lora',
      label: 'Lora',
      sampleText: L10nService().translate('core_theme_font_sample'),
    ),
  ];

  static List<SLFontOption> get cleanFontOptions => fontOptions;

  static String normalizeFontKey(String? fontKey) {
    final normalized = (fontKey ?? '').trim();
    final isSupported = cleanFontOptions.any((font) => font.key == normalized);
    return isSupported ? normalized : defaultFontKey;
  }

  static SLFontOption fontOptionForKey(String? fontKey) {
    final key = normalizeFontKey(fontKey);
    return cleanFontOptions.firstWhere((font) => font.key == key);
  }

  static TextTheme textThemeForKey(String? fontKey, TextTheme base) {
    switch (normalizeFontKey(fontKey)) {
      case 'patrickHand':
        return GoogleFonts.patrickHandTextTheme(base);
      case 'dancingScript':
        return GoogleFonts.dancingScriptTextTheme(base);
      case 'caveat':
        return GoogleFonts.caveatTextTheme(base);
      case 'lora':
        return GoogleFonts.loraTextTheme(base);
      case 'nunito':
        return GoogleFonts.nunitoTextTheme(base);
      case 'comfortaa':
        return GoogleFonts.comfortaaTextTheme(base);
      case 'playfair':
        return GoogleFonts.playfairDisplayTextTheme(base);
      case 'beVietnam':
        return GoogleFonts.beVietnamProTextTheme(base);
      case defaultFontKey:
      default:
        return GoogleFonts.quicksandTextTheme(base);
    }
  }

  static TextStyle textStyleForKey(
    String? fontKey, {
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
    final baseStyle = TextStyle(
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
    ).merge(textStyle);

    switch (normalizeFontKey(fontKey)) {
      case 'patrickHand':
        return GoogleFonts.patrickHand(textStyle: baseStyle);
      case 'dancingScript':
        return GoogleFonts.dancingScript(textStyle: baseStyle);
      case 'caveat':
        return GoogleFonts.caveat(textStyle: baseStyle);
      case 'lora':
        return GoogleFonts.lora(textStyle: baseStyle);
      case 'nunito':
        return GoogleFonts.nunito(textStyle: baseStyle);
      case 'comfortaa':
        return GoogleFonts.comfortaa(textStyle: baseStyle);
      case 'playfair':
        return GoogleFonts.playfairDisplay(textStyle: baseStyle);
      case 'beVietnam':
        return GoogleFonts.beVietnamPro(textStyle: baseStyle);
      case defaultFontKey:
      default:
        return GoogleFonts.quicksand(textStyle: baseStyle);
    }
  }

  // ── Backward-compat aliases ────────────────────────────────
  static const Color primary = SLColors.primary;
  static const Color primaryLight = SLColors.primaryLight;
  static const Color primaryDark = SLColors.primaryHover;
  static const Color accentPurple = SLColors.accentPurple;
  static const Color accentPurpleDark = SLColors.accentPurpleDark;
  static const Color accentBlueSoft = SLColors.accentBlueSoft;
  static const Color surface = SLColors.bgCard;
  static const Color surfaceSoft = SLColors.surfaceWarm;
  static const Color outlineSoft = SLColors.border;
  static const Color textMain = SLColors.textPrimary;
  static const Color textMuted = SLColors.textSecond;
  static const Color textLight = SLColors.textTertiary;

  static Color glassCardColor = const Color(0xD9FFF8F4);
  static Color glassCardStrong = const Color(0xEDFFFDFC);
  static Color glassBorder = const Color(0x66D7DEE5);
  static Color glassBorderThin = const Color(0x40D7E1E8);

  static const List<Color> defaultGradient = [
    Color(0xFFFFF0F3),
    Color(0xFFFFD6E0),
    Color(0xFFFBC2EB),
    Color(0xFFFF9A9E),
  ];
  static const List<Color> btnGradient = [SLColors.primary, SLColors.primary];

  static List<BoxShadow> cardShadow = SLShadow.glass;
  static List<BoxShadow> btnShadow = SLShadow.primary;

  // ─── Typography Alias ──────────────────────────────────────────
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
    return textStyleForKey(
      UiPrefs.notifier.value.fontKey,
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

  // ─── Background Mesh Pattern ──────────────────────────────────
  static Widget meshPattern() {
    return const RepaintBoundary(
      child: CustomPaint(painter: _CuteMeshPatternPainter()),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────
  static AppBar appBar(
    BuildContext context,
    String title, {
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      title: Text(
        title.toUpperCase(),
        style: SLTypography.titleMedium.copyWith(
          color: SLColors.primary,
          letterSpacing: 1.2,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        color: SLColors.bgElevated.withValues(alpha: 0.94),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: SLColors.primary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  // ─── Background (Web CSS replica) ─────────────────────────────
  static Widget background({required Widget child, String? themeKey}) {
    // ✅ FIX: Support custom background URL from UiPrefs
    final ui = UiPrefs.notifier.value;
    final hasCustomBackground = ui.customBackgroundUrl.trim().isNotEmpty;
    final customBackgroundUrl = ui.customBackgroundUrl.trim();

    if (themeKey == 'theme-true-black') {
      return Container(color: Colors.black, child: child);
    }
    if (themeKey == 'theme-dark' || themeKey == 'theme-mystic-dark') {
      return Container(color: SLColors.darkBgMain, child: child);
    }
    if (themeKey == 'off') {
      return Container(color: SLColors.bgMain, child: child);
    }

    // If custom background exists, apply it globally
    if (hasCustomBackground) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Base gradient background
          Container(
            color: SLColors.bgMain,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _SLBgPainter()),
                  ),
                ),
              ],
            ),
          ),
          // Custom background image
          Positioned.fill(
            child: Opacity(
              opacity: 0.95,
              child: CachedNetworkImage(
                maxWidthDiskCache: 1440,
                memCacheHeight: 1440,
                imageUrl: customBackgroundUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorWidget: (context, url, error) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1A1035), Color(0xFF0D0B1A)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Child content on top
          Positioned.fill(child: child),
        ],
      );
    }

    return Container(
      color: SLColors.bgMain,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _SLBgPainter())),
          ),
          child,
        ],
      ),
    );
  }

  // ─── Lightweight Decorative Canvas ────────────────────────────
  static Widget softCanvasBackdrop({
    required Widget child,
    Color baseColor = SLColors.bgMain,
    Color accentColor = SLColors.primary,
    Color secondaryAccent = SLColors.secondary,
    SLCanvasBackdropMotif motif = SLCanvasBackdropMotif.sparkles,
  }) {
    return ColoredBox(
      color: baseColor,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SLSoftCanvasBackdropPainter(
                    baseColor: baseColor,
                    accentColor: accentColor,
                    secondaryAccent: secondaryAccent,
                    motif: motif,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  static Widget softPanel({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Color color = const Color(0xF7FFFCFA),
    Color borderColor = SLColors.borderLight,
    double radius = 28,
  }) {
    return Container(
      margin: margin,
      padding: padding ?? SLSpacing.all20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF3F2430).withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.78),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Thẻ giấy chủ đạo của SoulLocket. Lớp giấy lệch, đường chỉ may và băng
  /// dính tạo cảm giác sổ kỷ niệm mà không cần thêm asset hay package mới.
  static Widget paperCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Color color = SLColors.paper,
    Color accentColor = SLColors.thread,
    double radius = 26,
    bool showTape = true,
  }) {
    final ui = UiPrefs.notifier.value;
    final surfaceColor = ui.transparentMode
        ? color.withValues(alpha: 0.86)
        : color;

    return Container(
      margin: margin,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            left: 5,
            top: 7,
            right: -4,
            bottom: -5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: SLColors.border, width: 1.15),
              boxShadow: SLShadow.paper,
            ),
            child: CustomPaint(
              foregroundPainter: _SLPaperStitchPainter(
                radius: radius,
                accentColor: accentColor,
              ),
              child: Padding(padding: padding ?? SLSpacing.all20, child: child),
            ),
          ),
          if (showTape)
            Positioned(
              top: -7,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.035,
                    child: Container(
                      width: 58,
                      height: 15,
                      decoration: BoxDecoration(
                        color: SLColors.washi.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: const Color(
                            0xFFF0B996,
                          ).withValues(alpha: 0.42),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static BoxDecoration authFieldDecoration({
    Color fillColor = const Color(0xFFFFF8F4),
    Color borderColor = const Color(0xFFE8DDD6),
    Color focusColor = SLColors.primary,
    double radius = 20,
  }) {
    return BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.25),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.72),
          blurRadius: 0,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  static InputDecoration authInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    Color fillColor = const Color(0x66FFFFFF),
    Color borderColor = const Color(0x40FFFFFF),
    Color focusColor = const Color(0xFFFF8FB1),
    double radius = 24,
  }) {
    OutlineInputBorder border(Color color, [double width = 1.0]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      hintStyle: SLTheme.quicksand(
        fontSize: 15.5,
        color: SLColors.textSecond.withValues(alpha: 0.5),
        fontWeight: FontWeight.w700,
      ),
      helperStyle: SLTheme.quicksand(
        fontSize: 11,
        color: SLColors.textSecond,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      enabledBorder: border(const Color(0xFFF0E5DF), 1.2),
      focusedBorder: border(const Color(0xFFFF5E7E), 1.6),
      errorBorder: border(SLColors.danger, 1.2),
      focusedErrorBorder: border(SLColors.danger, 1.5),
    );
  }

  static Widget authPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    List<Color> colors = const <Color>[Color(0xFFFF5E7E), Color(0xFFFF85A1)],
  }) {
    final bool isDisabled = onPressed == null;
    return Opacity(
      opacity: isDisabled ? 0.75 : 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisabled
                ? const [Color(0xFFF5EFEA), Color(0xFFE5DDD7)]
                : colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFFF5E7E).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      label,
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget authHintCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD6), width: 1),
      ),
      child: child,
    );
  }

  static Widget sectionHeader({
    required String title,
    String? trailing,
    Color titleColor = SLColors.textPrimary,
    Color trailingColor = SLColors.primary,
  }) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: SLTheme.quicksand(
            fontSize: 13.5,
            color: titleColor,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF7EEE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              trailing,
              style: SLTheme.quicksand(
                fontSize: 11,
                color: trailingColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static Widget authSurface({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return softPanel(
      margin: margin,
      padding: padding ?? const EdgeInsets.fromLTRB(18, 16, 18, 18),
      color: const Color(0xFFFDF9F6),
      borderColor: const Color(0xFFE9DFD9),
      radius: 26,
      child: child,
    );
  }

  static Widget authToggleCard({required Widget child, bool selected = false}) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFFFF0F5).withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? const Color(0xFFFF4B91).withValues(alpha: 0.5)
              : const Color(0xFFFFD6E0).withValues(alpha: 0.7),
          width: 1.3,
        ),
      ),
      child: child,
    );
  }

  static Color authMutedTextColor = const Color(0xFF8F7F8E);

  static Color authFieldFill = const Color(0xFFFFF8F4);

  static Color authFieldBorder = const Color(0xFFE8DDD6);

  static Color authSurfaceTint = const Color(0xFFF8F2EB);

  static Color authSurfaceStrong = const Color(0xFFFDF9F6);

  static Color authTagBackground = const Color(0xFFF7EEE7);

  static Color authHelpBackground = const Color(0xFFF8F2EB);

  static Color authChipText = const Color(0xFF7A5565);

  static Color authHeroGlow = const Color(0xFFE8D8CF);

  static Widget emptyStatePanel({
    required IconData icon,
    required String title,
    required String subtitle,
    Color accentColor = SLColors.primary,
    EdgeInsets? margin,
  }) {
    return Center(
      child: softPanel(
        margin: margin ?? SLSpacing.all24,
        padding: SLSpacing.all24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[
                    accentColor.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: accentColor.withValues(alpha: 0.24)),
              ),
              child: Icon(icon, color: accentColor, size: 32),
            ),
            SLSpacing.h16,
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: SLColors.textPrimary,
              ),
            ),
            SLSpacing.h8,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SLColors.textSecond,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Glass Card (clone .glass-card) ───────────────────────────
  static Widget glassCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double radius = 28,
    Color? color,
  }) {
    return glassCardWidget(
      child: child,
      padding: padding,
      margin: margin,
      radius: radius,
      color: color,
    );
  }

  static Widget glassCardWidget({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double radius = 28,
    Color? color,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: isTabSwiping,
      builder: (context, isSwiping, _) {
        final ui = UiPrefs.notifier.value;
        final effectProfile = UiPrefs.resolveEffectProfile(
          state: ui,
          isWeb: kIsWeb,
        );
        final useLiteGlass = !effectProfile.premiumEffects || isSwiping;
        final useJournalSurface = color == null && !ui.transparentMode;
        Color baseColor =
            color ?? (useJournalSurface ? SLColors.paper : glassCardColor);
        if (ui.transparentMode) {
          baseColor = baseColor.withValues(alpha: 0.8);
        }
        final effectiveColor = useJournalSurface
            ? baseColor
            : useLiteGlass
            ? Color.alphaBlend(
                Colors.white.withValues(alpha: kIsWeb ? 0.20 : 0.12),
                baseColor.withValues(alpha: 0.92),
              )
            : baseColor;
        final effectiveBorder = useJournalSurface
            ? SLColors.border
            : useLiteGlass
            ? glassBorder.withValues(alpha: 0.72)
            : glassBorder;
        final effectiveShadow = useJournalSurface
            ? SLShadow.paper
            : useLiteGlass
            ? SLShadow.sm
            : SLShadow.glass;

        final decoratedChild = Container(
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: effectiveBorder,
              width: useJournalSurface ? 1.1 : 0.5,
            ),
            boxShadow: effectiveShadow,
          ),
          child: CustomPaint(
            foregroundPainter: useJournalSurface
                ? _SLPaperStitchPainter(
                    radius: radius,
                    accentColor: SLColors.thread,
                  )
                : null,
            child: Padding(padding: padding ?? SLSpacing.all20, child: child),
          ),
        );

        return Container(
          margin: margin ?? const EdgeInsets.fromLTRB(15, 0, 15, 20),
          child: useLiteGlass || useJournalSurface
              ? decoratedChild
              : ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: FastBackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: decoratedChild,
                  ),
                ),
        );
      },
    );
  }

  // ─── Primary Button (clone .btn-full) ─────────────────────────
  static Widget primaryButton({
    String? label,
    String? text,
    required VoidCallback? onPressed,
    double? width,
    IconData? icon,
    EdgeInsets? padding,
    bool isLoading = false,
  }) {
    final String effectiveLabel = (label ?? text ?? '').toUpperCase();
    return SizedBox(
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: btnGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(SLRadius.pill),
          boxShadow: SLShadow.primary,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: padding ?? const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SLRadius.pill),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      SLSpacing.w8,
                    ],
                    Text(
                      effectiveLabel,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── Title Gradient ───────────────────────────────────────────
  static Widget titleGradient(String text, {double fontSize = 21}) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [SLColors.secondary, SLColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: SLTheme.quicksand(
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // ─── Input Field ──────────────────────────────────────────────
  static Widget inputField(
    TextEditingController ctrl,
    String hint, {
    IconData? icon,
    TextInputType? keyboardType,
    bool obscure = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      style: SLTheme.quicksand(
        color: SLColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: SLTheme.quicksand(
          color: SLColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: SLColors.primary.withValues(alpha: 0.6),
                size: 20,
              )
            : null,
        filled: true,
        fillColor: SLColors.bgElevated,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SLRadius.lg),
          borderSide: const BorderSide(color: SLColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SLRadius.lg),
          borderSide: const BorderSide(color: SLColors.primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  // ─── Chip ─────────────────────────────────────────────────────
  static Widget chip(
    String label,
    Color color, {
    bool isGold = false,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: isGold ? const Color(0xFFFFFAF0) : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SLRadius.md),
        border: Border.all(
          color: isGold ? SLColors.warningGold : color.withValues(alpha: 0.24),
          width: isGold ? 1.2 : 0.8,
        ),
        boxShadow: isGold
            ? [
                BoxShadow(
                  color: SLColors.warningGold.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          color: textColor ?? (isGold ? const Color(0xFFB45309) : color),
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
        ),
      ),
    );
  }

  // ─── Avatar Placeholder ───────────────────────────────────────
  static Widget avatarPlaceholder(String name, {double size = 56}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [SLColors.accentPink, SLColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  // ─── Author Tag ───────────────────────────────────────────────
  static Widget authorTag(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE3EE), Color(0xFFFFF8FB)],
        ),
        borderRadius: BorderRadius.circular(SLRadius.pill),
        boxShadow: [
          BoxShadow(
            color: SLColors.primary.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        name,
        style: SLTheme.quicksand(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: SLColors.primary,
        ),
      ),
    );
  }

  // ─── List Item ────────────────────────────────────────────────
  static Widget listItem({required Widget child, bool isHighlighted = false}) {
    return Container(
      padding: SLSpacing.all16,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: glassCardStrong,
        borderRadius: BorderRadius.circular(SLRadius.xl),
        border: Border(
          left: BorderSide(
            color: isHighlighted ? SLColors.accentPurple : SLColors.primary,
            width: 4,
          ),
        ),
        boxShadow: cardShadow,
      ),
      child: child,
    );
  }
}

class _SLPaperStitchPainter extends CustomPainter {
  const _SLPaperStitchPainter({
    required this.radius,
    required this.accentColor,
  });

  final double radius;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 28 || size.height < 28) return;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
          Radius.circular(math.max(6, radius - 7)),
        ),
      );
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 4.5, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 8.5;
      }
    }

    final heartPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final center = Offset(size.width - 24, size.height - 22);
    final heart = Path()
      ..moveTo(center.dx, center.dy + 6)
      ..cubicTo(
        center.dx - 13,
        center.dy - 2,
        center.dx - 7,
        center.dy - 10,
        center.dx,
        center.dy - 4,
      )
      ..cubicTo(
        center.dx + 7,
        center.dy - 10,
        center.dx + 13,
        center.dy - 2,
        center.dx,
        center.dy + 6,
      );
    canvas.drawPath(heart, heartPaint);
  }

  @override
  bool shouldRepaint(covariant _SLPaperStitchPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.accentColor != accentColor;
  }
}

enum SLCanvasBackdropMotif { sparkles, notes, safety, journal }

class _SLSoftCanvasBackdropPainter extends CustomPainter {
  const _SLSoftCanvasBackdropPainter({
    required this.baseColor,
    required this.accentColor,
    required this.secondaryAccent,
    required this.motif,
  });

  final Color baseColor;
  final Color accentColor;
  final Color secondaryAccent;
  final SLCanvasBackdropMotif motif;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = baseColor);

    void radial(Alignment center, double radius, Color color) {
      final Paint paint = Paint()
        ..shader = RadialGradient(
          center: center,
          radius: radius,
          colors: <Color>[color, Colors.transparent],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    radial(
      const Alignment(-0.95, -0.82),
      0.72,
      accentColor.withValues(alpha: 0.18),
    );
    radial(
      const Alignment(0.88, -0.36),
      0.68,
      secondaryAccent.withValues(alpha: 0.14),
    );
    radial(
      const Alignment(0.16, 1.08),
      0.82,
      Colors.white.withValues(alpha: 0.42),
    );

    final Paint linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.08)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    final Paint dotPaint = Paint()
      ..color = secondaryAccent.withValues(alpha: 0.13);

    switch (motif) {
      case SLCanvasBackdropMotif.journal:
        final Paint paperLinePaint = Paint()
          ..color = const Color(0xFFD8BFB2).withValues(alpha: 0.16)
          ..strokeWidth = 0.9;
        for (double y = 38; y < size.height; y += 34) {
          canvas.drawLine(
            Offset(18, y),
            Offset(size.width - 18, y + ((y ~/ 34).isEven ? 0.8 : -0.6)),
            paperLinePaint,
          );
        }
        canvas.drawLine(
          const Offset(34, 0),
          Offset(34, size.height),
          Paint()
            ..color = accentColor.withValues(alpha: 0.09)
            ..strokeWidth = 1.1,
        );

        final Path doodleHeart = Path()
          ..moveTo(size.width - 48, 62)
          ..cubicTo(
            size.width - 72,
            44,
            size.width - 84,
            76,
            size.width - 48,
            102,
          )
          ..cubicTo(
            size.width - 12,
            76,
            size.width - 24,
            44,
            size.width - 48,
            62,
          );
        canvas.drawPath(
          doodleHeart,
          Paint()
            ..color = accentColor.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );

        for (int i = 0; i < 10; i++) {
          final double x = 22 + (i * 47) % math.max(72, size.width - 28);
          final double y = 24 + (i * 83) % math.max(100, size.height - 22);
          canvas.drawCircle(Offset(x, y), i.isEven ? 2.1 : 1.4, dotPaint);
        }
        break;
      case SLCanvasBackdropMotif.notes:
        for (double y = 96; y < size.height; y += 42) {
          canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), linePaint);
        }
        for (int i = 0; i < 5; i++) {
          final double x = 32 + (i * 78) % math.max(96, size.width - 24);
          final double y = 58 + (i * 113) % math.max(140, size.height - 32);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 42, 30),
              const Radius.circular(8),
            ),
            Paint()..color = accentColor.withValues(alpha: 0.055),
          );
        }
        break;
      case SLCanvasBackdropMotif.safety:
        for (int i = 0; i < 7; i++) {
          final double y = 48 + (i * 86.0);
          canvas.drawLine(
            Offset(-28, y),
            Offset(size.width * 0.42, y - 86),
            linePaint,
          );
        }
        final Path shield = Path()
          ..moveTo(size.width - 96, 78)
          ..quadraticBezierTo(size.width - 54, 96, size.width - 60, 144)
          ..quadraticBezierTo(size.width - 66, 184, size.width - 96, 210)
          ..quadraticBezierTo(size.width - 126, 184, size.width - 132, 144)
          ..quadraticBezierTo(size.width - 138, 96, size.width - 96, 78);
        canvas.drawPath(
          shield,
          Paint()..color = accentColor.withValues(alpha: 0.06),
        );
        break;
      case SLCanvasBackdropMotif.sparkles:
        for (int i = 0; i < 16; i++) {
          final double x = 24 + (i * 53) % math.max(80, size.width - 24);
          final double y = 36 + (i * 91) % math.max(120, size.height - 24);
          canvas.drawCircle(Offset(x, y), i.isEven ? 2.6 : 1.7, dotPaint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SLSoftCanvasBackdropPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.secondaryAccent != secondaryAccent ||
        oldDelegate.motif != motif;
  }
}

/// Background painter (replicates web CSS radial gradients)
class _SLBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, Paint()..color = SLColors.surfaceWarm);

    final paperLine = Paint()
      ..color = const Color(0xFFD8BFB2).withValues(alpha: 0.11)
      ..strokeWidth = 0.8;
    for (double y = 44; y < size.height; y += 38) {
      canvas.drawLine(
        Offset(18, y),
        Offset(size.width - 18, y + ((y ~/ 38).isEven ? 0.7 : -0.5)),
        paperLine,
      );
    }

    final paint1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -1.2),
        radius: 0.65,
        colors: [SLColors.primary.withValues(alpha: 0.18), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.8, -0.6),
        radius: 0.7,
        colors: [
          const Color(0xFFF1D1C5).withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint2);

    final paint3 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, -0.6),
        radius: 0.7,
        colors: [
          SLColors.secondary.withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _CuteMeshPatternPainter extends CustomPainter {
  const _CuteMeshPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    // 1. Vẽ lưới chấm tròn nhỏ siêu nhẹ phong cách pastel kute
    final Paint dotPaint = Paint()
      ..color = const Color(0xFFFFB7D1).withValues(alpha: 0.12);
    const double spacing = 32.0;
    for (double x = spacing / 2; x < w; x += spacing) {
      for (double y = spacing / 2; y < h; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
      }
    }

    // 2. Vẽ các icon dễ thương rải rác cố định vị trí (deterministic pseudo-random)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final List<Map<String, dynamic>> icons = [
      {'text': '✨', 'color': const Color(0xFFFFD54F)},
      {'text': '⭐', 'color': const Color(0xFFFFE082)},
      {'text': '💖', 'color': const Color(0xFFFFB3CC)},
    ];

    int seed = 42;
    int nextRand() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    // Khoảng 35 họa tiết xinh xắn nổi bật
    final int count = ((w * h) / 14000).clamp(15, 60).toInt();
    for (int i = 0; i < count; i++) {
      final double x = (nextRand() % w.toInt()).toDouble();
      final double y = (nextRand() % h.toInt()).toDouble();
      final double sizeVal = (nextRand() % 8) + 12.0; // font size 12-20
      final icon = icons[nextRand() % icons.length];

      textPainter.text = TextSpan(
        text: icon['text'] as String,
        style: TextStyle(
          fontSize: sizeVal,
          color: (icon['color'] as Color).withValues(alpha: 0.16),
          fontFamily: 'Segoe UI Emoji',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CuteMeshPatternPainter oldDelegate) => false;
}

class _HeroPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color> colors;

  const _HeroPrimaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.colors,
  });

  @override
  State<_HeroPrimaryButton> createState() => _HeroPrimaryButtonState();
}

class _HeroPrimaryButtonState extends State<_HeroPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _scaleAnim = Tween<double>(
    begin: 1.0,
    end: 0.95,
  ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _animCtrl.forward(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _animCtrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: isDisabled ? null : () => _animCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Opacity(
          opacity: isDisabled ? 0.65 : 1.0,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDisabled
                    ? [const Color(0xFFF5D6E0), const Color(0xFFE8C1CD)]
                    : widget.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: widget.colors.first.withValues(
                          alpha: 0.4,
                        ), // Glow shadow
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                alignment: Alignment.center,
                child: widget.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        widget.label,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SLShadows {
  static List<BoxShadow> get glowingPrimary => [
    BoxShadow(
      color: SLColors.primary.withValues(alpha: 0.4),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get softCard => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      spreadRadius: -1,
      offset: const Offset(0, 2),
    ),
  ];
}

class SLGlassmorphism {
  static Widget apply({
    required Widget child,
    double blur = 24.0,
    double opacity = 0.65,
    BorderRadius? borderRadius,
    Color? color,
    BoxBorder? border,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? SLColors.bgElevated.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border:
                border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.0,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
