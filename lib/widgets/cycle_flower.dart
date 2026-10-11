import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Hoa dùng chung cho Chu kỳ và mẫu widget; nghỉ khi ẩn hoặc giảm chuyển động.
class CycleFlower extends StatefulWidget {
  const CycleFlower({super.key, this.width = 72, this.animated = true});

  final double width;
  final bool animated;

  @override
  State<CycleFlower> createState() => _CycleFlowerState();
}

class _CycleFlowerState extends State<CycleFlower>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4400),
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(covariant CycleFlower oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  void _updateMotion() {
    final media = MediaQuery.maybeOf(context);
    final enabled =
        widget.animated &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !(media?.disableAnimations ?? false);
    if (enabled) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.width / 1.2,
        child: AnimatedBuilder(
          animation: _motion,
          child: SvgPicture.asset('assets/images/widget_stickers/cycle.svg'),
          builder: (context, child) {
            final wave = math.sin(_motion.value * math.pi * 2);
            return Transform.translate(
              offset: Offset(0, wave * 2),
              child: Transform.rotate(
                key: const ValueKey('cycle-flower-motion'),
                angle: wave * .06,
                child: child,
              ),
            );
          },
        ),
      ),
    ),
  );
}
