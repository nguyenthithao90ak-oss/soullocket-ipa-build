import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../core/sl_theme.dart';

/// Night-sky palette lifted from the app icon (rose ↔ violet heart) so the
/// loading screen continues straight on from the black native splash.
abstract final class _Night {
  static const top = Color(0xFF1E0B31);
  static const middle = Color(0xFF130722);
  static const bottom = Color(0xFF08040F);
  static const rose = Color(0xFFFF5C9D);
  static const violet = Color(0xFF9D6BFF);
  static const peach = Color(0xFFFF9B7B);
  static const berry = Color(0xFFB0307A);
  static const blush = Color(0xFFFFC4DC);
  static const lilac = Color(0xFFDCCBFF);
}

// Light status-bar icons over the night sky. statusBarColor and
// navigationBarColor stay unset for the same Android 15 reason as main.dart.
const SystemUiOverlayStyle _kNightOverlayStyle = SystemUiOverlayStyle(
  systemNavigationBarDividerColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
);

// Mirrors the app-wide default set in main.dart. Restored when the last
// loading screen leaves so light pages without an AppBar keep dark icons.
const SystemUiOverlayStyle _kAppOverlayStyle = SystemUiOverlayStyle(
  systemNavigationBarDividerColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.dark,
);

// Same logical size flutter_native_splash gives assets/splash.png, so the
// icon lands exactly where the native splash drew it.
const double _kIconSize = 128;
const double _kIconRadius = 30;
const double _kEmblemSide = _kIconSize * 2.3;

// Tallest tip card at the default text scale. The layout reserves this much
// so the emblem never shifts when a shorter or longer tip rotates in.
const double _kTipReserve = 128;

// The pulse trace sweeps from just off the left edge to fully off the right
// edge in one beat, so every loop restarts on an empty track.
const double _kTraceStart = -0.05;
const double _kTraceSpan = 1.6;
const double _kTraceTail = 0.55;
const double _kSpikeX = 0.5;
const double _kEchoX = 0.68;

double _traceHeadAt(double beat) => _kTraceStart + beat * _kTraceSpan;
double _beatTimeAt(double x) => (x - _kTraceStart) / _kTraceSpan;
double _unit(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// 0 at rest, 1 on the "lub" as the trace crosses its spike, then a softer
/// "dub" on the echo wave. Icon, halo and ripples all follow this curve.
double _heartbeat(double beat) {
  double bump(double center, double width) {
    final d = (beat - center) / width;
    return math.exp(-d * d);
  }

  return bump(_beatTimeAt(_kSpikeX), 0.035) +
      0.55 * bump(_beatTimeAt(_kEchoX), 0.045);
}

class _LoadingMessage {
  final IconData icon;
  final String badge;
  final String text;
  final String subText;

  const _LoadingMessage({
    required this.icon,
    required this.badge,
    required this.text,
    required this.subText,
  });
}

const List<_LoadingMessage> _kLoadingMessages = [
  _LoadingMessage(
    icon: Icons.shield_rounded,
    badge: 'loading_security_badge',
    text: 'loading_security_text',
    subText: 'loading_security_hint',
  ),
  _LoadingMessage(
    icon: Icons.cloud_done_rounded,
    badge: 'loading_sync_badge',
    text: 'loading_sync_text',
    subText: 'loading_sync_hint',
  ),
  _LoadingMessage(
    icon: Icons.lock_rounded,
    badge: 'loading_privacy_badge',
    text: 'loading_privacy_text',
    subText: 'loading_privacy_hint',
  ),
  _LoadingMessage(
    icon: Icons.favorite_rounded,
    badge: 'loading_memories_badge',
    text: 'loading_memories_text',
    subText: 'loading_memories_hint',
  ),
  _LoadingMessage(
    icon: Icons.auto_awesome_rounded,
    badge: 'loading_countdown_badge',
    text: 'loading_countdown_text',
    subText: 'loading_countdown_hint',
  ),
  _LoadingMessage(
    icon: Icons.verified_user_rounded,
    badge: 'loading_backup_badge',
    text: 'loading_backup_text',
    subText: 'loading_backup_hint',
  ),
  _LoadingMessage(
    icon: Icons.favorite_border_rounded,
    badge: 'loading_message_badge',
    text: 'loading_message_text',
    subText: 'loading_message_hint',
  ),
];

class LoadingScaffold extends StatefulWidget {
  const LoadingScaffold({super.key});

  @override
  State<LoadingScaffold> createState() => _LoadingScaffoldState();
}

class _LoadingScaffoldState extends State<LoadingScaffold>
    with TickerProviderStateMixin {
  static const Duration _ambientPeriod = Duration(seconds: 24);
  static const Duration _beatPeriod = Duration(milliseconds: 1600);
  static const Duration _tipPeriod = Duration(milliseconds: 4200);
  static const Duration _entranceDuration = Duration(milliseconds: 1400);

  // Pose used when the system asks for reduced motion: full trace visible,
  // heart at rest.
  static const double _restingBeat = 0.64;

  // app_entry swaps between several LoadingScaffold placements while auth and
  // access resolve. Shared timing lets each new instance pick the motion up
  // where the previous one left off instead of replaying from zero.
  static final Stopwatch _clock = Stopwatch();
  static int _liveInstances = 0;
  static int? _lastDisposedAtMs;
  static int _tipSeed = 0;

  late final AnimationController _ambient;
  late final AnimationController _beat;
  late final AnimationController _tips;
  late final AnimationController _entrance;
  late final CurvedAnimation _reveal;
  late final CurvedAnimation _captionIn;
  late final CurvedAnimation _tipIn;
  late final ValueNotifier<int> _tipIndex;
  final _SkyCache _skyCache = _SkyCache();
  double _lastTipProgress = 0;
  bool? _reduceMotion;

  static double _phase(int elapsedMs, Duration period) =>
      (elapsedMs % period.inMilliseconds) / period.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _liveInstances++;
    if (!_clock.isRunning) {
      _clock.start();
      _tipSeed =
          (DateTime.now().millisecondsSinceEpoch ~/ 100) %
          _kLoadingMessages.length;
    }
    final elapsed = _clock.elapsedMilliseconds;
    final lastDisposed = _lastDisposedAtMs;
    final continuing =
        _liveInstances > 1 ||
        (lastDisposed != null && elapsed - lastDisposed < 800);

    _ambient = AnimationController(
      vsync: this,
      duration: _ambientPeriod,
      value: _phase(elapsed, _ambientPeriod),
    );
    _beat = AnimationController(
      vsync: this,
      duration: _beatPeriod,
      value: _phase(elapsed, _beatPeriod),
    );
    _tipIndex = ValueNotifier<int>(
      (_tipSeed + elapsed ~/ _tipPeriod.inMilliseconds) %
          _kLoadingMessages.length,
    );
    _tips = AnimationController(
      vsync: this,
      duration: _tipPeriod,
      value: _phase(elapsed, _tipPeriod),
    );
    _lastTipProgress = _tips.value;
    _tips
      ..addListener(_handleTipTick)
      ..repeat();

    _entrance = AnimationController(
      vsync: this,
      duration: _entranceDuration,
      value: continuing ? 1 : 0,
    );
    _reveal = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    );
    _captionIn = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.2, 0.75, curve: Curves.easeOutCubic),
    );
    _tipIn = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.4, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/icon.png'), context);

    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _ambient.stop();
      _beat
        ..stop()
        ..value = _restingBeat;
      _entrance.value = 1;
    } else {
      _ambient.repeat();
      _beat.repeat();
      if (_entrance.value < 1) _entrance.forward();
    }
  }

  void _handleTipTick() {
    final progress = _tips.value;
    if (progress < _lastTipProgress) {
      _tipIndex.value = (_tipIndex.value + 1) % _kLoadingMessages.length;
    }
    _lastTipProgress = progress;
  }

  @override
  void dispose() {
    _liveInstances--;
    _lastDisposedAtMs = _clock.elapsedMilliseconds;
    if (_liveInstances == 0) {
      SystemChrome.setSystemUIOverlayStyle(_kAppOverlayStyle);
    }
    _tips.removeListener(_handleTipTick);
    _reveal.dispose();
    _captionIn.dispose();
    _tipIn.dispose();
    _ambient.dispose();
    _beat.dispose();
    _tips.dispose();
    _entrance.dispose();
    _tipIndex.dispose();
    _skyCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kNightOverlayStyle,
      child: Scaffold(
        backgroundColor: _Night.bottom,
        body: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _NightSkyPainter(
                  ambient: _ambient,
                  reveal: _reveal,
                  cache: _skyCache,
                ),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: _StardustPainter(ambient: _ambient, reveal: _reveal),
              ),
            ),
            CustomMultiChildLayout(
              delegate: _LoadingLayoutDelegate(
                padding: MediaQuery.paddingOf(context),
              ),
              children: [
                LayoutId(
                  id: _Slot.emblem,
                  child: RepaintBoundary(
                    child: _LocketEmblem(
                      ambient: _ambient,
                      beat: _beat,
                      reveal: _reveal,
                    ),
                  ),
                ),
                LayoutId(
                  id: _Slot.caption,
                  child: _Rise(
                    animation: _captionIn,
                    distance: 14,
                    child: _Caption(ambient: _ambient, beat: _beat),
                  ),
                ),
                LayoutId(
                  id: _Slot.tip,
                  child: _Rise(
                    animation: _tipIn,
                    distance: 22,
                    child: _TipCard(
                      index: _tipIndex,
                      progress: _tips,
                      reduceMotion: _reduceMotion ?? false,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _Slot { emblem, caption, tip }

class _LoadingLayoutDelegate extends MultiChildLayoutDelegate {
  _LoadingLayoutDelegate({required this.padding});

  final EdgeInsets padding;

  static const double _captionGap = 44;

  @override
  void performLayout(Size size) {
    layoutChild(
      _Slot.emblem,
      BoxConstraints.tight(const Size.square(_kEmblemSide)),
    );

    final tipWidth = math.min(size.width - 40, 440.0);
    final tipSize = layoutChild(
      _Slot.tip,
      BoxConstraints.tightFor(width: math.max(0.0, tipWidth)),
    );
    final captionSize = layoutChild(
      _Slot.caption,
      BoxConstraints(maxWidth: math.max(0.0, math.min(size.width - 48, 420))),
    );

    final tipBottom = size.height - math.max(padding.bottom + 6, 18);
    positionChild(
      _Slot.tip,
      Offset((size.width - tipSize.width) / 2, tipBottom - tipSize.height),
    );

    // Prefer the exact screen centre (where the native splash drew the
    // icon) and lift the emblem only when the caption would reach the tip.
    const halfIcon = _kIconSize / 2;
    final tipTop = tipBottom - math.max(tipSize.height, _kTipReserve);
    final lowest = tipTop - 16 - captionSize.height - _captionGap - halfIcon;
    final highest = padding.top + halfIcon + 24;
    final centerY = math.max(highest, math.min(size.height / 2, lowest));

    positionChild(
      _Slot.emblem,
      Offset((size.width - _kEmblemSide) / 2, centerY - _kEmblemSide / 2),
    );
    positionChild(
      _Slot.caption,
      Offset(
        (size.width - captionSize.width) / 2,
        centerY + halfIcon + _captionGap,
      ),
    );
  }

  @override
  bool shouldRelayout(_LoadingLayoutDelegate oldDelegate) =>
      oldDelegate.padding != padding;
}

/// Fades a child in while lifting it into place.
class _Rise extends StatelessWidget {
  const _Rise({
    required this.animation,
    required this.distance,
    required this.child,
  });

  final Animation<double> animation;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, distance * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

// ─── Emblem ─────────────────────────────────────────────────────────

class _LocketEmblem extends StatelessWidget {
  const _LocketEmblem({
    required this.ambient,
    required this.beat,
    required this.reveal,
  });

  final Animation<double> ambient;
  final Animation<double> beat;
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HaloPainter(beat: beat, reveal: reveal),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _OrbitPainter(
              ambient: ambient,
              reveal: reveal,
              front: false,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: beat,
          builder: (context, child) => Transform.scale(
            scale: 1 + 0.04 * _heartbeat(beat.value),
            child: child,
          ),
          child: RepaintBoundary(child: _LocketIcon(ambient: ambient)),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _OrbitPainter(
              ambient: ambient,
              reveal: reveal,
              front: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocketIcon extends StatelessWidget {
  const _LocketIcon({required this.ambient});

  final Animation<double> ambient;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_kIconRadius);
    return SizedBox.square(
      dimension: _kIconSize,
      child: Image.asset(
        'assets/icon.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        // Glow and sheen wrap the decoded image so nothing shows as an empty
        // glowing tile while the asset is still decoding.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final icon = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: _Night.rose.withValues(alpha: 0.42),
                  blurRadius: 42,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 28,
                  spreadRadius: -12,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  RepaintBoundary(
                    child: CustomPaint(painter: _SheenPainter(ambient)),
                  ),
                ],
              ),
            ),
          );
          if (wasSynchronouslyLoaded) return icon;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: icon,
          );
        },
      ),
    );
  }
}

/// A glint that crosses the icon once every six seconds.
class _SheenPainter extends CustomPainter {
  _SheenPainter(this.ambient) : super(repaint: ambient);

  final Animation<double> ambient;

  static const double window = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    final cycle = (ambient.value * 4) % 1.0;
    if (cycle > window) return;
    final p = Curves.easeInOut.transform(cycle / window);
    final c = -0.3 + p * 1.6;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0),
          ],
          stops: [_unit(c - 0.12), _unit(c), _unit(c + 0.12)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter oldDelegate) =>
      oldDelegate.ambient != ambient;
}

/// Soft glow behind the icon plus ripples that leave the icon's outline on
/// every heartbeat and relax into circles as they fade.
class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.beat, required this.reveal})
    : super(repaint: Listenable.merge([beat, reveal]));

  final Animation<double> beat;
  final Animation<double> reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final r = reveal.value;
    if (r <= 0) return;
    final center = size.center(Offset.zero);
    final t = beat.value;
    final pulse = _heartbeat(t);

    final glowRadius = _kIconSize * (1.05 + 0.08 * pulse);
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _Night.rose.withValues(alpha: (0.34 + 0.16 * pulse) * r),
            _Night.violet.withValues(alpha: 0.16 * r),
            _Night.violet.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    _ripple(canvas, center, (t - _beatTimeAt(_kSpikeX)) % 1.0, 0.5 * r);
    _ripple(canvas, center, (t - _beatTimeAt(_kEchoX)) % 1.0, 0.24 * r);
  }

  void _ripple(Canvas canvas, Offset center, double phase, double strength) {
    const life = 0.92;
    if (phase > life || strength <= 0) return;
    final p = phase / life;
    final eased = Curves.easeOutCubic.transform(p);
    final reach = _kIconSize / 2 + 4 + _kIconSize * 0.58 * eased;
    final corner = _kIconRadius + (reach - _kIconRadius) * math.sqrt(eased);
    final bounds = Rect.fromCircle(center: center, radius: reach);
    final alpha = math.pow(1 - p, 1.8).toDouble() * strength;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, Radius.circular(corner)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 + 1.6 * (1 - p)
        ..shader = SweepGradient(
          colors: [
            _Night.rose.withValues(alpha: alpha),
            _Night.lilac.withValues(alpha: alpha),
            _Night.violet.withValues(alpha: alpha),
            _Night.rose.withValues(alpha: alpha),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) =>
      oldDelegate.beat != beat || oldDelegate.reveal != reveal;
}

/// Two tilted orbits, mirror images of each other, each carrying one glowing
/// "soul". The orbs sweep in opposite directions and meet in front of the
/// icon once per lap. Painted twice: once behind the icon and once in front,
/// so each orb really passes behind and around the locket.
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.ambient,
    required this.reveal,
    required this.front,
  }) : super(repaint: Listenable.merge([ambient, reveal]));

  final Animation<double> ambient;
  final Animation<double> reveal;
  final bool front;

  static const double _rx = _kIconSize * 0.98;
  static const double _ry = _kIconSize * 0.27;
  static const double _tilt = 0.3;
  static const int _lapsPerCycle = 4;
  static const int _trail = 22;
  static const double _trailStep = 0.03;

  static Offset _point(Offset center, double angle, bool mirrored) {
    final x = _rx * math.cos(angle);
    final y = _ry * math.sin(angle);
    final c = math.cos(_tilt);
    final s = math.sin(_tilt);
    final px = x * c + y * s;
    final py = -x * s + y * c;
    return center + Offset(mirrored ? -px : px, py);
  }

  // sin(angle) > 0 is the lower half of the ellipse, i.e. nearer the viewer.
  bool _inLayer(double angle) => (math.sin(angle) >= 0) == front;

  @override
  void paint(Canvas canvas, Size size) {
    final r = reveal.value;
    if (r <= 0) return;
    final center = size.center(Offset.zero);
    final theta = ambient.value * _lapsPerCycle * 2 * math.pi;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _Night.lilac.withValues(alpha: (front ? 0.17 : 0.09) * r);
    for (final mirrored in const [false, true]) {
      final path = Path();
      const steps = 48;
      final start = front ? 0.0 : math.pi;
      for (var i = 0; i <= steps; i++) {
        final p = _point(center, start + math.pi * i / steps, mirrored);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, track);
    }

    _orb(canvas, center, theta, false, _Night.rose, r);
    _orb(canvas, center, theta, true, _Night.lilac, r);

    // The two souls meet on the near side once per lap: a small spark.
    if (front && math.sin(theta) > 0) {
      final a = _point(center, theta, false);
      final b = _point(center, theta, true);
      final distance = (a - b).distance;
      const reach = 26.0;
      if (distance < reach) {
        final k = Curves.easeOut.transform(1 - distance / reach);
        final mid = Offset.lerp(a, b, 0.5)!;
        canvas.drawCircle(
          mid,
          18 * k,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.55 * k * r),
                _Night.rose.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: mid, radius: 18 * k)),
        );
        canvas.drawPath(
          _sparklePath(mid, 9 * k),
          Paint()..color = Colors.white.withValues(alpha: 0.9 * k * r),
        );
      }
    }
  }

  void _orb(
    Canvas canvas,
    Offset center,
    double theta,
    bool mirrored,
    Color color,
    double reveal,
  ) {
    for (var i = _trail; i >= 0; i--) {
      final angle = theta - i * _trailStep;
      if (!_inLayer(angle)) continue;
      final depth = (math.sin(angle) + 1) / 2;
      final fade = math.pow(1 - i / (_trail + 1), 2).toDouble();
      final p = _point(center, angle, mirrored);
      final radius = (1.6 + 2.6 * depth) * (i == 0 ? 1 : 0.55 + 0.45 * fade);
      final alpha = (0.35 + 0.65 * depth) * fade * reveal;
      if (i == 0) {
        final glow = radius * 4.2;
        canvas.drawCircle(
          p,
          glow,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: 0.55 * alpha),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: p, radius: glow)),
        );
        canvas.drawCircle(
          p,
          radius,
          Paint()
            ..color = Color.lerp(
              color,
              Colors.white,
              0.55,
            )!.withValues(alpha: alpha),
        );
      } else {
        canvas.drawCircle(
          p,
          radius,
          Paint()..color = color.withValues(alpha: alpha * 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) =>
      oldDelegate.ambient != ambient ||
      oldDelegate.reveal != reveal ||
      oldDelegate.front != front;
}

Path _sparklePath(Offset c, double s) {
  return Path()
    ..moveTo(c.dx, c.dy - s)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
    ..close();
}

Path _heartPath(Offset c, double w) {
  final h = w * 0.92;
  final l = c.dx - w / 2;
  final t = c.dy - h / 2;
  return Path()
    ..moveTo(l + w * 0.5, t + h * 0.26)
    ..cubicTo(
      l + w * 0.2,
      t - h * 0.1,
      l - w * 0.25,
      t + h * 0.6,
      l + w * 0.5,
      t + h,
    )
    ..cubicTo(
      l + w * 1.25,
      t + h * 0.6,
      l + w * 0.8,
      t - h * 0.1,
      l + w * 0.5,
      t + h * 0.26,
    )
    ..close();
}

// ─── Sky ────────────────────────────────────────────────────────────

// The sky is only soft gradients drifting a few pixels per second, so it is
// drawn into a third-resolution bitmap ten times a second and stretched over
// the screen. It looks the same as painting it live, but the GPU fills the
// screen once per frame instead of six times.
const double _kSkyScale = 1 / 3;
const int _kSkyStepsPerCycle = 240;

/// Deep plum night with slow aurora clouds. Fades up from black on first
/// show so it reads as a continuation of the native splash.
void _paintNightSky(Canvas canvas, Size size, double ambient, double reveal) {
  final rect = Offset.zero & size;
  final r = reveal;
  final t = ambient * 2 * math.pi;

  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(Colors.black, _Night.top, r)!,
          Color.lerp(Colors.black, _Night.middle, r)!,
          Color.lerp(Colors.black, _Night.bottom, r)!,
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect),
  );
  if (r <= 0) return;

  final extent = size.longestSide;
  _paintCloud(
    canvas,
    Offset(
      size.width * (0.16 + 0.12 * math.sin(t)),
      size.height * (0.14 + 0.06 * math.cos(2 * t)),
    ),
    extent * 0.55,
    _Night.rose,
    0.30 * r,
  );
  _paintCloud(
    canvas,
    Offset(
      size.width * (0.9 + 0.08 * math.cos(t)),
      size.height * (0.4 + 0.07 * math.sin(2 * t + 1)),
    ),
    extent * 0.6,
    _Night.violet,
    0.32 * r,
  );
  _paintCloud(
    canvas,
    Offset(
      size.width * (0.72 + 0.12 * math.sin(2 * t + 0.5)),
      size.height * (0.8 + 0.05 * math.cos(t + 2)),
    ),
    extent * 0.45,
    _Night.berry,
    0.24 * r,
  );
  _paintCloud(
    canvas,
    Offset(
      size.width * (0.22 + 0.14 * math.sin(t + 2)),
      size.height * (0.98 + 0.04 * math.cos(t)),
    ),
    extent * 0.5,
    _Night.peach,
    0.16 * r,
  );

  // Vignette keeps the edges dark and the eye on the locket.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.9,
        colors: [
          Colors.black.withValues(alpha: 0),
          Colors.black.withValues(alpha: 0.42),
        ],
        stops: const [0.55, 1],
      ).createShader(rect),
  );
}

void _paintCloud(
  Canvas canvas,
  Offset center,
  double radius,
  Color color,
  double alpha,
) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.4),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

/// Holds the latest sky bitmap and redraws it only when the size, the drift
/// step or the entrance fade changes.
class _SkyCache {
  ui.Image? _image;
  Size _size = Size.zero;
  int _step = -1;
  double _reveal = -1;

  ui.Image? imageFor(Size size, double ambient, double reveal) {
    final step = (ambient * _kSkyStepsPerCycle).floor();
    final current = _image;
    if (current != null &&
        size == _size &&
        step == _step &&
        reveal == _reveal) {
      return current;
    }
    final width = (size.width * _kSkyScale).ceil();
    final height = (size.height * _kSkyScale).ceil();
    if (width <= 0 || height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(width / size.width, height / size.height);
    _paintNightSky(canvas, size, step / _kSkyStepsPerCycle, reveal);
    final picture = recorder.endRecording();
    final next = picture.toImageSync(width, height);
    picture.dispose();
    current?.dispose();
    _image = next;
    _size = size;
    _step = step;
    _reveal = reveal;
    return next;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
  }
}

class _NightSkyPainter extends CustomPainter {
  _NightSkyPainter({
    required this.ambient,
    required this.reveal,
    required this.cache,
  }) : super(repaint: Listenable.merge([ambient, reveal]));

  final Animation<double> ambient;
  final Animation<double> reveal;
  final _SkyCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    final image = cache.imageFor(size, ambient.value, reveal.value);
    if (image == null) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_NightSkyPainter oldDelegate) =>
      oldDelegate.ambient != ambient ||
      oldDelegate.reveal != reveal ||
      oldDelegate.cache != cache;
}

class _Mote {
  const _Mote({
    required this.x,
    required this.y,
    required this.size,
    required this.laps,
    required this.sway,
    required this.phase,
    required this.twinkle,
    required this.heart,
    required this.tint,
  });

  final double x;
  final double y;
  final double size;
  // Whole trips up the screen per ambient cycle, so the loop is seamless.
  // 0 keeps the mote in place as a twinkling star.
  final int laps;
  final double sway;
  final double phase;
  final int twinkle;
  final bool heart;
  final Color tint;
}

/// Twinkling stars and tiny hearts drifting up through the sky.
class _StardustPainter extends CustomPainter {
  _StardustPainter({required this.ambient, required this.reveal})
    : super(repaint: Listenable.merge([ambient, reveal]));

  final Animation<double> ambient;
  final Animation<double> reveal;

  static final List<_Mote> _motes = _buildMotes();

  static List<_Mote> _buildMotes() {
    final rnd = math.Random(214);
    const tints = [_Night.blush, _Night.lilac, Colors.white, _Night.peach];
    return List<_Mote>.generate(38, (i) {
      final heart = i % 5 == 0;
      return _Mote(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        size: heart ? 6 + rnd.nextDouble() * 6 : 0.7 + rnd.nextDouble() * 1.5,
        laps: heart ? 1 + rnd.nextInt(2) : rnd.nextInt(3),
        sway: 0.008 + rnd.nextDouble() * 0.02,
        phase: rnd.nextDouble(),
        twinkle: 2 + rnd.nextInt(6),
        heart: heart,
        tint: tints[rnd.nextInt(tints.length)],
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = reveal.value;
    if (r <= 0) return;
    final t = ambient.value;
    for (final m in _motes) {
      final y = (m.y - m.laps * t) % 1.0;
      final swing = m.laps == 0
          ? 0.0
          : m.sway * math.sin(2 * math.pi * (2 * t + m.phase));
      final pos = Offset(
        (m.x + swing) * size.width,
        y * (size.height + 40) - 20,
      );
      final twinkle =
          0.5 + 0.5 * math.sin(2 * math.pi * (m.twinkle * t + m.phase));
      // Drifting motes fade in at the bottom and out near the top.
      final edge = m.laps == 0 ? 1.0 : _unit(y / 0.18) * _unit((1 - y) / 0.1);
      final alpha = (0.25 + 0.75 * twinkle) * edge * r;
      if (alpha <= 0.01) continue;

      if (m.heart) {
        canvas.drawPath(
          _heartPath(pos, m.size),
          Paint()..color = m.tint.withValues(alpha: 0.42 * alpha),
        );
      } else {
        canvas.drawCircle(
          pos,
          m.size * 3.4,
          Paint()..color = m.tint.withValues(alpha: 0.10 * alpha),
        );
        canvas.drawCircle(
          pos,
          m.size,
          Paint()..color = m.tint.withValues(alpha: 0.9 * alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StardustPainter oldDelegate) =>
      oldDelegate.ambient != ambient || oldDelegate.reveal != reveal;
}

// ─── Caption ────────────────────────────────────────────────────────

class _Caption extends StatelessWidget {
  const _Caption({required this.ambient, required this.beat});

  final Animation<double> ambient;
  final Animation<double> beat;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShimmerTitle(
          text: 'SoulLocket',
          ambient: ambient,
          style: SLTheme.textStyleForKey(
            'dancingScript',
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
            shadows: [
              Shadow(color: _Night.rose.withValues(alpha: 0.6), blurRadius: 22),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('app_entry_angmnginhc_763d46'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 16),
        RepaintBoundary(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0x00FFFFFF),
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0, 0.16, 0.84, 1],
            ).createShader(bounds),
            child: SizedBox(
              width: 216,
              height: 38,
              child: CustomPaint(painter: _PulseTracePainter(beat)),
            ),
          ),
        ),
      ],
    );
  }
}

/// The wordmark in a blush → lilac gradient with a glint that follows the
/// icon sheen across it.
class _ShimmerTitle extends StatelessWidget {
  const _ShimmerTitle({
    required this.text,
    required this.style,
    required this.ambient,
  });

  final String text;
  final TextStyle style;
  final Animation<double> ambient;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        RepaintBoundary(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_Night.blush, Colors.white, _Night.lilac],
            ).createShader(bounds),
            child: Text(text, style: style),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: ambient,
            child: Text(text, style: style.copyWith(shadows: const [])),
            builder: (context, child) {
              final cycle = (ambient.value * 4) % 1.0;
              const start = 0.1;
              const end = 0.3;
              if (cycle < start || cycle > end) return const SizedBox.shrink();
              final p = Curves.easeInOut.transform(
                (cycle - start) / (end - start),
              );
              final c = -0.25 + p * 1.5;
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: [_unit(c - 0.14), _unit(c), _unit(c + 0.14)],
                ).createShader(bounds),
                child: child,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A heartbeat trace drawn by a glowing head; its spike lines up with the
/// icon's pulse.
class _PulseTracePainter extends CustomPainter {
  _PulseTracePainter(this.beat) : super(repaint: beat);

  final Animation<double> beat;

  static const int _samples = 140;

  static double _wave(double x) {
    double bump(double center, double width, double amount) {
      final d = (x - center) / width;
      return amount * math.exp(-d * d);
    }

    return bump(0.36, 0.028, -0.12) +
        bump(0.47, 0.010, 0.16) +
        bump(_kSpikeX, 0.011, -1) +
        bump(0.53, 0.011, 0.38) +
        bump(_kEchoX, 0.038, -0.24);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height * 0.58;
    final amp = size.height * 0.48;
    Offset at(double x) => Offset(x * size.width, mid + _wave(x) * amp);

    final ghost = Path();
    for (var i = 0; i <= _samples; i++) {
      final p = at(i / _samples);
      if (i == 0) {
        ghost.moveTo(p.dx, p.dy);
      } else {
        ghost.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      ghost,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    final head = _traceHeadAt(beat.value);
    final tail = head - _kTraceTail;
    final from = math.max(0.0, tail);
    final to = math.min(1.0, head);
    if (to <= from) return;

    final trail = Path();
    final steps = math.max(2, ((to - from) * _samples).ceil());
    for (var i = 0; i <= steps; i++) {
      final p = at(from + (to - from) * i / steps);
      if (i == 0) {
        trail.moveTo(p.dx, p.dy);
      } else {
        trail.lineTo(p.dx, p.dy);
      }
    }
    final shaderRect = Rect.fromLTRB(
      tail * size.width,
      0,
      head * size.width,
      size.height,
    );
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [
            _Night.rose.withValues(alpha: 0),
            _Night.rose.withValues(alpha: 0.22),
          ],
        ).createShader(shaderRect),
    );
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [
            _Night.violet.withValues(alpha: 0),
            _Night.rose.withValues(alpha: 0.9),
            Colors.white,
          ],
          stops: const [0, 0.7, 1],
        ).createShader(shaderRect),
    );

    if (head >= 0 && head <= 1) {
      final p = at(head);
      canvas.drawCircle(
        p,
        11,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _Night.rose.withValues(alpha: 0.6),
              _Night.rose.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: 11)),
      );
      canvas.drawCircle(p, 2.6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_PulseTracePainter oldDelegate) =>
      oldDelegate.beat != beat;
}

// ─── Tip card ───────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.index,
    required this.progress,
    required this.reduceMotion,
  });

  final ValueListenable<int> index;
  final Animation<double> progress;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Mostly opaque plum so drifting stars don't speckle the text.
          colors: [
            const Color(0xFF34184A).withValues(alpha: 0.86),
            const Color(0xFF1D0C2C).withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: index,
              builder: (context, i, _) {
                final currentKey = ValueKey<int>(i);
                return AnimatedSize(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 520),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...previous, ?current],
                    ),
                    transitionBuilder: (child, animation) {
                      // New tip rises from below; the old one drifts upward.
                      final incoming = child.key == currentKey;
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, incoming ? 0.22 : -0.22),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _TipContent(
                      key: currentKey,
                      message: _kLoadingMessages[i],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 4,
              width: double.infinity,
              child: CustomPaint(
                painter: _TipIndicatorPainter(
                  progress: progress,
                  index: index,
                  count: _kLoadingMessages.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipContent extends StatelessWidget {
  const _TipContent({super.key, required this.message});

  final _LoadingMessage message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_Night.rose, _Night.violet],
            ),
            boxShadow: [
              BoxShadow(
                color: _Night.rose.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(message.icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(message.badge),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: _Night.blush,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr(message.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr(message.subText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11.6,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Story-style indicator: the active tip stretches into a pill that fills
/// until the next tip rotates in.
class _TipIndicatorPainter extends CustomPainter {
  _TipIndicatorPainter({
    required this.progress,
    required this.index,
    required this.count,
  }) : super(repaint: Listenable.merge([progress, index]));

  final Animation<double> progress;
  final ValueListenable<int> index;
  final int count;

  static const double _dot = 4;
  static const double _pill = 26;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    final grow = Curves.easeOutCubic.transform(math.min(1.0, p / 0.12));
    final active = index.value;
    final previous = (active - 1 + count) % count;

    double widthOf(int i) {
      if (i == active) return _dot + (_pill - _dot) * grow;
      if (i == previous) return _dot + (_pill - _dot) * (1 - grow);
      return _dot;
    }

    var total = _gap * (count - 1);
    for (var i = 0; i < count; i++) {
      total += widthOf(i);
    }
    var x = (size.width - total) / 2;
    final top = (size.height - _dot) / 2;
    final track = Paint()..color = Colors.white.withValues(alpha: 0.18);

    for (var i = 0; i < count; i++) {
      final w = widthOf(i);
      canvas.drawRRect(
        RRect.fromLTRBR(x, top, x + w, top + _dot, const Radius.circular(_dot)),
        track,
      );
      if (i == active) {
        final fill = Rect.fromLTWH(x, top, math.max(_dot, w * p), _dot);
        canvas.drawRRect(
          RRect.fromRectAndRadius(fill, const Radius.circular(_dot)),
          Paint()
            ..shader = const LinearGradient(
              colors: [_Night.rose, _Night.lilac],
            ).createShader(fill),
        );
      }
      x += w + _gap;
    }
  }

  @override
  bool shouldRepaint(_TipIndicatorPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.index != index ||
      oldDelegate.count != count;
}
