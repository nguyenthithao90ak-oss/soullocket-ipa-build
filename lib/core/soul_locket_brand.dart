import 'package:flutter/material.dart';

@immutable
class SoulLocketBrandStyle {
  final String key;
  final String label;
  final List<Color> backgroundColors;
  final Color frameColor;
  final Color surfaceColor;
  final Color heartColor;
  final Color heartOutlineColor;
  final Color glowColor;
  final Color sparkleColor;

  const SoulLocketBrandStyle({
    required this.key,
    required this.label,
    required this.backgroundColors,
    required this.frameColor,
    required this.surfaceColor,
    required this.heartColor,
    required this.heartOutlineColor,
    required this.glowColor,
    required this.sparkleColor,
  });
}

class SoulLocketBrand {
  SoulLocketBrand._();

  static const String defaultStyleKey = 'rose';

  static const List<SoulLocketBrandStyle> styles = <SoulLocketBrandStyle>[
    SoulLocketBrandStyle(
      key: 'rose',
      label: 'Rose Glow',
      backgroundColors: <Color>[Color(0xFFFFD5E4), Color(0xFFFF7EA8)],
      frameColor: Color(0xFFF8A7C1),
      surfaceColor: Color(0xFFFFF7FB),
      heartColor: Color(0xFFD81B60),
      heartOutlineColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFFFF7EA8),
      sparkleColor: Color(0xFFFFC5D9),
    ),
    SoulLocketBrandStyle(
      key: 'mint',
      label: 'Mint Kiss',
      backgroundColors: <Color>[Color(0xFFCBF5E8), Color(0xFF62D7B5)],
      frameColor: Color(0xFF8EE2C9),
      surfaceColor: Color(0xFFF4FFFB),
      heartColor: Color(0xFF0F9D84),
      heartOutlineColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFF38CBA7),
      sparkleColor: Color(0xFFBEF8E9),
    ),
    SoulLocketBrandStyle(
      key: 'ocean',
      label: 'Ocean Love',
      backgroundColors: <Color>[Color(0xFFD6F2FF), Color(0xFF5CB8FF)],
      frameColor: Color(0xFF97D7FF),
      surfaceColor: Color(0xFFF5FBFF),
      heartColor: Color(0xFF1877F2),
      heartOutlineColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFF5CB8FF),
      sparkleColor: Color(0xFFC8E8FF),
    ),
    SoulLocketBrandStyle(
      key: 'sunset',
      label: 'Sunset Pop',
      backgroundColors: <Color>[Color(0xFFFFDEB5), Color(0xFFFF8A65)],
      frameColor: Color(0xFFFFBC9E),
      surfaceColor: Color(0xFFFFFAF5),
      heartColor: Color(0xFFE85D04),
      heartOutlineColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFFFF9966),
      sparkleColor: Color(0xFFFFD7BD),
    ),
    SoulLocketBrandStyle(
      key: 'violet',
      label: 'Lilac Dream',
      backgroundColors: <Color>[Color(0xFFE4D8FF), Color(0xFFA971FF)],
      frameColor: Color(0xFFC9B0FF),
      surfaceColor: Color(0xFFFBF9FF),
      heartColor: Color(0xFF7C3AED),
      heartOutlineColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFFA971FF),
      sparkleColor: Color(0xFFE0D2FF),
    ),
    SoulLocketBrandStyle(
      key: 'midnight',
      label: 'Midnight',
      backgroundColors: <Color>[Color(0xFF243B55), Color(0xFF0F172A)],
      frameColor: Color(0xFF3F5E7A),
      surfaceColor: Color(0xFF162133),
      heartColor: Color(0xFFFF8CB6),
      heartOutlineColor: Color(0xFFEAF2FF),
      glowColor: Color(0xFF2A4365),
      sparkleColor: Color(0xFF9EC5FF),
    ),
    SoulLocketBrandStyle(
      key: 'aurora',
      label: 'Aurora',
      backgroundColors: <Color>[Color(0xFF67E8F9), Color(0xFF7C3AED)],
      frameColor: Color(0xFFA5B4FC),
      surfaceColor: Color(0xFFF9FAFB),
      heartColor: Color(0xFFFF5FA2),
      heartOutlineColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFF818CF8),
      sparkleColor: Color(0xFFC7D2FE),
    ),
    SoulLocketBrandStyle(
      key: 'sakura',
      label: 'Sakura Petal',
      backgroundColors: <Color>[Color(0xFFFFF1F2), Color(0xFFFDA4AF)],
      frameColor: Color(0xFFFECDD3),
      surfaceColor: Color(0xFFFFFBFB),
      heartColor: Color(0xFFFF5E7E),
      heartOutlineColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFFFF85A1),
      sparkleColor: Color(0xFFFFE3EA),
    ),
    SoulLocketBrandStyle(
      key: 'gold',
      label: 'Gold Luxury',
      backgroundColors: <Color>[Color(0xFFFEF3C7), Color(0xFFD97706)],
      frameColor: Color(0xFFFCD34D),
      surfaceColor: Color(0xFFFFFBEB),
      heartColor: Color(0xFFB45309),
      heartOutlineColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFFFBBF24),
      sparkleColor: Color(0xFFFEF3C7),
    ),
  ];

  static List<String> get supportedStyleKeys =>
      styles.map((style) => style.key).toList(growable: false);

  static String normalizeStyleKey(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (supportedStyleKeys.contains(normalized)) {
      return normalized;
    }
    return defaultStyleKey;
  }

  static SoulLocketBrandStyle styleFor(String? key) {
    final normalized = normalizeStyleKey(key);
    for (final style in styles) {
      if (style.key == normalized) {
        return style;
      }
    }
    return styles.first;
  }

  static String labelFor(String? key) => styleFor(key).label;
}
