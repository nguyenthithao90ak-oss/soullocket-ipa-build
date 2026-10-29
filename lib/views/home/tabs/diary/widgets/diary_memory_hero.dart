import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Chuyển cảnh bằng frame đã giải mã, giữ bộ tải ảnh ở đúng route của nó.
class DiaryMemoryHero extends StatefulWidget {
  const DiaryMemoryHero({
    super.key,
    required this.tag,
    required this.child,
    this.fit = BoxFit.contain,
  });

  final Object tag;
  final Widget child;
  final BoxFit fit;

  @override
  State<DiaryMemoryHero> createState() => _DiaryMemoryHeroState();
}

class _DiaryMemoryHeroState extends State<DiaryMemoryHero> {
  final _imageKey = GlobalKey();

  static RenderImage? _displayedImage(BuildContext context) {
    RenderImage? result;
    void visit(RenderObject object) {
      if (result != null) return;
      if (object is RenderImage && object.image != null) {
        result = object;
      } else {
        object.visitChildren(visit);
      }
    }

    // Overlay của Hero được dựng trong build; đọc cây render đã layout thay
    // vì duyệt Element khi Flutter đang cập nhật cây widget.
    final object = context.findRenderObject();
    if (object != null) visit(object);
    return result;
  }

  @override
  Widget build(BuildContext context) => Hero(
    tag: widget.tag,
    // Giữ cùng element cả khi Hero thay child bằng placeholder. Bộ tải ở
    // trang đích tiếp tục chạy, không bị dispose rồi xin link lại cuối flight.
    placeholderBuilder: (context, size, child) => SizedBox.fromSize(
      size: size,
      child: Offstage(child: child),
    ),
    flightShuttleBuilder: (context, animation, direction, from, to) {
      final frame = _displayedImage(from) ?? _displayedImage(to);
      if (frame?.image == null) return const SizedBox.expand();
      final fromFit = from
          .findAncestorWidgetOfExactType<DiaryMemoryHero>()
          ?.fit;
      final toFit = to.findAncestorWidgetOfExactType<DiaryMemoryHero>()?.fit;
      return _DiaryMemoryFlight(
        image: frame!.image!.clone(),
        animation: animation,
        reverse: direction == HeroFlightDirection.pop,
        fromFit: fromFit ?? BoxFit.contain,
        toFit: toFit ?? BoxFit.contain,
        isCurrent: () =>
            (from.mounted && _displayedImage(from)?.image != null) ||
            (to.mounted && _displayedImage(to)?.image != null),
      );
    },
    child: KeyedSubtree(key: _imageKey, child: widget.child),
  );
}

class _DiaryMemoryFlight extends StatefulWidget {
  const _DiaryMemoryFlight({
    required this.image,
    required this.animation,
    required this.reverse,
    required this.fromFit,
    required this.toFit,
    required this.isCurrent,
  });

  final ui.Image image;
  final Animation<double> animation;
  final bool reverse;
  final BoxFit fromFit;
  final BoxFit toFit;
  final bool Function() isCurrent;

  @override
  State<_DiaryMemoryFlight> createState() => _DiaryMemoryFlightState();
}

class _DiaryMemoryFlightState extends State<_DiaryMemoryFlight> {
  @override
  void dispose() {
    widget.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _DiaryMemoryFlightPainter(widget),
  );
}

class _DiaryMemoryFlightPainter extends CustomPainter {
  _DiaryMemoryFlightPainter(this.flight) : super(repaint: flight.animation);

  final _DiaryMemoryFlight flight;

  @override
  void paint(Canvas canvas, Size size) {
    // Nếu bộ tải đã xóa pixels vì logout/background thì snapshot cũng ngừng vẽ.
    if (size.isEmpty || !flight.isCurrent()) return;
    final imageSize = Size(
      flight.image.width.toDouble(),
      flight.image.height.toDouble(),
    );
    final from = applyBoxFit(flight.fromFit, imageSize, size);
    final to = applyBoxFit(flight.toFit, imageSize, size);
    final progress = flight.reverse
        ? 1 - flight.animation.value
        : flight.animation.value;
    // Mở dần phần ảnh bị cắt ở thumbnail, tránh đổi cover → contain đột ngột.
    final source = Rect.lerp(
      Alignment.center.inscribe(from.source, Offset.zero & imageSize),
      Alignment.center.inscribe(to.source, Offset.zero & imageSize),
      progress,
    )!;
    final destination = Rect.lerp(
      Alignment.center.inscribe(from.destination, Offset.zero & size),
      Alignment.center.inscribe(to.destination, Offset.zero & size),
      progress,
    )!;
    canvas.drawImageRect(
      flight.image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_DiaryMemoryFlightPainter oldDelegate) =>
      oldDelegate.flight != flight;
}
