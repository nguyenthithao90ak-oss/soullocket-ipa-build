part of '../../../tabs/main_home_tab.dart';

class _CountdownVisualSpec {
  final Color? outerColor;
  final Gradient? outerGradient;
  final Border? outerBorder;
  final List<BoxShadow> shadows;
  final Color? innerColor;
  final Gradient? innerGradient;
  final Border? innerBorder;
  final List<Color> numberGradient;
  final Color topLabelColor;
  final Color bottomLabelColor;
  final List<Shadow> labelShadows;
  final List<Shadow> numberShadows;

  const _CountdownVisualSpec({
    required this.outerColor,
    required this.outerGradient,
    required this.outerBorder,
    required this.shadows,
    required this.innerColor,
    required this.innerGradient,
    required this.innerBorder,
    required this.numberGradient,
    required this.topLabelColor,
    required this.bottomLabelColor,
    required this.labelShadows,
    required this.numberShadows,
  });

  factory _CountdownVisualSpec.resolve(String styleKey, bool transparentMode) {
    final isBasicStyle = styleKey == 'default' ||
        styleKey == 'glass' ||
        styleKey == 'plain' ||
        styleKey.isEmpty;
    if (transparentMode && isBasicStyle) {
      return _CountdownVisualSpec(
        outerColor: Colors.white.withValues(alpha: 0.30),
        outerGradient: null,
        outerBorder:
            Border.all(color: Colors.white.withValues(alpha: 0.34), width: 2.2),
        shadows: const [],
        innerColor: Colors.white.withValues(alpha: 0.08),
        innerGradient: null,
        innerBorder: null,
        numberGradient: const [Colors.white, Color(0xFFFFD1E4)],
        topLabelColor: Colors.white,
        bottomLabelColor: Colors.white.withValues(alpha: 0.92),
        labelShadows: const [
          Shadow(color: Colors.black, blurRadius: 8),
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
        return _CountdownVisualSpec(
          outerColor: Colors.white,
          outerGradient: null,
          outerBorder: Border.all(color: const Color(0xFFE9DDE6), width: 2.2),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          innerColor: const Color(0xFFFBF8FA),
          innerGradient: null,
          innerBorder: null,
          numberGradient: const [Color(0xFF252036), Color(0xFF51465F)],
          topLabelColor: const Color(0xFF51465F),
          bottomLabelColor: const Color(0xFF6E6475),
          labelShadows: const [],
          numberShadows: const [],
        );
      case 'floating_hearts':
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: null,
          outerBorder: null,
          shadows: [
            BoxShadow(
              color: const Color(0xFFFFC0CB).withValues(alpha: 0.25),
              blurRadius: 24.0,
              spreadRadius: 2.0,
              offset: const Offset(0, 10),
            ),
          ],
          innerColor: Colors.white.withValues(alpha: 0.08),
          innerGradient: null,
          innerBorder: null,
          numberGradient: const [
            Color(0xFFAD1457),
            Color(0xFFD81B60),
            Color(0xFFEC407A),
          ],
          topLabelColor: const Color(0xFFE91E63),
          bottomLabelColor: const Color(0xFFF06292),
          labelShadows: const [],
          numberShadows: const [],
        );
      case 'rose_wave':
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFFCFE), Color(0xFFFFEAF4), Color(0xFFFFCFE1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder: Border.all(
              color: Colors.white.withValues(alpha: 0.92), width: 4.5),
          shadows: const [],
          innerColor: null,
          innerGradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.34),
              const Color(0xFFFF9FBE).withValues(alpha: 0.20),
              Colors.white.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.34), width: 1),
          numberGradient: const [Color(0xFFFFF7FB), Color(0xFFFFD7E8)],
          topLabelColor: Colors.white,
          bottomLabelColor: Colors.white.withValues(alpha: 0.94),
          labelShadows: const [],
          numberShadows: const [],
        );
      case 'glass':
        return _CountdownVisualSpec(
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
          innerGradient: null,
          innerBorder: Border.all(
              color: Colors.white.withValues(alpha: 0.42), width: 1.2),
          numberGradient: const [Color(0xFF27B4FF), Color(0xFFD81B60)],
          topLabelColor: const Color(0xFF2378A8),
          bottomLabelColor: const Color(0xFF51606D),
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
        return _CountdownVisualSpec(
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
          innerBorder: null,
          numberGradient: const [Color(0xFFFF2F7A), Color(0xFFB5179E)],
          topLabelColor: const Color(0xFFC2185B),
          bottomLabelColor: const Color(0xFF7A2C58),
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
        return _CountdownVisualSpec(
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
          innerGradient: null,
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.58), width: 1),
          numberGradient: const [Color(0xFFFF3D9A), Color(0xFF36C9FF)],
          topLabelColor: const Color(0xFFE6378D),
          bottomLabelColor: const Color(0xFF4C6178),
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
        return _CountdownVisualSpec(
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
          innerGradient: null,
          innerBorder: Border.all(
              color: Colors.white.withValues(alpha: 0.38), width: 1.4),
          numberGradient: const [
            Colors.white,
            Color(0xFFFFF176),
            Color(0xFF00F5FF),
          ],
          topLabelColor: Colors.white,
          bottomLabelColor: const Color(0xFFFFF59D),
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
        return _CountdownVisualSpec(
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
          innerGradient: null,
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
          topLabelColor: Colors.white,
          bottomLabelColor:
              isLava ? const Color(0xFFFFD180) : const Color(0xFFBDEBFF),
          labelShadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.48), blurRadius: 10),
          ],
          numberShadows: [
            Shadow(
              color:
                  (isLava ? const Color(0xFFFF5A00) : const Color(0xFF00E5FF))
                      .withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        );
      case 'crystal':
        return _CountdownVisualSpec(
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
          innerGradient: null,
          innerBorder:
              Border.all(color: Colors.white.withValues(alpha: 0.52), width: 1),
          numberGradient: const [Color(0xFF7B61FF), Color(0xFFFF65B7)],
          topLabelColor: const Color(0xFF7B61FF),
          bottomLabelColor: const Color(0xFF5C6470),
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
      default:
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFF2F8),
              Color(0xFFFFE3F0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 5.0,
          ),
          shadows: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.9),
              blurRadius: 16,
              spreadRadius: 4,
              offset: const Offset(-6, -6),
            ),
            BoxShadow(
              color: const Color(0xFFFF85B3).withValues(alpha: 0.25),
              blurRadius: 36,
              spreadRadius: 8,
              offset: const Offset(8, 12),
            ),
            BoxShadow(
              color: const Color(0xFFFF5E92).withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
          innerColor: Colors.white.withValues(alpha: 0.5),
          innerGradient: const LinearGradient(
            colors: [
              Color(0x40FFFFFF),
              Color(0x10FFFFFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
          numberGradient: const [
            Color(0xFFFF3377),
            Color(0xFFFF72A1),
            Color(0xFFFF8EB5),
          ],
          topLabelColor: const Color(0xFFFF4282),
          bottomLabelColor: const Color(0xFFFF548F),
          labelShadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.9),
              blurRadius: 8,
              offset: const Offset(1, 1),
            ),
            Shadow(
              color: const Color(0xFFFF5E92).withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF1E69).withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            Shadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 4,
              offset: const Offset(-2, -2),
            ),
          ],
        );
    }
  }
}
