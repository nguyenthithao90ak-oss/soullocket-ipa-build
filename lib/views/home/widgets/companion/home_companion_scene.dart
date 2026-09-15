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
    this.pinToViewport = false,
    this.followScroll = false,
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

  /// Ghim bé tại góc an toàn của màn hình, không chạy theo layout/cuộn.
  final bool pinToViewport;

  /// Đường đi ở tọa độ nội dung; lớp vẽ dịch cùng ScrollPosition trong frame.
  final bool followScroll;
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
  final _paintOffset = ValueNotifier(Offset.zero);
  ScrollPosition? _scrollPosition;
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
      !(widget.captureMode?.value ?? false);

  // Cờ swipe của Home có thể bật ngay khi đặt tay, chưa phải chuyển tab.
  // Chỉ dừng chuyển động/âm thanh, không tháo bé khỏi lớp vẽ đang hiển thị.
  bool get _interactionPaused =>
      (widget.isSwiping?.value ?? false) ||
      (widget.isScrolling?.value ?? false) ||
      _localScrolling ||
      _downPointers.isNotEmpty;

  bool get _followingScroll =>
      widget.followScroll &&
      (_scrollPosition?.isScrollingNotifier.value ?? _localScrolling);

  void _observeScroll(ScrollPosition? position) {
    if (!widget.followScroll ||
        position == null ||
        axisDirectionToAxis(position.axisDirection) != Axis.vertical ||
        identical(position, _scrollPosition)) {
      return;
    }
    _scrollPosition?.removeListener(_scrollChanged);
    _scrollPosition?.isScrollingNotifier.removeListener(_scrollActivityChanged);
    _scrollPosition = position;
    position.addListener(_scrollChanged);
    position.isScrollingNotifier.addListener(_scrollActivityChanged);
    _scrollChanged();
  }

  void _scrollChanged() {
    final position = _scrollPosition;
    if (position == null || !position.hasPixels) return;
    final sign = position.axisDirection == AxisDirection.up ? 1.0 : -1.0;
    _paintOffset.value = Offset(0, position.pixels * sign);
  }

  void _scrollActivityChanged() {
    if (!mounted) return;
    _sync();
  }

  void _externalStateChanged() {
    if (!mounted) return;
    if (!_canShow) _clearPointers();
    _sync();
    _scheduleMeasure();
    _scheduleApproach();
  }

  void _sync() {
    final show = _canShow;
    final becameHidden = _visible.value && !show;
    if (!show) _clearPointers();
    _visible.value = show;
    final run =
        show &&
        widget.animate &&
        !_reduced &&
        (widget.pinToViewport || _followingScroll || !_interactionPaused) &&
        _motion.hasSurfaces;
    _audio.setEnabled(
      show &&
          widget.animate &&
          !_reduced &&
          _motion.hasSurfaces &&
          widget.soundEnabled &&
          !(widget.audioSuppressed?.value ?? false),
    );
    _audio.setPaused(_interactionPaused);
    if (run && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _lastTick = Duration.zero;
      // Giữ nguyên cả vị trí và độ cao cú nhảy khi người dùng chạm/giữ.
      // settle() ở đây sẽ làm bé rơi về mặt ô, trông như biến mất/chớp hình.
      if (!show || !_interactionPaused) _motion.settle();
    } else if (becameHidden) {
      // Home có thể bị che sau khi ngón tay đã dừng ticker. Vẫn phải
      // hủy lời chào/ý định cũ đúng một lần khi thực sự rời màn hình.
      _motion.settle();
    }
  }

  void _tick(Duration elapsed) {
    // Không đo layout hay rebuild Home theo từng frame của bé.
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    if (_motion.hasSurfaces) _motion.advance(delta);
    _audio.update(
      _motion.phase,
      greeting: _motion.greetingSerial,
      greetingActive: _motion.affection > 0,
    );
  }

  @override
  void didChangeMetrics() {
    // Viewport đổi khi xoay máy/resize cửa sổ, kể cả child không rebuild.
    _scheduleMeasure();
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
      // Trong lúc kéo, giữ hình học hợp lệ gần nhất. Đo lại sau khi thả
      // thay vì liên tục xóa/đổi đường đi theo các ô đang lướt khỏi màn hình.
      if (widget.enabled &&
          (!_canShow ||
              (!widget.pinToViewport &&
                  !widget.followScroll &&
                  _interactionPaused))) {
        return;
      }
      final root = _paintKey.currentContext?.findRenderObject();
      if (root is! RenderBox || !root.hasSize || root.size.isEmpty) return;
      var viewport = widget.safeInsets.deflateRect(Offset.zero & root.size);
      if (!widget.enabled) {
        _motion.setSurfaces(const [], viewport);
        _sync();
        return;
      }
      if (widget.pinToViewport) {
        _motion.setPinnedPosition(viewport.bottomRight, viewport);
        _sync();
        return;
      }
      final surfaces = <HomeCompanionSurface>[];
      for (final anchor in _anchors.toList(growable: false)) {
        if (!anchor.mounted || !anchor.widget.enabled) continue;
        final box = anchor._key.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        final transform = box.getTransformTo(root);
        final scroll = Scrollable.maybeOf(anchor.context)?.position;
        _observeScroll(scroll);
        final contentShift =
            widget.followScroll && identical(scroll, _scrollPosition)
            ? -_paintOffset.value
            : Offset.zero;
        final localRect = anchor.widget.insets.deflateRect(
          Offset.zero & box.size,
        );
        final rect = MatrixUtils.transformRect(
          transform,
          localRect,
        ).shift(contentShift);
        if (!rect.isFinite ||
            rect.isEmpty ||
            (!widget.followScroll && !rect.overlaps(viewport))) {
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
            points.map(
              (point) =>
                  MatrixUtils.transformPoint(transform, point) + contentShift,
            ),
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
            ).shift(contentShift),
          ),
        );
      }
      if (widget.followScroll && surfaces.isNotEmpty) {
        // Bao phủ các ô đã mount, không cắt đường đi theo mép viewport mỗi
        // lần cuộn. Thỏ ra khỏi khung cùng ô, không dịch chuyển tức thời sang ô khác.
        final bottom = surfaces.fold<double>(
          viewport.bottom,
          (value, surface) =>
              surface.bounds.bottom > value ? surface.bounds.bottom : value,
        );
        viewport = Rect.fromLTRB(
          viewport.left,
          viewport.top,
          viewport.right,
          bottom,
        );
      }
      _motion.setSurfaces(surfaces, viewport);
      _sync();
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (widget.followScroll &&
        notification.metrics.axis == Axis.vertical &&
        notification.context != null) {
      _observeScroll(Scrollable.maybeOf(notification.context!)?.position);
    }
    if (notification is ScrollStartNotification) {
      _localScrolling = true;
      _sync();
    } else if (notification is ScrollUpdateNotification &&
        (notification.scrollDelta ?? 0) != 0) {
      // Scrollable có thể thắng gesture ở vùng trống trước khi ngón tay
      // thật sự kéo. Chỉ loại lần chạm khi nội dung đã dịch chuyển.
      _dragged = true;
    } else if (notification is ScrollEndNotification) {
      _localScrolling = false;
      _sync();
      _scheduleApproach();
    }
    if (!widget.followScroll) _scheduleMeasure();
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
    _scheduleMeasure();
    if (!shortTap || !_canShow || !widget.animate || _reduced) return;
    // Unlock ngay trong thao tác thật; không tự phát âm khi vừa mở Home.
    if (widget.soundEnabled) _audio.unlock();
    // Gộp nhiều lần chạm trong cùng frame, chỉ đón điểm mới nhất.
    _pendingApproach = event.position;
    _scheduleApproach();
  }

  void _scheduleApproach() {
    if (_approachScheduled || _pendingApproach == null) return;
    _approachScheduled = true;
    // Đợi gesture gốc xử lý mở trang/bảng trước khi quyết định đuổi theo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _approachScheduled = false;
      final target = _pendingApproach;
      if (!mounted ||
          target == null ||
          !_canShow ||
          !(ModalRoute.isCurrentOf(context) ?? true)) {
        _pendingApproach = null;
        return;
      }
      // Parent có thể hạ cờ swipe ở frame sau PointerUp. Giữ lần chạm
      // hợp lệ tới khi cờ hạ, không bỏ mất thao tác hoặc chạy lúc đang kéo.
      if (_interactionPaused) return;
      _pendingApproach = null;
      if (!widget.animate || _reduced) return;
      final box = _paintKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final screenLocal = box.globalToLocal(target);
        final local =
            screenLocal -
            (widget.followScroll ? _paintOffset.value : Offset.zero);
        // Khi ghim, chỉ vuốt ve trực tiếp bé mới chào. Chạm nút/cuộn ở
        // nơi khác không khiến bé đuổi theo hoặc phát tiếng ngoài ý muốn.
        if (widget.pinToViewport && !_motion.isPetting(local)) return;
        final insidePaint = (Offset.zero & box.size).contains(screenLocal);
        if (insidePaint &&
            (widget.safeInsets
                    .deflateRect(Offset.zero & box.size)
                    .contains(screenLocal) ||
                _motion.isPetting(local))) {
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
    _scrollPosition?.removeListener(_scrollChanged);
    _scrollPosition?.isScrollingNotifier.removeListener(_scrollActivityChanged);
    _paintOffset.dispose();
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
            // Nhận cả chạm vào tai ở khoảng trống phía trên ô. Listener chỉ
            // quan sát pointer; nút và gesture của widget con vẫn xử lý trước.
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (_) {
              _clearPointers();
              _sync();
              _scheduleMeasure();
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
                                    paintOffset: widget.followScroll
                                        ? _paintOffset
                                        : null,
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
