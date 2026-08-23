import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import 'sl_colors.dart';
import 'sl_typography.dart';
import 'sl_spacing.dart';
import 'sl_radius.dart';
import 'sl_shadows.dart';
import 'sl_painters.dart';

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

  // â”€â”€ Backward-compat aliases â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Typography Alias â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Background Mesh Pattern â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Widget meshPattern() {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: SLCuteMeshPatternPainter(),
      ),
    );
  }

  // â”€â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        icon: const Icon(Icons.arrow_back_ios_new,
            color: SLColors.primary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  // â”€â”€â”€ Background (Web CSS replica) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Widget background({required Widget child, String? themeKey}) {
    // âœ… FIX: Support custom background URL from UiPrefs
    final ui = UiPrefs.notifier.value;
    final hasCustomBackground = ui.customBackgroundUrl.trim().isNotEmpty;
    final customBackgroundUrl = ui.customBackgroundUrl.trim();

    if (themeKey == 'theme-true-black') {
      return Container(
        color: Colors.black,
        child: child,
      );
    }
    if (themeKey == 'theme-dark' || themeKey == 'theme-mystic-dark') {
      return Container(
        color: SLColors.darkBgMain,
        child: child,
      );
    }
    if (themeKey == 'off') {
      return Container(
        color: SLColors.bgMain,
        child: child,
      );
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
                    child: CustomPaint(painter: SLBgPainter()),
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
                      colors: [
                        Color(0xFF1A1035),
                        Color(0xFF0D0B1A),
                      ],
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
            child: IgnorePointer(
              child: CustomPaint(painter: SLBgPainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }

  // â”€â”€â”€ Lightweight Decorative Canvas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                  painter: SLSoftCanvasBackdropPainter(
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

  /// Card mềm mại kiểu app hẹn hò — floating ambient glow
  static BoxDecoration datingCard({Color? accentColor}) {
    return BoxDecoration(
      color: SLColors.bgCard,
      borderRadius: BorderRadius.circular(SLRadius.xl),
      border: Border.all(
        color: SLColors.borderLight.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: SLShadow.dreamy,
    );
  }

  /// Card có glow màu accent — cho highlight sections
  static BoxDecoration glowCard({required Color accent}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(SLRadius.xl),
      border: Border.all(
        color: accent.withValues(alpha: 0.12),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.12),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Bottom sheet decoration chuẩn — bo tròn 32px, shadow mềm
  static BoxDecoration sheetDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      boxShadow: SLShadow.sheet,
    );
  }

  /// Drag handle pill mềm mại cho bottom sheet
  static Widget sheetHandle() {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0D6D9),
          borderRadius: BorderRadius.circular(999),
        ),
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
      enabledBorder:
          border(const Color(0xFFFFD6E0).withValues(alpha: 0.7), 1.2),
      focusedBorder:
          border(const Color(0xFFFF4B91), 1.6),
      errorBorder: border(SLColors.danger, 1.2),
      focusedErrorBorder: border(SLColors.danger, 1.5),
    );
  }

  static Widget authPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    List<Color> colors = const <Color>[
      Color(0xFFFF4B91),
      Color(0xFFFF69B4),
      Color(0xFFFF4B91),
    ],
  }) {
    final bool isDisabled = onPressed == null;
    return Opacity(
      opacity: isDisabled ? 0.75 : 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisabled
                ? const [Color(0xFFFFB6C1), Color(0xFFFFC0CB)]
                : colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFFF4B91).withValues(alpha: 0.38),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
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

  static Widget authHintCard({
    required Widget child,
    EdgeInsets? padding,
  }) {
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

  static Widget authToggleCard({
    required Widget child,
    bool selected = false,
  }) {
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

  // â”€â”€â”€ Glass Card (clone .glass-card) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        Color baseColor = color ?? glassCardColor;
        if (ui.transparentMode) {
          baseColor = baseColor.withValues(alpha: 0.8);
        }
        final effectiveColor = useLiteGlass
            ? Color.alphaBlend(
                Colors.white.withValues(alpha: kIsWeb ? 0.20 : 0.12),
                baseColor.withValues(alpha: 0.92),
              )
            : baseColor;
        final effectiveBorder =
            useLiteGlass ? glassBorder.withValues(alpha: 0.72) : glassBorder;
        final effectiveShadow = useLiteGlass ? SLShadow.sm : SLShadow.glass;

        final decoratedChild = Container(
          padding: padding ?? SLSpacing.all20,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: effectiveBorder, width: 0.5),
            boxShadow: effectiveShadow,
          ),
          child: child,
        );

        return Container(
          margin: margin ?? const EdgeInsets.fromLTRB(15, 0, 15, 20),
          child: useLiteGlass
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

  // â”€â”€â”€ Primary Button (clone .btn-full) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Title Gradient â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Input Field â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
            ? Icon(icon,
                color: SLColors.primary.withValues(alpha: 0.6), size: 20)
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // â”€â”€â”€ Chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Widget chip(String label, Color color,
      {bool isGold = false, Color? textColor}) {
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
                    blurRadius: 8)
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

  // â”€â”€â”€ Avatar Placeholder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Author Tag â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
              color: SLColors.primary.withValues(alpha: 0.12), blurRadius: 8),
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

  // â”€â”€â”€ List Item â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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


