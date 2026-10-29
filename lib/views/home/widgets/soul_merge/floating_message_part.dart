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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _slideAnim;
  bool _animate = false;
  bool _foreground = true;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 70),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 75),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _slideAnim = Tween<double>(
      begin: 0.0,
      end: -80.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));

    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    UiPrefs.notifier.addListener(_onMotionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _onMotionChanged() {
    if (mounted) setState(_syncMotion);
  }

  void _syncMotion() {
    _visible = _foreground && TickerMode.valuesOf(context).enabled;
    _animate = UiPrefs.resolveEffectProfile(
      state: UiPrefs.notifier.value,
      isWeb: kIsWeb,
      pauseAnimations: !_visible || MediaQuery.disableAnimationsOf(context),
    ).animationEnabled;
    if (_animate) {
      if (!_controller.isAnimating && !_controller.isCompleted) {
        _controller.forward();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) setState(_syncMotion);
  }

  @override
  void dispose() {
    UiPrefs.notifier.removeListener(_onMotionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final themeColor = widget.message.isSelf
        ? const Color(0xFFFF4F93)
        : const Color(0xFF9C2A6F);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.message.position.dx,
          top: widget.message.position.dy + (_animate ? _slideAnim.value : 0),
          child: RepaintBoundary(
            child: Opacity(
              opacity: _animate ? _opacityAnim.value.clamp(0.0, 1.0) : 1,
              child: Transform.scale(
                scale: _animate ? _scaleAnim.value : 1,
                child: child,
              ),
            ),
          ),
        );
      },
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          constraints: BoxConstraints(
            maxWidth: math.min(320, MediaQuery.sizeOf(context).width * .78),
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.message.isSelf ? 16 : 4),
              bottomRight: Radius.circular(widget.message.isSelf ? 4 : 16),
            ),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.25),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            widget.message.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
