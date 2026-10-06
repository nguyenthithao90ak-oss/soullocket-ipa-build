import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

/// Một trái tim duy nhất: ánh sáng chảy xuống, vẽ viền rồi sáng lên.
class SoulMergeTouchHeart extends StatefulWidget {
  const SoulMergeTouchHeart({
    super.key,
    this.pressed = false,
    this.partnerReady = false,
    this.connected = false,
    this.pulse = 0,
    this.style = 'basic',
  });

  final bool pressed;
  final bool partnerReady;
  final bool connected;
  final int pulse;
  final String style;

  @override
  State<SoulMergeTouchHeart> createState() => _SoulMergeTouchHeartState();
}

class _SoulMergeTouchHeartState extends State<SoulMergeTouchHeart>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flow;
  bool _foreground = true;
  bool _motion = false;
  bool _hasPlayed = false;

  bool get _lit => widget.pressed || widget.partnerReady || widget.connected;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    WidgetsBinding.instance.addObserver(this);
    UiPrefs.notifier.addListener(_onPrefsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    final profile = UiPrefs.resolveEffectProfile(
      state: UiPrefs.notifier.value,
      isWeb: kIsWeb,
      pauseAnimations:
          !_foreground ||
          !TickerMode.valuesOf(context).enabled ||
          MediaQuery.disableAnimationsOf(context),
    );
    _motion = profile.animationEnabled;
    if (!_motion) {
      _flow.stop();
      _hasPlayed = false;
      _flow.value = 0;
    }
  }

  void _onPrefsChanged() {
    if (!mounted) return;
    setState(_syncMotion);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _syncMotion();
    });
  }

  @override
  void didUpdateWidget(covariant SoulMergeTouchHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.pressed && !oldWidget.pressed) ||
        (widget.partnerReady && !oldWidget.partnerReady) ||
        (widget.connected && !oldWidget.connected) ||
        widget.pulse != oldWidget.pulse) {
      if (_motion) {
        _hasPlayed = true;
        _flow.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    UiPrefs.notifier.removeListener(_onPrefsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _flow,
            builder: (context, _) => CustomPaint(
              key: const ValueKey('soul-merge-single-heart'),
              painter: SoulMergeTouchHeartPainter(
                progress: _hasPlayed ? _flow.value : (_lit ? 1 : 0),
                lit: _lit,
                connected: widget.connected,
                dark: dark,
                style: widget.style,
                animate: _motion,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class SoulMergeTouchHeartPainter extends CustomPainter {
  const SoulMergeTouchHeartPainter({
    required this.progress,
    required this.lit,
    required this.connected,
    required this.dark,
    required this.style,
    required this.animate,
  });

  final double progress;
  final bool lit;
  final bool connected;
  final bool dark;
  final String style;
  final bool animate;

  static Path _heart(Rect r) {
    Offset p(double x, double y) =>
        Offset(r.left + x * r.width, r.top + y * r.height);
    final notch = p(.5, .23);
    final path = Path()..moveTo(notch.dx, notch.dy);
    void curve(
      double x1,
      double y1,
      double x2,
      double y2,
      double x3,
      double y3,
    ) {
      final a = p(x1, y1), b = p(x2, y2), c = p(x3, y3);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }

    curve(.69, -.07, 1.06, .01, .99, .36);
    curve(.95, .60, .70, .80, .5, .98);
    curve(.30, .80, .05, .60, .01, .36);
    curve(-.06, .01, .31, -.07, .5, .23);
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final d = math.min(size.width, size.height);
    final center = size.center(Offset.zero);
    final rect = Rect.fromCenter(
      center: center,
      width: d * .76,
      height: d * .71,
    );
    final heart = _heart(rect);
    final rose = style == 'aurora'
        ? const Color(0xFF4EAEA8)
        : style == 'cosmic'
        ? const Color(0xFF9969C5)
        : const Color(0xFFD65D85);
    final deep = style == 'aurora'
        ? const Color(0xFF277F91)
        : style == 'cosmic'
        ? const Color(0xFF69427F)
        : const Color(0xFFA63465);
    final pearl = style == 'aurora'
        ? const Color(0xFFDAFFF5)
        : style == 'cosmic'
        ? const Color(0xFFFFE9C6)
        : const Color(0xFFFFE8E8);
    final p = progress.clamp(0.0, 1.0);
    final fill = !animate && lit
        ? 1.0
        : Curves.easeInOutCubic.transform((p / .58).clamp(0.0, 1.0));
    final fading = lit
        ? 1.0
        : 1 - Curves.easeIn.transform(((p - .76) / .24).clamp(0.0, 1.0));
    final light = (!animate && lit) ? 1.0 : fill * fading;

    // Vầng sáng cố định quanh tim; không phát hạt hay bay ra ngoài vùng chạm.
    canvas.drawCircle(
      center,
      d * .48,
      Paint()
        ..shader = RadialGradient(
          colors: [
            rose.withValues(alpha: (dark ? .17 : .09) + light * .20),
            rose.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: d * .48)),
    );
    canvas.drawShadow(
      heart,
      deep.withValues(alpha: dark ? .35 : .13),
      3 + light * 3,
      false,
    );
    canvas.drawPath(
      heart,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF593949), const Color(0xFF30202D)]
              : [const Color(0xFFFFF9F4), const Color(0xFFF3D6E0)],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(heart);
    if (light > 0) {
      canvas.save();
      final frontY = rect.top + rect.height * fill;
      final wave = math.sin(fill * math.pi) * rect.height * .035;
      canvas.clipPath(
        Path()
          ..moveTo(rect.left - 2, rect.top - 2)
          ..lineTo(rect.right + 2, rect.top - 2)
          ..lineTo(rect.right + 2, frontY)
          ..cubicTo(
            rect.right - rect.width * .25,
            frontY + wave,
            rect.left + rect.width * .25,
            frontY - wave,
            rect.left - 2,
            frontY,
          )
          ..close(),
      );
      canvas.drawRect(
        rect.inflate(2),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              pearl.withValues(alpha: fading),
              rose.withValues(alpha: fading),
              deep.withValues(alpha: fading),
            ],
            stops: const [0, .42, 1],
          ).createShader(rect),
      );
      canvas.restore();

      // Dải sáng có đuôi liền mạch, chảy từ đỉnh xuống mũi tim.
      if (animate && p > 0 && p < .64) {
        final y = rect.top + rect.height * fill;
        final ribbon = Path()
          ..moveTo(rect.left + rect.width * .54, rect.top - 8)
          ..cubicTo(
            rect.left + rect.width * .36,
            rect.top + rect.height * .30,
            rect.left + rect.width * .65,
            y - rect.height * .23,
            center.dx,
            y,
          );
        canvas.drawPath(
          ribbon,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = d * .075
            ..shader =
                LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    pearl.withValues(alpha: 0),
                    pearl.withValues(alpha: .27),
                    Colors.white.withValues(alpha: .88),
                  ],
                  stops: const [0, .68, 1],
                ).createShader(
                  Rect.fromLTRB(rect.left, rect.top - 8, rect.right, y + 1),
                ),
        );
        canvas.drawCircle(
          Offset(center.dx, y),
          d * .024,
          Paint()..color = pearl,
        );
      }
    }

    // Phản chiếu mềm để tim có chiều sâu cả khi chưa chạm.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          rect.left + rect.width * .27,
          rect.top + rect.height * .24,
        ),
        width: rect.width * .30,
        height: rect.height * .24,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: dark ? .24 : .83),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(
                  rect.left + rect.width * .27,
                  rect.top + rect.height * .24,
                ),
                width: rect.width * .30,
                height: rect.height * .24,
              ),
            ),
    );
    canvas.restore();

    canvas.drawPath(
      heart,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? .54 : .95),
            rose.withValues(alpha: .62),
            pearl.withValues(alpha: .9),
          ],
        ).createShader(rect),
    );

    if (light > 0) {
      final contour = animate ? (p / .50).clamp(0.0, 1.0) : 1.0;
      for (final metric in heart.computeMetrics()) {
        final line = metric.extractPath(0, metric.length * contour);
        canvas.drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = connected ? 3.2 : 2.2
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                pearl.withValues(alpha: light),
                rose.withValues(alpha: light),
                pearl.withValues(alpha: light),
              ],
            ).createShader(rect),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SoulMergeTouchHeartPainter old) =>
      progress != old.progress ||
      lit != old.lit ||
      connected != old.connected ||
      dark != old.dark ||
      style != old.style ||
      animate != old.animate;
}
