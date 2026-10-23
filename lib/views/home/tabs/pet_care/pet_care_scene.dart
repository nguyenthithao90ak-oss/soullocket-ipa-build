import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../widgets/companion/home_companion_motion.dart';
import '../../widgets/companion/home_companion_painter.dart';
import '../../widgets/companion/home_companion_metrics.dart';
import 'pet_care_food_art.dart';
import 'pet_care_progress.dart';
import 'pet_care_play_tools.dart';
import 'pet_care_room_theme.dart';
import '../../../ui_prefs.dart';

// Phòng khai báo ở tiến trình để dữ liệu trang trí/đồ vật dùng chung.
export 'pet_care_progress.dart' show PetCareRoom;

part 'pet_care_house_painter.dart';
part 'pet_care_play_effects.dart';
part 'pet_care_pet_fx.dart';
part 'pet_care_props.dart';
part 'pet_care_rooms.dart';

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
    this.look = const PetCareLook(),
    this.roomLook = const PetCareRoomLook(),
    this.danceSerial = 0,
    this.friendSerial = 0,
    this.seedProps = const {},
    this.fridgeOpen = false,
    this.onPropTap,
    this.propLabel,
    this.onPartnerTap,
    this.partnerLabel,
    this.sleepingLabel,
    this.sleepingHint,
    this.onSleepingTap,
    this.sceneTool,
    this.onInteract,
    this.onActionComplete,
    this.onUseTool,
    this.onPetTap,
    this.onCue,
    this.dragListenable,
    this.interactionEpoch = 0,
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

  /// Xà phòng/vòi sen/khăn/điệu nhảy đang dùng; chỉ đổi hình và hiệu ứng.
  final PetCareLook look;

  /// Giấy tường/sàn/cửa sổ/màu nội thất của phòng đang xem.
  final PetCareRoomLook roomLook;

  /// Tăng khi vừa chọn điệu nhảy trong tiệm để bé nhảy thử một lượt.
  final int danceSerial;

  /// Tăng khi hai bé vừa ôm nhau để chạy hoạt ảnh.
  final int friendSerial;

  /// Đồ vật còn giấu hạt hôm nay (lấp lánh, chạm thì hạt bật ra).
  final Set<PetCareProp> seedProps;

  /// Tủ lạnh đang mở (bảng chọn món đang hiện).
  final bool fridgeOpen;
  final ValueChanged<PetCareProp>? onPropTap;
  final String Function(PetCareProp prop)? propLabel;
  final VoidCallback? onPartnerTap;
  final String? partnerLabel;

  /// Nhãn đọc màn hình cho chữ "z" của bé đang ngủ bên phòng ngủ.
  final String Function(PetCarePet pet)? sleepingLabel;
  final String? sleepingHint;

  /// Chạm chữ "z" của bé đang ngủ để sang phòng ngủ xem bé.
  final VoidCallback? onSleepingTap;

  /// Bọc vùng đồ thật trong phòng (đĩa trên bàn, xà phòng trên kệ, vòi sen,
  /// khăn) thành đồ kéo được; màn cha quyết định món nào đang dùng được.
  final Widget Function(PetCareTool tool, Widget area)? sceneTool;
  final VoidCallback? onInteract;
  final VoidCallback? onActionComplete;
  final ValueChanged<PetCareDrag>? onUseTool;
  final VoidCallback? onPetTap;
  final ValueChanged<PetCareCue>? onCue;
  final ValueListenable<PetCareDrag?>? dragListenable;
  final int interactionEpoch;
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
  late final _action =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 3000),
          value: 1,
        )
        ..addStatusListener(_onActionStatus)
        ..addListener(_actionFrame);
  late final _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: 1,
  )..addStatusListener(_onWalkStatus);

  /// Điệu nhảy mừng sau mỗi lần chăm xong; chỉ là hình, không giữ khóa thao tác.
  late final _dance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addStatusListener(_onDanceStatus);

  /// Máy quay tiến sát bé khi đang chăm, giống góc nhìn cận cảnh của mini game.
  late final _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  /// Hai bé ôm nhau; chỉ là hình, dữ liệu do màn cha lưu.
  late final _friend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  /// Đồ vật vừa chạm (mốc giây của đồng hồ cảnh) và đồ đang bật.
  final Map<PetCareProp, double> _propStart = {};
  final Set<PetCareProp> _propOn = {};
  final Map<PetCareProp, double> _propOnSince = {};
  final _propClock = ValueNotifier<double>(0);
  double _fridgeDoor = 0;
  PetCareProp? _seedPop;
  double _seedStart = 0;
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
  PetCareDrag? _hoverDrag;
  Offset? _hoverPoint;
  Offset? _holdPoint;
  Offset? _lastRub;
  double _rubDistance = 0;
  int _soundBeat = 0;
  bool _pendingDance = false;
  double _cameraTarget = 0;
  _PetCareViewport? _viewport;

  /// Bọt bám theo chỗ xoa, lưu tương đối với chân bé cho tới khi xả nước xong.
  List<_PetFoam> _foam = const [];
  Offset? _foamFrom;

  /// Món ăn bay từ chỗ người chơi thả về miệng bé.
  Offset? _feedFrom;

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

  static Offset _destination(PetCareRoom room, PetCarePet pet) =>
      switch (room) {
        PetCareRoom.living => const Offset(179, 260),
        // Bàn ăn cho hai: bé mình ngồi sau đĩa của mình, bé kia đĩa bên cạnh.
        PetCareRoom.kitchen =>
          pet == PetCarePet.rabbit
              ? const Offset(150, 254)
              : const Offset(232, 254),
        PetCareRoom.bathroom => const Offset(195, 254),
        // Đứng trước giường; đi ngủ thì nhảy lên nằm.
        PetCareRoom.bedroom => const Offset(186, 280),
      };

  /// Đĩa thức ăn trên bàn bếp ngay trước bé mình.
  static Offset plateFor(PetCarePet pet) =>
      Offset(_destination(PetCareRoom.kitchen, pet).dx + 2, 228);

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
    UiPrefs.notifier.addListener(_preferencesChanged);
    widget.dragListenable?.addListener(_dragChanged);
    _pet.setPinnedPosition(
      const Offset(180, 260),
      const Rect.fromLTWH(0, 0, 360, 300),
    );
    _from = _to = _destination(widget.room, widget.selectedPet);
    _sleepFrom = _sleepTarget =
        widget.room == PetCareRoom.bedroom && _vitals.sleeping ? 1 : 0;
  }

  void _preferencesChanged() {
    if (mounted) setState(_syncMotion);
  }

  void _dragChanged() {
    if (!mounted) return;
    setState(() {
      _clearDrag();
      if (widget.dragListenable?.value != null) _freezeWalking();
    });
    _syncCamera();
  }

  void _clearDrag() {
    _hoverDrag = null;
    _hoverPoint = null;
    _holdPoint = null;
    _lastRub = null;
    _foamFrom = null;
    _rubDistance = 0;
  }

  Rect get _petBounds => Rect.fromCenter(
    center: _position + const Offset(0, -68),
    width: 94,
    height: 116,
  );

  /// Thân bé dạng elip để bọt/nước không bám ra ngoài hình.
  Offset _onBody(Offset point) {
    final center = _position + const Offset(0, -62);
    final delta = point - center;
    final normalized = Offset(delta.dx / 34, delta.dy / 48);
    final length = normalized.distance;
    if (length <= 1) return point;
    return center + Offset(delta.dx / length, delta.dy / length);
  }

  bool _matchesTool(PetCareDrag data) =>
      widget.enabled &&
      _foreground &&
      TickerMode.valuesOf(context).enabled &&
      // Nhấc đồ ngay trong phòng (đĩa, kệ xà phòng): lần chạm đầu tới vùng
      // thả trước khi màn cha kịp ghi món đang kéo; lúc thả vẫn so đúng món.
      (widget.dragListenable == null ||
          widget.dragListenable!.value == null ||
          identical(widget.dragListenable!.value, data)) &&
      !_vitals.sleeping &&
      !_visualBusy &&
      data.pet == widget.selectedPet &&
      data.epoch == widget.interactionEpoch &&
      data.tool.roomIndex == widget.room.index &&
      (data.tool.bathStep == null ||
          data.tool.bathStep == (widget.bathStage == 3 ? 0 : widget.bathStage));

  /// Xà phòng, vòi sen và khăn đều phải xoa/xịt đủ quanh người bé.
  bool get _needsRub => _hoverDrag?.tool.bathStep != null;
  double get _rubProgress => (_rubDistance / 96).clamp(0, 1);

  double get _cameraScale =>
      1 + .3 * Curves.easeInOutCubic.transform(_camera.value);
  Offset _cameraFocus(_PetCareViewport viewport) =>
      viewport.toViewPoint(_position + const Offset(0, -64));

  /// Điểm chạm trên màn → điểm trong cảnh trước khi máy quay phóng to.
  Offset _uncamera(Offset view) {
    final viewport = _viewport;
    if (viewport == null || _camera.value <= 0) return view;
    final focus = _cameraFocus(viewport);
    return focus + (view - focus) / _cameraScale;
  }

  void _moveTool(
    DragTargetDetails<PetCareDrag> details,
    _PetCareViewport viewport,
  ) {
    if (!_matchesTool(details.data)) return;
    final box = context.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(details.offset);
    final point = viewport.toStage(_uncamera(local));
    // Hình món nổi phía trên ngón tay (xem feedback ở khay đồ).
    final held = viewport.toStage(_uncamera(local + const Offset(0, -45)));
    final onPet = _petBounds.contains(point);
    final tool = details.data.tool;
    setState(() {
      _hoverDrag = details.data;
      _hoverPoint = onPet ? point : null;
      _holdPoint = held;
      if (onPet && _lastRub != null) {
        // Chỉ tính nét xoa liên tục trên bé, không tính quãng kéo từ khay.
        final moved = math.min(24.0, (point - _lastRub!).distance);
        _rubDistance += moved;
        if (tool == PetCareTool.soap) _lather(_onBody(held));
        if (tool == PetCareTool.shower) _rinse(_onBody(held), moved);
      }
      _lastRub = onPet ? point : null;
    });
  }

  void _lather(Offset point) {
    final from = _foamFrom;
    if (from != null && (point - from).distance < 7) return;
    _foamFrom = point;
    final relative = point - _position;
    final next = [..._foam];
    for (var i = 0; i < next.length; i++) {
      if ((next[i].offset - relative).distance < 10) {
        next[i] = next[i].grow(.22);
        _foam = List.unmodifiable(next);
        return;
      }
    }
    if (next.length >= 18) return;
    next.add(_PetFoam(relative, .7, next.length * 7 + relative.dx.round()));
    _foam = List.unmodifiable(next);
  }

  void _rinse(Offset point, double moved) {
    if (_foam.isEmpty) return;
    final relative = point - _position;
    final washed = <_PetFoam>[];
    for (final blob in _foam) {
      final hit = (blob.offset - relative).distance < 26;
      final next = hit ? blob.grow(-(.05 + moved * .02)) : blob;
      if (next.size > .16) washed.add(next);
    }
    _foam = List.unmodifiable(washed);
  }

  /// Xoa xong bọt lan đều người bé; bấm nút thay vì kéo cũng thấy phủ bọt.
  void _fillFoam() {
    const pattern = [
      Offset(-18, -104),
      Offset(4, -112),
      Offset(22, -98),
      Offset(-24, -74),
      Offset(24, -70),
      Offset(-10, -52),
      Offset(14, -46),
      Offset(0, -80),
      Offset(-20, -30),
      Offset(20, -28),
    ];
    final next = [..._foam];
    for (var i = 0; i < pattern.length && next.length < 18; i++) {
      if (next.any((blob) => (blob.offset - pattern[i]).distance < 14)) {
        continue;
      }
      next.add(_PetFoam(pattern[i], .8 + (i % 3) * .15, 31 + i * 5));
    }
    _foam = List.unmodifiable(next);
  }

  void _dropTool(
    DragTargetDetails<PetCareDrag> details,
    _PetCareViewport viewport,
  ) {
    _moveTool(details, viewport);
    final accepted =
        _matchesTool(details.data) &&
        _hoverPoint != null &&
        (!_needsRub || _rubProgress >= 1);
    final from = _holdPoint;
    setState(() {
      _clearDrag();
      if (accepted && details.data.food != null) _feedFrom = from;
    });
    if (accepted) widget.onUseTool?.call(details.data);
  }

  void _actionFrame() {
    if (!_foreground || !_animate || !_action.isAnimating) return;
    if (widget.action == PetCareAction.feed) {
      final beat = _action.value >= .68
          ? 2
          : _action.value >= .46
          ? 1
          : 0;
      if (beat > _soundBeat) {
        _soundBeat = beat;
        widget.onCue?.call(PetCareCue.bite);
      }
    }
  }

  void _tick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    final dt = delta.inMicroseconds / Duration.microsecondsPerSecond;
    _clock.value += dt;
    _advanceProps(dt);
  }

  /// Hết nhịp thì bỏ khỏi danh sách; vòi/đài tự tắt; cửa tủ lạnh trượt mềm.
  /// Lớp đồ vật chỉ vẽ lại khi có gì đang chuyển động.
  void _advanceProps(double dt) {
    final now = _clock.value;
    var changed = _propStart.isNotEmpty;
    _propStart.removeWhere(
      (prop, start) => now - start > _PetPropSpots.duration(prop) + .05,
    );
    for (final entry in _propOnSince.entries.toList()) {
      final limit = _PetPropSpots.autoOff(entry.key);
      if (limit != null && now - entry.value > limit) {
        _propOn.remove(entry.key);
        _propOnSince.remove(entry.key);
        changed = true;
      }
    }
    final target = widget.fridgeOpen ? 1.0 : 0.0;
    if (_fridgeDoor != target) {
      final next = _fridgeDoor + (target - _fridgeDoor) * math.min(1, dt * 7);
      _fridgeDoor = (next - target).abs() < .004 ? target : next;
      changed = true;
    }
    if (_seedPop != null && now - _seedStart > 1.25) _seedPop = null;
    // Vòi nước/đài nhạc đang bật cần vẽ liên tục.
    if (_propOn.any((prop) => _PetPropSpots.autoOff(prop) != null)) {
      changed = true;
    }
    if (changed) _propClock.value = now;
  }

  Map<PetCareProp, double> get _propProgress {
    final now = _clock.value;
    return {
      for (final entry in _propStart.entries)
        if (now > entry.value)
          entry.key: ((now - entry.value) / _PetPropSpots.duration(entry.key))
              .clamp(0.0, 1.0),
    };
  }

  /// Chạm đồ vật: chạy hoạt ảnh, bật/tắt, hạt bật ra nếu còn giấu ở đây.
  void _tapProp(PetCareProp prop) {
    if (widget.small || !_foreground || prop.room != widget.room) return;
    final now = _clock.value;
    final rect = _PetPropSpots.rect(prop, _viewport?.wallExtension ?? 0);
    setState(() {
      _propStart[prop] = now;
      if (_PetPropSpots.toggles.contains(prop)) {
        if (_propOn.remove(prop)) {
          _propOnSince.remove(prop);
        } else {
          _propOn.add(prop);
          _propOnSince[prop] = now;
        }
      }
      if (_animate && widget.seedProps.contains(prop) && _seedPop != prop) {
        _seedPop = prop;
        _seedStart = now;
      }
      // Bé quay về phía đồ vật vừa được chạm.
      if (!_visualBusy && !_vitals.sleeping && !_walk.isAnimating) {
        final dx = rect.center.dx - _position.dx;
        if (dx.abs() > 8) _facingRight = dx > 0;
      }
    });
    _propClock.value = now;
    widget.onCue?.call(switch (prop) {
      PetCareProp.sink || PetCareProp.bathSink => PetCareCue.water,
      PetCareProp.duck => PetCareCue.squeak,
      PetCareProp.radio when _propOn.contains(prop) => PetCareCue.music,
      _ => PetCareCue.tap,
    });
    // Bật nhạc thì bé nhún nhảy theo điệu đang dùng.
    if (prop == PetCareProp.radio &&
        _propOn.contains(prop) &&
        !_vitals.sleeping) {
      _pendingDance = true;
      _startDance();
    }
    widget.onPropTap?.call(prop);
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
        !MediaQuery.accessibleNavigationOf(context) &&
        UiPrefs.resolveEffectProfile(
          state: UiPrefs.notifier.value,
          isWeb: kIsWeb,
        ).animationEnabled;
    if (animate == _animate) return;
    _animate = animate;
    if (animate) {
      _lastTick = Duration.zero;
      _idle.start();
      if (_resumeAction) {
        _resumeAction = false;
        _action.forward();
      }
      _startDance();
      _syncCamera();
    } else {
      _clearDrag();
      _idle.stop();
      _resumeAction = _action.isAnimating;
      _action.stop();
      _dance.stop();
      _dance.value = 0;
      _friend.stop();
      _friend.value = 0;
      _fridgeDoor = widget.fridgeOpen ? 1 : 0;
      _seedPop = null;
      _camera.stop();
      _camera.value = 0;
      _cameraTarget = 0;
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

  bool get _wantsCamera {
    if (!_animate || widget.small || widget.room == PetCareRoom.bedroom) {
      return false;
    }
    final drag = widget.dragListenable?.value;
    return drag?.pet == widget.selectedPet && widget.enabled ||
        _visualBusy ||
        _dance.isAnimating ||
        widget.room == PetCareRoom.bathroom &&
            (widget.bathStage == 1 || widget.bathStage == 2);
  }

  void _syncCamera() {
    if (!mounted) return;
    if (!_animate) return;
    final target = _wantsCamera ? 1.0 : 0.0;
    if (target == _cameraTarget) return;
    _cameraTarget = target;
    _camera.animateTo(
      target,
      duration: Duration(milliseconds: target > 0 ? 460 : 640),
      curve: Curves.easeInOutCubic,
    );
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
    if (widget.dragListenable != oldWidget.dragListenable) {
      oldWidget.dragListenable?.removeListener(_dragChanged);
      widget.dragListenable?.addListener(_dragChanged);
    }
    if (widget.interactionEpoch != oldWidget.interactionEpoch) _clearDrag();
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
      _foam = const [];
      _feedFrom = null;
      _action.stop();
      _action.value = 1;
      _dance.stop();
      _dance.value = 0;
      _friend.stop();
      _friend.value = 0;
      if (roomChanged) {
        _propStart.clear();
        _propOn.clear();
        _propOnSince.clear();
        _seedPop = null;
      }
      _sleepFrom = _sleepTarget = wantedSleep;
      if (roomChanged && _animate && !_vitals.sleeping) {
        _walkTo(_destination(widget.room, widget.selectedPet));
      } else {
        // Đổi bé: mỗi bé có chỗ riêng (bàn ăn hai đĩa), không đứng đè bé kia.
        _jumpTo(_destination(widget.room, widget.selectedPet));
      }
    } else {
      if (widget.bathStage == 1 && oldWidget.bathStage != 1) _fillFoam();
      if (widget.bathStage == 0 && oldWidget.bathStage != 0) {
        _foam = const [];
      }
      if (sleepChanged) {
        _sleepFrom = _sleepBlend;
        _sleepTarget = wantedSleep;
        // Giữ nguyên tư thế hiện tại trong lúc bé bước tới cạnh giường.
        _action.stop();
        _action.value = 0;
      }
      if (sequenceChanged || sleepChanged) {
        _visualGeneration++;
        _pendingVisual = true;
        _touch = null;
        _walkTo(
          _destination(widget.room, widget.selectedPet),
          after: _startActionAnimation,
          // Đi ngủ: bước tới cạnh giường rồi mới nhảy lên, không trượt.
          force: sleepChanged,
        );
      }
    }
    if (widget.danceSerial != oldWidget.danceSerial) {
      _pendingDance = true;
      _startDance();
    }
    if (widget.friendSerial != oldWidget.friendSerial && _animate) {
      _friend.forward(from: 0);
    }
    if (!widget.enabled && !_pendingVisual) {
      _pendingInteraction = null;
    }
    _syncCamera();
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
    PetCareRoom.bedroom => const Duration(milliseconds: 2600),
    PetCareRoom.living => Duration(milliseconds: widget.playing ? 3600 : 2800),
  };

  void _startActionAnimation() {
    if (!mounted) return;
    _pendingVisual = false;
    _resumeAction = false;
    _action.duration = _actionDuration;
    _soundBeat = 0;
    _dance.stop();
    _dance.value = 0;
    widget.onCue?.call(switch (widget.action) {
      PetCareAction.bath => switch (widget.bathStage) {
        1 => PetCareCue.scrub,
        2 => PetCareCue.rinse,
        _ => PetCareCue.dry,
      },
      PetCareAction.feed => _animate ? PetCareCue.pickup : PetCareCue.bite,
      PetCareAction.hug => widget.playing ? PetCareCue.bounce : PetCareCue.hug,
      null => PetCareCue.sleep,
    });
    if (_animate) {
      _action.forward(from: 0);
    } else {
      // Giảm chuyển động: bỏ qua hoạt ảnh xả, bọt trôi hết ngay.
      if (widget.room == PetCareRoom.bathroom && widget.bathStage == 2) {
        _foam = const [];
      }
      _action.value = 1;
      _notifyActionComplete();
    }
    _syncCamera();
  }

  void _onActionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final cheer = switch (widget.action) {
      PetCareAction.feed || PetCareAction.hug => true,
      PetCareAction.bath => widget.bathStage == 3,
      null => false,
    };
    if (widget.room == PetCareRoom.bathroom && widget.bathStage == 2) {
      _foam = const [];
    }
    _notifyActionComplete();
    if (cheer) {
      _pendingDance = true;
      _startDance();
    }
    _syncCamera();
  }

  /// Nhảy mừng chỉ chạy khi được phép chuyển động; tắt hiệu ứng thì bỏ qua.
  void _startDance() {
    if (!_pendingDance || !mounted || !_animate || _visualBusy) return;
    _pendingDance = false;
    widget.onCue?.call(PetCareCue.complete);
    _dance.forward(from: 0);
    _syncCamera();
  }

  void _onDanceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _dance.value = 0;
      _syncCamera();
    }
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

  void _walkTo(Offset target, {VoidCallback? after, bool force = false}) {
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
    if (_animate && (force || !_vitals.sleeping) && distance > 3) {
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
      _walkTo(
        _destination(widget.room, widget.selectedPet),
        after: widget.onInteract,
      );
    });
    _syncCamera();
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

  _PetHousePainter _painter(BuildContext context, _PetHouseLayer layer) {
    final drag = widget.dragListenable?.value;
    final scrubbing = _hoverPoint != null && _hoverDrag?.tool.bathStep != null;
    return _PetHousePainter(
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
      look: widget.look,
      foam: _foam,
      holdPoint: drag?.food != null ? _holdPoint : null,
      scrubbing: scrubbing,
      dryness: _hoverDrag?.tool == PetCareTool.towel ? _rubProgress : 0,
      feedFrom: _feedFrom,
      dance: _dance.isAnimating ? _dance.value : 0,
      roomLook: widget.roomLook,
      props: _propProgress,
      propsOn: Set.unmodifiable(_propOn),
      seedProps: widget.seedProps,
      seedPop: _seedPop,
      seedPopProgress: _seedPop == null
          ? 0
          : ((_clock.value - _seedStart) / 1.2).clamp(0.0, 1.0),
      friend: _friend.isAnimating ? _friend.value : 0,
      fridgeOpen: _animate ? _fridgeDoor : (widget.fridgeOpen ? 1 : 0),
      dragTool: drag?.tool,
      dragFood: drag?.food,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    UiPrefs.notifier.removeListener(_preferencesChanged);
    widget.dragListenable?.removeListener(_dragChanged);
    _idle.dispose();
    _clock.dispose();
    _action.dispose();
    _walk.dispose();
    _dance.dispose();
    _camera.dispose();
    _friend.dispose();
    _propClock.dispose();
    _pet.dispose();
    super.dispose();
  }

  /// Phòng khác: bé đang ngủ bên phòng ngủ chỉ còn chữ "z" bay lên ở chỗ
  /// bé hay đứng (không có biển chữ); chạm vào đó để sang phòng ngủ.
  List<(PetCarePet, Offset)> _awaySigns() {
    if (widget.room == PetCareRoom.bedroom) return const [];
    return [
      if (_vitals.sleeping) (widget.selectedPet, _position),
      if (_partnerVitals.sleeping)
        (
          _partnerPet,
          _PetHousePainter.partnerSpot(widget.room, widget.selectedPet),
        ),
    ];
  }

  Widget _sleepSign(_PetCareViewport viewport, PetCarePet pet, Offset at) {
    final label = widget.sleepingLabel!(pet);
    final hint = widget.sleepingHint;
    // Cùng chỗ với chữ "z" do painter vẽ (`_awayZees`).
    final rect = _touchable(
      viewport.toView(
        Rect.fromCenter(
          center: at + const Offset(18, -144),
          width: 64,
          height: 64,
        ),
      ),
    );
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: widget.onSleepingTap != null,
        label: hint == null ? label : '$label. $hint',
        onTap: widget.onSleepingTap,
        child: GestureDetector(
          key: ValueKey('pet-care-sleep-sign-${pet.name}'),
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSleepingTap,
        ),
      ),
    );
  }

  static Rect _touchable(Rect view) => Rect.fromCenter(
    center: view.center,
    width: math.max(48, view.width),
    height: math.max(48, view.height),
  );

  /// Đồ thật trong phòng kéo được tới bé, theo bước chăm đang làm.
  List<(PetCareTool, Rect)> _sceneTools(_PetCareViewport viewport) {
    switch (widget.room) {
      case PetCareRoom.kitchen:
        final plate = plateFor(widget.selectedPet);
        return [
          (
            PetCareTool.food,
            Rect.fromCenter(
              center: plate + const Offset(0, -10),
              width: 74,
              height: 50,
            ),
          ),
        ];
      case PetCareRoom.bathroom:
        final step = widget.bathStage == 3 ? 0 : widget.bathStage;
        return [
          switch (step) {
            0 => (PetCareTool.soap, const Rect.fromLTWH(298, 176, 46, 36)),
            1 => (PetCareTool.shower, const Rect.fromLTWH(228, 50, 48, 44)),
            _ => (
              PetCareTool.towel,
              _PetPropSpots.rect(PetCareProp.towel, viewport.wallExtension),
            ),
          },
        ];
      case PetCareRoom.living:
      case PetCareRoom.bedroom:
        return const [];
    }
  }

  /// Vùng chạm đồ vật, tối thiểu 48dp, có nhãn cho trình đọc màn hình.
  Widget _propTarget(_PetCareViewport viewport, PetCareProp prop) {
    final rect = _touchable(
      viewport.toView(_PetPropSpots.rect(prop, viewport.wallExtension)),
    );
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        label: widget.propLabel?.call(prop),
        onTap: () => _tapProp(prop),
        child: GestureDetector(
          key: ValueKey('pet-care-prop-${prop.name}'),
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: () => _tapProp(prop),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget room() => LayoutBuilder(
      builder: (context, constraints) {
        final viewport = _PetCareViewport(
          constraints.biggest,
          fillRoom: widget.fillRoom,
        );
        _viewport = viewport;
        final target = viewport.toView(_hotspot(widget.room));
        final drag = widget.dragListenable?.value;
        final content = Stack(
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
            // Đồ vật chạm được: lớp riêng, chỉ vẽ lại khi đang chuyển động.
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _propClock,
                builder: (context, _) => CustomPaint(
                  key: const ValueKey('pet-care-props-art'),
                  painter: _painter(context, _PetHouseLayer.props),
                  size: Size.infinite,
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
                    _dance,
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
            if (drag != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _clock,
                    builder: (context, _) => CustomPaint(
                      key: const ValueKey('pet-care-drop-guide'),
                      painter: _PetPlayEffectsPainter(
                        viewport: viewport,
                        bounds: _petBounds,
                        point: _hoverPoint,
                        held: _holdPoint,
                        body: _onBody,
                        tool: drag.tool,
                        style: drag.tool.styleSlot == null
                            ? null
                            : widget.look[drag.tool.styleSlot!],
                        rub: _rubProgress,
                        seconds: _clock.value,
                        ready:
                            _hoverPoint != null &&
                            (!_needsRub || _rubProgress >= 1),
                      ),
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
            if (!widget.small &&
                widget.onPartnerTap != null &&
                !(_partnerVitals.sleeping ||
                    (widget.room == PetCareRoom.bedroom && _vitals.sleeping)))
              Positioned.fromRect(
                rect: viewport.toView(
                  Rect.fromCenter(
                    center:
                        _PetHousePainter.partnerSpot(
                          widget.room,
                          widget.selectedPet,
                        ) +
                        const Offset(0, -60),
                    width: 78,
                    height: 108,
                  ),
                ),
                child: Semantics(
                  button: true,
                  label: widget.partnerLabel,
                  onTap: widget.onPartnerTap,
                  child: GestureDetector(
                    key: const ValueKey('pet-care-partner-touch'),
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onPartnerTap,
                  ),
                ),
              ),
            // Đồ vật nhỏ nằm trên vùng ôm bé kia để vẫn chạm được khi bé đứng
            // phía trước; vùng chạm bé mình vẫn ở trên cùng.
            if (!widget.small)
              for (final prop in PetCareProp.inRoom(widget.room))
                _propTarget(viewport, prop),
            if (!widget.small && widget.sleepingLabel != null)
              for (final (pet, at) in _awaySigns())
                _sleepSign(viewport, pet, at),
            if (!widget.small &&
                widget.onPetTap != null &&
                !(widget.room != PetCareRoom.bedroom && _vitals.sleeping))
              AnimatedBuilder(
                animation: _walk,
                builder: (context, _) {
                  // Đang nằm ngủ: cả chiếc giường là chỗ chạm để đánh thức.
                  final petTarget = viewport.toView(
                    widget.room == PetCareRoom.bedroom && _vitals.sleeping
                        ? const Rect.fromLTRB(96, 140, 272, 250)
                        : _petBounds,
                  );
                  return Positioned.fromRect(
                    rect: petTarget,
                    child: GestureDetector(
                      key: const ValueKey('pet-care-pet-touch'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.enabled && !_visualBusy
                          ? widget.room == PetCareRoom.bedroom
                                ? _interact
                                : widget.onPetTap
                          : null,
                    ),
                  );
                },
              ),
            // Đĩa trên bàn, xà phòng trên kệ, vòi sen, khăn: chạm như đồ dùng,
            // kéo thẳng tới bé như món ở khay dưới.
            if (!widget.small &&
                widget.sceneTool != null &&
                widget.onUseTool != null)
              for (final (tool, rect) in _sceneTools(viewport))
                Positioned.fromRect(
                  rect: _touchable(viewport.toView(rect)),
                  child: ExcludeSemantics(
                    child: widget.sceneTool!(
                      tool,
                      GestureDetector(
                        key: ValueKey('pet-care-scene-tool-${tool.name}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: tool == PetCareTool.towel
                            ? () => _tapProp(PetCareProp.towel)
                            : _interact,
                      ),
                    ),
                  ),
                ),
          ],
        );
        // Ma trận đơn vị khi không phóng to nên không tạo thêm layer.
        final camera = AnimatedBuilder(
          animation: Listenable.merge([_camera, _walk]),
          child: content,
          builder: (context, child) {
            final scale = _cameraScale;
            final focus = _cameraFocus(viewport);
            return Transform(
              key: const ValueKey('pet-care-camera'),
              transform: Matrix4.diagonal3Values(scale, scale, 1)
                ..setTranslationRaw(
                  focus.dx * (1 - scale),
                  focus.dy * (1 - scale),
                  0,
                ),
              child: child,
            );
          },
        );
        if (widget.onUseTool == null) return ClipRect(child: camera);
        return DragTarget<PetCareDrag>(
          key: const ValueKey('pet-care-drop-surface'),
          onWillAcceptWithDetails: (details) => _matchesTool(details.data),
          onMove: (details) => _moveTool(details, viewport),
          onLeave: (_) {
            if (mounted) setState(_clearDrag);
          },
          onAcceptWithDetails: (details) => _dropTool(details, viewport),
          builder: (_, _, _) => ClipRect(child: camera),
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

  Offset toViewPoint(Offset point) =>
      Offset(point.dx * scaleX, point.dy * scaleY + offsetY);

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
  bool cheering = false;
  bool gameFacingRight = true;
  double strideCycles = 0;
  double walkWeight = 0;
  double seconds = 0;
  double cuddle = 0;
  double lift = 0;
  double cheer = 0;

  @override
  HomeCompanionPhase get phase => walking
      ? HomeCompanionPhase.walking
      : cheering
      ? HomeCompanionPhase.celebrating
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
  @override
  double get celebration => cheering ? cheer : 0;
}
