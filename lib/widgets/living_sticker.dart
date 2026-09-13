import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../views/ui_prefs.dart';

import 'living_sticker_painter.dart';
import 'living_sticker_scene.dart';

/// Chế độ tĩnh cho ảnh xuất, chế độ nhẹ hoặc các vùng trang trí đã ẩn.
class StickerAnimationScope extends InheritedWidget {
  const StickerAnimationScope({
    super.key,
    required this.enabled,
    required super.child,
  });
  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StickerAnimationScope>()
          ?.enabled ??
      true;

  @override
  bool updateShouldNotify(StickerAnimationScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Vẽ từng bộ phận: không biến đổi toàn bộ ảnh, không tải thêm GIF từ mạng.
class LivingSticker extends StatefulWidget {
  const LivingSticker({
    super.key,
    required this.scene,
    this.width,
    this.height,
    this.animate = true,
    this.semanticLabel,
  });

  final LivingStickerScene scene;
  final double? width;
  final double? height;
  final bool animate;
  final String? semanticLabel;

  @override
  State<LivingSticker> createState() => _LivingStickerState();
}

class _LivingStickerState extends State<LivingSticker>
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
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    UiPrefs.notifier.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LivingSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene) _controller.value = 0;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final effects = UiPrefs.resolveEffectProfile(
      state: UiPrefs.notifier.value,
      isWeb: kIsWeb,
    );
    final enabled =
        widget.animate &&
        effects.animationEnabled &&
        _foreground &&
        StickerAnimationScope.enabledOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!enabled) {
      _controller.stop();
      if (_controller.value != 0) _controller.value = 0;
    }
  }

  @override
  void dispose() {
    UiPrefs.notifier.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: widget.semanticLabel,
    child: RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width =
                widget.width ??
                (constraints.hasBoundedWidth ? constraints.maxWidth : 72.0);
            final height =
                widget.height ??
                (constraints.hasBoundedHeight ? constraints.maxHeight : width);
            return CustomPaint(
              size: Size(math.max(0, width), math.max(0, height)),
              painter: LivingStickerPainter(
                scene: widget.scene,
                animation: _controller,
              ),
              isComplex: true,
              willChange: _controller.isAnimating,
            );
          },
        ),
      ),
    ),
  );
}
