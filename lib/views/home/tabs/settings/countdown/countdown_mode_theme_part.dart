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
          background: [Color(0xFF20182C), Color(0xFF352345), Color(0xFF4A325F)],
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
          background: [Color(0xFFF8FAFD), Color(0xFFF2F5FB), Color(0xFFE8EEF6)],
          overlay: [Color(0x08FFFFFF), Color(0x00FFFFFF), Color(0x18000000)],
          orbA: Color(0xFFD7E5FF),
          orbB: Color(0xFFFFD6E4),
          foreground: Color(0xFF2C3650),
          isDark: false,
        );
      case 'theme-pink-glow':
        return const _CountdownModeThemeData(
          background: [Color(0xFFFFF3F7), Color(0xFFFFE2EC), Color(0xFFFCE8FF)],
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
      String styleKey, bool transparentMode) {
    // Chỉ áp dụng transparent mode cho style cơ bản (giống home)
    final isBasicStyle = styleKey == 'default' || styleKey == 'glass' ||
        styleKey == 'plain' || styleKey.isEmpty || styleKey == 'rose_wave';
    if (transparentMode && isBasicStyle) {
      return _CountdownModeStyleData(
        outerColor: Colors.white.withValues(alpha: 0.30),
        outerGradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        innerColor: Colors.white.withValues(alpha: 0.08),
        innerGradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        outerBorder:
            Border.all(color: Colors.white.withValues(alpha: 0.34), width: 2.2),
        innerBorder:
            Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        shadows: const [],
        numberGradient: const [Colors.white, Color(0xFFFFD5E8)],
        topColor: Colors.white,
        bottomColor: Colors.white.withValues(alpha: 0.92),
        labelShadows: const [
          Shadow(color: Colors.black, blurRadius: 10),
        ],
        numberShadows: const [
          Shadow(
            color: Colors.black,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      );
    }

    switch (styleKey) {
      case 'plain':
        return _CountdownModeStyleData(
          outerColor: Colors.white,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
          ),
          innerColor: const Color(0xFFFBF8FA),
          outerBorder: Border.fromBorderSide(
              BorderSide(color: Color(0xFFE9DDE6), width: 2.2)),
          innerBorder: Border.all(color: Colors.transparent, width: 0),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          numberGradient: const [Color(0xFF252036), Color(0xFF51465F)],
          topColor: const Color(0xFF51465F),
          bottomColor: const Color(0xFF6E6475),
          labelShadows: const [],
          numberShadows: const [],
        );
      case 'floating_hearts':
        return _CountdownModeStyleData(
          outerColor: null,
          outerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.00),
              Colors.white.withValues(alpha: 0.00),
            ],
          ),
          innerColor: Colors.white.withValues(alpha: 0.08),
          outerBorder: Border.all(color: Colors.transparent, width: 0),
          innerBorder: Border.all(color: Colors.transparent, width: 0),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFFC0CB).withValues(alpha: 0.25),
              blurRadius: 24.0,
              spreadRadius: 2.0,
              offset: const Offset(0, 10),
            ),
          ],
          numberGradient: const [
            Color(0xFFAD1457),
            Color(0xFFD81B60),
            Color(0xFFEC407A),
          ],
          topColor: const Color(0xFFE91E63),
          bottomColor: const Color(0xFFF06292),
          labelShadows: const [],
          numberShadows: const [],
        );
      case 'rose_wave':
      case 'default':
        return _CountdownModeStyleData(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFF0F7), Color(0xFFFFDDEF), Color(0xFFFFC8DE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.95), width: 4.5),
          shadows: const [
            BoxShadow(
              color: Color(0xEAFFFFFF),
              blurRadius: 20,
              spreadRadius: 2,
              offset: Offset(-8, -8),
            ),
            BoxShadow(
              color: Color(0x61D4547A),
              blurRadius: 28,
              spreadRadius: 4,
              offset: Offset(8, 12),
            ),
            BoxShadow(
              color: Color(0x4CFF6FA7),
              blurRadius: 48,
              offset: Offset(0, 20),
            ),
          ],
          innerColor: null,
          innerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.52),
              const Color(0xFFFFA6C8).withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
          numberGradient: const [
            Color(0xFFFFFFFF),
            Color(0xFFFF5B9A),
            Color(0xFFD81B60),
          ],
          topColor: Colors.white,
          bottomColor: Colors.white.withValues(alpha: 0.94),
          labelShadows: [
            Shadow(
              color: const Color(0xFF9D315F).withValues(alpha: 0.52),
              blurRadius: 12,
            ),
            Shadow(color: Colors.white.withValues(alpha: 0.70), blurRadius: 4),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFF8D1A3B).withValues(alpha: 0.55),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
            Shadow(
              color: const Color(0xFF8D1A3B).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        );
      case 'glass':
        return _CountdownModeStyleData(
          outerColor: Colors.white.withValues(alpha: 0.58),
          outerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.86),
              const Color(0xFFE6F7FF).withValues(alpha: 0.54),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.82), width: 3),
          shadows: [
            BoxShadow(
              color: const Color(0xFF8EC5FC).withValues(alpha: 0.34),
              blurRadius: 42,
              offset: const Offset(0, 18),
            ),
          ],
          innerColor: Colors.white.withValues(alpha: 0.16),
          innerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.16),
            ],
          ),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.42), width: 1.2),
          numberGradient: const [Color(0xFF27B4FF), Color(0xFFD81B60)],
          topColor: const Color(0xFF2378A8),
          bottomColor: const Color(0xFF51606D),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.85), blurRadius: 8),
          ],
          numberShadows: const [
            Shadow(
              color: Color(0x2E27B4FF),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        );
      case 'glow':
        return _CountdownModeStyleData(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFF5FA), Color(0xFFFFD9E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.82), width: 5),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF5E92).withValues(alpha: 0.46),
              blurRadius: 50,
              spreadRadius: 8,
              offset: const Offset(0, 16),
            ),
          ],
          innerColor: null,
          innerGradient: LinearGradient(
            colors: [
              const Color(0xFFFF8DB5).withValues(alpha: 0.24),
              Colors.white.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerBorder: Border.all(color: Colors.transparent, width: 0),
          numberGradient: const [Color(0xFFFF2F7A), Color(0xFFB5179E)],
          topColor: const Color(0xFFC2185B),
          bottomColor: const Color(0xFF7A2C58),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.82), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF2F7A).withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        );
      case 'candy':
        return _CountdownModeStyleData(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFE3F3), Color(0xFFE0F7FF), Color(0xFFFFF4C8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.9), width: 4),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF77C8).withValues(alpha: 0.24),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: const Color(0xFF4DDCFF).withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 6),
            ),
          ],
          innerColor: Colors.white.withValues(alpha: 0.20),
          innerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.20),
              Colors.white.withValues(alpha: 0.20),
            ],
          ),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.58), width: 1),
          numberGradient: const [Color(0xFFFF3D9A), Color(0xFF36C9FF)],
          topColor: const Color(0xFFE6378D),
          bottomColor: const Color(0xFF4C6178),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.85), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF3D9A).withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'hyper':
        return _CountdownModeStyleData(
          outerColor: null,
          outerGradient: const SweepGradient(
            colors: [
              Color(0xFFFF005D),
              Color(0xFFFFD600),
              Color(0xFF00F5FF),
              Color(0xFF7C4DFF),
              Color(0xFFFF00C8),
              Color(0xFFFF005D),
            ],
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.88), width: 4),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF00A8).withValues(alpha: 0.45),
              blurRadius: 56,
              spreadRadius: 8,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.34),
              blurRadius: 42,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          innerColor: Colors.black.withValues(alpha: 0.16),
          innerGradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.16),
              Colors.black.withValues(alpha: 0.16),
            ],
          ),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.38), width: 1.4),
          numberGradient: const [
            Colors.white,
            Color(0xFFFFF176),
            Color(0xFF00F5FF),
          ],
          topColor: Colors.white,
          bottomColor: const Color(0xFFFFF59D),
          labelShadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF00A8).withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 7),
            ),
            Shadow(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.45),
              blurRadius: 16,
            ),
          ],
        );
      case 'galaxy':
      case 'neon':
      case 'aurora':
      case 'fireworks':
      case 'lava':
        final isLava = styleKey == 'lava';
        final isAurora = styleKey == 'aurora';
        return _CountdownModeStyleData(
          outerColor: const Color(0xFF0B0618),
          outerGradient: LinearGradient(
            colors: isLava
                ? const [Color(0xFF1A0502), Color(0xFF4A1103)]
                : isAurora
                    ? const [Color(0xFF001B2E), Color(0xFF021A10)]
                    : const [Color(0xFF120024), Color(0xFF05000F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.22), width: 3),
          shadows: [
            BoxShadow(
              color: (isLava
                      ? const Color(0xFFFF5A00)
                      : isAurora
                          ? const Color(0xFF00FFC8)
                          : const Color(0xFF8A2BFF))
                  .withValues(alpha: 0.42),
              blurRadius: 54,
              spreadRadius: 6,
              offset: const Offset(0, 16),
            ),
          ],
          innerColor: Colors.black.withValues(alpha: 0.12),
          innerGradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.12),
              Colors.black.withValues(alpha: 0.12),
            ],
          ),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
          numberGradient: isLava
              ? const [Color(0xFFFFF176), Color(0xFFFF5A00), Color(0xFFFF1744)]
              : isAurora
                  ? const [
                      Color(0xFFE6FFF9),
                      Color(0xFF00FFC8),
                      Color(0xFF7C4DFF),
                    ]
                  : const [
                      Color(0xFFFFFFFF),
                      Color(0xFF00E5FF),
                      Color(0xFFFF4EBB),
                    ],
          topColor: Colors.white,
          bottomColor:
              isLava ? const Color(0xFFFFD180) : const Color(0xFFBDEBFF),
          labelShadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.48), blurRadius: 10),
          ],
          numberShadows: [
            Shadow(
              color: (isLava ? const Color(0xFFFF5A00) : const Color(0xFF00E5FF))
                  .withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        );
      case 'crystal':
        return _CountdownModeStyleData(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFE8F4FF), Color(0xFFF6EAFF), Color(0xFFFFF8E7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.92), width: 4),
          shadows: [
            BoxShadow(
              color: const Color(0xFF9BE7FF).withValues(alpha: 0.28),
              blurRadius: 46,
              spreadRadius: 4,
              offset: const Offset(0, 14),
            ),
          ],
          innerColor: Colors.white.withValues(alpha: 0.18),
          innerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.18),
            ],
          ),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.52), width: 1),
          numberGradient: const [Color(0xFF7B61FF), Color(0xFFFF65B7)],
          topColor: const Color(0xFF7B61FF),
          bottomColor: const Color(0xFF5C6470),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFF9BE7FF).withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'off':
      default:
        return _CountdownModeStyleData(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFF0F7), Color(0xFFFFDDEF), Color(0xFFFFC8DE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.95), width: 4.5),
          shadows: const [
            BoxShadow(
              color: Color(0xEAFFFFFF),
              blurRadius: 20,
              spreadRadius: 2,
              offset: Offset(-8, -8),
            ),
            BoxShadow(
              color: Color(0x61D4547A),
              blurRadius: 28,
              spreadRadius: 4,
              offset: Offset(8, 12),
            ),
            BoxShadow(
              color: Color(0x4CFF6FA7),
              blurRadius: 48,
              offset: Offset(0, 20),
            ),
          ],
          innerColor: null,
          innerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.52),
              const Color(0xFFFFA6C8).withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
          numberGradient: const [
            Color(0xFFFFFFFF),
            Color(0xFFFF5B9A),
            Color(0xFFD81B60),
          ],
          topColor: Colors.white,
          bottomColor: Colors.white.withValues(alpha: 0.94),
          labelShadows: [
            Shadow(color: const Color(0xFF9D315F).withValues(alpha: 0.52),
                blurRadius: 12),
            Shadow(color: Colors.white.withValues(alpha: 0.70), blurRadius: 4),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFF8D1A3B).withValues(alpha: 0.55),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
            Shadow(
              color: const Color(0xFF8D1A3B).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        );
    }
  }
}
