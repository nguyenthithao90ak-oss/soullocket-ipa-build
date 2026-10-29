import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

/// Hiệu ứng chính khi chạm: trái tim neo ở một vị trí cố định.
/// Khi hai người kết nối, tim chỉ sáng lên và phát một burst ngắn; không rơi
/// lặp lại hay tạo particle vô hạn.
class SoulMergeTouchCascade extends StatefulWidget {
  const SoulMergeTouchCascade({super.key, required this.style});

  final String style;

  @override
  State<SoulMergeTouchCascade> createState() => SoulMergeTouchCascadeState();
}

class SoulMergeTouchCascadeState extends State<SoulMergeTouchCascade>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final AnimationController _shimmer;
  late final AnimationController _burst;
  Timer? _hideTimer;
  bool _visible = false;
  bool _connected = false;
  bool _holding = false;
  bool _celebrating = false;
  bool _foreground = true;
  bool _animate = true;

  bool get isVisible => _visible;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addObserver(this);
    UiPrefs.notifier.addListener(_onPrefsChanged);
  }

  void _onPrefsChanged() {
    if (!mounted) return;
    setState(_syncMotion);
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
    _animate = profile.animationEnabled;
    if (!_animate) {
      _controller.stop();
      _shimmer.stop();
      _burst.stop();
    } else if (_visible && (_holding || _celebrating)) {
      final target = _connected ? 1.0 : .72;
      if (_controller.value < target && !_controller.isAnimating) {
        _controller.animateTo(
          target,
          duration: _connected
              ? const Duration(milliseconds: 720)
              : Duration(
                  milliseconds: (2400 * (target - _controller.value) / .72)
                      .round(),
                ),
        );
      }
      if (!_shimmer.isAnimating) _shimmer.repeat();
      if (_connected &&
          _celebrating &&
          !_burst.isAnimating &&
          !_burst.isCompleted) {
        _burst.forward();
      }
    }
  }

  /// Tim chỉ chảy trong lúc giữ. Khi đang chờ, tim không tự đầy hoặc biến mất.
  void startHolding({bool connected = false}) {
    if (!mounted) return;
    _hideTimer?.cancel();
    if (!_visible) _controller.value = 0;
    _holding = true;
    _connected = connected;
    _visible = true;
    _syncMotion();
    setState(() {});
  }

  /// Thả hoặc hủy chạm dừng dòng chảy ở mức đang có, rồi ẩn nhẹ sau đó.
  void releaseHolding() {
    if (!mounted || !_holding) return;
    _holding = false;
    if (_celebrating) return;
    _controller.stop();
    _shimmer.stop();
    _scheduleHide(const Duration(milliseconds: 900));
  }

  /// Một phía đã thả/hết phiên: bỏ trạng thái ghép ngay, kể cả burst đang chạy.
  /// Nếu mình còn giữ, tim quay về mức chờ để lần ghép mới không dùng màu cũ.
  void resetConnection({required bool holding}) {
    if (!mounted) return;
    _hideTimer?.cancel();
    _controller.stop();
    _shimmer.stop();
    _burst.stop();
    _burst.value = 0;
    _connected = false;
    _celebrating = false;
    _holding = holding;
    if (_controller.value > .72) _controller.value = .72;
    if (holding) {
      _visible = true;
      _syncMotion();
    } else if (_visible) {
      _scheduleHide(const Duration(milliseconds: 900));
    }
    setState(() {});
  }

  /// Chỉ mốc kết nối đôi mới cho tim đầy, đổi màu và nổ sáng.
  void completeConnection() {
    if (!mounted) return;
    _hideTimer?.cancel();
    _controller.stop();
    _burst.value = 0;
    _connected = true;
    _celebrating = true;
    _visible = true;
    _syncMotion();
    setState(() {});
    _scheduleHide(const Duration(milliseconds: 2400));
  }

  void _scheduleHide(Duration delay) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay, () {
      if (!mounted) return;
      _celebrating = false;
      _burst.stop();
      if (_holding) return;
      _controller.stop();
      _shimmer.stop();
      setState(() => _visible = false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) releaseHolding();
    setState(_syncMotion);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    UiPrefs.notifier.removeListener(_onPrefsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _shimmer.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _shimmer, _burst]),
          builder: (context, _) => CustomPaint(
            key: const ValueKey('soul-merge-touch-cascade-painter'),
            painter: SoulMergeTouchCascadePainter(
              progress: _animate ? _controller.value : (_connected ? 1 : .72),
              shimmer: _animate ? _shimmer.value : 0,
              celebration: _animate ? _burst.value : 1,
              connected: _connected,
              style: widget.style,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class SoulMergeTouchCascadePainter extends CustomPainter {
  const SoulMergeTouchCascadePainter({
    required this.progress,
    required this.connected,
    required this.style,
    required this.dark,
    this.shimmer = 0,
    this.celebration = 1,
  });

  final double progress;
  final bool connected;
  final String style;
  final bool dark;
  final double shimmer;
  final double celebration;

  static double heartSizeFor(Size size) =>
      (math.min(size.width, 430.0) * .62).clamp(198.0, 272.0);

  Path _heart(Rect rect) {
    Offset p(double x, double y) =>
        Offset(rect.left + x * rect.width, rect.top + y * rect.height);
    final path = Path()..moveTo(p(.5, .22).dx, p(.5, .22).dy);
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

    curve(.67, -.08, 1.06, .02, .99, .36);
    curve(.94, .61, .70, .82, .5, .99);
    curve(.30, .82, .06, .61, .01, .36);
    curve(-.06, .02, .33, -.08, .5, .22);
    return path..close();
  }

  void _spark(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    canvas.drawCircle(center, radius * .18, paint);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: radius * .08, height: radius),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: radius, height: radius * .08),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.clamp(0.0, 1.0);
    final width = math.min(size.width, 430.0);
    // Tim lớn theo bề ngang màn hình, vẫn chừa viền cho ánh sáng lan.
    final double heartSize = heartSizeFor(size);
    final centerX = size.width / 2;
    final top = -heartSize * .76;
    final double destination = (size.height * .44)
        .clamp(250.0, math.max(250.0, size.height - 220.0))
        .toDouble();
    final fall = Curves.easeOutBack.transform((t / .72).clamp(0.0, 1.0));
    // Sau khi kết nối, tim được neo ngay tại điểm đích. Chỉ lớp sáng và burst
    // thay đổi; thân tim không rơi, nảy hoặc phóng to thêm.
    final y = connected ? destination : top + (destination - top) * fall;
    final double settle = !connected && t > .72
        ? math.sin(((t - .72) / .28) * math.pi)
        : 0.0;
    final double scale = 1.0 + settle * .045;
    final rect = Rect.fromCenter(
      center: Offset(centerX, y),
      width: heartSize * scale,
      height: heartSize * .92 * scale,
    );
    final heart = _heart(rect);
    final baseRose = style == 'aurora'
        ? const Color(0xFF55C9C0)
        : style == 'cosmic'
        ? const Color(0xFFA678FF)
        : const Color(0xFFF05D92);
    final baseDeep = style == 'aurora'
        ? const Color(0xFF228C9A)
        : style == 'cosmic'
        ? const Color(0xFF653D99)
        : const Color(0xFFB52B66);
    final baseLiquid = style == 'aurora'
        ? const Color(0xFFD3FFF5)
        : style == 'cosmic'
        ? const Color(0xFFFFE3FF)
        : const Color(0xFFFFE3EC);
    final colorPhase = (math.sin(shimmer * math.pi * 2) + 1) / 2;
    final rose = connected
        ? Color.lerp(baseRose, const Color(0xFFFFBF65), colorPhase * .8)!
        : baseRose;
    final deep = connected
        ? Color.lerp(
            const Color(0xFFBE4B99),
            const Color(0xFF785AD9),
            colorPhase,
          )!
        : baseDeep;
    final liquid = connected
        ? Color.lerp(
            const Color(0xFFFFECB7),
            const Color(0xFFECDFFF),
            colorPhase,
          )!
        : baseLiquid;
    final appear = Curves.easeOut.transform((t / .24).clamp(0.0, 1.0));
    final fill = connected
        ? Curves.easeInOutCubic.transform(((t - .12) / .64).clamp(0.0, 1.0))
        : Curves.easeInOutCubic.transform(((t - .12) / .60).clamp(0.0, 1.0)) *
              .78;
    final endGlow = connected
        ? 1.0
        : Curves.easeIn.transform(((t - .60) / .40).clamp(0.0, 1.0));

    // Một vệt liquid rơi theo trục dọc, nối trực tiếp vào tim lớn.
    final double streamTop = math.max(0.0, y - heartSize * .84).toDouble();
    final streamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = heartSize * .045
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          liquid.withValues(alpha: 0),
          liquid.withValues(alpha: appear * .76),
          rose.withValues(alpha: appear),
        ],
      ).createShader(Rect.fromLTRB(centerX, streamTop, centerX, y));
    canvas.drawLine(
      Offset(centerX, streamTop),
      Offset(centerX, y - rect.height * .35),
      streamPaint,
    );
    canvas.drawCircle(
      Offset(centerX, y - rect.height * .39),
      heartSize * .045,
      Paint()..color = liquid.withValues(alpha: appear * .8),
    );

    // Glow lớn theo nhịp rơi, có nhiều lớp mềm nhưng không tạo tim nhỏ bay loạn.
    final double glowRadius = heartSize * (.63 + endGlow * .19);
    canvas.drawCircle(
      Offset(centerX, y),
      glowRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                rose.withValues(alpha: (dark ? .18 : .10) + endGlow * .26),
                rose.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(centerX, y), radius: glowRadius),
            ),
    );

    canvas.drawShadow(
      heart,
      deep.withValues(alpha: .40),
      12 + endGlow * 8,
      false,
    );
    canvas.drawPath(
      heart,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF4F3244), const Color(0xFF241925)]
              : [const Color(0xFFFFF9F8), const Color(0xFFF4D3DE)],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(heart);
    final fillTop = rect.bottom - rect.height * fill;
    canvas.drawRect(
      Rect.fromLTRB(rect.left - 4, fillTop, rect.right + 4, rect.bottom + 4),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                liquid.withValues(alpha: appear),
                rose.withValues(alpha: appear),
                deep.withValues(alpha: appear),
              ],
            ).createShader(
              Rect.fromLTRB(rect.left, fillTop, rect.right, rect.bottom),
            ),
    );
    if (fill > .02 && fill < .98) {
      final wave =
          math.sin((t * 2.5 + shimmer) * math.pi * 2) * rect.height * .024;
      final water = Path()
        ..moveTo(rect.left - 4, fillTop)
        ..cubicTo(
          rect.left + rect.width * .22,
          fillTop + wave,
          rect.left + rect.width * .44,
          fillTop - wave,
          centerX,
          fillTop,
        )
        ..cubicTo(
          rect.left + rect.width * .66,
          fillTop + wave,
          rect.left + rect.width * .83,
          fillTop - wave,
          rect.right + 4,
          fillTop,
        );
      canvas.drawPath(
        water,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = heartSize * .026
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: .74),
      );
    }
    // Vệt phản chiếu chạy trên mặt tim khi giữ hoặc trong nhịp kết nối.
    canvas.save();
    canvas.translate(rect.left + rect.width * (shimmer * 1.8 - .4), rect.top);
    canvas.rotate(-.30);
    final sheenRect = Rect.fromLTWH(
      0,
      -rect.height * .4,
      rect.width * .23,
      rect.height * 2,
    );
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: connected ? .48 : .22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(sheenRect),
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          rect.left + rect.width * .30,
          rect.top + rect.height * .24,
        ),
        width: rect.width * .22,
        height: rect.height * .16,
      ),
      Paint()..color = Colors.white.withValues(alpha: dark ? .20 : .72),
    );
    canvas.restore();

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = connected ? 4.0 : 2.4
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: .9), rose, liquid],
      ).createShader(rect);
    canvas.drawPath(heart, outline);

    // Hai vòng lan ngắn khi tim chạm điểm giữa. Vòng tắt theo controller,
    // shimmer chỉ dùng cho ánh sáng nền nên không tạo nổ lặp vô hạn.
    if (endGlow > 0) {
      final celebrationProgress = connected
          ? Curves.easeOutCubic.transform(celebration.clamp(0.0, 1.0))
          : 0.0;
      final celebrationPulse = connected
          ? math.sin(celebrationProgress * math.pi)
          : 0.0;
      for (var i = 0; i < 2; i++) {
        final double ringProgress =
            (connected
                    ? (celebrationProgress + i * .34)
                    : ((t - .62) / .38 + i * .22))
                .clamp(0.0, 1.0)
                .toDouble();
        final double ringRadius = math.min(
          width * .47,
          heartSize * (.50 + ringProgress * .31),
        );
        canvas.drawCircle(
          Offset(centerX, y),
          ringRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = liquid.withValues(
              alpha: connected
                  ? celebrationPulse * (1 - ringProgress) * .68
                  : (1 - ringProgress) * .48 * endGlow,
            ),
        );
      }
      if (connected) {
        // Burst có số tia cố định, nở một lần rồi tắt. Các tia mảnh và ngắn
        // giữ cảm giác như một khoảnh khắc ảnh được mở ra, không giống pháo
        // hoa dày đặc phủ kín màn hình.
        final burst = celebrationProgress;
        final burstAlpha = celebrationPulse * endGlow;
        final burstPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.0 + (1 - burst) * 1.2
          ..shader =
              LinearGradient(
                colors: [
                  liquid.withValues(alpha: burstAlpha),
                  rose.withValues(alpha: burstAlpha * .72),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(centerX, y), radius: heartSize),
              );
        final burstCenter = Offset(centerX, y);
        for (var i = 0; i < 12; i++) {
          final angle = -math.pi / 2 + i * math.pi * 2 / 12;
          final startRadius = heartSize * (.46 + burst * .06);
          final endRadius = math.min(
            width * .47,
            heartSize * (.65 + burst * .18),
          );
          final start =
              burstCenter +
              Offset(math.cos(angle), math.sin(angle)) * startRadius;
          final end =
              burstCenter +
              Offset(math.cos(angle), math.sin(angle)) * endRadius;
          canvas.drawLine(start, end, burstPaint);
          canvas.drawCircle(
            end,
            heartSize * (.018 + (1 - burst) * .012),
            Paint()..color = liquid.withValues(alpha: burstAlpha),
          );
        }
      }
      final sparklePulse = .5 + .5 * math.sin(shimmer * math.pi * 6);
      final sparkOpacity =
          endGlow * (connected ? .45 + sparklePulse * .55 : .70);
      _spark(
        canvas,
        Offset(centerX - heartSize * .62, y - heartSize * .20),
        heartSize * .14,
        liquid,
        sparkOpacity,
      );
      _spark(
        canvas,
        Offset(centerX + heartSize * .59, y - heartSize * .03),
        heartSize * .11,
        Colors.white,
        sparkOpacity * .9,
      );
      _spark(
        canvas,
        Offset(centerX + heartSize * .30, y + heartSize * .58),
        heartSize * .08,
        liquid,
        sparkOpacity * .8,
      );
      if (connected) {
        for (var i = 0; i < 4; i++) {
          final angle = -math.pi * .72 + i * math.pi / 2;
          final point =
              Offset(centerX, y) +
              Offset(math.cos(angle), math.sin(angle)) * heartSize * .82;
          final twinkle =
              .3 + .7 * (math.sin(shimmer * math.pi * 6 + i * 1.7) + 1) / 2;
          _spark(
            canvas,
            point,
            heartSize * (.07 + twinkle * .05),
            i.isEven ? liquid : Colors.white,
            twinkle,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SoulMergeTouchCascadePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      shimmer != oldDelegate.shimmer ||
      celebration != oldDelegate.celebration ||
      connected != oldDelegate.connected ||
      style != oldDelegate.style ||
      dark != oldDelegate.dark;
}
