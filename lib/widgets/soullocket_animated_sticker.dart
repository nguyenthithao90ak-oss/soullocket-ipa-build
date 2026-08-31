import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SoulLocketStickerMotion {
  gentleFloat,
  pulse,
  bounce,
  sway,
  heartbeat,
  breathe,
  drift,
  wobble,
}

@immutable
class SoulLocketStickerSpec {
  final String id;
  final String assetPath;
  final int column;
  final int row;
  final int columns;
  final int rows;
  final SoulLocketStickerMotion motion;
  final Duration duration;

  const SoulLocketStickerSpec({
    required this.id,
    required this.assetPath,
    required this.column,
    required this.row,
    required this.columns,
    required this.rows,
    required this.motion,
    this.duration = const Duration(milliseconds: 2600),
  });
}

/// Kho sticker nội bộ có URI ổn định để thay asset mà không đổi dữ liệu đã lưu.
abstract final class SoulLocketStickerCatalog {
  static const String uriPrefix = 'soullocket://sticker/';
  static const String motionAtlas =
      'assets/images/soullocket_stickers/motion_couple_atlas_v1.png';
  static const String heartAtlas =
      'assets/images/soullocket_stickers/heart_atlas_v1.png';

  static const List<SoulLocketStickerSpec> motionStickers = [
    SoulLocketStickerSpec(
      id: 'motion_missing',
      assetPath: motionAtlas,
      column: 0,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'motion_cuddle',
      assetPath: motionAtlas,
      column: 1,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
    SoulLocketStickerSpec(
      id: 'motion_kiss',
      assetPath: motionAtlas,
      column: 2,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'motion_tease',
      assetPath: motionAtlas,
      column: 0,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
      duration: Duration(milliseconds: 2200),
    ),
    SoulLocketStickerSpec(
      id: 'motion_comfort',
      assetPath: motionAtlas,
      column: 1,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3200),
    ),
    SoulLocketStickerSpec(
      id: 'motion_celebrate',
      assetPath: motionAtlas,
      column: 2,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'motion_sleep',
      assetPath: motionAtlas,
      column: 0,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3600),
    ),
    SoulLocketStickerSpec(
      id: 'motion_send_love',
      assetPath: motionAtlas,
      column: 1,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.drift,
    ),
    SoulLocketStickerSpec(
      id: 'motion_dance',
      assetPath: motionAtlas,
      column: 2,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
      duration: Duration(milliseconds: 2100),
    ),
  ];

  static const List<SoulLocketStickerSpec> heartStickers = [
    SoulLocketStickerSpec(
      id: 'heart_scrapbook',
      assetPath: heartAtlas,
      column: 0,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'heart_plush',
      assetPath: heartAtlas,
      column: 1,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.heartbeat,
    ),
    SoulLocketStickerSpec(
      id: 'heart_glass',
      assetPath: heartAtlas,
      column: 2,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'heart_letter',
      assetPath: heartAtlas,
      column: 3,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'heart_locket',
      assetPath: heartAtlas,
      column: 0,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'heart_healing',
      assetPath: heartAtlas,
      column: 1,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3300),
    ),
    SoulLocketStickerSpec(
      id: 'heart_sleep',
      assetPath: heartAtlas,
      column: 2,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
      duration: Duration(milliseconds: 3400),
    ),
    SoulLocketStickerSpec(
      id: 'heart_celebrate',
      assetPath: heartAtlas,
      column: 3,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'heart_thread',
      assetPath: heartAtlas,
      column: 0,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'heart_calendar',
      assetPath: heartAtlas,
      column: 1,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'heart_heartbeat',
      assetPath: heartAtlas,
      column: 2,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.heartbeat,
      duration: Duration(milliseconds: 1800),
    ),
    SoulLocketStickerSpec(
      id: 'heart_gift',
      assetPath: heartAtlas,
      column: 3,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
  ];

  static const List<SoulLocketStickerSpec> all = [
    ...motionStickers,
    ...heartStickers,
  ];

  static String referenceFor(String id) => '$uriPrefix$id';

  static SoulLocketStickerSpec? find(String idOrReference) {
    final id = idOrReference.startsWith(uriPrefix)
        ? idOrReference.substring(uriPrefix.length)
        : idOrReference;
    for (final sticker in all) {
      if (sticker.id == id) return sticker;
    }
    return null;
  }
}

class SoulLocketAnimatedSticker extends StatefulWidget {
  final SoulLocketStickerSpec sticker;
  final double size;
  final bool animate;
  final String? semanticLabel;
  final FilterQuality filterQuality;

  const SoulLocketAnimatedSticker({
    super.key,
    required this.sticker,
    required this.size,
    this.animate = true,
    this.semanticLabel,
    this.filterQuality = FilterQuality.medium,
  });

  @override
  State<SoulLocketAnimatedSticker> createState() =>
      _SoulLocketAnimatedStickerState();
}

class _SoulLocketAnimatedStickerState extends State<SoulLocketAnimatedSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.sticker.duration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant SoulLocketAnimatedSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sticker.duration != widget.sticker.duration) {
      _controller.duration = widget.sticker.duration;
    }
    _syncMotion();
  }

  void _syncMotion() {
    final enabled = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (_motionEnabled == enabled) return;
    _motionEnabled = enabled;
    if (enabled) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sprite = RepaintBoundary(
      child: _SoulLocketAtlasCell(
        sticker: widget.sticker,
        size: widget.size,
        filterQuality: widget.filterQuality,
      ),
    );
    final visual = _motionEnabled
        ? AnimatedBuilder(
            animation: _controller,
            child: sprite,
            builder: (context, child) {
              final phase = _controller.value * math.pi * 2;
              var scale = 1.0;
              var rotation = 0.0;
              var offset = Offset.zero;

              switch (widget.sticker.motion) {
                case SoulLocketStickerMotion.gentleFloat:
                  offset = Offset(math.cos(phase) * 0.8, math.sin(phase) * 2.4);
                  rotation = math.sin(phase) * 0.018;
                case SoulLocketStickerMotion.pulse:
                  scale = 1 + ((math.sin(phase) + 1) * 0.022);
                case SoulLocketStickerMotion.bounce:
                  offset = Offset(0, -math.max(0, math.sin(phase)) * 4.2);
                  rotation = math.sin(phase) * 0.018;
                case SoulLocketStickerMotion.sway:
                  rotation = math.sin(phase) * 0.045;
                  offset = Offset(0, math.cos(phase) * 1.0);
                case SoulLocketStickerMotion.heartbeat:
                  final beat = math.pow(
                    math.max(0, math.sin(phase * 2)),
                    7,
                  ).toDouble();
                  scale = 1 + beat * 0.075;
                case SoulLocketStickerMotion.breathe:
                  scale = 1 + ((math.sin(phase) + 1) * 0.012);
                  offset = Offset(0, math.sin(phase) * 1.1);
                case SoulLocketStickerMotion.drift:
                  offset = Offset(math.sin(phase) * 3.0, -math.cos(phase) * 1.7);
                  rotation = math.sin(phase) * 0.026;
                case SoulLocketStickerMotion.wobble:
                  rotation = math.sin(phase * 2) * 0.055;
                  scale = 1 + math.max(0, math.sin(phase)) * 0.018;
              }

              return Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(scale: scale, child: child),
                ),
              );
            },
          )
        : sprite;

    if (widget.semanticLabel == null) return visual;
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(child: visual),
    );
  }
}

class _SoulLocketAtlasCell extends StatelessWidget {
  final SoulLocketStickerSpec sticker;
  final double size;
  final FilterQuality filterQuality;

  const _SoulLocketAtlasCell({
    required this.sticker,
    required this.size,
    required this.filterQuality,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -sticker.column * size,
              top: -sticker.row * size,
              width: size * sticker.columns,
              height: size * sticker.rows,
              child: Image.asset(
                sticker.assetPath,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: filterQuality,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF6F91),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
