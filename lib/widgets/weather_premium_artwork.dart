import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/weather_background.dart';

abstract final class WeatherBackgroundDesign {
  static const palettes = <WeatherBackgroundState, List<Color>>{
    WeatherBackgroundState.unknown: [
      Color(0xFFE7EDF4),
      Color(0xFFF4EFF8),
      Color(0xFFE8F1F3),
    ],
    WeatherBackgroundState.sunny: [
      Color(0xFFFFE6A8),
      Color(0xFFFFF3D8),
      Color(0xFFFFD7E8),
    ],
    WeatherBackgroundState.cloudy: [
      Color(0xFFD9E6F4),
      Color(0xFFECE7F8),
      Color(0xFFD7EFF0),
    ],
    WeatherBackgroundState.rain: [
      Color(0xFFB8D0EC),
      Color(0xFFD7D3ED),
      Color(0xFFBBDCE0),
    ],
    WeatherBackgroundState.lightning: [
      Color(0xFFB8A5D3),
      Color(0xFFE1C5E8),
      Color(0xFFFFE0A8),
    ],
    WeatherBackgroundState.cold: [
      Color(0xFFC9E8F4),
      Color(0xFFE4F2FA),
      Color(0xFFD7DDF7),
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
        Color.lerp(const Color(0xFF292735), colors[i], i == 1 ? .22 : .28)!,
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
  final bool dark, alternate;
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
  final WeatherBackgroundState left, right;
  final bool dark, alternate;

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
    final w = size.width, h = size.height;
    final unit = math.min(w / 150, h / 180).clamp(.5, 1.5);
    final palette = WeatherBackgroundDesign.palettes[state]!;
    if (!dark) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            colors: [
              palette.first.withValues(alpha: .35),
              palette.last.withValues(alpha: .2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Offset.zero & size),
      );
    }
    final cloud = Paint()
      ..isAntiAlias = true
      ..color = (dark ? Colors.white : const Color(0xFFFFFFFF)).withValues(
        alpha: dark ? .26 : .64,
      );
    final center = Offset(w * .22, h * .16 + (alternate ? 3 * unit : 0));
    switch (state) {
      case WeatherBackgroundState.sunny:
        final sun = Paint()
          ..isAntiAlias = true
          ..color = const Color(0xFFF4BA52).withValues(alpha: .68);
        canvas.drawCircle(center, 16 * unit, sun);
        final ray = Paint()
          ..color = const Color(0xFFE3A239).withValues(alpha: .52)
          ..strokeWidth = 2 * unit
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 10; i++) {
          final angle = i * math.pi / 5 + (alternate ? .12 : 0);
          final direction = Offset(math.cos(angle), math.sin(angle));
          canvas.drawLine(
            center + direction * (22 * unit),
            center + direction * (29 * unit),
            ray,
          );
        }
      case WeatherBackgroundState.cloudy:
        _cloud(canvas, center.translate(6 * unit, 0), unit, cloud);
        _cloud(canvas, Offset(w * .83, h * .83), unit * .72, cloud);
      case WeatherBackgroundState.rain:
      case WeatherBackgroundState.lightning:
        _cloud(canvas, center.translate(6 * unit, 0), unit, cloud);
        final rain = Paint()
          ..color = const Color(0xFF4D8BB8).withValues(alpha: dark ? .48 : .46)
          ..strokeWidth = 1.8 * unit
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 12; i++) {
          final x = w * (.1 + i % 4 * .25);
          final y = h * (.34 + i ~/ 4 * .23) + (alternate ? 7 * unit : 0);
          canvas.drawLine(
            Offset(x, y),
            Offset(x - 4 * unit, y + 11 * unit),
            rain,
          );
        }
        if (state == WeatherBackgroundState.lightning) {
          final x = w * .82, y = h * .21;
          final bolt = Path()
            ..moveTo(x, y)
            ..lineTo(x - 10 * unit, y + 20 * unit)
            ..lineTo(x + 1 * unit, y + 17 * unit)
            ..lineTo(x - 7 * unit, y + 38 * unit);
          canvas.drawPath(
            bolt,
            Paint()
              ..color = const Color(
                0xFFDFA137,
              ).withValues(alpha: alternate ? .9 : .75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * unit
              ..strokeJoin = StrokeJoin.round,
          );
        }
      case WeatherBackgroundState.cold:
        final snow = Paint()
          ..color = const Color(0xFF579BBF).withValues(alpha: dark ? .6 : .52)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * unit
          ..strokeCap = StrokeCap.round;
        for (final point in [
          center,
          Offset(w * .84, h * .28),
          Offset(w * .15, h * .81),
          Offset(w * .83, h * .84),
        ]) {
          for (var i = 0; i < 3; i++) {
            final angle = i * math.pi / 3;
            final arm = Offset(math.cos(angle), math.sin(angle)) * (7 * unit);
            canvas.drawLine(point - arm, point + arm, snow);
          }
        }
      case WeatherBackgroundState.unknown:
        break;
    }
  }

  void _cloud(Canvas canvas, Offset center, double u, Paint paint) {
    canvas.drawCircle(center.translate(-14 * u, 4 * u), 12 * u, paint);
    canvas.drawCircle(center.translate(0, -3 * u), 16 * u, paint);
    canvas.drawCircle(center.translate(15 * u, 5 * u), 11 * u, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, 8 * u),
          width: 48 * u,
          height: 16 * u,
        ),
        Radius.circular(8 * u),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(WeatherPremiumPainter old) =>
      old.left != left ||
      old.right != right ||
      old.dark != dark ||
      old.alternate != alternate;
}
