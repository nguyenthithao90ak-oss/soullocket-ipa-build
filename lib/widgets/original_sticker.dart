import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

part 'original_sticker_rigs.dart';
part 'original_sticker_performances.dart';

/// Vùng chuyển động được đặt theo chi tiết thật trên ảnh gốc.
/// Tọa độ chuẩn hóa theo từng ô atlas, không theo toàn bộ tấm ảnh.
@immutable
class OriginalStickerRegion {
  const OriginalStickerRegion(
    this.x,
    this.y,
    this.rx,
    this.ry, {
    this.dx = 0,
    this.dy = 0,
    this.grow = 0,
    this.blink = false,
    this.angle = 0,
    this.pivotX,
    this.pivotY,
    this.start = 0,
    this.end = 1,
    this.cue,
  });
  const OriginalStickerRegion.eye(double x, double y)
    : this(x, y, .058, .062, blink: true);

  /// Khớp cục bộ: đầu ngón/tai xoay quanh gốc, không xoay cả sticker.
  const OriginalStickerRegion.joint(
    double x,
    double y,
    double rx,
    double ry, {
    required double pivotX,
    required double pivotY,
    double angle = .16,
  }) : this(
         x,
         y,
         rx,
         ry,
         pivotX: pivotX,
         pivotY: pivotY,
         angle: angle,
         start: .28,
         end: .78,
       );

  const OriginalStickerRegion.breath(double x, double y, double rx, double ry)
    : this(x, y, rx, ry, grow: .055, dy: -.008);

  final double x, y, rx, ry, dx, dy, grow, angle, start, end;
  final double? pivotX, pivotY;
  final bool blink;
  final OriginalStickerCue? cue;

  OriginalStickerRegion directed(OriginalStickerCue cue) =>
      OriginalStickerRegion(
        x,
        y,
        rx,
        ry,
        dx: dx,
        dy: dy,
        grow: grow,
        blink: blink,
        angle: angle,
        pivotX: pivotX,
        pivotY: pivotY,
        start: start,
        end: end,
        cue: cue,
      );

  double activity(double phase) {
    if (cue != null) return cue!.valueAt(phase);
    final from = blink ? .16 : start;
    final to = blink ? .24 : end;
    if (phase <= from || phase >= to) return 0;
    final progress = (phase - from) / (to - from);
    // Khép/mở một lần rồi nghỉ, không dao động liên tục gây cảm giác rung.
    return (1 - math.cos(progress * math.pi * 2)) / 2;
  }

  Offset displacement(Offset point, double phase) =>
      deformation(point) * activity(phase);

  Offset deformation(Offset point) {
    final nx = (point.dx - x) / rx;
    final ny = (point.dy - y) / ry;
    final radius = nx * nx + ny * ny;
    if (radius >= 1) return Offset.zero;
    // Giữ chuyển động đều trong lòng mắt, nối êm về 0 tại viền vùng rig.
    final falloff = ((math.sqrt(radius) - .42) / .58).clamp(0.0, 1.0);
    final weight = blink
        ? 1 - falloff * falloff * (3 - 2 * falloff)
        : (1 - radius) * (1 - radius);
    final px = point.dx - (pivotX ?? x);
    final py = point.dy - (pivotY ?? y);
    final rotationX = px * (math.cos(angle) - 1) - py * math.sin(angle);
    final rotationY = px * math.sin(angle) + py * (math.cos(angle) - 1);
    return Offset(
      (dx + (point.dx - x) * grow + rotationX) * weight,
      (dy + (point.dy - y) * (blink ? -.94 : grow) + rotationY) * weight,
    );
  }
}

/// Chưa có rig thì hiển thị ảnh gốc tĩnh, không lắc ảnh để giả hoạt ảnh.
abstract final class OriginalStickerRigs {
  static final regions = Map<String, List<OriginalStickerRegion>>.unmodifiable(
    _baseRegions.map((id, rig) {
      final acting = OriginalStickerPerformances.byId[id]!;
      assert(acting.cues.length == rig.length, id);
      return MapEntry(
        id,
        List<OriginalStickerRegion>.unmodifiable([
          for (var i = 0; i < rig.length; i++) rig[i].directed(acting.cues[i]),
        ]),
      );
    }),
  );

  static const _baseRegions = <String, List<OriginalStickerRegion>>{
    ..._additionalOriginalStickerRigs,
    'diary_reflective': [
      OriginalStickerRegion(.51, .65, .14, .20, dx: .035, dy: -.025),
      OriginalStickerRegion(.24, .49, .15, .27, dx: -.012),
    ],
    'diary_shy': [
      OriginalStickerRegion(.22, .33, .16, .22, dy: -.022, grow: .10),
      OriginalStickerRegion(.435, .457, .07, .06, blink: true),
      OriginalStickerRegion(.605, .498, .07, .06, blink: true),
    ],
    'diary_missing': [
      OriginalStickerRegion.eye(.542, .447),
      OriginalStickerRegion(.56, .67, .21, .18, grow: .12),
      OriginalStickerRegion(.21, .49, .16, .25, dx: -.012),
    ],
    'diary_proud': [
      OriginalStickerRegion(.57, .60, .30, .26, grow: .075),
      OriginalStickerRegion(.56, .19, .13, .15, dy: -.014),
    ],
    'diary_sleepy': [
      OriginalStickerRegion(.48, .58, .31, .29, dy: -.009),
      OriginalStickerRegion(.35, .20, .10, .12, grow: .14),
    ],
    'diary_anxious': [
      OriginalStickerRegion(.40, .43, .065, .08, blink: true),
      OriginalStickerRegion(.565, .41, .065, .08, blink: true),
      OriginalStickerRegion(.43, .60, .18, .15, dx: .012, dy: -.030),
    ],
    'diary_grumpy': [
      OriginalStickerRegion.eye(.439, .457),
      OriginalStickerRegion.eye(.626, .454),
      OriginalStickerRegion(.48, .65, .23, .14, dx: .030, dy: -.018),
      OriginalStickerRegion(.54, .12, .24, .12, dy: .022),
    ],
    'diary_playful': [
      OriginalStickerRegion.eye(.612, .302),
      OriginalStickerRegion.joint(
        .65,
        .49,
        .18,
        .19,
        pivotX: .59,
        pivotY: .63,
        angle: -.22,
      ),
      OriginalStickerRegion(.80, .24, .10, .13, grow: .20),
    ],
    'diary_healing': [
      OriginalStickerRegion(.51, .49, .38, .31, grow: .045),
      OriginalStickerRegion(.48, .20, .17, .18, dx: .012),
    ],
    'motion_missing': [
      OriginalStickerRegion(.60, .61, .18, .19, dx: -.025, dy: -.028),
      OriginalStickerRegion.joint(
        .16,
        .50,
        .14,
        .27,
        pivotX: .27,
        pivotY: .20,
        angle: -.17,
      ),
      OriginalStickerRegion.breath(.48, .72, .21, .19),
    ],
    'motion_cuddle': [
      OriginalStickerRegion.joint(
        .635,
        .63,
        .18,
        .095,
        pivotX: .74,
        pivotY: .70,
        angle: .26,
      ),
      OriginalStickerRegion(.42, .70, .19, .075, dx: .025, dy: -.012),
      OriginalStickerRegion(.35, .20, .16, .15, dy: -.016),
    ],
    'motion_kiss': [
      OriginalStickerRegion.eye(.751, .505),
      OriginalStickerRegion(.42, .50, .13, .15, dx: .030, dy: -.008),
      OriginalStickerRegion(.42, .20, .18, .20, grow: .12, dy: -.015),
      OriginalStickerRegion(.60, .66, .14, .16, dx: -.024),
    ],
    'motion_tease': [
      OriginalStickerRegion.joint(
        .53,
        .49,
        .18,
        .13,
        pivotX: .67,
        pivotY: .60,
        angle: .20,
      ),
      OriginalStickerRegion.eye(.551, .383),
      OriginalStickerRegion.eye(.665, .442),
    ],
    'motion_comfort': [
      OriginalStickerRegion(.55, .52, .23, .13, dx: -.022, dy: .018),
      OriginalStickerRegion(.37, .15, .11, .12, grow: .15),
    ],
    'motion_celebrate': [
      OriginalStickerRegion(.47, .29, .11, .25, dy: -.018),
      OriginalStickerRegion(.40, .11, .23, .10, grow: .12),
    ],
    'motion_sleep': [
      OriginalStickerRegion(.44, .76, .20, .19, grow: .10),
      OriginalStickerRegion(.63, .11, .11, .09, grow: .18),
    ],
    'motion_send_love': [
      OriginalStickerRegion.eye(.271, .403),
      OriginalStickerRegion.eye(.363, .345),
      OriginalStickerRegion(.62, .11, .23, .14, dx: .012, dy: -.01),
      OriginalStickerRegion(.39, .50, .16, .20, dx: .022, dy: -.038),
    ],
    'motion_dance': [
      OriginalStickerRegion.joint(
        .83,
        .49,
        .12,
        .20,
        pivotX: .71,
        pivotY: .62,
        angle: -.24,
      ),
      OriginalStickerRegion(.23, .17, .11, .13, grow: .14),
    ],
  };
}

/// Giữ nguyên ảnh gốc; chưa chạy chuyển động khi chưa có lớp/frame tách riêng.
class OriginalSticker extends StatefulWidget {
  const OriginalSticker({
    super.key,
    required this.assetPath,
    required this.stickerId,
    this.column = 0,
    this.row = 0,
    this.columns = 1,
    this.rows = 1,
    this.width,
    this.height,
    this.animate = true,
    this.filterQuality = FilterQuality.medium,
  });
  final String assetPath, stickerId;
  final int column, row, columns, rows;
  final double? width, height;
  final bool animate;
  final FilterQuality filterQuality;

  @override
  State<OriginalSticker> createState() => _OriginalStickerState();
}

class _OriginalStickerState extends State<OriginalSticker> {
  ImageStream? _stream;
  ImageInfo? _info;
  bool _failed = false;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant OriginalSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _info?.dispose();
      _info = null;
      _failed = false;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final next = AssetImage(
      widget.assetPath,
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == next.key) return;
    _stream?.removeListener(_listener);
    _stream = next;
    next.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
      _failed = false;
    });
  }

  void _onError(Object error, StackTrace? stack) {
    if (mounted) setState(() => _failed = true);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: widget.width,
      height: widget.height,
      child: _failed
          ? const Icon(Icons.image_not_supported_outlined)
          : LayoutBuilder(
              builder: (context, constraints) {
                final width =
                    widget.width ??
                    (constraints.hasBoundedWidth ? constraints.maxWidth : 72.0);
                final height =
                    widget.height ??
                    (constraints.hasBoundedHeight
                        ? constraints.maxHeight
                        : width);
                final source = _info?.image;
                return CustomPaint(
                  size: Size(width, height),
                  painter: source == null
                      ? null
                      : OriginalStickerPainter(
                          image: source,
                          source: Rect.fromLTWH(
                            source.width * widget.column / widget.columns,
                            source.height * widget.row / widget.rows,
                            source.width / widget.columns,
                            source.height / widget.rows,
                          ),
                          regions: const [],
                          animation: const AlwaysStoppedAnimation(0),
                          filterQuality: widget.filterQuality,
                        ),
                );
              },
            ),
    ),
  );
}

/// Ảnh phẳng không có lớp mắt/tay độc lập: không uốn texture để giả cử động.
/// Giữ API cũ cho các caller; animation/regions không còn làm biến dạng ảnh.
class OriginalStickerPainter extends CustomPainter {
  OriginalStickerPainter({
    required this.image,
    required this.source,
    required this.regions,
    required this.animation,
    this.filterQuality = FilterQuality.medium,
  });

  final ui.Image image;
  final Rect source;
  final List<OriginalStickerRegion> regions;
  final Animation<double> animation;
  final FilterQuality filterQuality;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || source.isEmpty) return;
    // Giữ tỉ lệ ảnh ngay cả khi caller cung cấp khung không vuông.
    final fitted = applyBoxFit(BoxFit.contain, source.size, size);
    final target = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      target,
      Paint()..filterQuality = filterQuality,
    );
  }

  @override
  bool shouldRepaint(covariant OriginalStickerPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.source != source ||
      oldDelegate.filterQuality != filterQuality;
}
