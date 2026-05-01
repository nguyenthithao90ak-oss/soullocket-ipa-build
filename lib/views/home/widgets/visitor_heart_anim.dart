import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../ui_prefs.dart';

/// ============================================================
///  VisitorHeartAnim — Drop Heart Animation trên hồ sơ bạn
///  Dùng: VisitorHeartAnim.drop(context) để trigger
/// ============================================================

class VisitorHeartAnim extends StatefulWidget {
  final Widget child; // nội dung bên dưới (avatar, profile...)
  final bool enabled;

  const VisitorHeartAnim({
    super.key,
    required this.child,
    this.enabled = true,
  });

  // ── Static trigger (overlay) ──────────────────────────────
  static OverlayEntry? _entry;

  static void drop(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => _HeartDropOverlay(
        onDone: () {
          _entry?.remove();
          _entry = null;
        },
      ),
    );
    overlay.insert(_entry!);
  }

  @override
  State<VisitorHeartAnim> createState() => _VisitorHeartAnimState();
}

class _VisitorHeartAnimState extends State<VisitorHeartAnim> {
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled
          ? () {
              _tapCount++;
              if (_tapCount % 1 == 0) {
                VisitorHeartAnim.drop(context);
              }
            }
          : null,
      child: widget.child,
    );
  }
}

// ─── Overlay that shows floating hearts ──────────────────────
class _HeartDropOverlay extends StatefulWidget {
  final VoidCallback onDone;

  const _HeartDropOverlay({required this.onDone});

  @override
  State<_HeartDropOverlay> createState() => _HeartDropOverlayState();
}

class _HeartDropOverlayState extends State<_HeartDropOverlay> {
  final List<_HeartParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _spawn();
  }

  void _spawn() {
    final uiPrefs = UiPrefs.notifier.value;
    final qualityKey = uiPrefs.liteMode
        ? 'low'
        : (uiPrefs.graphicsQualityKey == 'auto'
            ? UiPrefs.getAutoGraphicsQuality()
            : uiPrefs.graphicsQualityKey);
    final heartCount = switch (qualityKey) {
      'low' => 1,
      'high' => 12,
      _ => 5,
    };

    for (int i = 0; i < heartCount; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (!mounted) return;
        setState(() {
          _particles.add(_HeartParticle(
            startX: 0.2 + _rng.nextDouble() * 0.6,
            delay: i * 80,
            size: 20 + _rng.nextDouble() * 24,
            hue: 320 + _rng.nextDouble() * 40,
            driftX: (_rng.nextDouble() - 0.5) * 0.2,
          ));
        });
      });
    }

    // Done after animation
    Future.delayed(const Duration(milliseconds: 2500), widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: _particles.map((p) => _AnimatedHeart(particle: p)).toList(),
      ),
    );
  }
}

class _HeartParticle {
  final double startX;
  final int delay;
  final double size;
  final double hue;
  final double driftX;

  const _HeartParticle({
    required this.startX,
    required this.delay,
    required this.size,
    required this.hue,
    required this.driftX,
  });
}

class _AnimatedHeart extends StatefulWidget {
  final _HeartParticle particle;

  const _AnimatedHeart({required this.particle});

  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _yAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _yAnim = Tween<double>(begin: 0.85, end: 0.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.2), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
    ]).animate(_ctrl);

    Future.delayed(Duration(milliseconds: widget.particle.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final x = widget.particle.startX + widget.particle.driftX * _ctrl.value;
        final y = _yAnim.value;

        return Positioned(
          left: x * size.width - widget.particle.size / 2,
          top: y * size.height,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: child,
            ),
          ),
        );
      },
      child: Icon(
        Icons.favorite,
        size: widget.particle.size,
        color: HSLColor.fromAHSL(1, widget.particle.hue, 0.9, 0.6).toColor(),
      ),
    );
  }
}

// ─── Inline heart button for profile cards ───────────────────
class HeartDropButton extends StatefulWidget {
  final int initialCount;
  final bool hasDropped;
  final VoidCallback onDrop;

  const HeartDropButton({
    super.key,
    required this.initialCount,
    required this.hasDropped,
    required this.onDrop,
  });

  @override
  State<HeartDropButton> createState() => _HeartDropButtonState();
}

class _HeartDropButtonState extends State<HeartDropButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late bool _dropped;
  late int _count;

  @override
  void initState() {
    super.initState();
    _dropped = widget.hasDropped;
    _count = widget.initialCount;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handle() {
    if (_dropped) return;
    setState(() {
      _dropped = true;
      _count++;
    });
    _ctrl.forward(from: 0);
    VisitorHeartAnim.drop(context);
    widget.onDrop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _dropped
              ? const Color(0xFFE91E8C).withOpacity(0.15)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _dropped
                ? const Color(0xFFE91E8C).withOpacity(0.6)
                : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.4).animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
              ),
              child: Icon(
                _dropped ? Icons.favorite : Icons.favorite_border,
                color: _dropped ? const Color(0xFFE91E8C) : Colors.white54,
                size: 18,
              ),
            ),
            SLSpacing.w8,
            Text(
              '$_count',
              style: TextStyle(
                color: _dropped ? const Color(0xFFE91E8C) : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
