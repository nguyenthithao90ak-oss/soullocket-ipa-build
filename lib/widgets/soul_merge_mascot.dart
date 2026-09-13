import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'soul_merge_mascot_painter.dart';

/// Icon đôi có khớp chuyển động riêng; thân và khung luôn đứng yên.
class SoulMergeMascot extends StatefulWidget {
  const SoulMergeMascot({
    super.key,
    required this.size,
    this.animate = true,
    this.framed = false,
  });

  final double size;
  final bool animate;
  final bool framed;

  @override
  State<SoulMergeMascot> createState() => _SoulMergeMascotState();
}

class _SoulMergeMascotState extends State<SoulMergeMascot>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
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
  void didUpdateWidget(covariant SoulMergeMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    final enabled =
        widget.animate &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!enabled) {
      _controller.stop();
      // Hiển thị tư thế nghỉ, không dừng ở giữa lần chớp mắt.
      if (_controller.value != 0) _controller.value = 0;
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
    return Semantics(
      image: true,
      label: context.tr('p4_soul_title'),
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: DecoratedBox(
            decoration: widget.framed
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFDF9), Color(0xFFFFEDF2)],
                    ),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAE5673).withValues(alpha: 0.12),
                        blurRadius: widget.size * 0.14,
                        offset: Offset(0, widget.size * 0.04),
                      ),
                    ],
                  )
                : const BoxDecoration(),
            child: Padding(
              padding: EdgeInsets.all(widget.framed ? widget.size * 0.045 : 0),
              child: CustomPaint(
                painter: SoulMergeMascotPainter(animation: _controller),
                isComplex: true,
                willChange: widget.animate,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
