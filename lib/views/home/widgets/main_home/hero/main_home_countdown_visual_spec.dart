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
    final isBasicStyle =
        styleKey == 'default' ||
        styleKey == 'glass' ||
        styleKey == 'plain' ||
        styleKey.isEmpty;
    if (transparentMode && isBasicStyle) {
      return _CountdownVisualSpec(
        outerColor: Colors.white.withValues(alpha: 0.30),
        outerGradient: null,
        outerBorder: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
          width: 2.2,
        ),
        shadows: const [],
        innerColor: Colors.white.withValues(alpha: 0.08),
        innerGradient: null,
        innerBorder: null,
        numberGradient: const [Colors.white, Color(0xFFFFD1E4)],
        topLabelColor: Colors.white,
        bottomLabelColor: Colors.white.withValues(alpha: 0.92),
        labelShadows: const [Shadow(color: Colors.black, blurRadius: 8)],
        numberShadows: const [
          Shadow(color: Colors.black, blurRadius: 18, offset: Offset(0, 6)),
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
          outerGradient: const SweepGradient(
            colors: [
              Color(0xFFFF4F93),
              Color(0xFFFFB5D0),
              Color(0xFFB388FF),
              Color(0xFFFFD166),
              Color(0xFFFF4F93),
            ],
          ),
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 5,
          ),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF4F93).withValues(alpha: 0.46),
              blurRadius: 52,
              spreadRadius: 7,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: const Color(0xFF9B5DE5).withValues(alpha: 0.24),
              blurRadius: 34,
              spreadRadius: 1,
            ),
          ],
          innerColor: null,
          innerGradient: RadialGradient(
            center: const Alignment(-0.35, -0.42),
            radius: 1.15,
            colors: [
              Colors.white.withValues(alpha: 0.92),
              const Color(0xFFFFE7F1).withValues(alpha: 0.82),
              const Color(0xFFEFE4FF).withValues(alpha: 0.72),
            ],
          ),
          innerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.72),
            width: 1.4,
          ),
          numberGradient: const [
            Color(0xFFAD1457),
            Color(0xFFFF2E84),
            Color(0xFF8E4FD8),
          ],
          topLabelColor: const Color(0xFF9E174D),
          bottomLabelColor: const Color(0xFF7D3862),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.92), blurRadius: 9),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF4F93).withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 7),
            ),
          ],
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
            color: Colors.white.withValues(alpha: 0.92),
            width: 4.5,
          ),
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
          innerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.34),
            width: 1,
          ),
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
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.82),
            width: 3,
          ),
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
            color: Colors.white.withValues(alpha: 0.42),
            width: 1.2,
          ),
          numberGradient: const [Color(0xFF27B4FF), Color(0xFFD81B60)],
          topLabelColor: const Color(0xFF51606D),
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
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.82),
            width: 5,
          ),
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
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 4,
          ),
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
          innerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.58),
            width: 1,
          ),
          numberGradient: const [Color(0xFFFF3D9A), Color(0xFF36C9FF)],
          topLabelColor: const Color(0xFF4C6178),
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
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.88),
            width: 4,
          ),
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
            color: Colors.white.withValues(alpha: 0.38),
            width: 1.4,
          ),
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
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 3,
          ),
          shadows: [
            BoxShadow(
              color:
                  (isLava
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
          innerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
          numberGradient: isLava
              ? const [Color(0xFFFFF176), Color(0xFFFF5A00), Color(0xFFFF1744)]
              : isAurora
              ? const [Color(0xFFE6FFF9), Color(0xFF00FFC8), Color(0xFF7C4DFF)]
              : const [Color(0xFFFFFFFF), Color(0xFF00E5FF), Color(0xFFFF4EBB)],
          topLabelColor: Colors.white,
          bottomLabelColor: isLava
              ? const Color(0xFFFFD180)
              : const Color(0xFFBDEBFF),
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
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 4,
          ),
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
          innerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.52),
            width: 1,
          ),
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
      case 'fireworks':
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: const SweepGradient(
            colors: [
              Color(0xFF1A0638),
              Color(0xFF5D1D8B),
              Color(0xFFFF4E9B),
              Color(0xFFFFC857),
              Color(0xFF1A0638),
            ],
          ),
          outerBorder: Border.all(
            color: const Color(0xFFFFE7A3).withValues(alpha: 0.78),
            width: 3.5,
          ),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF4E9B).withValues(alpha: 0.38),
              blurRadius: 48,
              spreadRadius: 5,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: const Color(0xFFFFC857).withValues(alpha: 0.22),
              blurRadius: 28,
            ),
          ],
          innerColor: const Color(0xFF110321),
          innerGradient: const RadialGradient(
            colors: [Color(0xFF3A0B62), Color(0xFF110321)],
          ),
          innerBorder: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          numberGradient: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFD76A),
            Color(0xFFFF4E9B),
          ],
          topLabelColor: Colors.white,
          bottomLabelColor: const Color(0xFFFFE7A3),
          labelShadows: const [Shadow(color: Colors.black, blurRadius: 10)],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF4E9B).withValues(alpha: 0.48),
              blurRadius: 23,
              offset: const Offset(0, 7),
            ),
          ],
        );
      case 'cherry_blossom':
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFFAF4), Color(0xFFFFD8E5), Color(0xFFF8BBD0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 4,
          ),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF8FB1).withValues(alpha: 0.30),
              blurRadius: 42,
              spreadRadius: 3,
              offset: const Offset(0, 14),
            ),
          ],
          innerColor: null,
          innerGradient: const RadialGradient(
            center: Alignment.topLeft,
            colors: [Color(0xFFFFFCFD), Color(0xFFFFE9F1)],
          ),
          innerBorder: Border.all(
            color: const Color(0xFFFFA7C1).withValues(alpha: 0.46),
          ),
          numberGradient: const [Color(0xFFD81B60), Color(0xFFFF6F9F)],
          topLabelColor: const Color(0xFF9D3159),
          bottomLabelColor: const Color(0xFF8A4B63),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.90), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF8FB1).withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'meteor_shower':
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFF080C2B), Color(0xFF312E81), Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder: Border.all(
            color: const Color(0xFFC4B5FD).withValues(alpha: 0.66),
            width: 3.2,
          ),
          shadows: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.42),
              blurRadius: 50,
              spreadRadius: 5,
              offset: const Offset(0, 16),
            ),
          ],
          innerColor: const Color(0xFF090D2B),
          innerGradient: const RadialGradient(
            center: Alignment.topLeft,
            colors: [Color(0xFF312E81), Color(0xFF080B25)],
          ),
          innerBorder: Border.all(color: Colors.white.withValues(alpha: 0.17)),
          numberGradient: const [
            Color(0xFFFFFFFF),
            Color(0xFF67E8F9),
            Color(0xFFC084FC),
          ],
          topLabelColor: Colors.white,
          bottomLabelColor: const Color(0xFFDDD6FE),
          labelShadows: const [Shadow(color: Colors.black, blurRadius: 10)],
          numberShadows: [
            Shadow(
              color: const Color(0xFF67E8F9).withValues(alpha: 0.40),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        );
      case 'deep_ocean':
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFF001F3F), Color(0xFF006994), Color(0xFF00B4D8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder: Border.all(
            color: const Color(0xFF90E0EF).withValues(alpha: 0.72),
            width: 3.5,
          ),
          shadows: [
            BoxShadow(
              color: const Color(0xFF00B4D8).withValues(alpha: 0.38),
              blurRadius: 48,
              spreadRadius: 4,
              offset: const Offset(0, 16),
            ),
          ],
          innerColor: const Color(0xFF002B4D),
          innerGradient: const RadialGradient(
            center: Alignment.topLeft,
            colors: [Color(0xFF0077A8), Color(0xFF001F3F)],
          ),
          innerBorder: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          numberGradient: const [
            Color(0xFFFFFFFF),
            Color(0xFF90E0EF),
            Color(0xFF52FFD5),
          ],
          topLabelColor: Colors.white,
          bottomLabelColor: const Color(0xFFB8F2FF),
          labelShadows: const [Shadow(color: Colors.black, blurRadius: 10)],
          numberShadows: [
            Shadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.36),
              blurRadius: 21,
              offset: const Offset(0, 7),
            ),
          ],
        );
      case 'golden_sunset':
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFD166), Color(0xFFFF8C61), Color(0xFFC94B86)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder: Border.all(
            color: const Color(0xFFFFF1BD).withValues(alpha: 0.82),
            width: 4,
          ),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF8C61).withValues(alpha: 0.38),
              blurRadius: 46,
              spreadRadius: 4,
              offset: const Offset(0, 15),
            ),
          ],
          innerColor: null,
          innerGradient: const RadialGradient(
            center: Alignment.topLeft,
            colors: [Color(0xFFFFE8A3), Color(0xFFFF9A76)],
          ),
          innerBorder: Border.all(color: Colors.white.withValues(alpha: 0.36)),
          numberGradient: const [
            Color(0xFFFFFDF1),
            Color(0xFFFFD166),
            Color(0xFFB72F72),
          ],
          topLabelColor: const Color(0xFF73294F),
          bottomLabelColor: const Color(0xFF70304B),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.50), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFB72F72).withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        );
      case 'neon_pulse':
        return _CountdownVisualSpec(
          outerColor: const Color(0xFF05010D),
          outerGradient: const SweepGradient(
            colors: [
              Color(0xFFFF2E97),
              Color(0xFF00F5FF),
              Color(0xFF9D4EDD),
              Color(0xFFFF2E97),
            ],
          ),
          outerBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.30),
            width: 3,
          ),
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF2E97).withValues(alpha: 0.42),
              blurRadius: 50,
              spreadRadius: 5,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.30),
              blurRadius: 32,
            ),
          ],
          innerColor: const Color(0xFF080313),
          innerGradient: const RadialGradient(
            colors: [Color(0xFF291047), Color(0xFF080313)],
          ),
          innerBorder: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          numberGradient: const [
            Color(0xFFFFFFFF),
            Color(0xFF00F5FF),
            Color(0xFFFF2E97),
          ],
          topLabelColor: Colors.white,
          bottomLabelColor: const Color(0xFFB9FBFF),
          labelShadows: const [Shadow(color: Colors.black, blurRadius: 10)],
          numberShadows: [
            Shadow(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.48),
              blurRadius: 24,
              offset: const Offset(0, 7),
            ),
          ],
        );
      default:
        return _CountdownVisualSpec(
          outerColor: null,
          outerGradient: const LinearGradient(
            colors: [Color(0xFFFFFDF8), Color(0xFFFFF1EB), Color(0xFFFFE5D8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          outerBorder: Border.all(color: const Color(0xFFE7CFC5), width: 2.0),
          shadows: [
            BoxShadow(
              color: const Color(0xFF6E3E45).withValues(alpha: 0.13),
              blurRadius: 28,
              spreadRadius: -8,
              offset: const Offset(0, 16),
            ),
          ],
          innerColor: const Color(0xFFFFFAF4),
          innerGradient: const LinearGradient(
            colors: [Color(0xFFFFFCF8), Color(0xFFFFF1F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          innerBorder: Border.all(color: const Color(0xFFF0DCD3), width: 1.0),
          numberGradient: const [
            Color(0xFFC93B59),
            Color(0xFFE65372),
            Color(0xFFF08A8D),
          ],
          topLabelColor: const Color(0xFF7C515C),
          bottomLabelColor: const Color(0xFF7C515C),
          labelShadows: const [],
          numberShadows: [
            Shadow(
              color: const Color(0xFFE65372).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        );
    }
  }
}
