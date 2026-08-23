import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

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

  /// Scroll physics adaptive theo ná»n táº£ng:
  /// - iOS: BouncingScrollPhysics (kÃ©o over-scroll)
  /// - Android/web: ClampingScrollPhysics (káº¹t cá»©ng)
  static ScrollPhysics scrollPhysicsForPlatform() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const BouncingScrollPhysics();
    }
    return const ClampingScrollPhysics();
  }
}

