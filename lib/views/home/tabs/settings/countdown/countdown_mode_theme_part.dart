part of '../../settings_tab.dart';

class _CountdownModeThemeData {
  const _CountdownModeThemeData({
    required this.background,
    required this.overlay,
    required this.orbA,
    required this.orbB,
    required this.foreground,
    required this.isDark,
    this.imageOpacity = 0.26,
  });

  final List<Color> background;
  final List<Color> overlay;
  final Color orbA;
  final Color orbB;
  final Color foreground;
  final bool isDark;
  final double imageOpacity;

  factory _CountdownModeThemeData.resolve(String themeKey) {
    switch (themeKey) {
      case 'theme-night':
        return const _CountdownModeThemeData(
          background: [Color(0xFF101728), Color(0xFF23144A), Color(0xFF171F3A)],
          overlay: [Color(0x44000000), Color(0x29000000), Color(0x66000000)],
          orbA: Color(0xFF8D7BFF),
          orbB: Color(0xFF56C6FF),
          foreground: Colors.white,
          isDark: true,
          imageOpacity: 0.22,
        );
      case 'theme-dark':
      case 'theme-mystic-dark':
        return const _CountdownModeThemeData(
          background: [Color(0xFF292329), Color(0xFF342B33), Color(0xFF3C3039)],
          overlay: [Color(0x33000000), Color(0x25000000), Color(0x55000000)],
          orbA: Color(0xFFFF7DB5),
          orbB: Color(0xFFA48BFF),
          foreground: Colors.white,
          isDark: true,
          imageOpacity: 0.22,
        );
      case 'theme-ocean':
        return const _CountdownModeThemeData(
          background: [Color(0xFFCFF7FF), Color(0xFF87D9FF), Color(0xFF63C9E9)],
          overlay: [Color(0x11FFFFFF), Color(0x08FFFFFF), Color(0x330A5673)],
          orbA: Color(0xFF6DD9FF),
          orbB: Color(0xFFB6F4FF),
          foreground: Color(0xFF10364A),
          isDark: false,
          imageOpacity: 0.24,
        );
      case 'theme-sunset':
        return const _CountdownModeThemeData(
          background: [Color(0xFFFFEDC8), Color(0xFFFFB5A7), Color(0xFFFF7D8D)],
          overlay: [Color(0x11FFFFFF), Color(0x08FFFFFF), Color(0x22000000)],
          orbA: Color(0xFFFF9B83),
          orbB: Color(0xFFFFD7A6),
          foreground: Color(0xFF592C2F),
          isDark: false,
          imageOpacity: 0.22,
        );
      case 'off':
      case 'theme-default':
        return const _CountdownModeThemeData(
          background: [Color(0xFFFAF6F4), Color(0xFFF8F0F1), Color(0xFFF1E5E9)],
          overlay: [Color(0x08FFFFFF), Color(0x00FFFFFF), Color(0x18000000)],
          orbA: Color(0xFFD7E5FF),
          orbB: Color(0xFFFFD6E4),
          foreground: Color(0xFF2C3650),
          isDark: false,
        );
      case 'theme-pink-glow':
        return const _CountdownModeThemeData(
          background: [Color(0xFFFAF6F4), Color(0xFFF8EFF1), Color(0xFFF3E6EB)],
          overlay: [Color(0x08FFFFFF), Color(0x00FFFFFF), Color(0x18000000)],
          orbA: Color(0xFFFFA5C2),
          orbB: Color(0xFFEAB8FF),
          foreground: Color(0xFF5D3656),
          isDark: false,
        );
      default:
        return const _CountdownModeThemeData(
          background: [Color(0xFF1A1A24), Color(0xFF252233), Color(0xFF15151D)],
          overlay: [Color(0x44000000), Color(0x22000000), Color(0x66000000)],
          orbA: Color(0xFFFF7DB5),
          orbB: Color(0xFF8D7BFF),
          foreground: Colors.white,
          isDark: true,
        );
    }
  }
}

class _CountdownModeStyleData {
  const _CountdownModeStyleData({
    this.outerColor,
    required this.outerGradient,
    this.innerColor,
    required this.innerGradient,
    required this.outerBorder,
    required this.innerBorder,
    required this.shadows,
    required this.numberGradient,
    required this.topColor,
    required this.bottomColor,
    required this.labelShadows,
    required this.numberShadows,
  });

  final Color? outerColor;
  final Gradient outerGradient;
  final Color? innerColor;
  final Gradient innerGradient;
  final Border outerBorder;
  final Border innerBorder;
  final List<BoxShadow> shadows;
  final List<Color> numberGradient;
  final Color topColor;
  final Color bottomColor;
  final List<Shadow> labelShadows;
  final List<Shadow> numberShadows;

  factory _CountdownModeStyleData.resolve(
    String styleKey,
    bool transparentMode,
  ) {
    final visual = CountdownVisualSpec.resolve(styleKey, transparentMode);
    return _CountdownModeStyleData(
      outerColor: visual.outerColor,
      outerGradient:
          visual.outerGradient ??
          LinearGradient(
            colors: [
              visual.outerColor ?? Colors.transparent,
              visual.outerColor ?? Colors.transparent,
            ],
          ),
      innerColor: visual.innerColor,
      innerGradient:
          visual.innerGradient ??
          LinearGradient(
            colors: [
              visual.innerColor ?? Colors.transparent,
              visual.innerColor ?? Colors.transparent,
            ],
          ),
      outerBorder: visual.outerBorder ?? Border.all(color: Colors.transparent),
      innerBorder: visual.innerBorder ?? Border.all(color: Colors.transparent),
      shadows: visual.shadows,
      numberGradient: visual.numberGradient,
      topColor: visual.topLabelColor,
      bottomColor: visual.bottomLabelColor,
      labelShadows: visual.labelShadows,
      numberShadows: visual.numberShadows,
    );
  }
}
