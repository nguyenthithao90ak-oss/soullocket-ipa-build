part of '../../../tabs/main_home_tab.dart';

/// Lớp trang trí nhẹ dành riêng cho từng kiểu vòng đếm. Kiểu cân bằng không
/// đi qua widget này để giữ nguyên giao diện và hiệu năng cũ.
class _CountdownThemeStickerOverlay extends StatelessWidget {
  final String styleKey;
  final bool enableMotion;

  const _CountdownThemeStickerOverlay({
    required this.styleKey,
    required this.enableMotion,
  });

  static const Map<String, List<_CountdownStickerPlacement>> _placements = {
    'floating_hearts': [
      _CountdownStickerPlacement(
        id: 'heart_locket',
        alignment: Alignment(-0.73, -0.55),
        sizeFactor: 0.17,
        angle: -0.10,
      ),
      _CountdownStickerPlacement(
        id: 'heart_plush',
        alignment: Alignment(0.73, -0.48),
        sizeFactor: 0.15,
        angle: 0.09,
      ),
      _CountdownStickerPlacement(
        id: 'heart_letter',
        alignment: Alignment(-0.66, 0.66),
        sizeFactor: 0.13,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'heart_celebrate',
        alignment: Alignment(0.69, 0.65),
        sizeFactor: 0.13,
        angle: 0.08,
      ),
    ],
    'glass': [
      _CountdownStickerPlacement(
        id: 'heart_glass',
        alignment: Alignment(-0.70, -0.55),
        sizeFactor: 0.15,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'novelty_raindrop_comfort',
        alignment: Alignment(0.70, 0.57),
        sizeFactor: 0.13,
        angle: 0.08,
      ),
    ],
    'glow': [
      _CountdownStickerPlacement(
        id: 'heart_heartbeat',
        alignment: Alignment(-0.71, -0.50),
        sizeFactor: 0.15,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'heart_healing',
        alignment: Alignment(0.70, 0.61),
        sizeFactor: 0.13,
        angle: 0.08,
      ),
    ],
    'candy': [
      _CountdownStickerPlacement(
        id: 'novelty_star_love',
        alignment: Alignment(-0.72, -0.52),
        sizeFactor: 0.15,
        angle: -0.10,
      ),
      _CountdownStickerPlacement(
        id: 'novelty_robot_laugh',
        alignment: Alignment(0.70, 0.61),
        sizeFactor: 0.14,
        angle: 0.08,
      ),
    ],
    'galaxy': [
      _CountdownStickerPlacement(
        id: 'novelty_planet_crush',
        alignment: Alignment(-0.69, -0.52),
        sizeFactor: 0.16,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'novelty_moon_kiss',
        alignment: Alignment(0.70, 0.60),
        sizeFactor: 0.14,
        angle: 0.08,
      ),
    ],
    'aurora': [
      _CountdownStickerPlacement(
        id: 'novelty_cloud_hug',
        alignment: Alignment(-0.71, -0.52),
        sizeFactor: 0.15,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'heart_glass',
        alignment: Alignment(0.70, 0.60),
        sizeFactor: 0.13,
        angle: 0.08,
      ),
    ],
    'crystal': [
      _CountdownStickerPlacement(
        id: 'heart_glass',
        alignment: Alignment(-0.70, -0.55),
        sizeFactor: 0.15,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'novelty_star_love',
        alignment: Alignment(0.70, 0.60),
        sizeFactor: 0.13,
        angle: 0.08,
      ),
    ],
    'fireworks': [
      _CountdownStickerPlacement(
        id: 'motion_celebrate',
        alignment: Alignment(-0.70, -0.52),
        sizeFactor: 0.16,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'novelty_game_party',
        alignment: Alignment(0.70, 0.60),
        sizeFactor: 0.14,
        angle: 0.08,
      ),
    ],
    'lava': [
      _CountdownStickerPlacement(
        id: 'heart_heartbeat',
        alignment: Alignment(-0.70, -0.52),
        sizeFactor: 0.15,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'motion_dance',
        alignment: Alignment(0.69, 0.61),
        sizeFactor: 0.14,
        angle: 0.08,
      ),
    ],
    'cherry_blossom': [
      _CountdownStickerPlacement(
        id: 'heart_letter',
        alignment: Alignment(-0.70, -0.52),
        sizeFactor: 0.15,
        angle: -0.09,
      ),
      _CountdownStickerPlacement(
        id: 'novelty_cloud_hug',
        alignment: Alignment(0.70, 0.61),
        sizeFactor: 0.14,
        angle: 0.08,
      ),
    ],
    'meteor_shower': [
      _CountdownStickerPlacement(
        id: 'novelty_love_plane',
        alignment: Alignment(-0.69, -0.54),
        sizeFactor: 0.16,
        angle: -0.09,
      ),
      _CountdownStickerPlacement(
        id: 'novelty_star_love',
        alignment: Alignment(0.70, 0.61),
        sizeFactor: 0.13,
        angle: 0.08,
      ),
    ],
    'deep_ocean': [
      _CountdownStickerPlacement(
        id: 'novelty_raindrop_comfort',
        alignment: Alignment(-0.70, -0.54),
        sizeFactor: 0.15,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'heart_glass',
        alignment: Alignment(0.70, 0.60),
        sizeFactor: 0.13,
        angle: 0.08,
      ),
    ],
    'golden_sunset': [
      _CountdownStickerPlacement(
        id: 'novelty_coffee_date',
        alignment: Alignment(-0.70, -0.53),
        sizeFactor: 0.15,
        angle: -0.09,
      ),
      _CountdownStickerPlacement(
        id: 'heart_letter',
        alignment: Alignment(0.70, 0.61),
        sizeFactor: 0.13,
        angle: 0.08,
      ),
    ],
    'neon_pulse': [
      _CountdownStickerPlacement(
        id: 'novelty_music_mix',
        alignment: Alignment(-0.70, -0.52),
        sizeFactor: 0.16,
        angle: -0.08,
      ),
      _CountdownStickerPlacement(
        id: 'motion_dance',
        alignment: Alignment(0.70, 0.61),
        sizeFactor: 0.14,
        angle: 0.08,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final placements = _placements[styleKey];
    if (placements == null || placements.isEmpty) {
      return const SizedBox.shrink();
    }
    final animate =
        enableMotion &&
        !UiPrefs.notifier.value.liteMode &&
        !MediaQuery.disableAnimationsOf(context);

    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = min(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _CountdownThemeOrnamentPainter(styleKey)),
                for (final placement in placements)
                  Align(
                    alignment: placement.alignment,
                    child: Transform.rotate(
                      angle: placement.angle,
                      child: Opacity(
                        opacity: styleKey == 'floating_hearts' ? 0.96 : 0.88,
                        child: SoulLocketAnimatedSticker(
                          sticker: SoulLocketStickerCatalog.find(placement.id)!,
                          size: side * placement.sizeFactor,
                          animate: animate,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountdownStickerPlacement {
  final String id;
  final Alignment alignment;
  final double sizeFactor;
  final double angle;

  const _CountdownStickerPlacement({
    required this.id,
    required this.alignment,
    required this.sizeFactor,
    required this.angle,
  });
}

/// Họa tiết tĩnh tạo chiều sâu; chuyển động chính vẫn do painter nền đảm nhiệm.
class _CountdownThemeOrnamentPainter extends CustomPainter {
  final String styleKey;

  const _CountdownThemeOrnamentPainter(this.styleKey);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) * 0.43;
    final colors = _palette(styleKey);
    final ringPaint = Paint()
      ..color = colors.first.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = styleKey == 'floating_hearts' ? 2.2 : 1.35;

    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(
      center,
      radius * 0.92,
      Paint()
        ..color = colors.last.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (styleKey == 'floating_hearts' || styleKey == 'glow') {
      for (var index = 0; index < 10; index++) {
        final angle = (index / 10) * pi * 2 - pi / 2;
        final point = Offset(
          center.dx + cos(angle) * radius * 0.96,
          center.dy + sin(angle) * radius * 0.96,
        );
        _drawHeart(
          canvas,
          point,
          index.isEven ? 4.0 : 2.8,
          colors[index % colors.length].withValues(alpha: 0.30),
        );
      }
      return;
    }

    if (styleKey == 'deep_ocean' || styleKey == 'glass') {
      for (var index = 0; index < 8; index++) {
        final x = size.width * (0.13 + ((index * 0.19) % 0.74));
        final y = size.height * (0.16 + ((index * 0.27) % 0.68));
        final bubbleRadius = 2.5 + (index % 3) * 1.8;
        canvas.drawCircle(
          Offset(x, y),
          bubbleRadius,
          Paint()
            ..color = colors[index % colors.length].withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      return;
    }

    if (styleKey == 'candy' || styleKey == 'fireworks') {
      for (var index = 0; index < 12; index++) {
        final angle = (index / 12) * pi * 2;
        final point = Offset(
          center.dx + cos(angle) * radius * (index.isEven ? 0.82 : 0.97),
          center.dy + sin(angle) * radius * (index.isEven ? 0.82 : 0.97),
        );
        _drawSparkle(
          canvas,
          point,
          index.isEven ? 4.4 : 3.0,
          colors[index % colors.length].withValues(alpha: 0.28),
        );
      }
      return;
    }

    if (styleKey == 'cherry_blossom') {
      for (var index = 0; index < 9; index++) {
        final angle = (index / 9) * pi * 2 + 0.18;
        final point = Offset(
          center.dx + cos(angle) * radius * 0.94,
          center.dy + sin(angle) * radius * 0.94,
        );
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate(angle);
        canvas.drawOval(
          const Rect.fromLTWH(-2, -5, 4, 9),
          Paint()
            ..color = colors[index % colors.length].withValues(alpha: 0.28),
        );
        canvas.restore();
      }
      return;
    }

    if (styleKey == 'lava' || styleKey == 'golden_sunset') {
      for (var index = 0; index < 16; index++) {
        final angle = (index / 16) * pi * 2;
        final start = Offset(
          center.dx + cos(angle) * radius * 0.86,
          center.dy + sin(angle) * radius * 0.86,
        );
        final end = Offset(
          center.dx + cos(angle) * radius * (index.isEven ? 0.98 : 0.93),
          center.dy + sin(angle) * radius * (index.isEven ? 0.98 : 0.93),
        );
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = colors[index % colors.length].withValues(alpha: 0.22)
            ..strokeWidth = index.isEven ? 1.8 : 1.1
            ..strokeCap = StrokeCap.round,
        );
      }
      return;
    }

    final points = <Offset>[
      Offset(size.width * 0.18, size.height * 0.30),
      Offset(size.width * 0.31, size.height * 0.17),
      Offset(size.width * 0.79, size.height * 0.25),
      Offset(size.width * 0.83, size.height * 0.67),
      Offset(size.width * 0.68, size.height * 0.81),
      Offset(size.width * 0.22, size.height * 0.73),
    ];
    final constellation = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      constellation.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      constellation,
      Paint()
        ..color = colors.first.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var index = 0; index < points.length; index++) {
      _drawSparkle(
        canvas,
        points[index],
        index.isEven ? 4.4 : 3.1,
        colors[index % colors.length].withValues(alpha: 0.28),
      );
    }
  }

  List<Color> _palette(String key) {
    return switch (key) {
      'floating_hearts' => const [
        Color(0xFFFF4F93),
        Color(0xFFFFB0CC),
        Color(0xFF9B5DE5),
        Color(0xFFFFD166),
      ],
      'glass' => const [Color(0xFF58C7F3), Color(0xFFFFFFFF)],
      'glow' => const [Color(0xFFFF2F7A), Color(0xFFFFB3D1)],
      'candy' => const [
        Color(0xFFFF4FA3),
        Color(0xFF36C9FF),
        Color(0xFFFFD54F),
      ],
      'aurora' => const [Color(0xFF00FFC8), Color(0xFF7C4DFF)],
      'crystal' => const [Color(0xFF7B61FF), Color(0xFF9BE7FF)],
      'fireworks' => const [Color(0xFFFFD54F), Color(0xFFFF4EBB)],
      'lava' => const [Color(0xFFFF5A00), Color(0xFFFFEA00)],
      'cherry_blossom' => const [Color(0xFFFF8FB1), Color(0xFFFFD8E5)],
      'deep_ocean' => const [Color(0xFF00D4FF), Color(0xFF52FFD5)],
      'golden_sunset' => const [Color(0xFFFFD166), Color(0xFFFF6B6B)],
      'neon_pulse' => const [Color(0xFFFF2E97), Color(0xFF00F5FF)],
      _ => const [Color(0xFFB388FF), Color(0xFF53D8FF)],
    };
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.62)
      ..cubicTo(
        center.dx - size,
        center.dy,
        center.dx - size * 0.55,
        center.dy - size * 0.82,
        center.dx,
        center.dy - size * 0.28,
      )
      ..cubicTo(
        center.dx + size * 0.55,
        center.dy - size * 0.82,
        center.dx + size,
        center.dy,
        center.dx,
        center.dy + size * 0.62,
      );
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.30, center.dy - size * 0.30)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx + size * 0.30, center.dy + size * 0.30)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size * 0.30, center.dy + size * 0.30)
      ..lineTo(center.dx - size, center.dy)
      ..lineTo(center.dx - size * 0.30, center.dy - size * 0.30)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CountdownThemeOrnamentPainter oldDelegate) {
    return oldDelegate.styleKey != styleKey;
  }
}
