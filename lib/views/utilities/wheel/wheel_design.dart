import 'package:flutter/material.dart';

abstract final class WheelDesign {
  static const ink = Color(0xFF493443);
  static const muted = Color(0xFF806F7B);
  static const accent = Color(0xFFA84468);
  static const border = Color(0xFFEADDE4);
  static const palette = [
    Color(0xFFF5BCD0),
    Color(0xFFCFC3EF),
    Color(0xFFF3D68D),
    Color(0xFFB8DDCD),
    Color(0xFFBED8EE),
    Color(0xFFF3C6B3),
    Color(0xFFE8C7E6),
    Color(0xFFD4DEA8),
  ];

  static Color choiceColor(int index) => index < palette.length
      ? palette[index]
      : HSVColor.fromAHSV(1, (index * 137.5) % 360, 0.25, 0.92).toColor();

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: const Color(0xFFFFFCFA),
    borderRadius: BorderRadius.circular(26),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: ink.withValues(alpha: 0.045),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
