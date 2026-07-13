part of '../soul_merge_screen.dart';

class FloatingMessage {
  final String text;
  final bool isSelf;
  final Offset position;
  final UniqueKey id = UniqueKey();

  FloatingMessage({
    required this.text,
    required this.isSelf,
    required this.position,
  });
}

class FloatingMessageWidget extends StatefulWidget {
  final FloatingMessage message;
  const FloatingMessageWidget({super.key, required this.message});

  @override
  State<FloatingMessageWidget> createState() => _FloatingMessageWidgetState();
}

class _FloatingMessageWidgetState extends State<FloatingMessageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _horizontalAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 15,
      ),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _slideAnim = Tween<double>(begin: 0.0, end: -120.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
      ),
    );

    _horizontalAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.message.isSelf ? null : widget.message.position.dx,
      right: widget.message.isSelf ? widget.message.position.dx : null,
      top: widget.message.position.dy,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Tạo dao động ngang nhỏ như bong bóng lơ lửng
          final wave = math.sin(_horizontalAnim.value * math.pi * 2) * 10;
          return Transform.translate(
            offset: Offset(wave, _slideAnim.value),
            child: Opacity(
              opacity: _opacityAnim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _scaleAnim.value,
                alignment: widget.message.isSelf ? Alignment.bottomRight : Alignment.bottomLeft,
                child: child,
              ),
            ),
          );
        },
        child: RepaintBoundary(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: widget.message.isSelf
                      ? const Color(0xFFFF4F93).withValues(alpha: 0.2)
                      : const Color(0xFF9C2A6F).withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(widget.message.isSelf ? 22 : 4),
                bottomRight: Radius.circular(widget.message.isSelf ? 4 : 22),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.message.isSelf
                          ? [
                              const Color(0xFFFF4F93).withValues(alpha: 0.85),
                              const Color(0xFFFF7EB3).withValues(alpha: 0.75),
                            ]
                          : [
                              const Color(0xFF6A11CB).withValues(alpha: 0.85),
                              const Color(0xFF9C2A6F).withValues(alpha: 0.75),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    widget.message.text,
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
