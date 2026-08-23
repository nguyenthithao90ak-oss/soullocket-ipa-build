import 'package:flutter/material.dart';
import '../sl_theme.dart';

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

  static List<BoxShadow> gold = [
    BoxShadow(
      color: SLColors.warningGold.withValues(alpha: 0.35),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];

  /// Ambient glow mềm mại cho card — cảm giác floating như app dating
  static List<BoxShadow> dreamy = [
    BoxShadow(
      color: SLColors.primary.withValues(alpha: 0.08),
      blurRadius: 32,
      spreadRadius: -4,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Glow hồng nhẹ cho button nổi bật
  static List<BoxShadow> rosePetal = [
    BoxShadow(
      color: const Color(0xFFFF4B91).withValues(alpha: 0.20),
      blurRadius: 24,
      spreadRadius: -2,
      offset: const Offset(0, 8),
    ),
  ];

  /// Shadow mềm mại cho bottom sheet
  static List<BoxShadow> sheet = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.10),
      blurRadius: 40,
      offset: const Offset(0, -12),
    ),
  ];
}

/// ─── Extended Shadow Presets ──────────────────────────────
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
