import 'package:flutter/material.dart';

class MapTiltCard extends StatefulWidget {
  final Widget child;

  const MapTiltCard({
    super.key,
    required this.child,
  });

  @override
  State<MapTiltCard> createState() => _MapTiltCardState();
}

class _MapTiltCardState extends State<MapTiltCard> {
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  void _onPointerMove(PointerEvent event, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final dx = (event.localPosition.dx / size.width) - 0.5;
    final dy = (event.localPosition.dy / size.height) - 0.5;
    setState(() {
      _tiltX = -dy * 0.12; // tilt pitch
      _tiltY = dx * 0.12;  // tilt roll
    });
  }

  void _onPointerExit(PointerEvent event) {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerMove: (e) => _onPointerMove(e, size),
          onPointerHover: (e) => _onPointerMove(e, size),
          onPointerCancel: _onPointerExit,
          onPointerUp: _onPointerExit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateX(_tiltX)
              ..rotateY(_tiltY),
            transformAlignment: Alignment.center,
            child: widget.child,
          ),
        );
      },
    );
  }
}
