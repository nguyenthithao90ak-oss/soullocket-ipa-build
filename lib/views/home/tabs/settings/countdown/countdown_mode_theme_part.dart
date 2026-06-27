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
    required this.outerGradient,
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

  final Gradient outerGradient;
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
    if (transparentMode) {
      return _CountdownModeStyleData(
        outerGradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
      case 'default':
        return _CountdownModeStyleData(
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFDF7FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerGradient: LinearGradient(
            colors: [
              const Color(0xFFFFE8F2).withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.86), width: 3.4),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.36), width: 1),
          shadows: [
            BoxShadow(
              color: const Color(0xFFD94C86).withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          numberGradient: const [Color(0xFFD94C86), Color(0xFF8A4B7A)],
          topColor: const Color(0xFFBF3D75),
          bottomColor: const Color(0xFF6E5B68),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.82), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFD94C86).withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        );
      case 'plain':
        return const _CountdownModeStyleData(
          outerGradient:
              LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF8F3F7)]),
          innerGradient:
              LinearGradient(colors: [Color(0xFFFBF8FA), Color(0xFFF4EEF4)]),
          outerBorder: Border.fromBorderSide(
              BorderSide(color: Color(0xFFE8DCE6), width: 2.2)),
          innerBorder: Border.fromBorderSide(
              BorderSide(color: Color(0xFFF3EBF1), width: 1)),
          shadows: [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8))
          ],
          numberGradient: [Color(0xFF252036), Color(0xFF51465F)],
          topColor: Color(0xFF51465F),
          bottomColor: Color(0xFF6E6475),
          labelShadows: [],
          numberShadows: [],
        );
      case 'glass':
        return _CountdownModeStyleData(
          outerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.88),
              const Color(0xFFE8F6FF).withValues(alpha: 0.64)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.26),
              Colors.white.withValues(alpha: 0.10)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.82), width: 3),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.38), width: 1.2),
          shadows: [
            BoxShadow(
              color: const Color(0xFF8EC5FC).withValues(alpha: 0.30),
              blurRadius: 42,
              offset: const Offset(0, 18),
            ),
          ],
          numberGradient: const [Color(0xFF27B4FF), Color(0xFFD81B60)],
          topColor: const Color(0xFF2378A8),
          bottomColor: const Color(0xFF51606D),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.84), blurRadius: 8)
          ],
          numberShadows: const [
            Shadow(
                color: Color(0x2E27B4FF), blurRadius: 16, offset: Offset(0, 6)),
          ],
        );
      case 'glow':
      case 'candy':
        return _CountdownModeStyleData(
          outerGradient: LinearGradient(
            colors: styleKey == 'glow'
                ? const [Color(0xFFFFF5FA), Color(0xFFFFD9E8)]
                : const [
                    Color(0xFFFFE3F3),
                    Color(0xFFE0F7FF),
                    Color(0xFFFFF4C8)
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerGradient: LinearGradient(
            colors: styleKey == 'glow'
                ? [
                    const Color(0xFFFF8DB5).withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0.10)
                  ]
                : [
                    Colors.white.withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0.10)
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.86), width: 4.5),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.42), width: 1),
          shadows: [
            BoxShadow(
              color: (styleKey == 'glow'
                      ? const Color(0xFFFF5E92)
                      : const Color(0xFFFF77C8))
                  .withValues(alpha: 0.32),
              blurRadius: 38,
              offset: const Offset(0, 14),
            ),
          ],
          numberGradient: styleKey == 'glow'
              ? const [Color(0xFFFF2F7A), Color(0xFFB5179E)]
              : const [Color(0xFFFF3D9A), Color(0xFF36C9FF)],
          topColor: styleKey == 'glow'
              ? const Color(0xFFC2185B)
              : const Color(0xFFE6378D),
          bottomColor: styleKey == 'glow'
              ? const Color(0xFF7A2C58)
              : const Color(0xFF4C6178),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.82), blurRadius: 8)
          ],
          numberShadows: [
            Shadow(
              color: (styleKey == 'glow'
                      ? const Color(0xFFFF2F7A)
                      : const Color(0xFFFF3D9A))
                  .withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'galaxy':
      case 'aurora':
      case 'fireworks':
      case 'lava':
      case 'crystal':
        final isLava = styleKey == 'lava';
        final isAurora = styleKey == 'aurora';
        final isCrystal = styleKey == 'crystal';
        return _CountdownModeStyleData(
          outerGradient: LinearGradient(
            colors: isCrystal
                ? const [
                    Color(0xFFE8F4FF),
                    Color(0xFFF6EAFF),
                    Color(0xFFFFF8E7)
                  ]
                : isLava
                    ? const [Color(0xFF1A0502), Color(0xFF4A1103)]
                    : isAurora
                        ? const [Color(0xFF001B2E), Color(0xFF021A10)]
                        : const [Color(0xFF120024), Color(0xFF05000F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerGradient: LinearGradient(
            colors: isCrystal
                ? [
                    Colors.white.withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0.10)
                  ]
                : [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.02)
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: isCrystal ? 0.92 : 0.22),
            width: isCrystal ? 4 : 3,
          ),
          innerBorder: Border.all(
            color: Colors.white.withValues(alpha: isCrystal ? 0.52 : 0.18),
            width: 1,
          ),
          shadows: [
            BoxShadow(
              color: (isCrystal
                      ? const Color(0xFF9BE7FF)
                      : isLava
                          ? const Color(0xFFFF5A00)
                          : isAurora
                              ? const Color(0xFF00FFC8)
                              : const Color(0xFF8A2BFF))
                  .withValues(alpha: 0.34),
              blurRadius: 46,
              offset: const Offset(0, 16),
            ),
          ],
          numberGradient: isCrystal
              ? const [Color(0xFF7B61FF), Color(0xFFFF65B7)]
              : isLava
                  ? const [
                      Color(0xFFFFF176),
                      Color(0xFFFF5A00),
                      Color(0xFFFF1744)
                    ]
                  : isAurora
                      ? const [
                          Color(0xFFE6FFF9),
                          Color(0xFF00FFC8),
                          Color(0xFF7C4DFF)
                        ]
                      : const [
                          Color(0xFFFFFFFF),
                          Color(0xFF00E5FF),
                          Color(0xFFFF4EBB)
                        ],
          topColor: isCrystal ? const Color(0xFF7B61FF) : Colors.white,
          bottomColor: isCrystal
              ? const Color(0xFF5C6470)
              : isLava
                  ? const Color(0xFFFFD180)
                  : const Color(0xFFBDEBFF),
          labelShadows: [
            Shadow(
              color: isCrystal
                  ? Colors.white.withValues(alpha: 0.90)
                  : Colors.black.withValues(alpha: 0.48),
              blurRadius: 8,
            ),
          ],
          numberShadows: [
            Shadow(
              color: (isCrystal
                      ? const Color(0xFF9BE7FF)
                      : isLava
                          ? const Color(0xFFFF5A00)
                          : const Color(0xFF00E5FF))
                  .withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'floating_hearts':
        return _CountdownModeStyleData(
          outerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95),
              const Color(0xFFFFEAF4).withValues(alpha: 0.90),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerGradient: LinearGradient(
            colors: [
              const Color(0xFFFFB6D4).withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.90), width: 4.5),
          innerBorder:
              Border.all(color: const Color(0xFFFFB6D4).withValues(alpha: 0.28), width: 1.2),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF69B4).withValues(alpha: 0.26),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
          numberGradient: const [Color(0xFFE8367E), Color(0xFFFF85BE)],
          topColor: const Color(0xFFCC3377),
          bottomColor: const Color(0xFF7A5C6E),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.84), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF69B4).withValues(alpha: 0.26),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'rose_wave':
      default:
        return _CountdownModeStyleData(
          outerGradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFFF2F8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerGradient: LinearGradient(
            colors: [
              const Color(0xFFFFC6DA).withValues(alpha: 0.32),
              Colors.white.withValues(alpha: 0.08)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.78), width: 4),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF69B4).withValues(alpha: 0.22),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
          numberGradient: const [SLColors.primary, SLColors.secondary],
          topColor: const Color(0xFFD9508A),
          bottomColor: const Color(0xFF6B5B79),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.74), blurRadius: 8)
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF7AA8).withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
    }
  }
}
