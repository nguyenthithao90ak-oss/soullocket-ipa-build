part of 'legacy_media_feed_reference_screen.dart';

// ─── Hiệu ứng Trái tim bay (Gray Style) ──────────────────────────────
class _FlyingHeart {
  final int id;
  final Offset position;
  final double angle;
  final double size;

  _FlyingHeart({
    required this.id,
    required this.position,
  })  : angle = (DateTime.now().microsecondsSinceEpoch % 100 - 50) / 50.0,
        size = 40.0 + (DateTime.now().microsecondsSinceEpoch % 20);
}

class _HeartAnimation extends StatefulWidget {
  final _FlyingHeart heart;
  final VoidCallback onComplete;

  const _HeartAnimation({
    super.key,
    required this.heart,
    required this.onComplete,
  });

  @override
  State<_HeartAnimation> createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<_HeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<Offset> _travel;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_ctrl);

    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 70),
    ]).animate(_ctrl);

    // Bay lên và hơi nghiêng
    final endOffset = Offset(
      widget.heart.angle * 100,
      -300 - (DateTime.now().microsecondsSinceEpoch % 100),
    );

    _travel = Tween<Offset>(
      begin: Offset.zero,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.heart.position.dx - (widget.heart.size / 2),
      top: widget.heart.position.dy - (widget.heart.size / 2),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
              offset: _travel.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Transform.rotate(
                  angle: widget.heart.angle * 0.3,
                  child: Icon(
                    Icons.favorite_rounded,
                    color: const Color(0xFFE91E63).withOpacity(0.9),
                    size: widget.heart.size,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
