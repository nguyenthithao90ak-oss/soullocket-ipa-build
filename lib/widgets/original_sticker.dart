import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../views/ui_prefs.dart';
import 'living_sticker.dart' show StickerAnimationScope;

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
  });
  final double x, y, rx, ry, dx, dy, grow;
  final bool blink;

  Offset displacement(Offset point, double phase) {
    final nx = (point.dx - x) / rx;
    final ny = (point.dy - y) / ry;
    final radius = nx * nx + ny * ny;
    if (radius >= 1) return Offset.zero;
    final weight = math.pow(1 - radius, 2).toDouble();
    // Mắt chỉ khép nhẹ trong một nhịp ngắn, không kéo méo cả khuôn mặt.
    final activity = blink
        ? (phase > .16 && phase < .24
              ? math.sin((phase - .16) / .08 * math.pi)
              : 0.0)
        : (1 - math.cos(phase * math.pi * 2)) / 2;
    return Offset(
      (dx + (point.dx - x) * grow) * weight * activity,
      (dy + (point.dy - y) * (blink ? -.65 : grow)) * weight * activity,
    );
  }
}

/// Chưa có rig thì hiển thị ảnh gốc tĩnh, không lắc ảnh để giả hoạt ảnh.
abstract final class OriginalStickerRigs {
  static const regions = <String, List<OriginalStickerRegion>>{
    'diary_reflective': [
      OriginalStickerRegion(.51, .65, .14, .20, dx: .012, dy: -.012),
      OriginalStickerRegion(.24, .49, .15, .27, dx: -.012),
    ],
    'diary_shy': [
      OriginalStickerRegion(.22, .33, .16, .22, dy: -.022, grow: .10),
      OriginalStickerRegion(.435, .457, .07, .06, blink: true),
      OriginalStickerRegion(.605, .498, .07, .06, blink: true),
    ],
    'diary_missing': [
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
      OriginalStickerRegion(.12, .32, .07, .20, dx: .012),
    ],
    'diary_grumpy': [
      OriginalStickerRegion(.54, .12, .26, .13, dx: .012),
      OriginalStickerRegion(.43, .24, .04, .07, dy: .018),
      OriginalStickerRegion(.62, .25, .04, .07, dy: .018),
    ],
    'diary_playful': [
      OriginalStickerRegion(.68, .51, .20, .20, dx: .013, dy: -.018),
      OriginalStickerRegion(.80, .24, .10, .13, grow: .20),
    ],
    'diary_healing': [
      OriginalStickerRegion(.51, .49, .38, .31, grow: .045),
      OriginalStickerRegion(.48, .20, .17, .18, dx: .012),
    ],
    'motion_missing': [
      OriginalStickerRegion(.77, .40, .15, .21, grow: .12, dy: -.016),
      OriginalStickerRegion(.17, .52, .13, .27, dx: -.012),
    ],
    'motion_cuddle': [
      OriginalStickerRegion(.45, .76, .22, .20, grow: .14),
      OriginalStickerRegion(.35, .20, .16, .15, dy: -.016),
    ],
    'motion_kiss': [
      OriginalStickerRegion(.42, .20, .18, .20, grow: .12, dy: -.015),
      OriginalStickerRegion(.14, .52, .12, .22, dx: -.012),
    ],
    'motion_tease': [
      OriginalStickerRegion(.52, .48, .19, .13, dx: -.018),
      OriginalStickerRegion(.65, .36, .045, .06, blink: true),
    ],
    'motion_comfort': [
      OriginalStickerRegion(.50, .68, .34, .22, dy: -.01),
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
      OriginalStickerRegion(.62, .11, .23, .14, dx: .012, dy: -.01),
      OriginalStickerRegion(.25, .53, .14, .16, grow: .13),
    ],
    'motion_dance': [
      OriginalStickerRegion(.83, .49, .12, .20, dy: -.018),
      OriginalStickerRegion(.23, .17, .11, .13, grow: .14),
    ],
  };
}

/// Giữ nguyên texture gốc; chỉ biến đổi lưới tại các chi tiết đã đặt rig.
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

class _OriginalStickerState extends State<OriginalSticker>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  ImageStream? _stream;
  ImageInfo? _info;
  bool _foreground = true;
  bool _failed = false;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    UiPrefs.notifier.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
    _sync();
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
    if (oldWidget.stickerId != widget.stickerId) _controller.value = 0;
    _sync();
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
    _sync();
  }

  void _onError(Object error, StackTrace? stack) {
    if (!mounted) return;
    setState(() => _failed = true);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final enabled =
        widget.animate &&
        _info != null &&
        !_failed &&
        OriginalStickerRigs.regions.containsKey(widget.stickerId) &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        StickerAnimationScope.enabledOf(context) &&
        !MediaQuery.disableAnimationsOf(context) &&
        UiPrefs.resolveEffectProfile(
          state: UiPrefs.notifier.value,
          isWeb: kIsWeb,
        ).animationEnabled;
    if (enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!enabled) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    UiPrefs.notifier.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    _stream?.removeListener(_listener);
    _info?.dispose();
    _controller.dispose();
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
                          regions:
                              OriginalStickerRigs.regions[widget.stickerId] ??
                              const [],
                          animation: _controller,
                          filterQuality: widget.filterQuality,
                        ),
                );
              },
            ),
    ),
  );
}

class OriginalStickerPainter extends CustomPainter {
  OriginalStickerPainter({
    required this.image,
    required this.source,
    required this.regions,
    required this.animation,
    this.filterQuality = FilterQuality.medium,
  }) : super(repaint: animation);
  final ui.Image image;
  final Rect source;
  final List<OriginalStickerRegion> regions;
  final Animation<double> animation;
  final FilterQuality filterQuality;
  static const _steps = 32;
  static final _indices = Uint16List.fromList([
    for (var y = 0; y < _steps; y++)
      for (var x = 0; x < _steps; x++) ...[
        y * (_steps + 1) + x,
        y * (_steps + 1) + x + 1,
        (y + 1) * (_steps + 1) + x,
        y * (_steps + 1) + x + 1,
        (y + 1) * (_steps + 1) + x + 1,
        (y + 1) * (_steps + 1) + x,
      ],
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final target = Offset.zero & size;
    if (animation.value == 0 || animation.value == 1 || regions.isEmpty) {
      canvas.drawImageRect(
        image,
        source,
        target,
        Paint()..filterQuality = filterQuality,
      );
      return;
    }
    final positions = Float32List((_steps + 1) * (_steps + 1) * 2);
    final texture = Float32List(positions.length);
    var index = 0;
    for (var y = 0; y <= _steps; y++) {
      for (var x = 0; x <= _steps; x++) {
        final point = Offset(x / _steps, y / _steps);
        var moved = point;
        for (final region in regions) {
          moved += region.displacement(point, animation.value);
        }
        positions[index] = moved.dx * size.width;
        texture[index++] = source.left + point.dx * source.width;
        positions[index] = moved.dy * size.height;
        texture[index++] = source.top + point.dy * source.height;
      }
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texture,
      indices: _indices,
    );
    final shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      filterQuality: filterQuality,
    );
    // Vẽ nền bằng đúng cách ở tư thế nghỉ. Chỉ thay pixel bên trong vùng rig;
    // phần chân/viền không bị đổi bộ lọc khi bắt đầu chạy hoạt ảnh.
    canvas.saveLayer(target, Paint());
    canvas.drawImageRect(
      image,
      source,
      target,
      Paint()..filterQuality = filterQuality,
    );
    final animatedArea = Path();
    for (final region in regions) {
      animatedArea.addOval(
        Rect.fromCenter(
          center: Offset(region.x * size.width, region.y * size.height),
          width: region.rx * size.width * 2,
          height: region.ry * size.height * 2,
        ),
      );
    }
    canvas.clipPath(animatedArea);
    canvas.drawVertices(
      vertices,
      BlendMode.src,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.src,
    );
    canvas.restore();
    vertices.dispose();
    shader.dispose();
  }

  @override
  bool shouldRepaint(covariant OriginalStickerPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.source != source ||
      oldDelegate.regions != regions ||
      oldDelegate.animation != animation ||
      oldDelegate.filterQuality != filterQuality;
}
