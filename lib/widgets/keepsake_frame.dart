import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bảng màu dùng chung để bản xem trước và vòng thật không bị lệch tông.
class KeepsakePalette {
  const KeepsakePalette(this.accent, this.secondary, this.paper);

  final Color accent;
  final Color secondary;
  final Color paper;

  static const newStyleKeys = ['ribbon_garden', 'moon_pearl', 'botanical'];
  static const refreshedRingKeys = [
    ...newStyleKeys,
    'glass',
    'glow',
    'candy',
    'floating_hearts',
  ];

  static KeepsakePalette of(String key) => switch (key) {
    'botanical' || 'aurora' => const KeepsakePalette(
      Color(0xFF397F72),
      Color(0xFFD5B777),
      Color(0xFFF1F8F0),
    ),
    'moon_pearl' || 'galaxy' || 'meteor_shower' => const KeepsakePalette(
      Color(0xFF75639A),
      Color(0xFFE5C681),
      Color(0xFFF6F2FD),
    ),
    'glass' || 'crystal' || 'deep_ocean' => const KeepsakePalette(
      Color(0xFF4387A2),
      Color(0xFFAACCCD),
      Color(0xFFF0F9FC),
    ),
    'pearl' || 'vip' || 'golden_sunset' => const KeepsakePalette(
      Color(0xFFAB8142),
      Color(0xFFE4BE99),
      Color(0xFFFFF9EB),
    ),
    'fireworks' || 'lava' || 'glow' => const KeepsakePalette(
      Color(0xFFBB644F),
      Color(0xFFF1B984),
      Color(0xFFFFF3EB),
    ),
    'squircle' || 'candy' => const KeepsakePalette(
      Color(0xFFA465A0),
      Color(0xFFA3CFC9),
      Color(0xFFFAF2FC),
    ),
    _ => const KeepsakePalette(
      Color(0xFFB74F72),
      Color(0xFFE3B59A),
      Color(0xFFFFF3F3),
    ),
  };

  Gradient get rim => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, secondary, paper, accent.withValues(alpha: .65)],
    stops: const [0, .35, .67, 1],
  );

  Gradient get fill => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [const Color(0xFFFFFEFA), paper],
  );
}

/// Charm vẽ bằng vector, không tải GIF và không che phần mặt/số ở giữa.
/// Chỉ repaint lớp trang trí, không rebuild ảnh hoặc nội dung vòng mỗi frame.
class KeepsakeOrnaments extends StatefulWidget {
  const KeepsakeOrnaments({
    super.key,
    required this.styleKey,
    this.animate = true,
    this.avatar = false,
    this.roundness = .5,
  });

  final String styleKey;
  final bool animate;
  final bool avatar;
  final double roundness;

  @override
  State<KeepsakeOrnaments> createState() => _KeepsakeOrnamentsState();
}

class _KeepsakeOrnamentsState extends State<KeepsakeOrnaments>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(KeepsakeOrnaments oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final enabled =
        widget.animate &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (enabled && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!enabled) {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: KeepsakeOrnamentPainter(
            styleKey: widget.styleKey,
            phase: _motion,
            avatar: widget.avatar,
            roundness: widget.roundness,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class KeepsakeOrnamentPainter extends CustomPainter {
  KeepsakeOrnamentPainter({
    required this.styleKey,
    required this.phase,
    this.avatar = false,
    this.roundness = .5,
  }) : super(repaint: phase);

  final String styleKey;
  final Animation<double> phase;
  final bool avatar;
  final double roundness;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || styleKey == 'off') return;
    final side = math.min(size.width, size.height);
    final palette = KeepsakePalette.of(styleKey);
    final center = size.center(Offset.zero);
    final radius = side * (avatar ? .455 : .438);
    final contour = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 2,
          ),
          Radius.circular(side * roundness),
        ),
      );
    final metric = contour.computeMetrics().first;
    Offset point(double fraction) =>
        metric.getTangentForOffset(metric.length * (fraction % 1))!.position;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (side * .003).clamp(.7, 1.5)
      ..color = palette.accent.withValues(alpha: .22);
    canvas.drawPath(contour, line);
    // Chừa vùng giữa; các hạt và charm chỉ chạy trên viền đã tính sẵn.
    for (var i = 0; i < 32; i++) {
      final p = point(i / 32);
      canvas.drawCircle(
        p,
        side * (i.isEven ? .006 : .003),
        Paint()..color = i.isEven ? Colors.white : palette.secondary,
      );
    }
    final t = phase.value * math.pi * 2;
    final glint = point(.12 + phase.value);
    _spark(canvas, glint, side * .015, palette.secondary);

    final floral = styleKey == 'botanical' || styleKey == 'cherry_blossom';
    final lunar = [
      'moon_pearl',
      'galaxy',
      'meteor_shower',
      'squircle',
    ].contains(styleKey);
    final glass = ['glass', 'crystal', 'deep_ocean'].contains(styleKey);
    final golden = ['pearl', 'vip', 'golden_sunset'].contains(styleKey);
    // Hai cụm đối xứng lệch góc, không rải sticker ngẫu nhiên lên nội dung.
    final locations = [point(.12), point(.62)];
    for (var i = 0; i < locations.length; i++) {
      canvas.save();
      canvas.translate(locations[i].dx, locations[i].dy);
      canvas.rotate((i == 0 ? -.18 : .18) + math.sin(t + i * math.pi) * .055);
      final s = side * (avatar ? .115 : .078);
      if (floral) {
        _flower(canvas, s, palette);
      } else if (lunar && i == 0) {
        _moon(canvas, s, palette);
      } else if (lunar || glass) {
        _gem(canvas, s * .85, palette);
      } else if (golden) {
        _pearl(canvas, s, palette);
      } else if (i == 0) {
        _bow(canvas, s, palette);
      } else {
        _heart(canvas, s * .85, palette);
      }
      canvas.restore();
    }
  }

  void _shape(Canvas c, Path path, Color fill, Color outline, double width) {
    c.drawShadow(path, outline.withValues(alpha: .18), 2, false);
    c.drawPath(path, Paint()..color = fill);
    c.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2.6
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _bow(Canvas c, double s, KeepsakePalette p) {
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(-s * 1.5, -s * 1.3, -s * 1.4, s, 0, s * .22)
      ..cubicTo(s * 1.4, s, s * 1.5, -s * 1.3, 0, 0)
      ..close();
    final tails = Path()
      ..moveTo(-s * .12, 0)
      ..lineTo(-s * .65, s * 1.05)
      ..lineTo(-s * .2, s * .84)
      ..lineTo(0, s * 1.12)
      ..lineTo(s * .18, s * .3)
      ..lineTo(s * .5, s * 1.02)
      ..lineTo(s * .73, s * .79)
      ..close();
    _shape(c, tails, p.paper, p.accent, s * .045);
    _shape(c, path, Color.lerp(p.paper, p.accent, .20)!, p.accent, s * .045);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * .42, height: s * .48),
        Radius.circular(s * .15),
      ),
      Paint()..color = p.accent,
    );
  }

  void _flower(Canvas c, double s, KeepsakePalette p) {
    for (var i = 0; i < 3; i++) {
      c.save();
      c.rotate(i * math.pi * 2 / 3 + .2);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(s * 1.6, -s, s * 1.35, s * .12)
        ..quadraticBezierTo(s * .6, s * .65, 0, 0);
      _shape(
        c,
        leaf,
        const Color(0xFFD6E8D7),
        const Color(0xFF729882),
        s * .025,
      );
      c.restore();
    }
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      final petal = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(math.cos(a), math.sin(a)) * s * .42,
            radius: s * .43,
          ),
        );
      _shape(c, petal, const Color(0xFFFFF4E9), p.secondary, s * .025);
    }
    c.drawCircle(
      Offset.zero,
      s * .22,
      Paint()..color = const Color(0xFFE7BA66),
    );
  }

  void _moon(Canvas c, double s, KeepsakePalette p) {
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: s)),
      Path()..addOval(
        Rect.fromCircle(center: Offset(s * .5, -s * .3), radius: s * .88),
      ),
    );
    _shape(c, moon, const Color(0xFFFFE5A6), p.secondary, s * .035);
    _spark(c, Offset(s * .6, s * .3), s * .42, p.accent);
  }

  void _gem(Canvas c, double s, KeepsakePalette p) {
    final diamond = Path()
      ..moveTo(0, -s)
      ..lineTo(s * .8, 0)
      ..lineTo(0, s)
      ..lineTo(-s * .8, 0)
      ..close();
    _shape(c, diamond, p.paper, p.accent, s * .05);
    c.drawLine(
      Offset(0, -s * .65),
      Offset(0, s * .65),
      Paint()
        ..color = p.secondary
        ..strokeWidth = s * .08,
    );
    _spark(c, Offset(s * .72, -s * .7), s * .3, p.secondary);
  }

  void _pearl(Canvas c, double s, KeepsakePalette p) {
    for (var i = 0; i < 3; i++) {
      final pos = Offset((i - 1) * s * .65, i == 1 ? 0 : s * .25);
      final rect = Rect.fromCircle(center: pos, radius: s * .46);
      c.drawCircle(pos, s * .49, Paint()..color = p.secondary);
      c.drawCircle(
        pos,
        s * .43,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.4, -.4),
            colors: [Colors.white, Color(0xFFE6D6C6)],
          ).createShader(rect),
      );
    }
    _spark(c, Offset(s * .6, -s * .6), s * .35, p.accent);
  }

  void _heart(Canvas c, double s, KeepsakePalette p) {
    final heart = Path()
      ..moveTo(0, s * .85)
      ..cubicTo(-s * 1.8, -s * .35, -s * .6, -s * 1.3, 0, -s * .45)
      ..cubicTo(s * .6, -s * 1.3, s * 1.8, -s * .35, 0, s * .85)
      ..close();
    _shape(c, heart, Color.lerp(p.paper, p.accent, .22)!, p.accent, s * .045);
    c.drawCircle(
      Offset(-s * .32, -s * .3),
      s * .13,
      Paint()..color = Colors.white,
    );
  }

  void _spark(Canvas c, Offset p, double s, Color color) {
    final star = Path()
      ..moveTo(p.dx, p.dy - s)
      ..quadraticBezierTo(p.dx + s * .15, p.dy - s * .15, p.dx + s, p.dy)
      ..quadraticBezierTo(p.dx + s * .15, p.dy + s * .15, p.dx, p.dy + s)
      ..quadraticBezierTo(p.dx - s * .15, p.dy + s * .15, p.dx - s, p.dy)
      ..quadraticBezierTo(p.dx - s * .15, p.dy - s * .15, p.dx, p.dy - s);
    c.drawPath(star, Paint()..color = color);
  }

  @override
  bool shouldRepaint(KeepsakeOrnamentPainter oldDelegate) =>
      oldDelegate.styleKey != styleKey ||
      oldDelegate.phase != phase ||
      oldDelegate.avatar != avatar ||
      oldDelegate.roundness != roundness;
}

/// Thẻ có kích thước ổn định khi chọn, hỗ trợ nhãn dài và cỡ chữ lớn.
class KeepsakeChoiceCard extends StatelessWidget {
  const KeepsakeChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
    this.lockLabel,
  });

  final String label;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;
  final String? lockLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: lockLabel == null ? label : '$label, $lockLabel',
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      color: selected ? const Color(0xFFFFF0F2) : const Color(0xFFFFFEFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: selected ? const Color(0xFFB74F72) : const Color(0xFFEADFD9),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    preview,
                    if (selected)
                      const PositionedDirectional(
                        end: 0,
                        top: 0,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: Color(0xFFB74F72),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF493D40),
                  height: 1.3,
                ),
              ),
              if (lockLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  lockLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF816267),
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class KeepsakeChoiceGrid extends StatelessWidget {
  const KeepsakeChoiceGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minWidth = MediaQuery.textScalerOf(
        context,
      ).scale(110).clamp(120.0, 220.0);
      final columns = ((constraints.maxWidth + 10) / (minWidth + 10))
          .floor()
          .clamp(1, 4);
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class KeepsakeRingPreview extends StatelessWidget {
  const KeepsakeRingPreview({super.key, required this.styleKey});
  final String styleKey;

  @override
  Widget build(BuildContext context) {
    final p = KeepsakePalette.of(styleKey);
    return SizedBox.square(
      dimension: 88,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.rim),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.fill),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.favorite_rounded, size: 24, color: p.accent),
                Positioned.fill(
                  child: KeepsakeOrnaments(styleKey: styleKey, animate: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
