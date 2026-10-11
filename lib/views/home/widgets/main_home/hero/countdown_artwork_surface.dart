import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

part 'countdown_artwork_painter.dart';

/// Mỗi phong cách có silhouette, vùng chữ, bảng màu và nhịp chuyển động riêng.
/// Home và các bản xem trước cùng dùng catalog này, không dựng mẫu giả bằng icon.
class CountdownArtworkDesign {
  const CountdownArtworkDesign({
    required this.key,
    required this.ink,
    required this.accent,
    required this.paper,
    required this.wash,
    required this.contentRect,
    this.period = const Duration(seconds: 8),
    this.night = false,
  });

  final String key;
  final Color ink;
  final Color accent;
  final Color paper;
  final Color wash;
  final Rect contentRect;
  final Duration period;
  final bool night;

  static const styleKeys = <String>[
    'ribbon_garden',
    'moon_pearl',
    'botanical',
    'default',
    'floating_hearts',
    'glass',
    'glow',
    'candy',
    'galaxy',
    'aurora',
    'crystal',
    'fireworks',
    'lava',
    'cherry_blossom',
    'meteor_shower',
    'deep_ocean',
    'golden_sunset',
    'neon_pulse',
  ];

  List<Color> get numberColors => night
      ? [paper, Color.lerp(paper, accent, .24)!]
      : [ink, Color.lerp(ink, accent, .24)!];
  Color get labelColor => night ? paper.withValues(alpha: .88) : ink;

  static CountdownArtworkDesign of(String styleKey) {
    final key = switch (styleKey.trim().toLowerCase()) {
      'balanced' || 'plain' || 'rose_wave' || '' => 'default',
      'hyper' => 'neon_pulse',
      'vip' || 'pearl' => 'golden_sunset',
      _ => styleKey.trim().toLowerCase(),
    };
    return switch (key) {
      'ribbon_garden' => const CountdownArtworkDesign(
        key: 'ribbon_garden',
        ink: Color(0xFF984260),
        accent: Color(0xFFE993AC),
        paper: Color(0xFFFFFBF3),
        wash: Color(0xFFF8D9E1),
        contentRect: Rect.fromLTWH(.17, .26, .66, .59),
        period: Duration(seconds: 9),
      ),
      'moon_pearl' => const CountdownArtworkDesign(
        key: 'moon_pearl',
        ink: Color(0xFF695188),
        accent: Color(0xFFBCABE5),
        paper: Color(0xFFFFFAEB),
        wash: Color(0xFFEDE5FA),
        contentRect: Rect.fromLTWH(.27, .27, .62, .57),
        period: Duration(seconds: 12),
      ),
      'botanical' => const CountdownArtworkDesign(
        key: 'botanical',
        ink: Color(0xFF276A52),
        accent: Color(0xFF82B599),
        paper: Color(0xFFF6FAE8),
        wash: Color(0xFFD7EAC4),
        contentRect: Rect.fromLTWH(.18, .16, .65, .65),
        period: Duration(seconds: 10),
      ),
      'floating_hearts' => const CountdownArtworkDesign(
        key: 'floating_hearts',
        ink: Color(0xFFA23C66),
        accent: Color(0xFFEE9BBB),
        paper: Color(0xFFFFF6F9),
        wash: Color(0xFFF9D2E2),
        contentRect: Rect.fromLTWH(.18, .13, .64, .63),
        period: Duration(seconds: 11),
      ),
      'glass' => const CountdownArtworkDesign(
        key: 'glass',
        ink: Color(0xFF396C8D),
        accent: Color(0xFF9CD8E7),
        paper: Color(0xFFF5FDFF),
        wash: Color(0xFFCCE7F1),
        contentRect: Rect.fromLTWH(.18, .21, .64, .64),
        period: Duration(seconds: 13),
      ),
      'glow' => const CountdownArtworkDesign(
        key: 'glow',
        ink: Color(0xFFAE6941),
        accent: Color(0xFFFFCF86),
        paper: Color(0xFFFFFEEC),
        wash: Color(0xFFFFE8BA),
        contentRect: Rect.fromLTWH(.19, .19, .62, .62),
        period: Duration(seconds: 6),
      ),
      'candy' => const CountdownArtworkDesign(
        key: 'candy',
        ink: Color(0xFFA44C78),
        accent: Color(0xFF75C4C9),
        paper: Color(0xFFFFFBF2),
        wash: Color(0xFFFFD3E4),
        contentRect: Rect.fromLTWH(.11, .10, .67, .64),
        period: Duration(seconds: 7),
      ),
      'galaxy' => const CountdownArtworkDesign(
        key: 'galaxy',
        ink: Color(0xFF584381),
        accent: Color(0xFFBFA6EB),
        paper: Color(0xFFFEF8FF),
        wash: Color(0xFFE1D2F5),
        contentRect: Rect.fromLTWH(.20, .15, .62, .60),
        period: Duration(seconds: 16),
      ),
      'aurora' => const CountdownArtworkDesign(
        key: 'aurora',
        ink: Color(0xFF246861),
        accent: Color(0xFF91CABB),
        paper: Color(0xFFF1FFF6),
        wash: Color(0xFFD0F1E5),
        contentRect: Rect.fromLTWH(.17, .20, .66, .66),
        period: Duration(seconds: 14),
      ),
      'crystal' => const CountdownArtworkDesign(
        key: 'crystal',
        ink: Color(0xFF536EAC),
        accent: Color(0xFFB3C8EE),
        paper: Color(0xFFFCFAFF),
        wash: Color(0xFFE0E5FC),
        contentRect: Rect.fromLTWH(.18, .17, .64, .64),
        period: Duration(seconds: 12),
      ),
      'fireworks' => const CountdownArtworkDesign(
        key: 'fireworks',
        ink: Color(0xFFAB564B),
        accent: Color(0xFFEAC184),
        paper: Color(0xFFFFFCF0),
        wash: Color(0xFFFBE1C7),
        contentRect: Rect.fromLTWH(.17, .17, .66, .66),
        period: Duration(seconds: 5),
      ),
      'lava' => const CountdownArtworkDesign(
        key: 'lava',
        ink: Color(0xFF9B4D3C),
        accent: Color(0xFFE89463),
        paper: Color(0xFFFFF8EB),
        wash: Color(0xFFFAD7BC),
        contentRect: Rect.fromLTWH(.16, .18, .67, .65),
        period: Duration(seconds: 9),
      ),
      'cherry_blossom' => const CountdownArtworkDesign(
        key: 'cherry_blossom',
        ink: Color(0xFF9C526E),
        accent: Color(0xFFECA9BD),
        paper: Color(0xFFFFF7F2),
        wash: Color(0xFFFFDDE4),
        contentRect: Rect.fromLTWH(.19, .20, .62, .62),
        period: Duration(seconds: 10),
      ),
      'meteor_shower' => const CountdownArtworkDesign(
        key: 'meteor_shower',
        ink: Color(0xFF363967),
        accent: Color(0xFF8FBADB),
        paper: Color(0xFFF2F4FF),
        wash: Color(0xFFDDDFFA),
        contentRect: Rect.fromLTWH(.26, .13, .64, .67),
        period: Duration(seconds: 7),
      ),
      'deep_ocean' => const CountdownArtworkDesign(
        key: 'deep_ocean',
        ink: Color(0xFF337D88),
        accent: Color(0xFF97D1CD),
        paper: Color(0xFFF3FFFA),
        wash: Color(0xFFCFECE9),
        contentRect: Rect.fromLTWH(.18, .23, .64, .64),
        period: Duration(seconds: 11),
      ),
      'golden_sunset' => const CountdownArtworkDesign(
        key: 'golden_sunset',
        ink: Color(0xFFA05C45),
        accent: Color(0xFFE7B37C),
        paper: Color(0xFFFFF9E9),
        wash: Color(0xFFFFE1BD),
        contentRect: Rect.fromLTWH(.16, .18, .68, .66),
        period: Duration(seconds: 15),
      ),
      'neon_pulse' => const CountdownArtworkDesign(
        key: 'neon_pulse',
        ink: Color(0xFF433750),
        accent: Color(0xFF93DED9),
        paper: Color(0xFFFFF1FE),
        wash: Color(0xFF302939),
        contentRect: Rect.fromLTWH(.15, .17, .70, .66),
        period: Duration(seconds: 4),
        night: true,
      ),
      'default' => const CountdownArtworkDesign(
        key: 'default',
        ink: Color(0xFF9C4E68),
        accent: Color(0xFFDCA9B8),
        paper: Color(0xFFFFFBF6),
        wash: Color(0xFFF7E2E8),
        contentRect: Rect.fromLTWH(.18, .18, .64, .64),
        period: Duration(seconds: 9),
      ),
      _ => of('default'),
    };
  }
}

/// Lớp chữ không rebuild theo animation: chỉ lớp sticker/hiệu ứng repaint.
class CountdownArtworkSurface extends StatefulWidget {
  const CountdownArtworkSurface({
    super.key,
    required this.styleKey,
    this.child,
    this.enableMotion = false,
    this.transparent = false,
    this.progress,
    this.minimumContentExtent = 0,
    this.isActiveListenable,
  });

  final String styleKey;
  final Widget? child;
  final bool enableMotion;
  final bool transparent;
  final double? progress;
  final double minimumContentExtent;
  final ValueListenable<bool>? isActiveListenable;

  static ShapeBorder shapeFor(String key) =>
      _CountdownArtworkBorder(CountdownArtworkDesign.of(key));

  @override
  State<CountdownArtworkSurface> createState() =>
      _CountdownArtworkSurfaceState();
}

class _CountdownArtworkSurfaceState extends State<CountdownArtworkSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: CountdownArtworkDesign.of(widget.styleKey).period,
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    widget.isActiveListenable?.addListener(_syncMotion);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(CountdownArtworkSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveListenable != widget.isActiveListenable) {
      oldWidget.isActiveListenable?.removeListener(_syncMotion);
      widget.isActiveListenable?.addListener(_syncMotion);
    }
    if (oldWidget.styleKey != widget.styleKey) {
      _motion.stop();
      _motion.value = 0;
      _motion.duration = CountdownArtworkDesign.of(widget.styleKey).period;
    }
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!mounted) return;
    final enabled =
        widget.enableMotion &&
        _foreground &&
        (widget.isActiveListenable?.value ?? true) &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (enabled && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!enabled) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    widget.isActiveListenable?.removeListener(_syncMotion);
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = CountdownArtworkDesign.of(widget.styleKey);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = math.min(constraints.maxWidth, constraints.maxHeight);
        if (!extent.isFinite || extent <= 0) return const SizedBox.shrink();
        final r = design.contentRect;
        final minFace = math.min(widget.minimumContentExtent, extent * .84);
        final faceWidth = math.max(r.width * extent, minFace);
        final faceHeight = math.max(r.height * extent, minFace);
        final face = Rect.fromCenter(
          center: Offset(r.center.dx * extent, r.center.dy * extent),
          width: faceWidth,
          height: faceHeight,
        );
        return Center(
          child: SizedBox.square(
            dimension: extent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: CountdownArtworkPainter(
                            design: design,
                            dark: dark,
                            transparent: widget.transparent,
                            progress: widget.progress,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.child != null)
                  Positioned.fromRect(rect: face, child: widget.child!),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: CountdownArtworkPainter(
                            design: design,
                            phase: _motion,
                            ornaments: true,
                            dark: dark,
                            transparent: widget.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountdownArtworkBorder extends ShapeBorder {
  const _CountdownArtworkBorder(this.design);
  final CountdownArtworkDesign design;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      CountdownArtworkPainter.silhouette(design.key).transform(
        Matrix4.identity().storage
          ..[0] = rect.width
          ..[5] = rect.height
          ..[12] = rect.left
          ..[13] = rect.top,
      );
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
  @override
  ShapeBorder scale(double t) => this;
}
