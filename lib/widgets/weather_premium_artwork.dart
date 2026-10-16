import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/weather_background.dart';

/// Bảng màu và artwork dùng chung cho nền Thời tiết PRO.
///
/// Mỗi nửa của card vẫn được vẽ độc lập theo presence của từng người, nhưng
/// các lớp ánh sáng, khí quyển và hạt trang trí dùng cùng một nhịp để hai
/// widget native không bị lệch phong cách so với Home/preview Flutter.
abstract final class WeatherBackgroundDesign {
  static const palettes = <WeatherBackgroundState, List<Color>>{
    WeatherBackgroundState.unknown: [
      Color(0xFFDCE7F1),
      Color(0xFFF7F3FA),
      Color(0xFFDCEDED),
    ],
    WeatherBackgroundState.sunny: [
      Color(0xFFFFC96B),
      Color(0xFFFFF0C9),
      Color(0xFFF5CBDD),
    ],
    WeatherBackgroundState.cloudy: [
      Color(0xFFB5CBE0),
      Color(0xFFE8E6F2),
      Color(0xFFB9D9D7),
    ],
    WeatherBackgroundState.rain: [
      Color(0xFF7FA5CF),
      Color(0xFFBEC8E4),
      Color(0xFF9FCACD),
    ],
    WeatherBackgroundState.lightning: [
      Color(0xFF6D639F),
      Color(0xFF9C8CC0),
      Color(0xFFF0C47D),
    ],
    WeatherBackgroundState.cold: [
      Color(0xFFA8D8E9),
      Color(0xFFE0F1FA),
      Color(0xFFBBC7EC),
    ],
  };

  static List<Color> colors(
    WeatherBackgroundSnapshot weather, {
    bool dark = false,
  }) {
    final first = palettes[weather.left]!;
    final second = palettes[weather.right]!;
    final colors = [
      Color.lerp(first[0], second[0], .28)!,
      Color.lerp(first[1], second[1], .5)!,
      Color.lerp(first[2], second[2], .28)!,
    ];
    if (!dark) return colors;
    return [
      for (var i = 0; i < colors.length; i++)
        Color.lerp(const Color(0xFF252538), colors[i], i == 1 ? .34 : .42)!,
    ];
  }
}

/// Họa tiết chia theo từng người; không suy thời tiết người này sang người kia.
class WeatherPremiumArtwork extends StatelessWidget {
  const WeatherPremiumArtwork({
    super.key,
    required this.weather,
    this.dark = false,
    this.alternate = false,
  });

  final WeatherBackgroundSnapshot weather;
  final bool dark;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: CustomPaint(
        painter: WeatherPremiumPainter(
          left: rtl ? weather.right : weather.left,
          right: rtl ? weather.left : weather.right,
          dark: dark,
          alternate: alternate,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class WeatherPremiumPainter extends CustomPainter {
  const WeatherPremiumPainter({
    required this.left,
    required this.right,
    this.dark = false,
    this.alternate = false,
  });

  final WeatherBackgroundState left;
  final WeatherBackgroundState right;
  final bool dark;
  final bool alternate;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = size.width / 2;
    for (var i = 0; i < 2; i++) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(i * half, 0, half, size.height));
      canvas.translate(i * half, 0);
      _paintState(canvas, Size(half, size.height), i == 0 ? left : right);
      canvas.restore();
    }
  }

  void _paintState(Canvas canvas, Size size, WeatherBackgroundState state) {
    final w = size.width;
    final h = size.height;
    final unit = math.min(w / 150, h / 180).clamp(.5, 1.5);
    final rect = Offset.zero & size;
    final palette = WeatherBackgroundDesign.palettes[state]!;

    // Lớp màu khí quyển giúp nền có chiều sâu ngay cả khi card rất nhỏ.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            palette[0].withValues(alpha: dark ? .58 : .72),
            palette[1].withValues(alpha: dark ? .42 : .52),
            palette[2].withValues(alpha: dark ? .64 : .68),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    final glowCenter = Offset(
      state == WeatherBackgroundState.lightning ? w * .76 : w * .28,
      state == WeatherBackgroundState.cold ? h * .72 : h * .18,
    );
    canvas.drawCircle(
      glowCenter,
      math.max(w, h) * .64,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _accent(state).withValues(alpha: dark ? .20 : .26),
                _accent(state).withValues(alpha: .04),
                Colors.transparent,
              ],
              stops: const [.0, .46, 1],
            ).createShader(
              Rect.fromCircle(center: glowCenter, radius: math.max(w, h) * .64),
            ),
    );

    final center = Offset(w * .22, h * .17 + (alternate ? 3 * unit : 0));
    switch (state) {
      case WeatherBackgroundState.sunny:
        _sun(canvas, center, unit);
      case WeatherBackgroundState.cloudy:
        _cloud(canvas, center.translate(8 * unit, 1 * unit), unit);
        _cloud(canvas, Offset(w * .82, h * .78), unit * .62, muted: true);
        _mist(canvas, h * .84, unit, const Color(0xFFFFFFFF), .16);
      case WeatherBackgroundState.rain:
        _cloud(canvas, center.translate(8 * unit, 1 * unit), unit, storm: true);
        _rain(canvas, w, h, unit, storm: false);
        _mist(canvas, h * .88, unit, const Color(0xFFB9E4E5), .20);
      case WeatherBackgroundState.lightning:
        _cloud(canvas, center.translate(8 * unit, 1 * unit), unit, storm: true);
        _cloud(canvas, Offset(w * .80, h * .30), unit * .52, storm: true);
        _rain(canvas, w, h, unit, storm: true);
        _lightning(canvas, w * .80, h * .20, unit);
        _mist(canvas, h * .91, unit, const Color(0xFFF5D89E), .14);
      case WeatherBackgroundState.cold:
        _frost(canvas, w, h, center, unit);
        _mist(canvas, h * .82, unit, const Color(0xFFF4FCFF), .24);
      case WeatherBackgroundState.unknown:
        _ambient(canvas, w, h, unit);
    }

    // Vignette rất nhẹ để chữ/avatar ở giữa card luôn có vùng tương phản.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: dark ? .015 : .10),
            Colors.transparent,
            Colors.black.withValues(alpha: dark ? .12 : .025),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
  }

  Color _accent(WeatherBackgroundState state) => switch (state) {
    WeatherBackgroundState.sunny => const Color(0xFFFFB946),
    WeatherBackgroundState.cloudy => const Color(0xFFEDF5FF),
    WeatherBackgroundState.rain => const Color(0xFF6B9FD2),
    WeatherBackgroundState.lightning => const Color(0xFFFFD36D),
    WeatherBackgroundState.cold => const Color(0xFFB9F1FF),
    WeatherBackgroundState.unknown => const Color(0xFFEFFFFB),
  };

  void _sun(Canvas canvas, Offset center, double u) {
    final glowRect = Rect.fromCircle(center: center, radius: 34 * u);
    canvas.drawCircle(
      center,
      34 * u,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF4BD).withValues(alpha: .72),
            const Color(0xFFFFCF67).withValues(alpha: .24),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );
    final rays = Paint()
      ..color = const Color(0xFFFFC45C).withValues(alpha: .66)
      ..strokeWidth = 2.2 * u
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + (alternate ? .10 : 0);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (22 * u),
        center + direction * (31 * u),
        rays,
      );
    }
    canvas.drawCircle(
      center,
      16 * u,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF1A8), Color(0xFFF5B948)],
        ).createShader(glowRect),
    );
    canvas.drawCircle(
      center.translate(-4 * u, -5 * u),
      4 * u,
      Paint()..color = Colors.white.withValues(alpha: .28),
    );
  }

  void _cloud(
    Canvas canvas,
    Offset center,
    double u, {
    bool muted = false,
    bool storm = false,
  }) {
    final shadow = Paint()
      ..color = (storm ? const Color(0xFF465878) : const Color(0xFF657B99))
          .withValues(alpha: storm ? .30 : .15);
    final body = Paint()
      ..color = (storm ? const Color(0xFFE7EDF9) : Colors.white).withValues(
        alpha: muted ? .34 : (storm ? .66 : .72),
      );
    final highlight = Paint()
      ..color = Colors.white.withValues(
        alpha: muted ? .18 : (storm ? .24 : .38),
      );
    final shapes = [
      (center.translate(-16 * u, 5 * u), 13 * u),
      (center.translate(-2 * u, -5 * u), 18 * u),
      (center.translate(16 * u, 4 * u), 12 * u),
    ];
    for (final shape in shapes) {
      canvas.drawCircle(shape.$1.translate(1 * u, 2 * u), shape.$2, shadow);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, 9 * u),
          width: 52 * u,
          height: 18 * u,
        ),
        Radius.circular(9 * u),
      ),
      shadow,
    );
    for (final shape in shapes) {
      canvas.drawCircle(shape.$1, shape.$2, body);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, 7 * u),
          width: 52 * u,
          height: 18 * u,
        ),
        Radius.circular(9 * u),
      ),
      body,
    );
    canvas.drawCircle(center.translate(-7 * u, -10 * u), 5 * u, highlight);
  }

  void _rain(
    Canvas canvas,
    double w,
    double h,
    double u, {
    required bool storm,
  }) {
    final far = Paint()
      ..color = const Color(0xFFEAF7FF).withValues(alpha: storm ? .20 : .30)
      ..strokeWidth = 1.2 * u
      ..strokeCap = StrokeCap.round;
    final near = Paint()
      ..color = const Color(0xFF3978B4).withValues(alpha: storm ? .54 : .42)
      ..strokeWidth = 1.9 * u
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 18; i++) {
      final column = i % 6;
      final row = i ~/ 6;
      final x = w * (.06 + column * .18) + (row.isEven ? 3 * u : 0);
      final y = h * (.34 + row * .22) + (alternate ? 6 * u : 0);
      final length = (row == 0 ? 8 : 12) * u;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 4 * u, y + length),
        row == 0 ? far : near,
      );
    }
    for (final point in [
      Offset(w * .18, h * .50),
      Offset(w * .56, h * .62),
      Offset(w * .84, h * .47),
    ]) {
      canvas.drawCircle(
        point,
        2.1 * u,
        Paint()..color = Colors.white.withValues(alpha: storm ? .28 : .38),
      );
    }
  }

  void _lightning(Canvas canvas, double x, double y, double u) {
    final bolt = Path()
      ..moveTo(x, y)
      ..lineTo(x - 11 * u, y + 22 * u)
      ..lineTo(x + 1 * u, y + 18 * u)
      ..lineTo(x - 8 * u, y + 42 * u);
    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(0xFFFFE29A).withValues(alpha: .34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * u
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(
          0xFFFFF4C5,
        ).withValues(alpha: alternate ? .98 : .88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * u
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _frost(Canvas canvas, double w, double h, Offset center, double u) {
    final snow = Paint()
      ..color = const Color(0xFF4F9FC3).withValues(alpha: .48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * u
      ..strokeCap = StrokeCap.round;
    final sparkle = Paint()
      ..color = Colors.white.withValues(alpha: .68)
      ..strokeWidth = 1.2 * u
      ..strokeCap = StrokeCap.round;
    final points = [
      center,
      Offset(w * .82, h * .26),
      Offset(w * .14, h * .74),
      Offset(w * .82, h * .78),
      Offset(w * .42, h * .54),
    ];
    for (var pointIndex = 0; pointIndex < points.length; pointIndex++) {
      final point = points[pointIndex];
      final radius = (pointIndex.isEven ? 8 : 5.5) * u;
      for (var i = 0; i < 3; i++) {
        final angle = i * math.pi / 3;
        final arm = Offset(math.cos(angle), math.sin(angle)) * radius;
        canvas.drawLine(point - arm, point + arm, snow);
        final branch = arm * .56;
        canvas.drawLine(
          point - branch,
          point - branch + Offset(-arm.dy, arm.dx) * .22,
          snow,
        );
        canvas.drawLine(
          point + branch,
          point + branch + Offset(arm.dy, -arm.dx) * .22,
          snow,
        );
      }
      if (pointIndex.isEven) {
        canvas.drawLine(
          point.translate(-2 * u, -2 * u),
          point.translate(2 * u, 2 * u),
          sparkle,
        );
      }
    }
    for (final point in [
      Offset(w * .28, h * .36),
      Offset(w * .66, h * .45),
      Offset(w * .28, h * .88),
    ]) {
      canvas.drawCircle(point, 1.8 * u, sparkle);
    }
  }

  void _mist(Canvas canvas, double y, double u, Color color, double alpha) {
    final rect = Rect.fromCenter(
      center: Offset(0, y),
      width: 210 * u,
      height: 30 * u,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  void _ambient(Canvas canvas, double w, double h, double u) {
    final dot = Paint()..color = Colors.white.withValues(alpha: .34);
    for (final point in [
      Offset(w * .18, h * .28),
      Offset(w * .70, h * .22),
      Offset(w * .84, h * .66),
      Offset(w * .30, h * .78),
    ]) {
      canvas.drawCircle(point, (alternate ? 2.2 : 1.6) * u, dot);
    }
  }

  @override
  bool shouldRepaint(WeatherPremiumPainter old) =>
      old.left != left ||
      old.right != right ||
      old.dark != dark ||
      old.alternate != alternate;
}
