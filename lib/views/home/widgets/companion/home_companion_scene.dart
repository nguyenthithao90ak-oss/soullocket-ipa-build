import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'home_companion_motion.dart';
import 'home_companion_audio.dart';
import 'home_companion_outline.dart';
import 'home_companion_painter.dart';

/// Lớp trang trí cục bộ: chỉ quan sát chạm, không tham gia gesture arena.
class HomeCompanionScene extends StatefulWidget {
  const HomeCompanionScene({
    super.key,
    required this.child,
    required this.enabled,
    required this.animate,
    required this.isActive,
    this.foreground,
    this.isScrolling,
    this.isSwiping,
    this.captureMode,
    this.soundEnabled = false,
    this.audioSuppressed,
    this.safeInsets = const EdgeInsets.fromLTRB(26, 84, 26, 92),
    this.motion,
    this.audio,
  });

  final Widget child;

  /// Nút header được vẽ trên bé, vẫn là con trực tiếp của Stack.
  final Widget? foreground;
  final bool enabled;
  final bool animate;
  final bool soundEnabled;
  final ValueListenable<bool>? audioSuppressed;
  final ValueListenable<bool> isActive;
  final ValueListenable<bool>? isScrolling;
  final ValueListenable<bool>? isSwiping;
  final ValueListenable<bool>? captureMode;

  /// Giới hạn vị trí chân; khoảng trên chừa đủ chỗ cho cả tai thỏ.
  final EdgeInsets safeInsets;

  /// Cho phép kiểm thử độc lập; scene chỉ dispose bộ điều khiển tự tạo.
  final HomeCompanionMotion? motion;
  final HomeCompanionAudio? audio;

  @override
  State<HomeCompanionScene> createState() => _HomeCompanionSceneState();
}

class _HomeCompanionSceneState extends State<HomeCompanionScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late HomeCompanionMotion _motion;
  late HomeCompanionAudio _audio;
  late final Ticker _ticker;
  final _paintKey = GlobalKey();
  final _visible = ValueNotifier(false);
  final Set<_HomeCompanionAnchorState> _anchors = {};
  Duration _lastTick = Duration.zero;
  bool _measureScheduled = false;
  bool _foreground = true;
  bool _routeCurrent = true;
  bool _tickerAllowed = true;
  bool _reduced = false;
  bool _localScrolling = false;
  int? _pointer;
  Offset? _pointerOrigin;
  Duration? _pointerStart;
  Timer? _holdTimer;
  bool _dragged = false;
  Offset? _pendingApproach;
  bool _approachScheduled = false;
  final Set<int> _downPointers = {};

  @override
  void initState() {
    super.initState();
    _motion = widget.motion ?? HomeCompanionMotion();
    _audio = widget.audio ?? HomeCompanionAudio();
    _ticker = createTicker(_tick);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _listen(widget, true);
  }

  void _listen(HomeCompanionScene config, bool add) {
    for (final source in <ValueListenable<bool>?>[
      config.isActive,
      config.isScrolling,
      config.isSwiping,
      config.captureMode,
      config.audioSuppressed,
    ]) {
      if (add) {
        source?.addListener(_externalStateChanged);
      } else {
        source?.removeListener(_externalStateChanged);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _tickerAllowed = TickerMode.valuesOf(context).enabled;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant HomeCompanionScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen(oldWidget, false);
    _listen(widget, true);
    if (oldWidget.motion != widget.motion) {
      _ticker.stop();
      if (oldWidget.motion == null) _motion.dispose();
      _motion = widget.motion ?? HomeCompanionMotion();
    }
    if (oldWidget.audio != widget.audio) {
      _audio.setEnabled(false);
      if (oldWidget.audio == null) _audio.dispose();
      _audio = widget.audio ?? HomeCompanionAudio();
    }
    _sync();
    _scheduleMeasure();
  }

  bool get _canShow =>
      widget.enabled &&
      _foreground &&
      _routeCurrent &&
      _tickerAllowed &&
      widget.isActive.value &&
      !(widget.captureMode?.value ?? false) &&
      !(widget.isSwiping?.value ?? false) &&
      !(widget.isScrolling?.value ?? false) &&
      !_localScrolling;

  void _externalStateChanged() {
    if (!mounted) return;
    if (!_canShow) _clearPointers();
    _sync();
    _scheduleMeasure();
  }

  void _sync() {
    final show = _canShow;
    if (!show) _clearPointers();
    _visible.value = show;
    final run =
        show &&
        widget.animate &&
        !_reduced &&
        _downPointers.isEmpty &&
        _motion.hasSurfaces;
    _audio.setEnabled(
      run && widget.soundEnabled && !(widget.audioSuppressed?.value ?? false),
    );
    if (run && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _lastTick = Duration.zero;
      _motion.settle();
    }
  }

  void _tick(Duration elapsed) {
    // Không đo layout hay rebuild Home theo từng frame của bé.
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    if (_motion.hasSurfaces) _motion.advance(delta);
    _audio.update(_motion.phase);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _clearPointers();
    _sync();
    if (_foreground) _scheduleMeasure();
  }

  void _register(_HomeCompanionAnchorState anchor) {
    _anchors.add(anchor);
    _scheduleMeasure();
  }

  void _unregister(_HomeCompanionAnchorState anchor) {
    _anchors.remove(anchor);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (!mounted || _measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final root = _paintKey.currentContext?.findRenderObject();
      if (root is! RenderBox || !root.hasSize || root.size.isEmpty) return;
      final viewport = widget.safeInsets.deflateRect(Offset.zero & root.size);
      if (!widget.enabled) {
        _motion.setSurfaces(const [], viewport);
        _sync();
        return;
      }
      final surfaces = <HomeCompanionSurface>[];
      for (final anchor in _anchors.toList(growable: false)) {
        if (!anchor.mounted || !anchor.widget.enabled) continue;
        final box = anchor._key.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        final transform = box.getTransformTo(root);
        final localRect = anchor.widget.insets.deflateRect(
          Offset.zero & box.size,
        );
        final rect = MatrixUtils.transformRect(transform, localRect);
        if (!rect.isFinite || rect.isEmpty || !rect.overlaps(viewport)) {
          continue;
        }
        List<Offset>? outline;
        if (anchor.widget.shape == HomeCompanionSurfaceShape.outline) {
          final path =
              anchor.widget.pathBuilder?.call(localRect) ??
              anchor.widget.border.getOuterPath(
                localRect,
                textDirection: Directionality.of(context),
              );
          final points = sampleHomeCompanionOutline(path);
          if (points == null) continue;
          outline = List.unmodifiable(
            points.map((point) => MatrixUtils.transformPoint(transform, point)),
          );
        }
        surfaces.add(
          HomeCompanionSurface(
            id: anchor.widget.id,
            bounds: rect,
            shape: anchor.widget.shape,
            outline: outline,
            obstacleBounds: MatrixUtils.transformRect(
              box.getTransformTo(root),
              Offset.zero & box.size,
            ),
          ),
        );
      }
      _motion.setSurfaces(surfaces, viewport);
      _sync();
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _localScrolling = true;
      _dragged = true;
      _sync();
    } else if (notification is ScrollEndNotification) {
      _localScrolling = false;
      _sync();
    }
    _scheduleMeasure();
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_canShow) return;
    _pendingApproach = null;
    _downPointers.add(event.pointer);
    if (_downPointers.length == 1) {
      _pointer = event.pointer;
      _pointerOrigin = event.position;
      _pointerStart = event.timeStamp;
      _dragged = false;
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: 350), () {
        // Timestamp của một số nguồn pointer/test không tăng lúc giữ yên.
        // Giữ lâu luôn nhường gesture gốc, kể cả không có pointer move.
        _dragged = true;
      });
    } else {
      _dragged = true;
    }
    _sync();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer == event.pointer &&
        _pointerOrigin != null &&
        (event.position - _pointerOrigin!).distance > kTouchSlop) {
      _dragged = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final shortTap =
        _pointer == event.pointer &&
        !_dragged &&
        _downPointers.length == 1 &&
        _pointerStart != null &&
        event.timeStamp - _pointerStart! < const Duration(milliseconds: 350);
    _downPointers.remove(event.pointer);
    if (_downPointers.isEmpty) _clearPointers();
    _sync();
    if (!shortTap || !_canShow || !widget.animate || _reduced) return;
    // Unlock ngay trong thao tác thật; không tự phát âm khi vừa mở Home.
    if (widget.soundEnabled) _audio.unlock();
    // Gộp nhiều lần chạm trong cùng frame, chỉ đón điểm mới nhất.
    _pendingApproach = event.position;
    if (_approachScheduled) return;
    _approachScheduled = true;
    // Đợi gesture gốc xử lý mở trang/bảng trước khi quyết định đuổi theo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _approachScheduled = false;
      final target = _pendingApproach;
      _pendingApproach = null;
      if (!mounted ||
          target == null ||
          _downPointers.isNotEmpty ||
          !_canShow ||
          !(ModalRoute.isCurrentOf(context) ?? true)) {
        return;
      }
      final box = _paintKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final local = box.globalToLocal(target);
        if (widget.safeInsets
            .deflateRect(Offset.zero & box.size)
            .contains(local)) {
          _motion.approach(local);
        }
      }
    });
  }

  void _clearPointers() {
    _pendingApproach = null;
    _holdTimer?.cancel();
    _holdTimer = null;
    _downPointers.clear();
    _pointer = null;
    _pointerOrigin = null;
    _pointerStart = null;
    _dragged = false;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _listen(widget, false);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _audio.setEnabled(false);
    if (widget.audio == null) _audio.dispose();
    _visible.dispose();
    if (widget.motion == null) _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return _HomeCompanionScope(
      scene: this,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleMeasure();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (_) {
              _clearPointers();
              _sync();
            },
            child: Stack(
              key: _paintKey,
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _visible,
                        builder: (context, visible, _) => visible
                            ? RepaintBoundary(
                                child: CustomPaint(
                                  key: const ValueKey('home-companion-paint'),
                                  painter: HomeCompanionPainter(
                                    motion: _motion,
                                    showEffects: widget.animate && !_reduced,
                                    darkMode:
                                        Theme.of(context).brightness ==
                                        Brightness.dark,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                if (widget.foreground != null) widget.foreground!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCompanionScope extends InheritedWidget {
  const _HomeCompanionScope({required this.scene, required super.child});
  final _HomeCompanionSceneState scene;
  @override
  bool updateShouldNotify(_HomeCompanionScope oldWidget) =>
      scene != oldWidget.scene;
}

/// Mốc bề mặt được đo từ layout thật, không phụ thuộc tọa độ ảnh chụp.
class HomeCompanionAnchor extends StatefulWidget {
  const HomeCompanionAnchor({
    super.key,
    required this.id,
    required this.shape,
    required this.child,
    this.enabled = true,
    this.insets = EdgeInsets.zero,
    this.border = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
    ),
    this.pathBuilder,
  });
  final String id;
  final HomeCompanionSurfaceShape shape;
  final Widget child;
  final bool enabled;
  final EdgeInsets insets;
  final ShapeBorder border;
  final Path Function(Rect)? pathBuilder;
  @override
  State<HomeCompanionAnchor> createState() => _HomeCompanionAnchorState();
}

class _HomeCompanionAnchorState extends State<HomeCompanionAnchor> {
  final _key = GlobalKey();
  _HomeCompanionSceneState? _scene;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context
        .dependOnInheritedWidgetOfExactType<_HomeCompanionScope>()
        ?.scene;
    if (_scene != next) {
      _scene?._unregister(this);
      _scene = next;
      _scene?._register(this);
    }
  }

  @override
  void dispose() {
    _scene?._unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scene?._scheduleMeasure();
    return SizeChangedLayoutNotifier(
      child: SizedBox(key: _key, child: widget.child),
    );
  }
}
