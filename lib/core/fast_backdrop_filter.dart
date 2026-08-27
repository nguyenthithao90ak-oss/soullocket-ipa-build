import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

/// A global notifier that any scrollable widget can set to true/false.
/// When true, all FastBackdropFilter instances swap to a cheap ColoredBox.
final ValueNotifier<bool> globalScrollingNotifier = ValueNotifier<bool>(false);

class FastBackdropFilter extends StatelessWidget {
  final ImageFilter filter;
  final Widget? child;
  final BlendMode blendMode;
  final Color? fallbackColor;

  const FastBackdropFilter({
    super.key,
    required this.filter,
    this.child,
    this.blendMode = BlendMode.srcOver,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final ui = UiPrefs.notifier.value;
    final resolvedGraphicsQuality = ui.liteMode
        ? 'low'
        : (ui.graphicsQualityKey == 'auto'
            ? UiPrefs.getAutoGraphicsQuality()
            : ui.graphicsQualityKey);
    final useLiteFallback = ui.liteMode ||
        resolvedGraphicsQuality == 'low' ||
        (kIsWeb && resolvedGraphicsQuality != 'high');
    if (useLiteFallback) {
      return ColoredBox(
        color: fallbackColor ??
            Colors.black.withValues(alpha: kIsWeb ? 0.04 : 0.05),
        child: child,
      );
    }
    // During scrolling, skip the expensive GPU blur and use a cheap fallback
    return ValueListenableBuilder<bool>(
      valueListenable: globalScrollingNotifier,
      builder: (context, isScrolling, _) {
        if (isScrolling) {
          return ColoredBox(
            color: fallbackColor ??
                Colors.black.withValues(alpha: 0.06),
            child: child,
          );
        }
        return BackdropFilter(
          filter: filter,
          blendMode: blendMode,
          child: child,
        );
      },
    );
  }
}

