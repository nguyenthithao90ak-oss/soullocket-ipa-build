import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';

/// Bảng màu riêng của góc giấy; không thay theme hay dữ liệu tiện ích.
class UtilitiesScrapbookColors {
  const UtilitiesScrapbookColors({required this.dark});

  factory UtilitiesScrapbookColors.of(BuildContext context) =>
      UtilitiesScrapbookColors(
        dark: Theme.of(context).brightness == Brightness.dark,
      );

  final bool dark;

  Color get canvas => dark ? const Color(0xFF241F2B) : const Color(0xFFFFF9F0);
  Color get paper => dark ? const Color(0xFF342D3C) : const Color(0xFFFFFCF7);
  Color get ink => dark ? const Color(0xFFF5EAF8) : const Color(0xFF47243F);
  Color get muted => dark ? const Color(0xFFCEBDD1) : const Color(0xFF7B6076);
  Color get accent => dark ? const Color(0xFFB09ADE) : const Color(0xFF8B64B7);
  Color get onAccent => dark ? const Color(0xFF291B3D) : Colors.white;
  Color get lilac => dark ? const Color(0xFF3E334E) : const Color(0xFFF4EBF8);
  Color get rose => dark ? const Color(0xFF44323E) : const Color(0xFFFFEEF0);
  Color get line => dark ? const Color(0xFF60506A) : const Color(0xFFE6CEDF);
}

/// Lớp giấy tĩnh, không có gesture/listener hoặc bộ điều khiển animation.
class UtilitiesScrapbookBackdrop extends StatelessWidget {
  const UtilitiesScrapbookBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = UtilitiesScrapbookColors.of(context);
    return ColoredBox(
      color: colors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _GridPaperPainter(colors)),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Giấy có viền khâu/băng dính, để Material của nội dung vẫn nhận ripple.
class UtilitiesScrapbookPaper extends StatelessWidget {
  const UtilitiesScrapbookPaper({
    super.key,
    required this.child,
    this.color,
    this.perforated = false,
    this.tape = true,
  });

  final Widget child;
  final Color? color;
  final bool perforated;
  final bool tape;

  @override
  Widget build(BuildContext context) {
    final colors = UtilitiesScrapbookColors.of(context);
    return CustomPaint(
      painter: _ScrapbookPaperPainter(
        colors,
        color ?? colors.paper,
        perforated,
      ),
      foregroundPainter: tape ? _TapePainter(colors.dark) : null,
      child: child,
    );
  }
}

class UtilitiesScrapbookHeading extends StatelessWidget {
  const UtilitiesScrapbookHeading({
    super.key,
    required this.title,
    this.count,
    this.badgeColor,
  });

  final String title;
  final int? count;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final colors = UtilitiesScrapbookColors.of(context);
    return Row(
      children: [
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor ?? colors.rose,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$count',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 10),
        const UtilitiesStationeryArt(size: 30, bouquet: true),
      ],
    );
  }
}

/// Minh họa Canvas: ảnh phong cảnh, hướng dương và hoa giấy; không nhân vật.
class UtilitiesStationeryArt extends StatelessWidget {
  const UtilitiesStationeryArt({
    super.key,
    required this.size,
    this.bouquet = false,
  });

  final double size;
  final bool bouquet;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _StationeryPainter(
                dark: UtilitiesScrapbookColors.of(context).dark,
                bouquet: bouquet,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPaperPainter extends CustomPainter {
  const _GridPaperPainter(this.colors);

  final UtilitiesScrapbookColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.line.withValues(alpha: colors.dark ? .14 : .16)
      ..strokeWidth = .5;
    for (var x = 0.0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPaperPainter oldDelegate) =>
      oldDelegate.colors.dark != colors.dark;
}

class _ScrapbookPaperPainter extends CustomPainter {
  const _ScrapbookPaperPainter(this.colors, this.fill, this.perforated);

  final UtilitiesScrapbookColors colors;
  final Color fill;
  final bool perforated;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(2);
    var shape = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(22)));
    if (perforated) {
      final holes = Path();
      for (var x = 24.0; x < size.width - 20; x += 18) {
        holes
          ..addOval(Rect.fromCircle(center: Offset(x, 2), radius: 3))
          ..addOval(
            Rect.fromCircle(center: Offset(x, size.height - 2), radius: 3),
          );
      }
      shape = Path.combine(PathOperation.difference, shape, holes);
    }
    canvas.drawShadow(
      shape,
      const Color(0xFF5C3652).withValues(alpha: .16),
      4,
      false,
    );
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..color = colors.line.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final stitch = Paint()
      ..color = colors.line.withValues(alpha: .75)
      ..strokeWidth = .8
      ..strokeCap = StrokeCap.round;
    for (var x = 28.0; x < size.width - 28; x += 9) {
      canvas.drawLine(Offset(x, 11), Offset(x + 4, 11), stitch);
      canvas.drawLine(
        Offset(x, size.height - 11),
        Offset(x + 4, size.height - 11),
        stitch,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrapbookPaperPainter oldDelegate) =>
      oldDelegate.colors.dark != colors.dark ||
      oldDelegate.fill != fill ||
      oldDelegate.perforated != perforated;
}

class _TapePainter extends CustomPainter {
  const _TapePainter(this.dark);

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width - 42, 6);
    canvas.rotate(.22);
    _drawTape(canvas, const Rect.fromLTWH(-27, -6, 54, 16), dark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TapePainter oldDelegate) => oldDelegate.dark != dark;
}

void _drawTape(Canvas canvas, Rect rect, bool dark) {
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)));
  canvas.drawRect(
    rect,
    Paint()..color = dark ? const Color(0xFF746284) : const Color(0xFFF4E6F7),
  );
  final check = Paint()..color = const Color(0xFFC3A1DA).withValues(alpha: .48);
  for (var x = rect.left; x < rect.right; x += 10) {
    canvas.drawRect(Rect.fromLTWH(x, rect.top, 5, rect.height), check);
  }
  for (var y = rect.top; y < rect.bottom; y += 10) {
    canvas.drawRect(Rect.fromLTWH(rect.left, y, rect.width, 5), check);
  }
  canvas.restore();
}

class _StationeryPainter extends CustomPainter {
  const _StationeryPainter({required this.dark, required this.bouquet});

  final bool dark;
  final bool bouquet;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 160);
    if (bouquet) {
      _sprig(canvas, const Offset(80, 136), 1.5);
      _flower(canvas, const Offset(58, 55), 26);
      _flower(canvas, const Offset(110, 101), 16);
    } else {
      _sprig(canvas, const Offset(136, 108), .85);
      _photo(canvas, const Offset(42, 57), -0.17, 0);
      _photo(canvas, const Offset(105, 70), .14, 1);
      _photo(canvas, const Offset(77, 108), -.08, 2);
      _flower(canvas, const Offset(25, 119), 11);
      _pencil(canvas);
      _heart(canvas, const Offset(136, 27), 7);
    }
    canvas.restore();
  }

  void _photo(Canvas canvas, Offset center, double angle, int motif) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    const paper = Rect.fromLTWH(-31, -39, 62, 78);
    final shape = Path()
      ..addRRect(RRect.fromRectAndRadius(paper, const Radius.circular(3)));
    canvas.drawShadow(
      shape,
      const Color(0xFF775543).withValues(alpha: .3),
      3,
      false,
    );
    canvas.drawPath(shape, Paint()..color = const Color(0xFFFFFCF6));
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xFFE4CFC4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    const image = Rect.fromLTWH(-26, -34, 52, 57);
    canvas.save();
    canvas.clipRect(image);
    if (motif == 0) {
      canvas.drawRect(image, Paint()..color = const Color(0xFFC5E1F2));
      canvas.drawCircle(
        const Offset(14, -23),
        7,
        Paint()..color = const Color(0xFFFFDEA1),
      );
      for (final cloud in [const Offset(-16, -21), const Offset(5, -9)]) {
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            cloud + Offset(i * 6, (i == 1 ? -2 : 0)),
            5,
            Paint()..color = const Color(0xFFFFFCF4),
          );
        }
      }
      final hill = Path()
        ..moveTo(-27, 8)
        ..quadraticBezierTo(-4, -22, 27, 8)
        ..lineTo(27, 25)
        ..lineTo(-27, 25)
        ..close();
      canvas.drawPath(hill, Paint()..color = const Color(0xFF98B799));
      final foreground = Path()
        ..moveTo(-27, 14)
        ..quadraticBezierTo(8, -2, 27, 20)
        ..lineTo(27, 25)
        ..lineTo(-27, 25)
        ..close();
      canvas.drawPath(foreground, Paint()..color = const Color(0xFFB8C899));
      for (var i = 0; i < 6; i++) {
        canvas.drawCircle(
          Offset(-21 + i * 8, 15 + (i % 2) * 5),
          1.4,
          Paint()..color = const Color(0xFFFFF0A8),
        );
      }
    } else if (motif == 1) {
      canvas.drawRect(image, Paint()..color = const Color(0xFFE5EFD8));
      canvas.drawLine(
        const Offset(0, 25),
        const Offset(0, -13),
        Paint()
          ..color = const Color(0xFF70966B)
          ..strokeWidth = 2.5,
      );
      canvas.drawOval(
        const Rect.fromLTWH(-16, 6, 17, 7),
        Paint()..color = const Color(0xFF92B478),
      );
      _flower(canvas, const Offset(0, -13), 18, sunflower: true);
    } else {
      canvas.drawRect(image, Paint()..color = const Color(0xFFF8DADF));
      _heart(canvas, const Offset(0, -4), 17);
    }
    canvas.restore();
    canvas.restore();
  }

  void _pencil(Canvas canvas) {
    canvas.save();
    canvas.translate(123, 132);
    canvas.rotate(-.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-36, -3, 61, 6),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFE5B549),
    );
    canvas.drawLine(
      const Offset(-32, -1),
      const Offset(25, -1),
      Paint()
        ..color = const Color(0xFFFFE597)
        ..strokeWidth = 1.2,
    );
    final tip = Path()
      ..moveTo(-36, -3)
      ..lineTo(-45, 0)
      ..lineTo(-36, 3)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFFEAD2AB));
    canvas.drawCircle(
      const Offset(-44, 0),
      1,
      Paint()..color = const Color(0xFF605065),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, -3, 9, 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFC9A1BC),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StationeryPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.bouquet != bouquet;
}

void _sprig(Canvas canvas, Offset base, double scale) {
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.scale(scale);
  final stem = Paint()
    ..color = const Color(0xFF879D6E)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-5, -25, -18, -48),
    stem,
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(13, -20, 18, -50),
    stem,
  );
  canvas.drawOval(
    const Rect.fromLTWH(-21, -29, 17, 8),
    Paint()..color = const Color(0xFFA2B68B),
  );
  canvas.drawOval(
    const Rect.fromLTWH(2, -22, 19, 8),
    Paint()..color = const Color(0xFF91AC84),
  );
  _flower(canvas, const Offset(-18, -48), 8);
  _flower(canvas, const Offset(18, -50), 6);
  _flower(canvas, const Offset(9, -35), 5);
  canvas.restore();
}

void _flower(
  Canvas canvas,
  Offset center,
  double radius, {
  bool sunflower = false,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  final petals = sunflower ? 13 : 8;
  for (var i = 0; i < petals; i++) {
    canvas.save();
    canvas.rotate(i * math.pi * 2 / petals);
    final petal = Rect.fromLTWH(
      -radius * .22,
      -radius,
      radius * .44,
      radius * .83,
    );
    canvas.drawOval(
      petal,
      Paint()
        ..color = sunflower ? const Color(0xFFF4C45D) : const Color(0xFFFFFBEC),
    );
    canvas.drawOval(
      petal,
      Paint()
        ..color = const Color(0xFFE3C9A7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .55,
    );
    canvas.restore();
  }
  canvas.drawCircle(
    Offset.zero,
    radius * .34,
    Paint()
      ..color = sunflower ? const Color(0xFF94603D) : const Color(0xFFEEC56B),
  );
  canvas.drawCircle(
    Offset(-radius * .06, -radius * .06),
    radius * .22,
    Paint()
      ..color = sunflower ? const Color(0xFFB88646) : const Color(0xFFF7D986),
  );
  canvas.restore();
}

void _heart(Canvas canvas, Offset center, double radius) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  final path = Path()
    ..moveTo(0, radius * .7)
    ..cubicTo(
      -radius * 1.7,
      -radius * .3,
      -radius * .7,
      -radius * 1.4,
      0,
      -radius * .5,
    )
    ..cubicTo(
      radius * .7,
      -radius * 1.4,
      radius * 1.7,
      -radius * .3,
      0,
      radius * .7,
    )
    ..close();
  canvas.drawPath(path, Paint()..color = const Color(0xFFECA5B9));
  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFFD67F9B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8,
  );
  canvas.restore();
}
