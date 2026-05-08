import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

class FastBackdropFilter extends StatelessWidget {
  final ImageFilter filter;
  final Widget? child;
  final BlendMode blendMode;

  const FastBackdropFilter({
    super.key,
    required this.filter,
    this.child,
    this.blendMode = BlendMode.srcOver,
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
        color: Colors.black.withValues(alpha: kIsWeb ? 0.04 : 0.05),
        child: child,
      );
    }
    return BackdropFilter(
      filter: filter,
      blendMode: blendMode,
      child: child,
    );
  }
}
