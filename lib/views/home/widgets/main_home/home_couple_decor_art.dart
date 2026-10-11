import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sticker vector có viền giấy, màu pastel và nét riêng, dùng được offline.
class HomeCoupleDecorArt extends StatefulWidget {
  const HomeCoupleDecorArt({
    super.key,
    required this.id,
    this.size = 48,
    this.animate = false,
  });

  final String id;
  final double size;
  final bool animate;

  @override
  State<HomeCoupleDecorArt> createState() => _HomeCoupleDecorArtState();
}

class _HomeCoupleDecorArtState extends State<HomeCoupleDecorArt>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _controller;
  AppLifecycleState? _lifecycleState;

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant HomeCoupleDecorArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hadController = _controller != null;
    _lifecycleState = state;
    _syncMotion();
    if (!hadController && _controller != null && mounted) {
      setState(() {});
    }
  }

  void _syncMotion() {
    final enabled =
        widget.animate &&
        !MediaQuery.of(context).disableAnimations &&
        TickerMode.valuesOf(context).enabled &&
        (_lifecycleState == null ||
            _lifecycleState == AppLifecycleState.resumed);
    if (enabled) {
      _controller ??= AnimationController(
        vsync: this,
        duration: _motionDuration(widget.id),
      );
      if (!_controller!.isAnimating) _controller!.repeat();
    } else {
      _controller?.stop();
      _controller?.value = 0;
    }
  }

  Duration _motionDuration(String id) => switch (id) {
    'bunny' => const Duration(milliseconds: 1650),
    'bear' => const Duration(milliseconds: 2100),
    'panda' => const Duration(milliseconds: 2600),
    'unicorn' => const Duration(milliseconds: 3200),
    'milk_tea' => const Duration(milliseconds: 2350),
    'cloud_star' => const Duration(milliseconds: 2900),
    'balloon_heart' => const Duration(milliseconds: 2500),
    'rainbow' => const Duration(milliseconds: 3600),
    'cat' => const Duration(milliseconds: 1900),
    'cherry' => const Duration(milliseconds: 3000),
    _ => const Duration(milliseconds: 1800),
  };

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final artwork = CustomPaint(painter: _DecorArtPainter(widget.id));
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: controller == null
            ? artwork
            : AnimatedBuilder(
                animation: controller,
                builder: (context, child) => CustomPaint(
                  painter: _DecorArtPainter(
                    widget.id,
                    phase: controller.value,
                  ),
                ),
              ),
      ),
    );
  }
}

class _DecorArtPainter extends CustomPainter {
  const _DecorArtPainter(this.id, {this.phase = 0});
  final String id;
  final double phase;

  static const ink = Color(0xFF8D6070);
  static const pink = Color(0xFFF5A8BE);
  static const green = Color(0xFF9CCDB1);
  static const gold = Color(0xFFFFD77D);
  static const purple = Color(0xFFBEACE8);
  static const blue = Color(0xFFABD5E6);

  void shape(Canvas canvas, Path path, Color color, {bool paper = true}) {
    if (paper) {
      canvas.drawShadow(path, const Color(0x557B4C60), 2, true);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = ink.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void oval(Canvas canvas, Rect rect, Color color, {bool paper = true}) =>
      shape(canvas, Path()..addOval(rect), color, paper: paper);

  void line(
    Canvas canvas,
    Path path, {
    Color color = ink,
    double width = 1.4,
  }) => canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  Path heart(double x, double y, double size) => Path()
    ..moveTo(x, y + size * .7)
    ..cubicTo(x - size, y, x - size * .6, y - size * .8, x, y - size * .3)
    ..cubicTo(x + size * .6, y - size * .8, x + size, y, x, y + size * .7)
    ..close();

  Path star(double x, double y, double radius, {int points = 5}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = -math.pi / 2 + i * math.pi / points;
      final r = i.isEven ? radius : radius * .48;
      final dx = x + math.cos(angle) * r;
      final dy = y + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    return path..close();
  }

  void face(
    Canvas canvas,
    double x,
    double y, {
    double gap = 6,
    bool blink = false,
  }) {
    final paint = Paint()..color = ink;
    if (blink) {
      line(
        canvas,
        Path()
          ..moveTo(x - gap - 2, y)
          ..quadraticBezierTo(x - gap, y + 2, x - gap + 2, y),
        width: 1.3,
      );
      line(
        canvas,
        Path()
          ..moveTo(x + gap - 2, y)
          ..quadraticBezierTo(x + gap, y + 2, x + gap + 2, y),
        width: 1.3,
      );
    } else {
      canvas.drawCircle(Offset(x - gap, y), 1.4, paint);
      canvas.drawCircle(Offset(x + gap, y), 1.4, paint);
    }
    line(
      canvas,
      Path()
        ..moveTo(x - 2.5, y + 4)
        ..quadraticBezierTo(x, y + 7, x + 2.5, y + 4),
      width: 1.2,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x - gap - 3, y + 4),
        width: 5,
        height: 2.5,
      ),
      Paint()..color = pink.withValues(alpha: .6),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + gap + 3, y + 4),
        width: 5,
        height: 2.5,
      ),
      Paint()..color = pink.withValues(alpha: .6),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final radians = phase * math.pi * 2;
    final bounce = math.sin(radians);
    final blink = phase > .47 && phase < .54;
    switch (id) {
      case 'bunny':
        canvas.save();
        canvas.translate(21, 25);
        canvas.rotate(math.sin(radians) * .13);
        canvas.translate(-21, -25);
        shape(
          canvas,
          Path()
            ..moveTo(21, 25)
            ..cubicTo(10, 5, 14, -2, 23, 4)
            ..cubicTo(29, 10, 27, 20, 27, 25),
          const Color(0xFFF7C9D8),
        );
        canvas.restore();
        canvas.save();
        canvas.translate(43, 25);
        canvas.rotate(math.sin(radians + 1.8) * .16);
        canvas.translate(-43, -25);
        shape(
          canvas,
          Path()
            ..moveTo(37, 25)
            ..cubicTo(37, 12, 35, 4, 41, 2)
            ..cubicTo(51, -2, 54, 9, 43, 26),
          const Color(0xFFF7C9D8),
        );
        canvas.restore();
        oval(canvas, const Rect.fromLTWH(14, 20, 36, 34), Colors.white);
        oval(
          canvas,
          const Rect.fromLTWH(23, 39, 18, 11),
          const Color(0xFFFFE5EE),
          paper: false,
        );
        face(canvas, 32, 34, gap: 5, blink: blink);
        shape(
          canvas,
          heart(32, 20 + math.sin(radians) * 2, 5),
          pink,
          paper: false,
        );
      case 'bear':
        oval(
          canvas,
          const Rect.fromLTWH(9, 12, 18, 18),
          const Color(0xFFD59A72),
        );
        oval(
          canvas,
          const Rect.fromLTWH(37, 12, 18, 18),
          const Color(0xFFD59A72),
        );
        oval(
          canvas,
          const Rect.fromLTWH(12, 18, 40, 36),
          const Color(0xFFE1AC82),
        );
        oval(
          canvas,
          const Rect.fromLTWH(24, 36, 16, 11),
          const Color(0xFFFFD9B7),
          paper: false,
        );
        face(canvas, 32, 31 + math.sin(radians + 1) * 1.5, gap: 5, blink: blink);
        shape(canvas, heart(32, 50 + math.sin(radians + 1) * 2, 5), pink, paper: false);
      case 'panda':
        oval(
          canvas,
          const Rect.fromLTWH(9, 10, 18, 18),
          const Color(0xFF6C6573),
        );
        oval(
          canvas,
          const Rect.fromLTWH(37, 10, 18, 18),
          const Color(0xFF6C6573),
        );
        oval(canvas, const Rect.fromLTWH(12, 17, 40, 38), Colors.white);
        oval(
          canvas,
          const Rect.fromLTWH(18, 27, 12, 15),
          const Color(0xFF6C6573),
          paper: false,
        );
        oval(
          canvas,
          const Rect.fromLTWH(34, 27, 12, 15),
          const Color(0xFF6C6573),
          paper: false,
        );
        face(canvas, 32, 34, gap: 5, blink: blink);
        canvas.save();
        canvas.translate(32, 50);
        canvas.scale(
          1 + math.sin(radians * 2) * .12,
          1 + math.sin(radians * 2) * .12,
        );
        canvas.translate(-32, -50);
        shape(canvas, heart(32, 50, 5), const Color(0xFFEAA2B9), paper: false);
        canvas.restore();
      case 'unicorn':
        canvas.save();
        canvas.translate(39, 19);
        canvas.rotate(math.sin(radians * .5) * .12);
        canvas.translate(-39, -19);
        shape(
          canvas,
          Path()
            ..moveTo(31, 19)
            ..lineTo(39, 2)
            ..lineTo(44, 20)
            ..close(),
          const Color(0xFFFFD77D),
        );
        canvas.restore();
        oval(
          canvas,
          const Rect.fromLTWH(13, 18, 39, 34),
          const Color(0xFFE8D9FF),
        );
        for (final entry in const [
          (21.0, 18.0, Color(0xFFF5A8BE)),
          (27.0, 13.0, Color(0xFFFFD77D)),
          (34.0, 12.0, Color(0xFF9FD9D0)),
          (41.0, 17.0, Color(0xFFABD5E6)),
        ]) {
          canvas.drawCircle(
            Offset(entry.$1, entry.$2),
            5,
            Paint()..color = entry.$3,
          );
        }
        face(canvas, 32, 34, gap: 5, blink: blink);
        shape(
          canvas,
          heart(32, 50, 5 + math.sin(radians * 1.5) * .7),
          pink,
          paper: false,
        );
      case 'milk_tea':
        canvas.save();
        canvas.translate(48, 18);
        canvas.rotate(math.sin(radians + .6) * .12);
        canvas.translate(-48, -18);
        line(
          canvas,
          Path()
            ..moveTo(42, 18)
            ..quadraticBezierTo(51, 7, 48, 2),
          color: const Color(0xFFB88A9B),
          width: 2.5,
        );
        canvas.restore();
        shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(14, 18, 36, 38),
              const Radius.circular(8),
            ),
          ),
          const Color(0xFFE6B78F),
        );
        oval(
          canvas,
          const Rect.fromLTWH(12, 14, 40, 11),
          const Color(0xFFFFE0B9),
        );
        for (final point in const [
          Offset(23, 47),
          Offset(32, 50),
          Offset(41, 46),
        ]) {
          canvas.drawCircle(
            point,
            3.2,
            Paint()..color = const Color(0xFF8B6170),
          );
        }
        shape(
          canvas,
          heart(32, 30, 6 + math.sin(radians * 1.7) * .8),
          pink,
          paper: false,
        );
      case 'cloud_star':
        shape(
          canvas,
          Path()
            ..moveTo(10, 48)
            ..cubicTo(0, 45, 4, 30, 16, 31)
            ..cubicTo(18, 12, 42, 10, 45, 30)
            ..cubicTo(61, 29, 64, 47, 51, 49)
            ..close(),
          const Color(0xFFD9ECF7),
        );
        canvas.save();
        canvas.translate(45, 17);
        canvas.rotate(math.sin(radians * .5) * .28);
        canvas.translate(-45, -17);
        shape(canvas, star(45, 17, 12, points: 4), gold);
        canvas.restore();
        face(canvas, 28, 39 + math.sin(radians + 2) * 1.2, gap: 4, blink: blink);
      case 'balloon_heart':
        line(
          canvas,
          Path()
            ..moveTo(19, 35)
            ..cubicTo(12, 45, 28, 47, 25, 60)
            ..moveTo(44, 38)
            ..cubicTo(51, 48, 36, 48, 39, 60),
          color: const Color(0xFFB88A9B),
        );
        shape(canvas, heart(20, 23 + math.sin(radians) * 3, 15), pink);
        shape(canvas, heart(44, 26 + math.sin(radians + 2.2) * 3, 15), purple);
        shape(
          canvas,
          star(32, 12 + math.sin(radians * 1.5) * 2, 8, points: 4),
          gold,
          paper: false,
        );
      case 'rainbow':
        for (final entry in const [
          (Color(0xFFE987A8), 0.0),
          (Color(0xFFFFC86B), 5.0),
          (Color(0xFF9DCE9D), 10.0),
          (Color(0xFF8FC8E4), 15.0),
          (Color(0xFFB69AE8), 20.0),
        ]) {
          canvas.drawArc(
            Rect.fromLTWH(
              8 + entry.$2,
              8 + entry.$2,
              48 - entry.$2 * 2,
              48 - entry.$2 * 2,
            ),
            math.pi,
            math.pi,
            false,
            Paint()
              ..color = entry.$1
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4,
          );
        }
        oval(canvas, const Rect.fromLTWH(7, 43, 22, 13), Colors.white);
        oval(canvas, const Rect.fromLTWH(38, 43, 20, 13), Colors.white);
        canvas.save();
        canvas.translate(32, 26);
        canvas.rotate(math.sin(radians * .7) * .3);
        canvas.translate(-32, -26);
        shape(canvas, star(32, 26, 7, points: 4), gold, paper: false);
        canvas.restore();
      case 'cat':
        shape(
          canvas,
          Path()
            ..moveTo(15, 28)
            ..lineTo(17, 10)
            ..lineTo(29, 20)
            ..lineTo(35, 20)
            ..lineTo(47, 10)
            ..lineTo(49, 29)
            ..close(),
          const Color(0xFFFFD0A7),
        );
        oval(
          canvas,
          const Rect.fromLTWH(13, 18, 38, 37),
          const Color(0xFFFFD0A7),
        );
        face(canvas, 32, 35, gap: 5, blink: blink);
        line(
          canvas,
          Path()
            ..moveTo(20, 39)
            ..lineTo(8, 36)
            ..moveTo(20, 43)
            ..lineTo(8, 45)
            ..moveTo(44, 39)
            ..lineTo(56, 36)
            ..moveTo(44, 43)
            ..lineTo(56, 45),
          color: ink.withValues(alpha: .7),
        );
        shape(canvas, heart(32, 50 + math.sin(radians * 1.6) * 1.5, 5), pink, paper: false);
      case 'cherry':
        line(
          canvas,
          Path()
            ..moveTo(31, 46)
            ..quadraticBezierTo(27, 21, 17, 13)
            ..moveTo(32, 46)
            ..quadraticBezierTo(36, 20, 48, 12),
          color: const Color(0xFF78AD8D),
          width: 2.2,
        );
        for (final point in const [
          Offset(16, 14),
          Offset(26, 7),
          Offset(38, 9),
          Offset(48, 14),
        ]) {
          for (var petal = 0; petal < 5; petal++) {
            canvas.save();
            canvas.translate(point.dx, point.dy);
            canvas.rotate(petal * math.pi / 2.5);
            oval(canvas, const Rect.fromLTWH(-3, -8, 6, 9), pink);
            canvas.restore();
          }
          canvas.drawCircle(point, 2.6, Paint()..color = gold);
        }
        shape(canvas, heart(32, 53 + math.sin(radians) * 1.5, 6), pink, paper: false);
      case 'flower':
        line(
          canvas,
          Path()
            ..moveTo(32, 33)
            ..quadraticBezierTo(26, 46, 31, 56),
          color: const Color(0xFF77AD8D),
          width: 3,
        );
        shape(
          canvas,
          Path()
            ..moveTo(30, 48)
            ..quadraticBezierTo(12, 51, 17, 39)
            ..quadraticBezierTo(29, 38, 30, 48),
          green,
        );
        for (var i = 0; i < 6; i++) {
          canvas.save();
          canvas.translate(32, 27);
          canvas.rotate(i * math.pi / 3);
          oval(canvas, const Rect.fromLTWH(-7, -22, 14, 24), pink);
          canvas.restore();
        }
        oval(canvas, const Rect.fromLTWH(23, 18, 18, 18), gold, paper: false);
        face(canvas, 32, 25, gap: 3.5);
      case 'tulip':
        line(
          canvas,
          Path()
            ..moveTo(31, 32)
            ..quadraticBezierTo(33, 45, 31, 56),
          color: const Color(0xFF78AF91),
          width: 3,
        );
        shape(
          canvas,
          Path()
            ..moveTo(31, 50)
            ..quadraticBezierTo(14, 45, 17, 36)
            ..quadraticBezierTo(29, 38, 31, 50),
          green,
        );
        shape(
          canvas,
          Path()
            ..moveTo(31, 51)
            ..quadraticBezierTo(48, 40, 47, 34)
            ..quadraticBezierTo(34, 36, 31, 51),
          green,
        );
        shape(
          canvas,
          Path()
            ..moveTo(16, 15)
            ..lineTo(26, 21)
            ..lineTo(32, 9)
            ..lineTo(39, 21)
            ..lineTo(49, 14)
            ..quadraticBezierTo(52, 37, 32, 38)
            ..quadraticBezierTo(12, 35, 16, 15),
          const Color(0xFFFFB6A2),
        );
        line(
          canvas,
          Path()
            ..moveTo(26, 21)
            ..quadraticBezierTo(26, 31, 31, 35),
        );
      case 'leaf':
        shape(
          canvas,
          Path()
            ..moveTo(16, 49)
            ..quadraticBezierTo(6, 16, 50, 11)
            ..quadraticBezierTo(54, 47, 16, 49),
          green,
        );
        line(
          canvas,
          Path()
            ..moveTo(12, 54)
            ..lineTo(43, 20),
          color: const Color(0xFF608C73),
          width: 2,
        );
        line(
          canvas,
          Path()
            ..moveTo(24, 40)
            ..lineTo(23, 28)
            ..moveTo(32, 31)
            ..lineTo(43, 32),
          color: const Color(0xFF608C73),
        );
      case 'butterfly':
        shape(
          canvas,
          Path()
            ..moveTo(31, 32)
            ..cubicTo(12, 0, 0, 21, 20, 33)
            ..cubicTo(0, 47, 26, 60, 31, 33),
          pink,
        );
        shape(
          canvas,
          Path()
            ..moveTo(33, 32)
            ..cubicTo(52, 0, 64, 21, 44, 33)
            ..cubicTo(64, 47, 38, 60, 33, 33),
          purple,
        );
        oval(canvas, const Rect.fromLTWH(29, 25, 6, 23), gold, paper: false);
        line(
          canvas,
          Path()
            ..moveTo(32, 26)
            ..quadraticBezierTo(29, 16, 24, 18)
            ..moveTo(33, 26)
            ..quadraticBezierTo(36, 16, 41, 18),
        );
        oval(
          canvas,
          const Rect.fromLTWH(15, 21, 8, 9),
          const Color(0xFFFFE9F0),
          paper: false,
        );
        oval(
          canvas,
          const Rect.fromLTWH(42, 21, 8, 9),
          const Color(0xFFF5EFFF),
          paper: false,
        );
      case 'sparkle':
        shape(canvas, star(29, 33, 24, points: 4), gold);
        shape(canvas, star(49, 13, 8, points: 4), pink);
        canvas.drawCircle(const Offset(13, 15), 3, Paint()..color = purple);
      case 'star':
        shape(canvas, star(32, 32, 26), gold);
        face(canvas, 32, 31);
        oval(
          canvas,
          const Rect.fromLTWH(23, 17, 5, 8),
          const Color(0xFFFFF3C7),
          paper: false,
        );
      case 'sun':
        for (var i = 0; i < 10; i++) {
          canvas.save();
          canvas.translate(32, 32);
          canvas.rotate(i * math.pi / 5);
          line(
            canvas,
            Path()
              ..moveTo(0, -22)
              ..lineTo(0, -27),
            color: const Color(0xFFECC05C),
            width: 3,
          );
          canvas.restore();
        }
        oval(canvas, const Rect.fromLTWH(14, 14, 36, 36), gold);
        face(canvas, 32, 31);
      case 'cloud':
        shape(
          canvas,
          Path()
            ..moveTo(14, 47)
            ..cubicTo(0, 45, 2, 26, 17, 28)
            ..cubicTo(18, 8, 43, 9, 44, 27)
            ..cubicTo(62, 25, 64, 46, 50, 47)
            ..close(),
          const Color(0xFFD3EAF4),
        );
        face(canvas, 32, 35);
        shape(canvas, heart(48, 16, 7), pink);
      case 'heart':
        shape(canvas, heart(32, 30, 28), pink);
        face(canvas, 32, 31);
        line(
          canvas,
          Path()
            ..moveTo(17, 23)
            ..quadraticBezierTo(18, 16, 24, 18),
          color: const Color(0xFFFFEEF3),
          width: 3,
        );
      case 'heart_outline':
        line(canvas, heart(32, 30, 27), color: Colors.white, width: 7);
        line(
          canvas,
          heart(32, 30, 27),
          color: const Color(0xFFD890BA),
          width: 3.5,
        );
        shape(canvas, star(46, 16, 7, points: 4), gold);
      case 'bow':
        shape(
          canvas,
          Path()
            ..moveTo(29, 29)
            ..lineTo(20, 56)
            ..lineTo(15, 49)
            ..lineTo(6, 51)
            ..lineTo(20, 28)
            ..close(),
          pink,
        );
        shape(
          canvas,
          Path()
            ..moveTo(35, 29)
            ..lineTo(44, 56)
            ..lineTo(49, 49)
            ..lineTo(58, 51)
            ..lineTo(44, 28)
            ..close(),
          pink,
        );
        shape(
          canvas,
          Path()
            ..moveTo(30, 27)
            ..cubicTo(3, 1, 2, 14, 9, 32)
            ..quadraticBezierTo(21, 41, 30, 27),
          purple,
        );
        shape(
          canvas,
          Path()
            ..moveTo(34, 27)
            ..cubicTo(61, 1, 62, 14, 55, 32)
            ..quadraticBezierTo(43, 41, 34, 27),
          purple,
        );
        shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(26, 21, 12, 14),
              const Radius.circular(5),
            ),
          ),
          pink,
        );
        line(
          canvas,
          Path()
            ..moveTo(13, 20)
            ..lineTo(24, 26)
            ..moveTo(50, 20)
            ..lineTo(40, 26),
          color: const Color(0xFF9C84C5),
        );
      case 'kiss':
        shape(
          canvas,
          Path()
            ..moveTo(7, 33)
            ..quadraticBezierTo(23, 12, 32, 24)
            ..quadraticBezierTo(41, 12, 57, 33)
            ..quadraticBezierTo(32, 59, 7, 33),
          const Color(0xFFED99AD),
        );
        line(
          canvas,
          Path()
            ..moveTo(9, 33)
            ..quadraticBezierTo(24, 37, 32, 32)
            ..quadraticBezierTo(42, 36, 55, 33),
        );
        shape(canvas, heart(49, 13, 7), pink);
      case 'picnic':
        line(
          canvas,
          Path()
            ..moveTo(16, 32)
            ..cubicTo(15, 4, 49, 4, 48, 32),
          color: const Color(0xFFB99370),
          width: 4,
        );
        oval(
          canvas,
          const Rect.fromLTWH(14, 19, 12, 29),
          const Color(0xFFFFD895),
        );
        oval(canvas, const Rect.fromLTWH(36, 20, 13, 21), pink);
        shape(
          canvas,
          Path()
            ..moveTo(10, 31)
            ..lineTo(54, 31)
            ..lineTo(49, 53)
            ..quadraticBezierTo(32, 60, 15, 53)
            ..close(),
          const Color(0xFFE4BC8F),
        );
        for (var i = 0; i < 4; i++) {
          line(
            canvas,
            Path()
              ..moveTo(20 + i * 8, 35)
              ..lineTo(21 + i * 7, 52),
            color: const Color(0xFFBA926C),
          );
        }
        line(
          canvas,
          Path()
            ..moveTo(14, 40)
            ..lineTo(51, 40)
            ..moveTo(16, 47)
            ..lineTo(49, 47),
          color: const Color(0xFFBA926C),
        );
        shape(canvas, heart(32, 42, 6), const Color(0xFFF9E7D4), paper: false);
      case 'cake':
        oval(canvas, const Rect.fromLTWH(9, 45, 46, 10), blue);
        shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(14, 24, 36, 26),
              const Radius.circular(5),
            ),
          ),
          pink,
        );
        line(
          canvas,
          Path()
            ..moveTo(14, 41)
            ..lineTo(50, 41),
          color: const Color(0xFFFFF4DF),
          width: 5,
        );
        shape(
          canvas,
          Path()
            ..moveTo(14, 25)
            ..quadraticBezierTo(31, 15, 50, 25)
            ..lineTo(50, 33)
            ..quadraticBezierTo(45, 40, 41, 32)
            ..quadraticBezierTo(36, 41, 31, 32)
            ..quadraticBezierTo(25, 40, 22, 32)
            ..quadraticBezierTo(17, 38, 14, 32)
            ..close(),
          const Color(0xFFFFF6E9),
        );
        shape(canvas, heart(32, 15, 8), const Color(0xFFE897AB));
        line(
          canvas,
          Path()
            ..moveTo(30, 10)
            ..lineTo(28, 7)
            ..moveTo(32, 10)
            ..lineTo(35, 7),
          color: green,
          width: 2,
        );
      case 'gift':
        shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(13, 27, 38, 28),
              const Radius.circular(5),
            ),
          ),
          blue,
        );
        shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(10, 23, 44, 10),
              const Radius.circular(4),
            ),
          ),
          const Color(0xFFC4E7EB),
        );
        shape(
          canvas,
          Path()..addRect(const Rect.fromLTWH(28, 24, 8, 31)),
          pink,
          paper: false,
        );
        shape(
          canvas,
          Path()
            ..moveTo(32, 23)
            ..cubicTo(8, 21, 19, 2, 32, 23)
            ..cubicTo(46, 2, 56, 21, 32, 23),
          pink,
        );
        shape(canvas, heart(44, 44, 5), const Color(0xFFFFF3EA), paper: false);
      case 'balloon':
        line(
          canvas,
          Path()
            ..moveTo(23, 34)
            ..cubicTo(14, 45, 41, 44, 28, 58)
            ..moveTo(43, 39)
            ..cubicTo(53, 50, 32, 46, 35, 58),
          color: const Color(0xFFB9A5BA),
        );
        oval(canvas, const Rect.fromLTWH(7, 8, 29, 32), pink);
        oval(canvas, const Rect.fromLTWH(31, 14, 25, 29), purple);
        line(
          canvas,
          Path()
            ..moveTo(14, 17)
            ..quadraticBezierTo(15, 13, 19, 14)
            ..moveTo(37, 23)
            ..quadraticBezierTo(39, 19, 42, 20),
          color: Colors.white,
          width: 2.5,
        );
        shape(
          canvas,
          Path()
            ..moveTo(21, 39)
            ..lineTo(18, 43)
            ..lineTo(25, 43)
            ..close(),
          pink,
          paper: false,
        );
        shape(
          canvas,
          Path()
            ..moveTo(43, 42)
            ..lineTo(40, 46)
            ..lineTo(47, 46)
            ..close(),
          purple,
          paper: false,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DecorArtPainter oldDelegate) =>
      oldDelegate.id != id;
}
