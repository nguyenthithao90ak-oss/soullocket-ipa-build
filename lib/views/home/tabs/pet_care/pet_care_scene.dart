import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../widgets/companion/home_companion_motion.dart';
import '../../widgets/companion/home_companion_painter.dart';
import 'pet_care_progress.dart';

part 'pet_care_house_painter.dart';

enum PetCareRoom { living, kitchen, bathroom, bedroom }

/// Căn nhà dùng đúng nét Thỏ/Gấu của Home, không cần ảnh hoặc mạng.
/// Mọi thay đổi chỉ số do màn cha xử lý; scene chỉ nhận thao tác/chuyển động.
class PetCareScene extends StatefulWidget {
  const PetCareScene({
    this.action,
    this.serial = 0,
    this.decoration,
    this.small = false,
    this.fillRoom = false,
    this.careListenable,
    this.room = PetCareRoom.living,
    this.selectedPet = PetCarePet.rabbit,
    this.food = PetCareFood.carrot,
    this.upgrades = const {},
    this.onInteract,
    this.onActionComplete,
    this.interactionLabel,
    this.enabled = true,
    this.playing = false,
    this.bathStage = 0,
    super.key,
  });

  final PetCareAction? action;
  final int serial;
  final PetCareDecor? decoration;
  final bool small;

  /// Nối tường tới HUD, giữ nhân vật và đồ dùng cùng tỷ lệ.
  final bool fillRoom;
  final ValueListenable<Map<PetCarePet, PetCareVitals>>? careListenable;
  final PetCareRoom room;
  final PetCarePet selectedPet;
  final PetCareFood food;
  final Map<PetCareUpgrade, int> upgrades;
  final VoidCallback? onInteract;
  final VoidCallback? onActionComplete;
  final String? interactionLabel;
  final bool enabled;
  final bool playing;

  /// 0: chờ; 1: xoa xà phòng; 2: xả vòi sen; 3: sạch, thơm.
  final int bathStage;

  @override
  State<PetCareScene> createState() => _PetCareSceneState();
}

class _PetCareSceneState extends State<PetCareScene>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _clock = ValueNotifier<double>(0);
  late final _idle = createTicker(_tick);
  late final _action = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
    value: 1,
  )..addStatusListener(_onActionStatus);
  late final _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: 1,
  )..addStatusListener(_onWalkStatus);
  final _pet = _PetSceneMotion();
  Duration _lastTick = Duration.zero;
  Offset _from = const Offset(180, 260);
  Offset _to = const Offset(180, 260);
  Offset? _touch;
  VoidCallback? _pendingInteraction;
  bool _pendingVisual = false;
  bool _foreground = true;
  bool _animate = false;
  bool _resumeAction = false;
  bool _facingRight = true;
  double _strideOrigin = 0;
  double _startWalkWeight = 0;
  double _sleepFrom = 0;
  double _sleepTarget = 0;
  int _visualGeneration = 0;
  int _notifiedGeneration = -1;

  double get _travel => Curves.easeInOutSine.transform(_walk.value);
  Offset get _position => Offset.lerp(_from, _to, _travel)!;
  double get _strideCycles =>
      _strideOrigin + (_to - _from).distance * _travel / 48;
  double get _walkWeight {
    if (!_walk.isAnimating) return 0;
    final enter = Curves.easeOutSine.transform((_walk.value / .18).clamp(0, 1));
    final leave = Curves.easeOutSine.transform(
      ((1 - _walk.value) / .18).clamp(0, 1),
    );
    return math.min(_startWalkWeight + (1 - _startWalkWeight) * enter, leave);
  }

  double get _sleepBlend =>
      _sleepFrom +
      (_sleepTarget - _sleepFrom) *
          Curves.easeInOutSine.transform(_action.value);
  bool get _visualBusy =>
      _pendingVisual || _action.isAnimating || _resumeAction;
  PetCareVitals get _vitals =>
      widget.careListenable?.value[widget.selectedPet] ?? const PetCareVitals();
  PetCarePet get _partnerPet => widget.selectedPet == PetCarePet.rabbit
      ? PetCarePet.bear
      : PetCarePet.rabbit;
  PetCareVitals get _partnerVitals =>
      widget.careListenable?.value[_partnerPet] ?? const PetCareVitals();

  static Offset _destination(PetCareRoom room) => switch (room) {
    PetCareRoom.living => const Offset(179, 260),
    PetCareRoom.kitchen => const Offset(190, 254),
    PetCareRoom.bathroom => const Offset(195, 254),
    PetCareRoom.bedroom => const Offset(182, 252),
  };

  static Rect _hotspot(PetCareRoom room) => switch (room) {
    PetCareRoom.living => const Rect.fromLTWH(251, 218, 64, 56),
    PetCareRoom.kitchen => const Rect.fromLTWH(113, 180, 150, 93),
    PetCareRoom.bathroom => const Rect.fromLTWH(106, 160, 178, 116),
    PetCareRoom.bedroom => const Rect.fromLTWH(92, 179, 182, 104),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pet.setPinnedPosition(
      const Offset(180, 260),
      const Rect.fromLTWH(0, 0, 360, 300),
    );
    _from = _to = _destination(widget.room);
    _sleepFrom = _sleepTarget =
        widget.room == PetCareRoom.bedroom && _vitals.sleeping ? 1 : 0;
  }

  void _tick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    _clock.value += delta.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final animate =
        _foreground &&
        !widget.small &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    if (animate == _animate) return;
    _animate = animate;
    if (animate) {
      _lastTick = Duration.zero;
      _idle.start();
      if (_resumeAction) {
        _resumeAction = false;
        _action.forward();
      }
    } else {
      _idle.stop();
      _resumeAction = _action.isAnimating;
      _action.stop();
      // Lệnh chưa tới đồ dùng bị hủy khi ra nền; không ghi dữ liệu trễ.
      final canceledVisual = _pendingVisual;
      _pendingInteraction = null;
      _pendingVisual = false;
      _freezeWalking();
      if (canceledVisual) {
        _action.value = 1;
        _notifyActionComplete();
      }
    }
  }

  void _freezeWalking() {
    final current = _position;
    _strideOrigin = _strideCycles;
    _walk.stop();
    _from = _to = current;
    _startWalkWeight = 0;
    _walk.value = 1;
  }

  void _jumpTo(Offset target) {
    final current = _position;
    _strideOrigin = _strideCycles;
    _walk.stop();
    if ((target.dx - current.dx).abs() > 2) {
      _facingRight = target.dx > current.dx;
    }
    _from = _to = target;
    _startWalkWeight = 0;
    _walk.value = 1;
  }

  @override
  void didUpdateWidget(PetCareScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
    final roomChanged = widget.room != oldWidget.room;
    final petChanged = widget.selectedPet != oldWidget.selectedPet;
    // Chọn món, cập nhật chỉ số hoặc kết thúc chơi không phải lệnh chăm mới.
    final sequenceChanged = widget.serial != oldWidget.serial;
    final wantedSleep = widget.room == PetCareRoom.bedroom && _vitals.sleeping
        ? 1.0
        : 0.0;
    final sleepChanged = wantedSleep != _sleepTarget;

    if (roomChanged || petChanged) {
      _visualGeneration++;
      _notifiedGeneration = _visualGeneration;
      _resumeAction = false;
      _pendingInteraction = null;
      _pendingVisual = false;
      _touch = null;
      _action.stop();
      _action.value = 1;
      _sleepFrom = _sleepTarget = wantedSleep;
      if (roomChanged && _animate && !_vitals.sleeping) {
        _walkTo(_destination(widget.room));
      } else if (roomChanged) {
        _jumpTo(_destination(widget.room));
      } else {
        _freezeWalking();
      }
    } else {
      if (sleepChanged) {
        _sleepFrom = _sleepBlend;
        _sleepTarget = wantedSleep;
      }
      if (sequenceChanged || sleepChanged) {
        _visualGeneration++;
        _pendingVisual = true;
        _touch = null;
        _walkTo(_destination(widget.room), after: _startActionAnimation);
      }
    }
    if (!widget.enabled && !_pendingVisual) {
      _pendingInteraction = null;
    }
  }

  Duration get _actionDuration => switch (widget.room) {
    PetCareRoom.kitchen => const Duration(milliseconds: 3200),
    PetCareRoom.bathroom => Duration(
      milliseconds: switch (widget.bathStage) {
        1 => 2800,
        2 => 3000,
        _ => 2200,
      },
    ),
    PetCareRoom.bedroom => const Duration(milliseconds: 1800),
    PetCareRoom.living => Duration(milliseconds: widget.playing ? 3600 : 2800),
  };

  void _startActionAnimation() {
    if (!mounted) return;
    _pendingVisual = false;
    _resumeAction = false;
    _action.duration = _actionDuration;
    if (_animate) {
      _action.forward(from: 0);
    } else {
      _action.value = 1;
      _notifyActionComplete();
    }
  }

  void _onActionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _notifyActionComplete();
  }

  void _notifyActionComplete() {
    if (_notifiedGeneration == _visualGeneration) return;
    _notifiedGeneration = _visualGeneration;
    final generation = _visualGeneration;
    final serial = widget.serial;
    final room = widget.room;
    final pet = widget.selectedPet;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          generation == _visualGeneration &&
          widget.serial == serial &&
          widget.room == room &&
          widget.selectedPet == pet) {
        widget.onActionComplete?.call();
      }
    });
  }

  void _onWalkStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final interaction = _pendingInteraction;
    _pendingInteraction = null;
    if (mounted && widget.enabled && _foreground) {
      interaction?.call();
    }
  }

  void _walkTo(Offset target, {VoidCallback? after}) {
    _pendingInteraction = null;
    final current = _position;
    final phase = _strideCycles;
    final weight = _walkWeight;
    _walk.stop();
    _from = current;
    _to = target;
    _strideOrigin = phase;
    _startWalkWeight = weight;
    if ((target.dx - current.dx).abs() > 2) {
      _facingRight = target.dx > current.dx;
    }
    final distance = (_to - _from).distance;
    if (_animate && !_vitals.sleeping && distance > 3) {
      _pendingInteraction = after;
      _walk.duration = Duration(
        milliseconds: (480 + distance * 5).round().clamp(560, 2600),
      );
      _walk.forward(from: 0);
    } else {
      _walk.value = 1;
      after?.call();
    }
  }

  void _interact() {
    if (!widget.enabled || widget.onInteract == null || _visualBusy) return;
    setState(() {
      _touch = null;
      _walkTo(_destination(widget.room), after: widget.onInteract);
    });
  }

  void _tapFloor(TapDownDetails details, _PetCareViewport viewport) {
    if (!widget.enabled || widget.small || _vitals.sleeping || _visualBusy) {
      return;
    }
    final point = viewport.toStage(details.localPosition);
    if (point.dy < 210) return;
    setState(() {
      _touch = Offset(point.dx.clamp(54, 308), point.dy.clamp(244, 279));
      _walkTo(_touch!);
    });
  }

  _PetHousePainter _painter(BuildContext context, _PetHouseLayer layer) =>
      _PetHousePainter(
        motion: _pet,
        layer: layer,
        room: widget.room,
        selectedPet: widget.selectedPet,
        partnerVitals: _partnerVitals,
        food: widget.food,
        upgrades: widget.upgrades,
        vitals: _vitals,
        seconds: _clock.value,
        time: layer == _PetHouseLayer.background ? 0 : _clock.value / 8,
        progress: _action.value,
        action: widget.action,
        decoration: widget.decoration,
        small: widget.small,
        fillRoom: widget.fillRoom,
        dark: Theme.of(context).brightness == Brightness.dark,
        position: _position,
        walking: _walk.isAnimating,
        walkProgress: _walk.value,
        strideCycles: _strideCycles,
        walkWeight: _walkWeight,
        sleepBlend: _sleepBlend,
        facingRight: _facingRight,
        playing: widget.playing,
        bathStage: widget.bathStage,
        touch: _touch,
        actionable: widget.enabled && widget.onInteract != null,
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle.dispose();
    _clock.dispose();
    _action.dispose();
    _walk.dispose();
    _pet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget room() => LayoutBuilder(
      builder: (context, constraints) {
        final viewport = _PetCareViewport(
          constraints.biggest,
          fillRoom: widget.fillRoom,
        );
        final target = viewport.toView(_hotspot(widget.room));
        return Stack(
          key: ValueKey('pet_care_scene_${widget.room.name}'),
          fit: StackFit.expand,
          children: [
            // Nền có hàng trăm nét vẽ chỉ repaint khi đổi phòng/đồ trang trí.
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              switchInCurve: Curves.easeInOutSine,
              switchOutCurve: Curves.easeInOutSine,
              child: RepaintBoundary(
                key: ValueKey('pet-care-background-${widget.room.name}'),
                child: CustomPaint(
                  key: const ValueKey('pet-care-room-art'),
                  painter: _painter(context, _PetHouseLayer.background),
                  size: Size.infinite,
                  isComplex: true,
                ),
              ),
            ),
            GestureDetector(
              key: const ValueKey('pet-care-scene-floor'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _tapFloor(details, viewport),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _clock,
                    _action,
                    _walk,
                    widget.careListenable,
                  ]),
                  builder: (context, _) => CustomPaint(
                    key: const ValueKey('pet_care_house_paint'),
                    painter: _painter(context, _PetHouseLayer.foreground),
                    willChange: _animate,
                  ),
                ),
              ),
            ),
            if (!widget.small && widget.onInteract != null)
              Positioned(
                left: target.left,
                top: target.top,
                width: math.max(48, target.width),
                height: math.max(48, target.height),
                child: Semantics(
                  key: const ValueKey('pet-care-scene-interact'),
                  button: true,
                  enabled: widget.enabled,
                  label: widget.interactionLabel,
                  onTap: widget.enabled ? _interact : null,
                  child: GestureDetector(
                    key: ValueKey('pet_care_interaction_${widget.room.name}'),
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.enabled ? _interact : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
    return RepaintBoundary(
      child: widget.fillRoom
          ? room()
          : AspectRatio(aspectRatio: widget.small ? 1.25 : 1.2, child: room()),
    );
  }
}

/// Painter và vùng chạm dùng chung một phép đổi tọa độ.
/// Phòng cao chỉ nối thêm tường; nhân vật giữ đúng tỷ lệ theo chiều rộng.
class _PetCareViewport {
  _PetCareViewport(Size size, {required bool fillRoom})
    : scaleX = size.width / 360,
      scaleY = fillRoom ? size.width / 360 : size.height / 300,
      offsetY = fillRoom
          ? math.max(0, size.height - size.width / 360 * 352)
          : 0;

  final double scaleX;
  final double scaleY;
  final double offsetY;
  double get wallExtension => offsetY / scaleY;

  Offset toStage(Offset point) =>
      Offset(point.dx / scaleX, (point.dy - offsetY) / scaleY);

  Rect toView(Rect rect) => Rect.fromLTWH(
    rect.left * scaleX,
    rect.top * scaleY + offsetY,
    rect.width * scaleX,
    rect.height * scaleY,
  );
}

/// Chỉ cấp tư thế bước chân cho painter dùng chung; không chạy AI/đường đi Home.
/// Đường đi và đồng hồ thuộc controller scene, nên giảm chuyển động dừng tất cả.
class _PetSceneMotion extends HomeCompanionMotion {
  _PetSceneMotion() : super(createsDust: false);

  bool walking = false;
  bool hopping = false;
  bool gameFacingRight = true;
  double strideCycles = 0;
  double walkWeight = 0;
  double seconds = 0;
  double cuddle = 0;
  double lift = 0;

  @override
  HomeCompanionPhase get phase => walking
      ? HomeCompanionPhase.walking
      : hopping
      ? HomeCompanionPhase.hopping
      : HomeCompanionPhase.idle;
  @override
  bool get facingRight => gameFacingRight;
  @override
  double get stride =>
      math.asin(math.sin(strideCycles * math.pi * 2) * walkWeight) /
      (math.pi * 2);
  @override
  double get elapsedSeconds => seconds;
  @override
  double get affection => cuddle;
  @override
  double get hopLift => lift;
}
