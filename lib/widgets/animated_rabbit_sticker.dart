import 'dart:math' as math;

import 'package:flutter/material.dart';

const String _interactionStickerPrefix = 'assets/images/interaction_stickers/';
const String _numberedStickerPrefix =
    'assets/images/interaction_stickers/custom/numbered/';
const String _cutoutStickerPrefix = 'assets/images/sticker_import/cutout/';

bool isAnimatedRabbitStickerAsset(String assetPath) {
  final normalized = assetPath.trim().toLowerCase();
  return normalized.startsWith(_interactionStickerPrefix) ||
      normalized.startsWith(_cutoutStickerPrefix);
}

class AnimatedRabbitSticker extends StatelessWidget {
  const AnimatedRabbitSticker(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.isAntiAlias = true,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isAntiAlias;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final image = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      isAntiAlias: isAntiAlias,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
    if (reduceMotion || !isAnimatedRabbitStickerAsset(assetPath)) {
      return image;
    }
    return _RabbitStickerMotion(
      assetPath: assetPath,
      child: RepaintBoundary(child: image),
    );
  }
}

class _RabbitStickerMotion extends StatefulWidget {
  const _RabbitStickerMotion({
    required this.assetPath,
    required this.child,
  });

  final String assetPath;
  final Widget child;

  @override
  State<_RabbitStickerMotion> createState() => _RabbitStickerMotionState();
}

enum _StickerMotionPreset {
  bounce,
  sway,
  pulse,
  wiggle,
  float,
  pop,
}

class _RabbitStickerMotionState extends State<_RabbitStickerMotion>
    with SingleTickerProviderStateMixin {
  late final String _normalizedPath = widget.assetPath.trim().toLowerCase();
  late final int _seed = widget.assetPath.codeUnits.fold<int>(
    0,
    (sum, unit) => sum + unit,
  );
  late final _StickerMotionPreset _preset = _resolvePreset(_normalizedPath);
  late final double _phase = (_seed % 360) * math.pi / 180;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: _baseDurationFor(_preset) + (_seed % 5) * 110,
    ),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final childWidget = child;
        if (childWidget == null) {
          return const SizedBox.shrink();
        }

        final cycle = (_controller.value * math.pi * 2) + _phase;
        final primary = math.sin(cycle);
        final secondary = math.sin((cycle * 2) + (_phase * 0.7));
        final tertiary = math.sin((cycle * 3) - (_phase * 0.45));
        final lift = (math.sin(cycle - (math.pi / 2)) + 1) / 2;
        final isNumberedSticker = _normalizedPath.startsWith(
          _numberedStickerPrefix,
        );
        final keepAspectRatio = _normalizedPath.startsWith(
          _cutoutStickerPrefix,
        );

        return _buildMotion(
          childWidget,
          primary: primary,
          secondary: secondary,
          tertiary: tertiary,
          lift: lift,
          alignment:
              isNumberedSticker ? Alignment.bottomCenter : Alignment.center,
          keepAspectRatio: keepAspectRatio,
        );
      },
    );
  }

  int _baseDurationFor(_StickerMotionPreset preset) {
    switch (preset) {
      case _StickerMotionPreset.bounce:
        return 1320;
      case _StickerMotionPreset.sway:
        return 1710;
      case _StickerMotionPreset.pulse:
        return 1640;
      case _StickerMotionPreset.wiggle:
        return 1240;
      case _StickerMotionPreset.float:
        return 1920;
      case _StickerMotionPreset.pop:
        return 1420;
    }
  }

  _StickerMotionPreset _resolvePreset(String normalizedPath) {
    final index = _extractStickerIndex(normalizedPath);
    if (normalizedPath.startsWith(_numberedStickerPrefix)) {
      switch (index % 6) {
        case 0:
          return _StickerMotionPreset.bounce;
        case 1:
          return _StickerMotionPreset.wiggle;
        case 2:
          return _StickerMotionPreset.pulse;
        case 3:
          return _StickerMotionPreset.sway;
        case 4:
          return _StickerMotionPreset.pop;
        case 5:
          return _StickerMotionPreset.float;
      }
    }

    if (normalizedPath.contains('/sheet_02/')) {
      return index.isEven
          ? _StickerMotionPreset.sway
          : _StickerMotionPreset.pulse;
    }
    if (normalizedPath.contains('/sheet_03/')) {
      return index.isEven
          ? _StickerMotionPreset.float
          : _StickerMotionPreset.wiggle;
    }
    if (normalizedPath.contains('/sheet_04/')) {
      return index.isEven
          ? _StickerMotionPreset.pop
          : _StickerMotionPreset.pulse;
    }

    switch (_seed % 4) {
      case 0:
        return _StickerMotionPreset.bounce;
      case 1:
        return _StickerMotionPreset.sway;
      case 2:
        return _StickerMotionPreset.pulse;
      case 3:
        return _StickerMotionPreset.float;
      default:
        return _StickerMotionPreset.bounce;
    }
  }

  int _extractStickerIndex(String normalizedPath) {
    final match = RegExp(r'sticker_(\d+)').firstMatch(normalizedPath);
    return int.tryParse(match?.group(1) ?? '') ?? (_seed % 97);
  }

  Widget _buildMotion(
    Widget child, {
    required double primary,
    required double secondary,
    required double tertiary,
    required double lift,
    required Alignment alignment,
    required bool keepAspectRatio,
  }) {
    switch (_preset) {
      case _StickerMotionPreset.bounce:
        final squash = (1 - lift) * 0.04;
        return _buildTransform(
          child,
          keepAspectRatio: keepAspectRatio,
          alignment: alignment,
          dx: secondary * 1.2,
          dy: -2.2 - (lift * 4.6),
          angle: primary * 0.035,
          scaleX: 1 + squash,
          scaleY: 1 - squash,
        );
      case _StickerMotionPreset.sway:
        return _buildTransform(
          child,
          keepAspectRatio: keepAspectRatio,
          alignment: alignment,
          dx: primary * 2.6,
          dy: -1.0 - (lift * 2.3),
          angle: primary * 0.055,
          scaleX: 1 + (secondary.abs() * 0.015),
          scaleY: 1 - (secondary.abs() * 0.012),
        );
      case _StickerMotionPreset.pulse:
        final pulse = (lift * 0.055) + (secondary.abs() * 0.01);
        return _buildTransform(
          child,
          keepAspectRatio: keepAspectRatio,
          alignment: alignment,
          dx: secondary * 0.7,
          dy: -1.6 - (lift * 2.0),
          angle: tertiary * 0.018,
          scaleX: 1 + pulse,
          scaleY: 1 + (pulse * 0.92),
        );
      case _StickerMotionPreset.wiggle:
        return _buildTransform(
          child,
          keepAspectRatio: keepAspectRatio,
          alignment: alignment,
          dx: secondary * 1.8,
          dy: -1.0 - (lift * 2.5),
          angle: primary * 0.075,
          scaleX: 1 + (tertiary.abs() * 0.012),
          scaleY: 1 - (tertiary.abs() * 0.018),
        );
      case _StickerMotionPreset.float:
        return _buildTransform(
          child,
          keepAspectRatio: keepAspectRatio,
          alignment: alignment,
          dx: (primary * 1.6) + (secondary * 0.8),
          dy: -2.0 - (lift * 3.0),
          angle: primary * 0.024,
          scaleX: 1 + (lift * 0.016),
          scaleY: 1 + (lift * 0.018),
        );
      case _StickerMotionPreset.pop:
        final pop = math.max(0.0, primary);
        return _buildTransform(
          child,
          keepAspectRatio: keepAspectRatio,
          alignment: alignment,
          dx: tertiary * 0.9,
          dy: -1.0 - (pop * 4.0),
          angle: secondary * 0.03,
          scaleX: 1 + (pop * 0.045),
          scaleY: 1 + (pop * 0.03),
        );
    }
  }

  Widget _buildTransform(
    Widget child, {
    required Alignment alignment,
    required double dx,
    required double dy,
    required double angle,
    required double scaleX,
    required double scaleY,
    required bool keepAspectRatio,
  }) {
    final resolvedScaleX = keepAspectRatio ? (scaleX + scaleY) / 2 : scaleX;
    final resolvedScaleY = keepAspectRatio ? resolvedScaleX : scaleY;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        alignment: alignment,
        angle: angle,
        child: Transform(
          alignment: alignment,
          transform: Matrix4.diagonal3Values(
            resolvedScaleX,
            resolvedScaleY,
            1,
          ),
          child: child,
        ),
      ),
    );
  }
}
