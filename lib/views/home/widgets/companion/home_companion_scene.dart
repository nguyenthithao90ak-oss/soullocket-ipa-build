import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'home_companion_motion.dart';
import 'home_companion_audio.dart';
import 'home_companion_outline.dart';
import 'home_companion_painter.dart';
import 'home_companion_play.dart';
import 'home_companion_wardrobe.dart';
import '../../../ui_prefs.dart';

/// Lớp trang trí cục bộ: quan sát chạm nền; chỉ nhận tap/giữ đúng trên bé.
/// Gesture kéo vẫn nhường Scrollable, không phủ vùng bắt chạm toàn màn hình.
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
    this.safeInsets = const EdgeInsets.fromLTRB(32, 92, 32, 92),
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
  // Dùng chung ticker/layout với thỏ; không có timer hoặc âm thanh nền thứ hai.
  final _buddy = HomeCompanionMotion(initialSpacing: 60, createsDust: false);
  double _nextMeetAt = 4;
  double _nextHelloAt = 7;
  double _nextPrankAt = 18;
  bool _bearPranksNext = false;
  final _play = HomeCompanionPlay();
  HomeCompanionCharacter? _pendingPlay;
  double _playDeadline = 0;
  bool _wardrobeOpen = false;
  bool _spriteHandledThisTap = false;
  bool _spriteGestureRejected = false;
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
  HomeCompanionCharacter? _pendingSprite;
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
      !_wardrobeOpen &&
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
    if (!show || !widget.animate || _reduced) {
      _play.cancel();
      _pendingPlay = null;
    }
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
      if (!show || !_interactionPaused) {
        _motion.settle();
        _buddy.settle();
      }
    } else if (becameHidden) {
      // Home có thể bị che sau khi ngón tay đã dừng ticker. Vẫn phải
      // hủy lời chào/ý định cũ đúng một lần khi thực sự rời màn hình.
      _motion.settle();
      _buddy.settle();
    }
  }

  void _tick(Duration elapsed) {
    // Không đo layout hay rebuild Home theo từng frame của bé.
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    final wasPlaying = _play.active;
    _play.advance(delta);
    if (!wasPlaying) {
      if (_motion.hasSurfaces) _motion.advance(delta);
      if (_buddy.hasSurfaces) _buddy.advance(delta);
    }
    if (_pendingPlay != null && !_play.active) {
      if (_buddy.elapsedSeconds > _playDeadline ||
          _play.start(_pendingPlay!, _motion, _buddy)) {
        _pendingPlay = null;
      }
    }
    if (!_play.active &&
        !widget.pinToViewport &&
        _buddy.elapsedSeconds >= _nextPrankAt) {
      _nextPrankAt = _buddy.elapsedSeconds + 18;
      if (_play.start(
        _bearPranksNext
            ? HomeCompanionCharacter.bear
            : HomeCompanionCharacter.bunny,
        _motion,
        _buddy,
      )) {
        _bearPranksNext = !_bearPranksNext;
      }
    }
    if (!_play.active &&
        !widget.pinToViewport &&
        _buddy.elapsedSeconds >= _nextMeetAt) {
      // Xen kẽ tự khám phá và tìm bạn; không giành đường đi/việc dọn bụi của thỏ.
      _nextMeetAt = _buddy.elapsedSeconds + 3.6;
      _buddy.visitFriend(_motion);
    }
    final separation = _buddy.position - _motion.position;
    if (!_play.active &&
        !widget.pinToViewport &&
        _buddy.elapsedSeconds >= _nextHelloAt &&
        separation.distance >= 42 &&
        separation.distance <= 90 &&
        separation.dy.abs() < 14) {
      _nextHelloAt = _buddy.elapsedSeconds + 16;
      _motion.greetFriend(_buddy);
      _buddy.greetFriend(_motion);
    }
    _audio.update(
      _play.active ? HomeCompanionPhase.idle : _motion.phase,
      greeting: _motion.greetingSerial + _buddy.greetingSerial,
      // Chừa khoảng yên cho tiếng oa ở điểm va chạm, không phát chào trước
      // rồi khiến cooldown nuốt mất âm thanh chính của trò đùa.
      greetingActive:
          !_play.active && (_motion.affection > 0 || _buddy.affection > 0),
      playfulImpact: _play.impactSerial,
    );
  }

  HomeCompanionCharacter? _spriteAt(Offset global) {
    if (!_canShow) return null;
    final box = _paintKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final screen = box.globalToLocal(global);
    if (!(Offset.zero & box.size).contains(screen)) return null;
    final local =
        screen - (widget.followScroll ? _paintOffset.value : Offset.zero);
    HomeCompanionCharacter? found;
    var nearest = double.infinity;
    for (final character in HomeCompanionCharacter.values) {
      final motion = character == HomeCompanionCharacter.bunny
          ? _motion
          : _buddy;
      if (!motion.hasSurfaces) continue;
      final pose = _play.pose(character);
      final center =
          motion.position +
          pose.offset -
          Offset(
            0,
            32 + (widget.animate && !_reduced ? motion.hopLift + pose.lift : 0),
          );
      final bounds = Rect.fromCenter(
        center: center,
        width: character == HomeCompanionCharacter.bear ? 54 : 48,
        height: 70,
      );
      if (bounds.contains(local) && (center - local).distance < nearest) {
        found = character;
        nearest = (center - local).distance;
      }
    }
    return found;
  }

  void _tapSprite(Offset global) {
    final character = _spriteAt(global);
    if (character == null || _spriteGestureRejected) return;
    _spriteHandledThisTap = true;
    if (!widget.animate || _reduced) return;
    if (widget.soundEnabled) _audio.unlock();
    _pendingSprite = character;
    _pendingApproach = global;
    _scheduleApproach();
  }

  void _playWith(HomeCompanionCharacter character) {
    // Lần chạm mới thay thế lời mời đang đợi, không phát lại sau cooldown.
    _pendingPlay = null;
    final pet = character == HomeCompanionCharacter.bunny ? _motion : _buddy;
    final friend = character == HomeCompanionCharacter.bunny ? _buddy : _motion;
    if (!_play.active) {
      pet.approach(pet.position - Offset(0, 28 + pet.hopLift));
    }
    if (widget.pinToViewport) {
      return;
    }
    if (!_play.start(character, _motion, _buddy)) {
      if (!_play.active) {
        pet.visitFriend(friend, userInvited: true);
        _pendingPlay = character;
        _playDeadline = _buddy.elapsedSeconds + 8;
      }
    }
  }

  Future<void> _openWardrobe(Offset global) async {
    final character = _spriteAt(global);
    if (character == null ||
        _wardrobeOpen ||
        _spriteGestureRejected ||
        _downPointers.length != 1 ||
        _localScrolling) {
      return;
    }
    _spriteHandledThisTap = true;
    _wardrobeOpen = true;
    _sync();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HomeCompanionWardrobe(
          character: character,
          initial:
              UiPrefs.companionOutfits.value[character] ??
              HomeCompanionOutfit.defaults(character),
          onSave: (outfit) => UiPrefs.setCompanionOutfit(character, outfit),
        ),
      );
    } finally {
      if (mounted) {
        _wardrobeOpen = false;
        _sync();
        _scheduleMeasure();
      }
    }
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
        _buddy.setSurfaces(const [], viewport);
        _sync();
        return;
      }
      if (widget.pinToViewport) {
        _motion.setPinnedPosition(viewport.bottomRight, viewport);
        _buddy.setPinnedPosition(
          viewport.bottomRight - const Offset(56, 0),
          viewport,
        );
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
      final feet = _motion.position;
      final buddyFeet = _buddy.position;
      _motion.setSurfaces(surfaces, viewport);
      _buddy.setSurfaces(surfaces, viewport);
      if (feet != _motion.position || buddyFeet != _buddy.position) {
        // Khi resize/đổi layout làm neo chân đổi, không dùng cú nhảy tương
        // đối của layout cũ. Cuộn giữ nguyên tọa độ nội dung nên không bị hủy.
        _play.cancel();
        _pendingPlay = null;
      }
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
    _spriteHandledThisTap = false;
    _downPointers.add(event.pointer);
    if (_downPointers.length == 1) {
      _spriteGestureRejected = false;
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
      _spriteGestureRejected = true;
    }
    _sync();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer == event.pointer &&
        _pointerOrigin != null &&
        (event.position - _pointerOrigin!).distance > kTouchSlop) {
      _dragged = true;
      _spriteGestureRejected = true;
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
    if (!shortTap ||
        _spriteHandledThisTap ||
        !_canShow ||
        !widget.animate ||
        _reduced) {
      return;
    }
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
      final sprite = _pendingSprite;
      _pendingSprite = null;
      _pendingApproach = null;
      if (!widget.animate || _reduced) return;
      if (sprite != null) {
        _playWith(sprite);
        return;
      }
      final box = _paintKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final screenLocal = box.globalToLocal(target);
        final local =
            screenLocal -
            (widget.followScroll ? _paintOffset.value : Offset.zero);
        // Khi ghim, chỉ vuốt ve trực tiếp bé mới chào. Chạm nút/cuộn ở
        // nơi khác không khiến bé đuổi theo hoặc phát tiếng ngoài ý muốn.
        if (widget.pinToViewport &&
            !_motion.isPetting(local) &&
            !_buddy.isPetting(local)) {
          return;
        }
        final insidePaint = (Offset.zero & box.size).contains(screenLocal);
        if (insidePaint &&
            (widget.safeInsets
                    .deflateRect(Offset.zero & box.size)
                    .contains(screenLocal) ||
                _motion.isPetting(local) ||
                _buddy.isPetting(local))) {
          _pendingPlay = null;
          final petBuddy =
              _buddy.isPetting(local) &&
              (!_motion.isPetting(local) ||
                  (local - _buddy.position).distance <
                      (local - _motion.position).distance);
          if (petBuddy) {
            _buddy.approach(local);
            _motion.visitFriend(_buddy);
          } else {
            _motion.approach(local);
            // Hai bé nhận cùng lời mời nhưng không chọn trùng điểm tiếp đất.
            _buddy.visitFriend(_motion, atDestination: true);
          }
          _nextMeetAt = _buddy.elapsedSeconds + 5;
        }
      }
    });
  }

  void _clearPointers() {
    _pendingApproach = null;
    _pendingSprite = null;
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
    _buddy.dispose();
    _play.dispose();
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
                                child:
                                    ValueListenableBuilder<
                                      Map<
                                        HomeCompanionCharacter,
                                        HomeCompanionOutfit
                                      >
                                    >(
                                      valueListenable: UiPrefs.companionOutfits,
                                      builder: (context, outfits, _) => CustomPaint(
                                        key: const ValueKey(
                                          'home-companion-paint',
                                        ),
                                        painter: HomeCompanionPainter(
                                          motion: _motion,
                                          outfit:
                                              outfits[HomeCompanionCharacter
                                                  .bunny],
                                          play: _play,
                                          paintOffset: widget.followScroll
                                              ? _paintOffset
                                              : null,
                                          showEffects:
                                              widget.animate && !_reduced,
                                          darkMode:
                                              Theme.of(context).brightness ==
                                              Brightness.dark,
                                        ),
                                        foregroundPainter: HomeCompanionPainter(
                                          motion: _buddy,
                                          character:
                                              HomeCompanionCharacter.bear,
                                          outfit:
                                              outfits[HomeCompanionCharacter
                                                  .bear],
                                          play: _play,
                                          paintOffset: widget.followScroll
                                              ? _paintOffset
                                              : null,
                                          showEffects:
                                              widget.animate && !_reduced,
                                          darkMode:
                                              Theme.of(context).brightness ==
                                              Brightness.dark,
                                        ),
                                      ),
                                    ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: RawGestureDetector(
                    // Translucent giữ Scrollable bên dưới trong hit-test path.
                    // Chỉ nhận tap/giữ đúng hình bé; kéo vẫn nhường cuộn gốc.
                    behavior: HitTestBehavior.translucent,
                    gestures: {
                      _CompanionTapRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _CompanionTapRecognizer
                          >(() => _CompanionTapRecognizer(), (recognizer) {
                            recognizer.allowed = (position) =>
                                _spriteAt(position) != null;
                            recognizer.onTapUp = (details) =>
                                _tapSprite(details.globalPosition);
                          }),
                      _CompanionHoldRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _CompanionHoldRecognizer
                          >(() => _CompanionHoldRecognizer(), (recognizer) {
                            recognizer.allowed = (position) =>
                                _spriteAt(position) != null;
                            recognizer.onLongPressStart = (details) =>
                                unawaited(
                                  _openWardrobe(details.globalPosition),
                                );
                          }),
                    },
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

class _CompanionTapRecognizer extends TapGestureRecognizer {
  bool Function(Offset)? allowed;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      (allowed?.call(event.position) ?? false) && super.isPointerAllowed(event);
}

class _CompanionHoldRecognizer extends LongPressGestureRecognizer {
  bool Function(Offset)? allowed;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      (allowed?.call(event.position) ?? false) && super.isPointerAllowed(event);
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
