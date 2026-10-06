import 'dart:math' as math;

import 'package:flutter/material.dart';

class CoupleDefaultAvatar extends StatefulWidget {
  const CoupleDefaultAvatar({
    super.key,
    this.female = false,
    this.animate = true,
  });

  static const maleAsset =
      'assets/images/widget_stickers/couple_avatar_male_v1.webp';
  static const femaleAsset =
      'assets/images/widget_stickers/couple_avatar_female_v1.webp';

  final bool female;
  final bool animate;

  @override
  State<CoupleDefaultAvatar> createState() => _CoupleDefaultAvatarState();
}

class _CoupleDefaultAvatarState extends State<CoupleDefaultAvatar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _foreground = true;
  bool _motionEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CoupleDefaultAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _syncAnimation();
    });
  }

  void _syncAnimation() {
    _motionEnabled =
        widget.animate &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_motionEnabled) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final heartColor = dark ? const Color(0xFFF7A6B8) : const Color(0xFFE77F9A);
    final background = widget.female
        ? (dark ? const Color(0xFF392B34) : const Color(0xFFFFEAF0))
        : (dark ? const Color(0xFF293831) : const Color(0xFFEAF3EC));
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : 88.0;
              final height = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : width;
              final dimension = math.min(width, height);
              return SizedBox.square(
                dimension: dimension,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        dark
                            ? const Color(0xFF292C32)
                            : const Color(0xFFFFFCF6),
                        background,
                      ],
                    ),
                  ),
                  child: AnimatedBuilder(
                    animation: _controller,
                    child: Padding(
                      padding: EdgeInsets.all(dimension * 0.055),
                      child: Image.asset(
                        widget.female
                            ? CoupleDefaultAvatar.femaleAsset
                            : CoupleDefaultAvatar.maleAsset,
                        fit: BoxFit.contain,
                        cacheWidth: 384,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.favorite_rounded,
                          size: dimension * 0.36,
                          color: heartColor,
                        ),
                      ),
                    ),
                    builder: (context, child) {
                      final wave = math.sin(_controller.value * math.pi * 2);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.translate(
                            offset: Offset(0, wave * dimension * -0.012),
                            child: Transform.rotate(
                              angle: wave * (widget.female ? -0.014 : 0.014),
                              child: child,
                            ),
                          ),
                          CustomPaint(
                            painter: _AvatarHeartsPainter(
                              phase: _controller.value,
                              enabled: _motionEnabled,
                              color: heartColor,
                              female: widget.female,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AvatarHeartsPainter extends CustomPainter {
  const _AvatarHeartsPainter({
    required this.phase,
    required this.enabled,
    required this.color,
    required this.female,
  });

  final double phase;
  final bool enabled;
  final Color color;
  final bool female;

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled || size.isEmpty) return;
    for (var index = 0; index < 4; index++) {
      final progress = (phase - index * 0.13) / 0.52;
      if (progress <= 0 || progress >= 1) continue;
      final direction = (index.isEven != female) ? -1.0 : 1.0;
      final travel = Curves.easeOutCubic.transform(progress);
      final opacity = math.sin(progress * math.pi) * 0.88;
      final center = Offset(
        size.width * (0.5 + direction * (0.08 + 0.30 * travel)),
        size.height * (0.67 - 0.48 * progress),
      );
      final radius = size.shortestSide * (0.038 + index * 0.003);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(direction * progress * 0.25);
      canvas.scale(radius * (0.65 + travel * 0.45));
      final heart = Path()
        ..moveTo(0, 0.92)
        ..cubicTo(-0.3, 0.6, -1.0, 0.16, -1.0, -0.36)
        ..cubicTo(-1.0, -1.02, -0.25, -1.12, 0, -0.54)
        ..cubicTo(0.25, -1.12, 1.0, -1.02, 1.0, -0.36)
        ..cubicTo(1.0, 0.16, 0.3, 0.6, 0, 0.92)
        ..close();
      canvas.drawPath(heart, Paint()..color = color.withValues(alpha: opacity));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarHeartsPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.enabled != enabled ||
      oldDelegate.color != color ||
      oldDelegate.female != female;
}
