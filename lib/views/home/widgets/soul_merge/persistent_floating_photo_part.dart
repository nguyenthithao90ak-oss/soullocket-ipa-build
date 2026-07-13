part of '../soul_merge_screen.dart';

class PersistentFloatingPhotoWidget extends StatefulWidget {
  final String url;
  final int index;
  const PersistentFloatingPhotoWidget(
      {super.key, required this.url, required this.index});

  @override
  State<PersistentFloatingPhotoWidget> createState() =>
      _PersistentFloatingPhotoWidgetState();
}

class _PersistentFloatingPhotoWidgetState
    extends State<PersistentFloatingPhotoWidget> {
  double _x = 0;
  double _y = 0;
  double _angle = 0;
  Timer? _timer;
  bool _isDragging = false;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _randomizePosition();
      _timer = Timer.periodic(
          const Duration(seconds: 8), (_) => _randomizePosition());
    });
  }

  void _randomizePosition() {
    if (!mounted || _isDragging) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      _x = 20 + _random.nextDouble() * (size.width - 140);
      _y = 100 + _random.nextDouble() * (size.height - 400);
      _angle = (_random.nextDouble() - 0.5) * 0.3;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_x == 0 && _y == 0) return const SizedBox();

    Widget content = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _timer?.cancel();
        setState(() => _isDragging = true);
      },
      onPointerMove: (event) {
        if (_isDragging) {
          setState(() {
            _x += event.delta.dx;
            _y += event.delta.dy;
          });
        }
      },
      onPointerUp: (event) {
        setState(() => _isDragging = false);
        _timer?.cancel();
        _timer = Timer.periodic(
            const Duration(seconds: 8), (_) => _randomizePosition());
      },
      onPointerCancel: (event) {
        setState(() => _isDragging = false);
        _timer?.cancel();
        _timer = Timer.periodic(
            const Duration(seconds: 8), (_) => _randomizePosition());
      },
      child: Transform.rotate(
        angle: _angle,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
            image: DecorationImage(
              image: CachedNetworkImageProvider(widget.url),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );

    if (_isDragging) {
      return Positioned(left: _x, top: _y, child: content);
    }

    return AnimatedPositioned(
      duration: const Duration(seconds: 8),
      curve: Curves.easeInOutSine,
      left: _x,
      top: _y,
      child: content,
    );
  }
}

// ─── Cute Background Pattern Painter ──────────────────────────────────────────
