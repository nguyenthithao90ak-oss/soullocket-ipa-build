import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../widgets/companion/companion_hand_spin.dart';
import '../../widgets/companion/home_companion_motion.dart';
import '../../widgets/companion/home_companion_painter.dart';
import '../../widgets/companion/home_companion_metrics.dart';
import '../../widgets/companion/three_d/companion_3d_asset.dart';
import 'pet_care_food_art.dart';
import 'pet_care_progress.dart';
import 'pet_care_play_tools.dart';
import 'pet_care_room_theme.dart';
import '../../../ui_prefs.dart';

// Phòng khai báo ở tiến trình để dữ liệu trang trí/đồ vật dùng chung.
export 'pet_care_progress.dart' show PetCareRoom;

part 'pet_care_house_painter.dart';
part 'pet_care_play_effects.dart';
part 'pet_care_room_play.dart';
part 'pet_care_pet_fx.dart';
part 'pet_care_props.dart';
part 'pet_care_rooms.dart';
part 'pet_care_skits.dart';
part 'pet_care_together.dart';
part 'pet_care_guest.dart';

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
    this.outfits = const {},
    this.roomLook = const PetCareRoomLook(),
    this.danceSerial = 0,
    this.friendSerial = 0,
    this.seedProps = const {},
    this.fridgeOpen = false,
    this.onPropTap,
    this.propLabel,
    this.onToyChestTap,
    this.toyChestLabel,
    this.toyChestOpen = false,
    this.livingLampLabel,
    this.onGardenTap,
    this.gardenDoorLabel,
    this.backDoorOpen = false,
    this.guest,
    this.guestLeaving = false,
    this.onGuestTreated,
    this.onGuestLeft,
    this.guestLabel,
    this.guestHint,
    this.petTouchLabel,
    this.partnerTouchLabel,
    this.petStrokeHint,
    this.tapBallHint,
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
    this.growth = 1,
    this.baby = false,
    this.together = false,
    this.mateCare = false,
    this.mateMealSerial = 0,
    this.mateFood = PetCareFood.carrot,
    this.party = false,
    this.talkListenable,
    this.listenListenable,
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

  /// Quần áo chung của hai bé, cùng snapshot với Home.
  final Map<PetCarePet, PetCareOutfit> outfits;

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

  /// Hòm đồ chơi mở bảng chọn của màn cha, không tự tìm Hạt hay lưu.
  final VoidCallback? onToyChestTap;
  final String? toyChestLabel;
  final bool toyChestOpen;
  final String? livingLampLabel;
  final VoidCallback? onGardenTap;
  final String? gardenDoorLabel;
  final bool backDoorOpen;

  /// Bạn đang ghé chơi phòng khách (Mèo Mây/Chuột Phô Mai), do màn cha chọn.
  final HomeCompanionCharacter? guest;

  /// Màn cha báo khách ra về: scene vẫy chào, đi ra rồi gọi [onGuestLeft].
  final bool guestLeaving;

  /// Khách ăn xong bánh được mời (một lần mỗi lượt ghé).
  final VoidCallback? onGuestTreated;

  /// Khách đã ra khỏi phòng (hoặc lượt ghé bị bỏ khi đổi phòng/ẩn cảnh).
  final VoidCallback? onGuestLeft;
  final String? guestLabel;
  final String? guestHint;
  final String? petTouchLabel;
  final String? partnerTouchLabel;
  final String? petStrokeHint;
  final String? tapBallHint;
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

  /// Cỡ hai bé theo điểm gắn kết (xem [petCareGrowth]); mỗi lần chăm được
  /// điểm là bé lớn thêm một chút, có nảy nhẹ.
  final double growth;

  /// Hai bé còn sơ sinh: ngậm ti giả, đi lẫm chẫm.
  final bool baby;

  /// Đang bật "Cả hai": bé kia vào bồn tắm chung, ngồi ăn cùng lúc.
  final bool together;

  /// Bé kia cùng được chăm trong lượt đang diễn (tắm chung, chơi chung).
  final bool mateCare;

  /// Tăng mỗi lần bé kia vừa được cho ăn [mateFood] (kéo món tới miệng bé
  /// kia): bé kia ăn riêng, không chờ bé mình ăn xong.
  final int mateMealSerial;
  final PetCareFood mateFood;

  /// Đang mở tiệc sinh nhật: hai bé đội mũ tiệc, nhảy mừng liên tục.
  final bool party;

  /// Độ há miệng khi bé nhại giọng (0..1).
  final ValueListenable<double>? talkListenable;

  /// Bé đang nghe người chơi nói: độ to giọng (0 = không nghe).
  final ValueListenable<double>? listenListenable;

  /// Kiểm thử: nguồn ngẫu nhiên cố định cho tiểu cảnh hai bé.
  @visibleForTesting
  static math.Random? debugRandom;

  /// Kiểm thử/ảnh QA: ép tiểu cảnh kế tiếp.
  @visibleForTesting
  static PetCareSkit? debugNextSkit;

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

  /// Bé kia đang ăn phần riêng (chạy song song với hoạt ảnh của bé mình).
  late final _mateMeal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  Offset? _mateFeedFrom;

  late final _seat = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 760))..addStatusListener(_onSeatStatus);
  late final _livingLight = AnimationController(vsync: this, value: 1,
    duration: const Duration(milliseconds: 420));
  late final _gardenDoor = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 240));
  bool _livingLampOn = true;
  bool _seatRequested = false;
  VoidCallback? _afterSeatExit;

  double get _sit => Curves.easeInOutSine.transform(_seat.value);
  Offset get _seatPoint {
    final character = widget.selectedPet == PetCarePet.rabbit
        ? HomeCompanionCharacter.bunny : HomeCompanionCharacter.bear;
    final roomScale = widget.selectedPet == PetCarePet.rabbit ? 2.85 : 2.55;
    // Khớp hông nằm trên mặt nệm; cỡ sơ sinh và trưởng thành cùng ngồi đúng chỗ.
    final hip = 17.8 * .43 * HomeCompanionMetrics.modelScale *
        HomeCompanionMetrics.scale(character) * roomScale * _growth;
    return Offset(_position.dx, 176 + hip);
  }
  Offset get _seatedPosition => Offset.lerp(_position, _seatPoint, _sit)! -
      Offset(0, math.sin(_seat.value * math.pi) * 19);

  void _resetSeat() {
    _afterSeatExit = null;
    _seatRequested = false;
    _seat.stop();
    _seat.value = 0;
  }

  void _onSeatStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    final next = _afterSeatExit;
    _afterSeatExit = null;
    if (next != null && mounted && _foreground && widget.enabled) setState(next);
  }

  void _toggleSofa() {
    if (!widget.enabled || !_foreground || _vitals.sleeping || _visualBusy ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _cancelRoomPlay();
    _interruptSkit();
    _dance.stop();
    _dance.value = 0;
    _pendingDance = false;
    setState(() {
      if (_seatRequested || _seat.value > 0) {
        _seatRequested = false;
        _walkTo(_home);
      } else {
        _seatRequested = true;
        _touch = null;
        _walkTo(Offset(widget.selectedPet == PetCarePet.rabbit ? 178 : 236, 248),
          after: () {
            if (!_seatRequested || !mounted) return;
            _facingRight = widget.selectedPet == PetCarePet.rabbit;
            if (_animate) {
              _seat.forward();
            } else {
              _seat.value = 1;
            }
          });
      }
    });
    widget.onCue?.call(PetCareCue.tap);
    widget.onPropTap?.call(PetCareProp.cushion);
  }

  void _toggleLivingLamp() {
    if (!_foreground || !TickerMode.valuesOf(context).enabled) return;
    setState(() {
      _livingLampOn = !_livingLampOn;
      if (_animate) {
        _livingLight.animateTo(_livingLampOn ? 1 : 0);
      } else {
        _livingLight.value = _livingLampOn ? 1 : 0;
      }
    });
    widget.onCue?.call(PetCareCue.tap);
  }


  /// Bé đang được rê món tới: bé mình hoặc bé kia.
  PetCarePet? _hoverPet;

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

  final _roomBall = PetCareBallMotion();
  Offset _ballMineAt = const Offset(179, 260);
  Offset _ballPartnerAt = const Offset(274, 260);
  Offset _ballMineFrom = const Offset(179, 260);
  Offset _ballPartnerFrom = const Offset(274, 260);
  double _ballStarted = -100;
  double _ballReturning = -100;
  double _ballInviteStarted = -100;
  double _ballKickAt = -100;
  double _ballMineStride = 0;
  double _ballPartnerStride = 0;
  double _ballMineMoved = 0;
  double _ballPartnerMoved = 0;
  double _ballMissUntil = -100;
  bool _ballMissMine = false;
  bool _ballSession = false;
  bool _ballInviting = false;
  bool _nextIdleBall = true;
  int _ballKicks = 0;
  int _ballTurns = 0;
  Offset? _ballPanLast;
  Offset? _committedBallAt;
  Offset? _committedBallVelocity;
  PetCarePet? _strokePet;
  Offset? _strokePoint;
  Offset? _strokeLast;
  bool _strokeHead = false;
  bool _strokeLive = false;
  bool _strokeFired = false;
  double _strokeDistance = 0;
  Duration _strokeStartFrame = Duration.zero;
  double _strokeUntil = -100;

  /// Vuốt ngang dứt khoát trên bé thì xoay bé (thay vì cưng).
  final _spinMine = CompanionHandSpin();
  final _spinPartner = CompanionHandSpin();
  Offset? _strokeGlobal;
  Offset _strokeNet = Offset.zero;
  bool _strokeSpin = false;

  /// Bạn ghé chơi: chuyển động/xoay riêng, không dùng chung với hai bé.
  final _guestMotion = _PetSceneMotion();
  final _guestSpin = CompanionHandSpin();
  _PetGuestVisit? _visit;
  double _localCuddleAt = -100;
  Offset _localCuddleFrom = const Offset(274, 260);
  bool get _localCuddleActive =>
      _animate &&
      widget.room == PetCareRoom.living &&
      !_partnerVitals.sleeping &&
      _clock.value - _localCuddleAt < 2.8;
  double get _localCuddleT =>
      ((_clock.value - _localCuddleAt) / 2.8).clamp(0.0, 1.0);
  Offset get _localCuddlePoint {
    final t = _localCuddleT;
    final beside =
        _position +
        Offset(
          (_localCuddleFrom.dx >= _position.dx ? 1 : -1) * 55 * _growth,
          3,
        );
    return t < .34
        ? Offset.lerp(
            _localCuddleFrom,
            beside,
            Curves.easeInOutSine.transform((t / .34).clamp(0.0, 1.0)),
          )!
        : t < .7
        ? beside
        : Offset.lerp(
            beside,
            _partnerHome,
            Curves.easeInOutSine.transform(((t - .7) / .3).clamp(0.0, 1.0)),
          )!;
  }

  bool get _ballBusy => _ballSession || _ballInviting;
  bool get _canRoomBall =>
      widget.room == PetCareRoom.living &&
      !widget.small &&
      widget.enabled &&
      _foreground &&
      TickerMode.valuesOf(context).enabled &&
      !_vitals.sleeping &&
      (!_visualBusy || widget.playing);

  Offset _stageGlobal(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    return _viewport!.toStage(_uncamera(box.globalToLocal(global)));
  }

  Offset get _partnerHome => _PetHousePainter.partnerSpot(
    widget.room,
    widget.selectedPet,
    together: _togetherTo,
    growth: _growTo,
  );

  Offset _touchFeet(bool mine) => _ballBusy
      ? (mine ? _ballMineAt : _ballPartnerAt)
      : mine
      ? _seatedPosition
      : _localCuddleActive
      ? _localCuddlePoint
      : _partnerHome;

  Rect _touchPetRect(bool mine) => Rect.fromCenter(
    center: _touchFeet(mine) + Offset(0, -(mine ? 68 : 60) * _growth),
    width: math.max(mine ? 64 : 60, (mine ? 94 : 78) * _growth),
    height: math.max(mine ? 76 : 72, (mine ? 116 : 108) * _growth),
  );

  void _cancelRoomPlay({bool keepCommittedBall = false}) {
    if (!keepCommittedBall) {
      _committedBallAt = null;
      _committedBallVelocity = null;
    }
    _roomBall.reset();
    _ballSession = false;
    _ballInviting = false;
    _ballPanLast = null;
    _ballReturning = -100;
    _strokeLive = false;
    _strokePet = null;
    _strokePoint = null;
    _strokeLast = null;
    _strokeUntil = -100;
    _releaseSpin();
    _localCuddleAt = -100;
  }

  /// Thả bé đang xoay dở (đổi phòng/bé, bắt đầu chơi bóng…), không giữ đà.
  void _releaseSpin() {
    if (!_strokeSpin) return;
    _strokeSpin = false;
    _spinMine.release(_clock.value, 0);
    _spinPartner.release(_clock.value, 0);
  }

  void _prepareBall() {
    _resetSeat();
    _interruptSkit();
    _sulk = 0;
    _freezeWalking();
    _dance.stop();
    _dance.value = 0;
    _pendingDance = false;
    _strokeLive = false;
    _strokePet = null;
    _releaseSpin();
    _localCuddleAt = -100;
    if (!_ballBusy) {
      _ballMineAt = _position;
      _ballPartnerAt = _partnerHome;
      _ballMineStride = _ballPartnerStride = 0;
    }
    _ballSession = true;
    _ballInviting = false;
    _ballStarted = _clock.value;
    _ballReturning = -100;
    _ballKicks = 0;
    _ballKickAt = _clock.value;
  }

  void _launchRoomBall({Offset? velocity}) {
    if (!_canRoomBall) return;
    if (_animate) {
      setState(() {
        _prepareBall();
        _ballTurns++;
        final toward = _ballPartnerAt.dx >= _roomBall.position.dx ? 1.0 : -1.0;
        _roomBall.launch(velocity ?? Offset(toward * 185, -125));
        _committedBallAt = _roomBall.position;
        _committedBallVelocity = _roomBall.velocity;
      });
      _syncCamera();
    } else {
      setState(_cancelRoomPlay);
    }
    // Một lần mỗi tap/lần thả; idle và mọi khung physics không ghi chỉ số.
    widget.onInteract?.call();
  }

  void _ballPanStart(DragStartDetails details) {
    if (!_canRoomBall) return;
    setState(() {
      _prepareBall();
      _ballPanLast = _stageGlobal(details.globalPosition);
      _roomBall.hold(_ballPanLast!);
    });
    widget.onCue?.call(PetCareCue.pickup);
  }

  void _ballPanUpdate(DragUpdateDetails details) {
    if (!_roomBall.held || !_canRoomBall) return;
    setState(() {
      _ballPanLast = _stageGlobal(details.globalPosition);
      _roomBall.move(_ballPanLast!);
    });
  }

  void _ballPanEnd(DragEndDetails details) {
    if (!_roomBall.held || !_canRoomBall) return;
    final speed = details.velocity.pixelsPerSecond;
    final viewport = _viewport!;
    final velocity = Offset(
      speed.dx / (viewport.scaleX * _cameraScale),
      speed.dy / (viewport.scaleY * _cameraScale),
    );
    _launchRoomBall(
      velocity: velocity.distance < 40
          ? Offset(_roomBall.position.dx > 180 ? -160 : 160, -95)
          : velocity,
    );
    _ballPanLast = null;
  }

  void _ballPanCancel() {
    if (!_roomBall.held) return;
    setState(_cancelRoomPlay);
  }

  void _beginBallReturn() {
    _ballSession = true;
    _ballReturning = _clock.value;
    _ballMineFrom = _ballMineAt;
    _ballPartnerFrom = _ballPartnerAt;
    _ballInviting = false;
    _roomBall.active = false;
    _roomBall.held = false;
    _ballPanLast = _roomBall.position;
  }

  void _startBallInvitation() {
    _prepareBall();
    _ballSession = false;
    _ballInviting = true;
    _ballInviteStarted = _clock.value;
    _ballMineFrom = _ballMineAt;
    _ballPartnerFrom = _ballPartnerAt;
    _roomBall.reset();
    _nextIdleBall = false;
  }

  void _advanceRoomPlay(double dt) {
    if (!_ballBusy && _ballReturning < 0) return;
    if (!_foreground ||
        widget.room != PetCareRoom.living ||
        _vitals.sleeping ||
        _partnerVitals.sleeping && _ballInviting) {
      _cancelRoomPlay();
      return;
    }
    final now = _clock.value;
    if (_ballReturning >= 0) {
      final t = ((now - _ballReturning) / 1.1).clamp(0.0, 1.0);
      final eased = Curves.easeInOutSine.transform(t);
      _ballMineAt = Offset.lerp(_ballMineFrom, _position, eased)!;
      _ballPartnerAt = Offset.lerp(_ballPartnerFrom, _partnerHome, eased)!;
      _roomBall.position = Offset.lerp(
        _ballPanLast!,
        PetCareBallMotion.home,
        eased,
      )!;
      _ballMineMoved = _ballPartnerMoved = t < 1 ? 1 : 0;
      if (t >= 1) {
        _cancelRoomPlay();
        _idleSince = now;
        _nextSkitIn = 35 + _random.nextDouble() * 20;
      }
      return;
    }
    if (_ballInviting) {
      final t = now - _ballInviteStarted;
      // Bé bên phải gần hòm/bóng đi lấy; bé mình nhường đường. Cả hai luôn
      // giữ thứ tự trái/phải, kể cả cỡ trưởng thành 122%, không đi xuyên nhau.
      const mineWait = Offset(126, 260);
      const partnerFetch = Offset(289, 260);
      const partnerWait = Offset(258, 260);
      final liftY = 260 - 24 * _growth;
      final lifted = Offset(320, liftY);
      final carryEnd = Offset(220, liftY);
      const placed = Offset(220, 279);
      final settle = Curves.easeInOutSine.transform((t / 1.4).clamp(0.0, 1.0));
      _ballMineAt = Offset.lerp(_ballMineFrom, mineWait, settle)!;
      if (t < 1.4) {
        _ballPartnerAt = Offset.lerp(_ballPartnerFrom, partnerFetch, settle)!;
        _roomBall.position = PetCareBallMotion.home;
      } else if (t < 2.0) {
        _ballPartnerAt = partnerFetch;
        final u = Curves.easeInOutSine.transform(
          ((t - 1.4) / .6).clamp(0.0, 1.0),
        );
        _roomBall.position = Offset.lerp(PetCareBallMotion.home, lifted, u)!;
      } else if (t < 3.4) {
        final u = Curves.easeInOutSine.transform(
          ((t - 2.0) / 1.4).clamp(0.0, 1.0),
        );
        _ballPartnerAt = Offset.lerp(partnerFetch, partnerWait, u)!;
        // Quay người đưa bóng ra phía bạn trong lúc mang về, không đổi vị trí
        // quả bóng đột ngột khi nâng, quay hoặc đặt xuống.
        _roomBall.position = Offset.lerp(lifted, carryEnd, u)!;
      } else if (t < 4.0) {
        _ballPartnerAt = partnerWait;
        final u = Curves.easeInOutSine.transform(
          ((t - 3.4) / .6).clamp(0.0, 1.0),
        );
        _roomBall.position = Offset.lerp(carryEnd, placed, u)!;
      } else {
        _ballPartnerAt = partnerWait;
        _roomBall.position = placed;
      }
      _ballMineMoved = t < 1.4 ? 1 : 0;
      _ballPartnerMoved = t < 1.4 || t > 2.0 && t < 3.4 ? 1 : 0;
      _ballMineStride = t * 1.6;
      _ballPartnerStride = t * 1.4;
      if (t > 6.4) _beginBallReturn();
      return;
    }
    if (_roomBall.held) return;
    final beforeBounces = _roomBall.bounces;
    _roomBall.step(dt);
    if (_roomBall.bounces != beforeBounces) {
      widget.onCue?.call(PetCareCue.bounce);
    }
    if (now - _ballStarted >= 6 || !_roomBall.active) {
      _beginBallReturn();
      return;
    }
    final ball = _roomBall.position;
    void chase(bool mine) {
      if (!mine && _partnerVitals.sleeping) return;
      final pet = mine ? widget.selectedPet : _partnerPet;
      final old = mine ? _ballMineAt : _ballPartnerAt;
      final other = mine ? _ballPartnerAt : _ballMineAt;
      final side = old.dx <= ball.dx ? -1.0 : 1.0;
      final targetX = (ball.dx + side * 31 * _growth).clamp(46.0, 314.0);
      final speed = pet == PetCarePet.rabbit ? 116.0 : 79.0;
      final dx = (targetX - old.dx).clamp(-speed * dt, speed * dt);
      var next = Offset(old.dx + dx, 260 + (mine ? 0 : 6));
      // Chạy hai làn sàn; giữ khoảng cách ngang để hai mặt không chồng lên nhau.
      if ((next.dx - other.dx).abs() < 55 * _growth &&
          (targetX - other.dx).abs() < (old.dx - other.dx).abs()) {
        next = old;
      }
      final moved = (next - old).distance;
      if (mine) {
        _ballMineAt = next;
        _ballMineMoved = moved;
        _ballMineStride += moved / 27;
      } else {
        _ballPartnerAt = next;
        _ballPartnerMoved = moved;
        _ballPartnerStride += moved / 27;
      }
      if (now - _ballKickAt < .72 ||
          _ballKicks >= 4 ||
          ball.dy < 240 ||
          (next.dx - ball.dx).abs() > 42 * _growth + 8) {
        return;
      }
      _ballKickAt = now;
      _ballKicks++;
      if (pet == PetCarePet.bear && (_ballKicks + _ballTurns).isOdd) {
        _ballMissMine = mine;
        _ballMissUntil = now + .65;
        widget.onCue?.call(PetCareCue.squeak);
        return;
      }
      final toward = other.dx > next.dx ? 1.0 : -1.0;
      _roomBall.kick(
        Offset(
          toward * (pet == PetCarePet.rabbit ? 220 : 170),
          pet == PetCarePet.rabbit ? -95 : -65,
        ),
      );
      widget.onCue?.call(PetCareCue.bounce);
    }

    final mineFirst = _ballKicks.isEven;
    chase(mineFirst);
    chase(!mineFirst);
  }

  bool _canTouch(bool mine) =>
      !widget.small &&
      widget.enabled &&
      _foreground &&
      TickerMode.valuesOf(context).enabled &&
      !_visualBusy &&
      !(mine ? _vitals.sleeping : _partnerVitals.sleeping);

  void _beginPetTouch(bool mine, Offset global) {
    if (!_canTouch(mine)) return;
    final point = _stageGlobal(global);
    final anchor = _touchFeet(mine);
    _interruptSkit();
    _cancelRoomPlay();
    if (mine) _jumpTo(anchor);
    _freezeWalking();
    _strokePet = mine ? widget.selectedPet : _partnerPet;
    _strokePoint = _strokeLast = point;
    _strokeHead = point.dy < _touchFeet(mine).dy - 75 * _growth;
    _strokeDistance = 0;
    _strokeFired = false;
    _strokeStartFrame = WidgetsBinding.instance.currentSystemFrameTimeStamp;
    _strokeLive = true;
    _strokeUntil = _clock.value + .8;
    _strokeGlobal = global;
    _strokeNet = Offset.zero;
    _strokeSpin = false;
    setState(() {});
  }

  void _movePetTouch(bool mine, Offset global) {
    if (!_strokeLive || !_canTouch(mine)) return;
    final last = _strokeGlobal ?? global;
    final delta = global - last;
    _strokeGlobal = global;
    final spin = mine ? _spinMine : _spinPartner;
    if (_strokeSpin) {
      setState(() => spin.dragBy(delta.dx));
      return;
    }
    _strokeNet += delta;
    if (_animate &&
        _strokeNet.dx.abs() > 44 &&
        _strokeNet.dx.abs() > _strokeNet.dy.abs() * 1.8) {
      // Vuốt ngang dứt khoát: bé quay theo ngón tay, không tính là cưng.
      setState(() {
        _strokeSpin = true;
        _strokePet = null;
        _strokePoint = null;
        _strokeLast = null;
        spin.grab(_clock.value);
        spin.dragBy(_strokeNet.dx);
      });
      return;
    }
    final point = _stageGlobal(global);
    if (!_touchPetRect(mine).inflate(8).contains(point)) {
      _strokeLast = null;
      return;
    }
    setState(() {
      if (_strokeLast != null) {
        _strokeDistance += math.min(24.0, (point - _strokeLast!).distance);
      }
      _strokePoint = _strokeLast = point;
      _strokeHead = point.dy < _touchFeet(mine).dy - 75 * _growth;
      _strokeUntil = _clock.value + .8;
    });
  }

  void _endPetTouch(
    bool mine, {
    bool tapped = false,
    bool canceled = false,
    double velocity = 0,
  }) {
    if (!_strokeLive) return;
    if (_strokeSpin) {
      _strokeSpin = false;
      _strokeLive = false;
      (mine ? _spinMine : _spinPartner).release(
        _clock.value,
        canceled ? 0 : velocity,
      );
      setState(() {});
      return;
    }
    final enough =
        _strokeDistance >= 36 * math.max(.6, _growth) &&
        WidgetsBinding.instance.currentSystemFrameTimeStamp -
                _strokeStartFrame >=
            const Duration(milliseconds: 180);
    final commit =
        !canceled && !_strokeFired && _canTouch(mine) && (tapped || enough);
    _strokeLive = false;
    _strokeUntil = _clock.value + .85;
    _strokeFired = commit;
    if (commit) {
      if (mine &&
          _animate &&
          widget.room == PetCareRoom.living &&
          !_partnerVitals.sleeping) {
        _localCuddleFrom = _partnerHome;
        _localCuddleAt = _clock.value;
      }
      if (mine && widget.room == PetCareRoom.bedroom && tapped) {
        _interact();
      } else {
        (mine ? widget.onPetTap : widget.onPartnerTap)?.call();
      }
    }
    setState(() {});
  }

  _PetRoomPlayFrame get _roomPlayFrame {
    final now = _clock.value;
    _SkitPose pose(bool mine) {
      final at = mine ? _ballMineAt : _ballPartnerAt;
      final moved = mine ? _ballMineMoved : _ballPartnerMoved;
      final pet = mine ? widget.selectedPet : _partnerPet;
      final stride = mine ? _ballMineStride : _ballPartnerStride;
      final miss = now < _ballMissUntil && _ballMissMine == mine;
      return _SkitPose(
        at: at,
        facingRight: _roomBall.position.dx >= at.dx,
        walking: moved > .02,
        stride: stride,
        lift: pet == PetCarePet.rabbit && moved > .02
            ? math.sin(stride * math.pi).abs() * .3
            : 0,
        tilt: miss ? math.sin((now - _ballKickAt) * 8) * .14 : 0,
        squash: miss ? .35 : 0,
        mood: _SkitMood.happy,
      );
    }

    final strength = _strokePet == null || !_animate
        ? 0.0
        : _strokeLive
        ? .85
        : ((_strokeUntil - now) / .85).clamp(0.0, 1.0);
    return _PetRoomPlayFrame(
      ball: _roomBall.position,
      rotation: _roomBall.rotation,
      active: _ballBusy,
      held: _roomBall.held,
      inviting: _ballInviting,
      mine: _ballBusy ? pose(true) : null,
      partner: _ballBusy && !_partnerVitals.sleeping
          ? pose(false)
          : _localCuddleActive
          ? _SkitPose(
              at: _localCuddlePoint,
              facingRight: _position.dx >= _localCuddlePoint.dx,
              walking: _localCuddleT < .34 || _localCuddleT > .7,
              stride: _localCuddleT * 5,
              mood: _SkitMood.happy,
            )
          : null,
      cuddle: _localCuddleActive ? math.sin(_localCuddleT * math.pi) : 0,
      missAt: _ballBusy && now < _ballMissUntil
          ? (_ballMissMine ? _ballMineAt : _ballPartnerAt)
          : null,
      touchPet: strength > 0 ? _strokePet : null,
      touchPoint: _strokePoint,
      touchHead: _strokeHead,
      touchStrength: strength,
      spinMine: _animate
          ? _spinMine.frameAt(now)
          : CompanionSpinFrame.none,
      spinPartner: _animate
          ? _spinPartner.frameAt(now)
          : CompanionSpinFrame.none,
      guest: _guestFrame,
    );
  }

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

  static Offset _destination(
    PetCareRoom room,
    PetCarePet pet, {
    bool together = false,
    double growth = 1,
  }) => switch (room) {
    PetCareRoom.living => const Offset(179, 260),
    // Bàn ăn cho hai: bé mình ngồi sau đĩa của mình, bé kia đĩa bên cạnh.
    PetCareRoom.kitchen => Offset(
      pet == PetCarePet.rabbit ? 150 : 232,
      254 - _seatLift(room, growth),
    ),
    // Tắm chung: bé mình nhích sang phải, nửa bồn bên trái cho bé kia.
    PetCareRoom.bathroom => Offset(
      together ? 226 : 195,
      254 - _seatLift(room, growth),
    ),
    // Đứng trước giường; đi ngủ thì nhảy lên nằm.
    PetCareRoom.bedroom => const Offset(186, 280),
  };

  /// Bé còn nhỏ thì ngồi cao lên (ghế ăn dặm, bậc trong bồn) để mặt không
  /// bị bàn ăn hay thành bồn che mất.
  static double _seatLift(PetCareRoom room, double growth) {
    final small = (1 - growth).clamp(0.0, 1.0);
    return switch (room) {
      PetCareRoom.kitchen => small * 30,
      PetCareRoom.bathroom => small * 20,
      PetCareRoom.living || PetCareRoom.bedroom => 0,
    };
  }

  /// Chỗ bé mình đứng chăm trong phòng đang xem.
  Offset get _home => _destination(
    widget.room,
    widget.selectedPet,
    together: widget.together,
    growth: widget.small ? 1 : _growTo,
  );

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
    _guestMotion.setPinnedPosition(
      const Offset(180, 260),
      const Rect.fromLTWH(0, 0, 360, 300),
    );
    if (widget.guest != null) {
      // Chờ frame đầu để biết có được chạy chuyển động hay không.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_syncGuest);
      });
    }
    _growFrom = _growTo = widget.growth;
    _togetherFrom = _togetherTo = widget.together ? 1 : 0;
    _from = _to = _home;
    // Cảnh đầu tiên sau khoảng nửa phút để yên.
    _nextSkitIn = 22 + _random.nextDouble() * 12;
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
      if (widget.dragListenable?.value != null) {
        _cancelRoomPlay();
        _freezeWalking();
        _interruptSkit();
      }
    });
    _syncCamera();
  }

  void _clearDrag() {
    _hoverDrag = null;
    _hoverPet = null;
    _hoverPoint = null;
    _holdPoint = null;
    _lastRub = null;
    _foamFrom = null;
    _rubDistance = 0;
  }

  // ── Tiểu cảnh hai bé tự chơi khi người chơi để yên ──────────────────
  final _skitRandom = math.Random();
  math.Random get _random => PetCareScene.debugRandom ?? _skitRandom;
  PetCareSkit? _skit;
  PetCareSkit? _lastSkit;
  double _skitStart = 0;
  bool _skitMineFirst = true;
  int _skitBeat = 0;
  double _idleSince = 0;
  double _nextSkitIn = 26;

  /// Bé đang dỗi: 0 không, 1 bé mình, 2 bé kia; hết dỗi sau [_sulkUntil].
  int _sulk = 0;
  double _sulkUntil = 0;

  double get _skitProgress {
    final skit = _skit;
    return skit == null
        ? 0
        : ((_clock.value - _skitStart) / skit.seconds).clamp(0.0, 1.0);
  }

  /// Chỉ diễn khi cả hai bé thức, không ai đang chăm/kéo/nói chuyện với bé.
  bool get _skitReady =>
      _animate &&
      _foreground &&
      widget.enabled &&
      !widget.small &&
      widget.onPartnerTap != null &&
      widget.dragListenable?.value == null &&
      !_visualBusy &&
      !_seatRequested &&
      _seat.value == 0 &&
      !_walk.isAnimating &&
      !_dance.isAnimating &&
      !_friend.isAnimating &&
      !_mateMeal.isAnimating &&
      !_vitals.sleeping &&
      !_partnerVitals.sleeping &&
      !widget.playing &&
      widget.bathStage == 0 &&
      (widget.talkListenable?.value ?? 0) == 0 &&
      (widget.listenListenable?.value ?? 0) == 0 &&
      _sulk == 0;

  void _runSkits() {
    final now = _clock.value;
    final skit = _skit;
    if (skit != null) {
      final t = (now - _skitStart) / skit.seconds;
      final beats = skit.beats;
      while (_skitBeat < beats.length && t >= beats[_skitBeat].$1) {
        widget.onCue?.call(beats[_skitBeat].$2);
        _skitBeat++;
      }
      if (t >= 1) _endSkit();
      return;
    }
    if (_sulk != 0 && now >= _sulkUntil) setState(() => _sulk = 0);
    // Có bạn ghé chơi thì hai bé đứng tiếp khách, không tự diễn chạy khắp
    // phòng (che mất khách).
    if (_ballBusy || _strokeLive || _localCuddleActive || _visit != null) {
      _idleSince = now;
      return;
    }
    if (!_skitReady) {
      _idleSince = now;
      return;
    }
    if (now - _idleSince >= _nextSkitIn) {
      if (widget.room == PetCareRoom.living &&
          _nextIdleBall &&
          PetCareScene.debugNextSkit == null &&
          widget.onInteract != null) {
        setState(_startBallInvitation);
      } else {
        _nextIdleBall = true;
        _startSkit();
      }
    }
  }

  void _startSkit() {
    final options = PetCareSkit.forRoom(
      widget.room,
    ).where((skit) => skit != _lastSkit).toList();
    final random = _random;
    setState(() {
      final skit =
          PetCareScene.debugNextSkit ?? options[random.nextInt(options.length)];
      _skit = skit;
      _lastSkit = skit;
      _skitMineFirst = random.nextBool();
      _skitStart = _clock.value;
      _skitBeat = 0;
    });
  }

  void _endSkit({bool interrupted = false}) {
    final skit = _skit;
    if (skit == null) return;
    final sulker = skit.sulker;
    setState(() {
      _skit = null;
      if (!interrupted && sulker != null) {
        final mineSulks = (sulker == PetSkitRole.instigator) == _skitMineFirst;
        _sulk = mineSulks ? 1 : 2;
        _sulkUntil = _clock.value + 22;
      }
    });
    _idleSince = _clock.value;
    _nextSkitIn = 35 + _random.nextDouble() * 35;
  }

  /// Người chơi chạm/kéo/chăm: dừng tiểu cảnh, đếm lại thời gian rảnh.
  void _interruptSkit() {
    _idleSince = _clock.value;
    if (_skit != null) _endSkit(interrupted: true);
  }

  double _growFrom = 1;
  double _growTo = 1;
  double _growAt = -10;

  /// Cỡ bé đang vẽ: chuyển dần từ cỡ cũ sang cỡ mới khi lên cấp.
  double get _growth {
    final t = ((_clock.value - _growAt) / 1.4).clamp(0.0, 1.0);
    if (t >= 1) return _growTo;
    return _growFrom + (_growTo - _growFrom) * Curves.easeOutBack.transform(t);
  }

  /// Đang lớn thêm (sau khi chăm được điểm): 0 → 1 → 0 trong lúc chuyển cỡ.
  double get _growPulse {
    if (_growTo <= _growFrom) return 0;
    final t = (_clock.value - _growAt) / 1.4;
    return t <= 0 || t >= 1 ? 0 : math.sin(t * math.pi);
  }

  Rect get _petBounds => Rect.fromCenter(
    center: _position + Offset(0, -68 * _growth),
    width: 94 * _growth,
    height: 116 * _growth,
  );

  /// Vùng chạm/thả đồ lên bé: bé sơ sinh nhỏ xíu vẫn dễ trúng.
  Rect get _petTarget {
    final bounds = _petBounds;
    return Rect.fromCenter(
      center: bounds.center,
      width: math.max(64, bounds.width),
      height: math.max(76, bounds.height),
    );
  }

  double _togetherFrom = 0;
  double _togetherTo = 0;
  double _togetherAt = -10;

  /// Bật "Cả hai": bé kia nhảy vào bồn tắm chung (0 → 1), tắt thì ra lại.
  double get _togetherBlend {
    final t = ((_clock.value - _togetherAt) / .9).clamp(0.0, 1.0);
    return _togetherFrom +
        (_togetherTo - _togetherFrom) * Curves.easeInOutSine.transform(t);
  }

  /// Điểm trong cảnh ↔ điểm trên hình bé cỡ đầy đủ (painter phóng quanh chân).
  Offset _ungrown(Offset point) => _position + (point - _position) / _growth;
  Offset _grown(Offset point) => _position + (point - _position) * _growth;

  /// [_onBody] cho điểm trong cảnh, trả về điểm trong cảnh.
  Offset _onGrownBody(Offset point) => _grown(_onBody(_ungrown(point)));

  /// Thân bé (cỡ đầy đủ) dạng elip để bọt/nước không bám ra ngoài hình.
  Offset _onBody(Offset point) {
    final center = _position + const Offset(0, -62);
    final delta = point - center;
    final normalized = Offset(delta.dx / 34, delta.dy / 48);
    final length = normalized.distance;
    if (length <= 1) return point;
    return center + Offset(delta.dx / length, delta.dy / length);
  }

  /// Món đang kéo thuộc đúng lượt, phòng và bước tắm (chưa xét bé nào nhận).
  bool _toolValid(PetCareDrag data) =>
      widget.enabled &&
      _foreground &&
      TickerMode.valuesOf(context).enabled &&
      // Nhấc đồ ngay trong phòng (đĩa, kệ xà phòng): lần chạm đầu tới vùng
      // thả trước khi màn cha kịp ghi món đang kéo; lúc thả vẫn so đúng món.
      (widget.dragListenable == null ||
          widget.dragListenable!.value == null ||
          identical(widget.dragListenable!.value, data)) &&
      data.pet == widget.selectedPet &&
      data.epoch == widget.interactionEpoch &&
      data.tool.roomIndex == widget.room.index &&
      (data.tool.bathStep == null ||
          data.tool.bathStep == (widget.bathStage == 3 ? 0 : widget.bathStage));

  /// Bé mình nhận món: đang thức, không bận hoạt ảnh khác.
  bool _mineTakes(PetCareDrag data) =>
      _toolValid(data) && !_vitals.sleeping && !_visualBusy;

  /// Bé kia nhận món mà không cần chọn bé: đồ ăn thả vào miệng (ăn song song
  /// với bé mình), đồ tắm khi hai bé chung bồn (bước tắm dùng chung).
  bool _mateTakes(PetCareDrag data) {
    if (widget.small || !_toolValid(data) || _partnerVitals.sleeping) {
      return false;
    }
    if (data.food != null) {
      return widget.room == PetCareRoom.kitchen && !_mateMeal.isAnimating;
    }
    return data.tool.bathStep != null &&
        widget.room == PetCareRoom.bathroom &&
        _togetherTo == 1 &&
        _mineTakes(data);
  }

  bool _matchesTool(PetCareDrag data) => _mineTakes(data) || _mateTakes(data);

  /// Vùng nhận đồ trên người bé kia.
  Rect get _mateTarget {
    final spot = _PetHousePainter.partnerSpot(
      widget.room,
      widget.selectedPet,
      together: _togetherTo,
      growth: _growTo,
    );
    return Rect.fromCenter(
      center: spot + Offset(0, -60 * _growTo),
      width: math.max(64, 84 * _growTo),
      height: math.max(76, 104 * _growTo),
    );
  }

  /// Xà phòng, vòi sen và khăn đều phải xoa/xịt đủ quanh người bé.
  bool get _needsRub => _hoverDrag?.tool.bathStep != null;
  double get _rubProgress => (_rubDistance / 96).clamp(0, 1);

  double get _cameraScale =>
      1 + .3 * Curves.easeInOutCubic.transform(_camera.value);
  Offset _cameraFocus(_PetCareViewport viewport) =>
      viewport.toViewPoint(_position + Offset(0, -64 * _growth));

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
    final data = details.data;
    // Thả vào bé nào thì bé đó nhận, không cần chọn bé trước.
    final target = _mineTakes(data) && _petTarget.contains(point)
        ? widget.selectedPet
        : _mateTakes(data) && _mateTarget.contains(point)
        ? _partnerPet
        : null;
    final onPet = target != null;
    final mine = target == widget.selectedPet;
    final tool = data.tool;
    setState(() {
      _hoverDrag = data;
      _hoverPoint = onPet ? point : null;
      _hoverPet = target;
      _holdPoint = held;
      if (onPet && _lastRub != null) {
        // Chỉ tính nét xoa liên tục trên bé, không tính quãng kéo từ khay.
        final moved = math.min(24.0, (point - _lastRub!).distance);
        _rubDistance += moved;
        // Bọt lưu theo hình bé cỡ đầy đủ; painter phóng theo cỡ hiện tại.
        if (mine && tool == PetCareTool.soap) {
          _lather(_onBody(_ungrown(held)));
        }
        if (mine && tool == PetCareTool.shower) {
          _rinse(_onBody(_ungrown(held)), moved / _growth);
        }
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
    final data = details.data;
    final mate = _hoverPet == _partnerPet;
    final accepted =
        _matchesTool(data) &&
        _hoverPoint != null &&
        (!_needsRub || _rubProgress >= 1);
    final from = _holdPoint;
    setState(() {
      _clearDrag();
      if (accepted && data.food != null) {
        if (mate) {
          _mateFeedFrom = from;
        } else {
          _feedFrom = from;
        }
      }
    });
    if (!accepted) return;
    // Món ăn thả vào bé kia: báo màn cha đúng bé nhận.
    widget.onUseTool?.call(
      mate && data.food != null
          ? PetCareDrag(
              tool: data.tool,
              pet: _partnerPet,
              epoch: data.epoch,
              food: data.food,
            )
          : data,
    );
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
    _advanceRoomPlay(dt);
    _advanceGuest();
    _runSkits();
  }

  // ------------------------------------------------------------ bạn ghé chơi

  /// Khách đứng ở phía còn trống (ngược phía bé kia), sát ngoài vùng đầu bé
  /// mình theo cỡ bé hiện tại để không che mặt nhau, lùi về sau một chút.
  Offset get _guestSpot {
    final growth = widget.small ? 1.0 : _growTo;
    final mineHalf =
        (widget.selectedPet == PetCarePet.rabbit ? 44.8 : 51.2) * growth;
    final guestHalf = 50 * _guestGrowth;
    final x = widget.selectedPet == PetCarePet.rabbit
        ? 179 - mineHalf - guestHalf - 2
        : 179 + mineHalf + guestHalf + 2;
    return Offset(x.clamp(44.0, 316.0), 254);
  }

  /// Bạn nhỏ ghé chơi nhỏ hơn bé chủ nhà một chút.
  double get _guestGrowth =>
      ((widget.small ? 1.0 : _growTo) * .92).clamp(.4, .92);

  void _syncGuest() {
    final guest = widget.small || widget.room != PetCareRoom.living
        ? null
        : widget.guest;
    final visit = _visit;
    if (guest == null) {
      if (visit != null) _reportGuestLeft();
      return;
    }
    if (visit?.character == guest && !(visit?.leftReported ?? true)) return;
    _guestSpin.reset();
    // Khách tới: dừng tiểu cảnh và lượt hai bé tự rủ chơi bóng (người chơi
    // đang tự chơi bóng thì giữ nguyên).
    _interruptSkit();
    if (_ballInviting && !_ballSession) _cancelRoomPlay();
    _visit = _PetGuestVisit(
      character: guest,
      startAt: _clock.value,
      spot: _guestSpot,
      animated: _animate,
    );
    if (widget.guestLeaving) _guestLeave();
  }

  void _guestLeave() {
    final visit = _visit;
    if (visit == null || visit.leaveAt != null) return;
    visit.leaveAt = _clock.value;
    if (!_animate || !visit.animated) _reportGuestLeft();
  }

  void _reportGuestLeft() {
    final visit = _visit;
    if (visit == null) return;
    _visit = null;
    _guestSpin.reset();
    if (visit.leftReported) return;
    visit.leftReported = true;
    // Báo sau frame: màn cha có thể đang dựng lại cây widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onGuestLeft?.call();
    });
  }

  void _reportGuestTreat() {
    final visit = _visit;
    if (visit == null || visit.treatReported) return;
    visit.treatReported = true;
    widget.onGuestTreated?.call();
  }

  /// Theo nhịp đồng hồ cảnh: ăn xong thì báo tặng quà, đi khuất thì báo về.
  void _advanceGuest() {
    final visit = _visit;
    if (visit == null) return;
    final now = _clock.value;
    if (!visit.treatReported && visit.doneEatingAt(now)) _reportGuestTreat();
    if (visit.goneAt(now)) setState(_reportGuestLeft);
  }

  bool get _guestTouchable {
    final visit = _visit;
    return visit != null &&
        widget.enabled &&
        _foreground &&
        visit.arrivedAt(_clock.value);
  }

  /// Chạm khách: lần đầu là mời bánh, sau đó là cưng (mắt tim, vẫy tay).
  void _tapGuest() {
    final visit = _visit;
    if (visit == null || !_guestTouchable) return;
    _interruptSkit();
    final now = _clock.value;
    setState(() {
      if (!visit.treated) {
        visit.treatAt = now;
        widget.onCue?.call(PetCareCue.bite);
      } else {
        visit.petAt = now;
        widget.onCue?.call(PetCareCue.hug);
      }
    });
    if (!_animate || !visit.animated) _reportGuestTreat();
  }

  _PetGuestFrame? get _guestFrame {
    final visit = _visit;
    if (visit == null || widget.small || widget.room != PetCareRoom.living) {
      return null;
    }
    final now = _clock.value;
    return visit.frameAt(
      now,
      motion: _guestMotion,
      spin: _animate ? _guestSpin.frameAt(now) : CompanionSpinFrame.none,
      growth: _guestGrowth,
    );
  }

  Widget _guestTouchTarget(_PetCareViewport viewport) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      final frame = _guestFrame;
      if (frame == null) return const SizedBox.shrink();
      final g = frame.growth;
      var stage = Rect.fromCenter(
        center: frame.at + Offset(0, -frame.height * .45),
        width: 92 * g,
        height: frame.height * .95,
      );
      // Đứng trước hòm đồ chơi thì nhường phần chồng lên cho hòm.
      final chest = _PetPropSpots.rect(
        PetCareProp.basket,
        viewport.wallExtension,
      );
      if (stage.overlaps(chest) && stage.center.dx < chest.left) {
        stage = Rect.fromLTRB(
          stage.left,
          stage.top,
          math.min(stage.right, chest.left),
          stage.bottom,
        );
      }
      final rect = viewport.toView(stage);
      final enabled = _guestTouchable;
      return Positioned.fromRect(
        rect: rect,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: widget.guestLabel,
          hint: widget.guestHint,
          onTap: enabled ? _tapGuest : null,
          child: GestureDetector(
            key: const ValueKey('pet-care-guest-touch'),
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _tapGuest : null,
            // Vuốt ngang để xoay bé khách như hai bé chủ nhà.
            onHorizontalDragStart: enabled && _animate
                ? (_) => setState(() => _guestSpin.grab(_clock.value))
                : null,
            onHorizontalDragUpdate: enabled && _animate
                ? (d) => setState(() => _guestSpin.dragBy(d.delta.dx))
                : null,
            onHorizontalDragEnd: enabled && _animate
                ? (d) => setState(
                    () => _guestSpin.release(
                      _clock.value,
                      d.velocity.pixelsPerSecond.dx,
                    ),
                  )
                : null,
            onHorizontalDragCancel: () =>
                setState(() => _guestSpin.release(_clock.value, 0)),
          ),
        ),
      );
    },
  );

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
    if (prop == PetCareProp.cushion) {
      _toggleSofa();
      return;
    }
    _cancelRoomPlay();
    _interruptSkit();
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
    if (!_foreground) setState(_cancelRoomPlay);
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
    if (!_foreground || !TickerMode.valuesOf(context).enabled) {
      _cancelRoomPlay();
      _afterSeatExit = null;
      _pendingInteraction = null;
      _seatRequested = _seat.value > 0;
      _seat.stop();
      if (_seat.value > 0) _seat.value = 1;
      _gardenDoor.stop();
      _gardenDoor.value = widget.backDoorOpen ? 1 : 0;
      _livingLight.stop();
      _livingLight.value = _livingLampOn ? 1 : 0;
    }
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
      _cancelRoomPlay();
      _afterSeatExit = null;
      _seat.stop();
      _seatRequested = _seat.value > 0;
      _seat.value = _seatRequested ? 1 : 0;
      _gardenDoor.stop();
      _gardenDoor.value = widget.backDoorOpen ? 1 : 0;
      _livingLight.stop();
      _livingLight.value = _livingLampOn ? 1 : 0;
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
    if (!_animate ||
        widget.small ||
        _ballBusy ||
        widget.room == PetCareRoom.bedroom) {
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
    if (widget.backDoorOpen != oldWidget.backDoorOpen) {
      if (_animate) {
        _gardenDoor.animateTo(widget.backDoorOpen ? 1 : 0, curve: Curves.easeInOutCubic);
      } else {
        _gardenDoor.value = widget.backDoorOpen ? 1 : 0;
      }
    }
    if (widget.growth != _growTo) {
      // Lên cấp: bé lớn dần trong hơn một giây, có nảy nhẹ ở cuối.
      _growFrom = _animate ? _growth : widget.growth;
      _growTo = widget.growth;
      _growAt = _clock.value;
    }
    if (widget.dragListenable != oldWidget.dragListenable) {
      oldWidget.dragListenable?.removeListener(_dragChanged);
      widget.dragListenable?.addListener(_dragChanged);
    }
    if (widget.interactionEpoch != oldWidget.interactionEpoch) {
      _clearDrag();
      _cancelRoomPlay();
    }
    if (!widget.enabled) _cancelRoomPlay(keepCommittedBall: true);
    final roomChanged = widget.room != oldWidget.room;
    final petChanged = widget.selectedPet != oldWidget.selectedPet;
    // Chọn món, cập nhật chỉ số hoặc kết thúc chơi không phải lệnh chăm mới.
    final sequenceChanged = widget.serial != oldWidget.serial;
    final friendChanged = widget.friendSerial != oldWidget.friendSerial;
    if (!oldWidget.enabled && widget.enabled && !sequenceChanged) {
      _committedBallAt = null;
      _committedBallVelocity = null;
    }
    if (roomChanged ||
        petChanged ||
        sequenceChanged ||
        friendChanged ||
        widget.danceSerial != oldWidget.danceSerial) {
      _interruptSkit();
    }
    // Dỗ bé đang dỗi: hai bé ôm nhau, hoặc ôm bé mình khi bé mình dỗi.
    if (roomChanged ||
        petChanged ||
        friendChanged ||
        (sequenceChanged && _sulk == 1 && widget.action == PetCareAction.hug)) {
      _sulk = 0;
    }
    final wantedSleep = widget.room == PetCareRoom.bedroom && _vitals.sleeping
        ? 1.0
        : 0.0;
    final sleepChanged = wantedSleep != _sleepTarget;

    if (roomChanged || petChanged) {
      _resetSeat();
      _cancelRoomPlay();
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
        _walkTo(_home);
      } else {
        // Đổi bé: mỗi bé có chỗ riêng (bàn ăn hai đĩa), không đứng đè bé kia.
        _jumpTo(_home);
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
      if (sleepChanged || _vitals.sleeping) _cancelRoomPlay();
      if (sequenceChanged || sleepChanged) {
        _seatRequested = false;
        _visualGeneration++;
        _pendingVisual = true;
        _touch = null;
        if (widget.room == PetCareRoom.living && widget.playing && _animate) {
          if (!_ballBusy) {
            _prepareBall();
            _ballTurns++;
            final savedAt = _committedBallAt;
            final savedVelocity = _committedBallVelocity;
            if (savedAt != null) _roomBall.position = savedAt;
            _roomBall.launch(
              savedVelocity ??
                  Offset(
                    _ballPartnerAt.dx >= _roomBall.position.dx ? 185 : -185,
                    -125,
                  ),
            );
            _committedBallAt = null;
            _committedBallVelocity = null;
          }
          _startActionAnimation();
        } else {
          _walkTo(
            _home,
            after: _startActionAnimation,
            // Đi ngủ: bước tới cạnh giường rồi mới nhảy lên, không trượt.
            force: sleepChanged,
          );
        }
      }
    }
    if (sequenceChanged &&
        widget.room == PetCareRoom.living &&
        widget.action == PetCareAction.hug &&
        !widget.playing &&
        _animate &&
        !_partnerVitals.sleeping) {
      _localCuddleFrom = _partnerHome;
      _localCuddleAt = _clock.value;
    }
    if (widget.mateMealSerial != oldWidget.mateMealSerial) {
      // Bé kia ăn phần riêng; đang dỗi thì được ăn là hết dỗi.
      _interruptSkit();
      if (_sulk == 2) _sulk = 0;
      if (_animate) {
        _mateMeal.forward(from: 0);
      } else {
        _mateMeal.value = 0;
        _mateFeedFrom = null;
      }
      widget.onCue?.call(PetCareCue.bite);
    }
    if (roomChanged || petChanged) {
      _mateMeal.stop();
      _mateMeal.value = 0;
      _mateFeedFrom = null;
    }
    if (widget.together != oldWidget.together) {
      final target = widget.together ? 1.0 : 0.0;
      _togetherFrom = _animate ? _togetherBlend : target;
      _togetherTo = target;
      _togetherAt = _clock.value;
      _interruptSkit();
      // Tắm chung: bé mình nhích sang nhường chỗ trong bồn.
      if (!roomChanged &&
          !petChanged &&
          !sequenceChanged &&
          !_visualBusy &&
          !_vitals.sleeping) {
        _walkTo(_home);
      }
    }
    if (widget.party && !oldWidget.party) _pendingDance = true;
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
    if (widget.guest != oldWidget.guest ||
        widget.room != oldWidget.room ||
        widget.small != oldWidget.small) {
      _syncGuest();
    }
    if (widget.guestLeaving && !oldWidget.guestLeaving) _guestLeave();
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
      // Tiệc sinh nhật: nhảy tiếp nhịp sau cho tới khi tiệc kết thúc.
      if (widget.party && mounted) {
        _pendingDance = true;
        _startDance();
      }
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
    if (_seat.value > 0) {
      _seatRequested = false;
      if (_animate) {
        _afterSeatExit = () => _walkTo(target, after: after, force: force);
        _seat.reverse();
        return;
      }
      _resetSeat();
    }
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
    _cancelRoomPlay();
    _interruptSkit();
    setState(() {
      _touch = null;
      _walkTo(_home, after: widget.onInteract);
    });
    _syncCamera();
  }

  void _tapFloor(TapDownDetails details, _PetCareViewport viewport) {
    if (!widget.enabled || widget.small || _vitals.sleeping || _visualBusy) {
      return;
    }
    final point = viewport.toStage(details.localPosition);
    if (point.dy < 210) return;
    _cancelRoomPlay();
    _interruptSkit();
    setState(() {
      _seatRequested = false;
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
      position: _seatedPosition,
      sitting: _sit,
      livingLight: _livingLight.value,
      gardenDoor: _gardenDoor.value,
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
      outfits: widget.outfits,
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
      growth: widget.small ? 1 : _growth,
      baby: widget.baby && !widget.small,
      together: widget.small ? 0 : _togetherBlend,
      mateCare: widget.mateCare && !widget.small,
      mateMeal: _mateMeal.isAnimating ? _mateMeal.value : 0,
      mateFood: widget.mateFood,
      mateFeedFrom: _mateFeedFrom,
      party: widget.party && !widget.small,
      growPulse: widget.small ? 0 : _growPulse,
      talk: widget.talkListenable?.value ?? 0,
      listening: widget.listenListenable?.value ?? 0,
      skit: _skit,
      skitProgress: _skitProgress,
      skitMineFirst: _skitMineFirst,
      sulk: _sulk,
      roomPlay: _roomPlayFrame,
      toyChestOpen: widget.toyChestOpen,
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
    _mateMeal.dispose();
    _seat.dispose();
    _livingLight.dispose();
    _gardenDoor.dispose();
    _propClock.dispose();
    _pet.dispose();
    _guestMotion.dispose();
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

  void _openToyChest() {
    if (widget.small ||
        !_foreground ||
        !TickerMode.valuesOf(context).enabled ||
        widget.onToyChestTap == null) {
      return;
    }
    _interruptSkit();
    setState(_cancelRoomPlay);
    widget.onCue?.call(PetCareCue.tap);
    widget.onToyChestTap?.call();
  }

  void _semanticPetTap(bool mine) {
    if (mine && widget.room == PetCareRoom.bedroom && _vitals.sleeping) {
      _interact();
      return;
    }
    if (!_canTouch(mine)) return;
    _interruptSkit();
    setState(() {
      _cancelRoomPlay();
      _strokePet = mine ? widget.selectedPet : _partnerPet;
      _strokePoint = _touchFeet(mine) + Offset(0, -90 * _growth);
      _strokeHead = true;
      _strokeUntil = _clock.value + .85;
    });
    if (mine && widget.room == PetCareRoom.bedroom) {
      _interact();
    } else {
      (mine ? widget.onPetTap : widget.onPartnerTap)?.call();
    }
  }

  Widget _petTouchTarget(_PetCareViewport viewport, bool mine) =>
      AnimatedBuilder(
        animation: Listenable.merge([_clock, _walk, _seat, widget.careListenable]),
        builder: (context, _) {
          final sleepingBed =
              mine && widget.room == PetCareRoom.bedroom && _vitals.sleeping;
          final rect = viewport.toView(
            sleepingBed
                ? const Rect.fromLTRB(96, 140, 272, 250)
                : _touchPetRect(mine),
          );
          final enabled = sleepingBed ? widget.enabled : _canTouch(mine);
          return Positioned.fromRect(
            rect: rect,
            child: Semantics(
              button: true,
              enabled: enabled,
              label: mine
                  ? widget.petTouchLabel
                  : widget.partnerTouchLabel ?? widget.partnerLabel,
              hint: widget.petStrokeHint,
              onTap: enabled ? () => _semanticPetTap(mine) : null,
              child: Listener(
                onPointerCancel: (_) => _endPetTouch(mine, canceled: true),
                child: GestureDetector(
                  key: ValueKey(
                    mine ? 'pet-care-pet-touch' : 'pet-care-partner-touch',
                  ),
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTapDown: enabled && !sleepingBed
                      ? (d) => _beginPetTouch(mine, d.globalPosition)
                      : null,
                  onTapUp: enabled
                      ? (_) => sleepingBed
                            ? _interact()
                            : _endPetTouch(mine, tapped: true)
                      : null,
                  onTapCancel: () => _endPetTouch(mine, canceled: true),
                  onPanStart: enabled && !sleepingBed
                      ? (d) => _beginPetTouch(mine, d.globalPosition)
                      : null,
                  onPanUpdate: enabled && !sleepingBed
                      ? (d) => _movePetTouch(mine, d.globalPosition)
                      : null,
                  onPanEnd: enabled && !sleepingBed
                      ? (d) => _endPetTouch(
                          mine,
                          velocity: d.velocity.pixelsPerSecond.dx,
                        )
                      : null,
                  onPanCancel: () => _endPetTouch(mine, canceled: true),
                ),
              ),
            ),
          );
        },
      );

  Widget _roomBallTarget(_PetCareViewport viewport) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      final rect = _touchable(
        viewport.toView(
          Rect.fromCircle(center: _roomBall.position, radius: 25),
        ),
      );
      return Positioned.fromRect(
        rect: rect,
        child: Semantics(
          key: const ValueKey('pet-care-scene-interact'),
          button: true,
          enabled: _canRoomBall,
          label: widget.interactionLabel,
          hint: widget.tapBallHint,
          onTap: _canRoomBall ? _launchRoomBall : null,
          child: SizedBox(
            key: const ValueKey('pet-care-room-ball'),
            child: Listener(
              onPointerCancel: (_) => _ballPanCancel(),
              child: GestureDetector(
                key: const ValueKey('pet_care_interaction_living'),
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTap: _canRoomBall ? _launchRoomBall : null,
                onPanStart: _canRoomBall ? _ballPanStart : null,
                onPanUpdate: _canRoomBall ? _ballPanUpdate : null,
                onPanEnd: _canRoomBall ? _ballPanEnd : null,
                onPanCancel: _ballPanCancel,
              ),
            ),
          ),
        ),
      );
    },
  );

  /// Vùng chạm đồ vật, tối thiểu 48dp, có nhãn cho trình đọc màn hình.
  Widget _propTarget(_PetCareViewport viewport, PetCareProp prop) {
    final rect = _touchable(
      viewport.toView(_PetPropSpots.rect(prop, viewport.wallExtension)),
    );
    final chest = prop == PetCareProp.basket && widget.onToyChestTap != null;
    final tap = chest ? _openToyChest : () => _tapProp(prop);
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        label: chest ? widget.toyChestLabel : widget.propLabel?.call(prop),
        onTap: tap,
        child: GestureDetector(
          key: ValueKey('pet-care-prop-${prop.name}'),
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: tap,
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
                animation: Listenable.merge([_propClock, _livingLight, _gardenDoor]),
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
                    _seat,
                    _livingLight,
                    widget.careListenable,
                    widget.talkListenable,
                    widget.listenListenable,
                    Companion3DAssets.instance,
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
                        // Vòng gợi ý quanh bé đang được rê món tới.
                        bounds: _hoverPet == _partnerPet
                            ? _mateTarget
                            : _petBounds,
                        point: _hoverPoint,
                        held: _holdPoint,
                        body: _hoverPet == _partnerPet
                            ? (point) => point
                            : _onGrownBody,
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
            if (!widget.small &&
                widget.onInteract != null &&
                widget.room != PetCareRoom.living)
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
              _petTouchTarget(viewport, false),
            // Đồ vật nhỏ nằm trên vùng ôm bé kia để vẫn chạm được khi bé đứng
            // phía trước; vùng chạm bé mình vẫn ở trên cùng.
            if (!widget.small)
              for (final prop in PetCareProp.inRoom(widget.room))
                if (!(prop == PetCareProp.cushion &&
                    (_seatRequested || _seat.value > 0)))
                  _propTarget(viewport, prop),
            if (!widget.small && widget.room == PetCareRoom.living)
              Positioned.fromRect(
                rect: _touchable(viewport.toView(const Rect.fromLTWH(56, 81, 54, 66))),
                child: Semantics(button: true, toggled: _livingLampOn,
                  label: widget.livingLampLabel,
                  onTap: _toggleLivingLamp,
                  child: GestureDetector(key: const ValueKey('pet-care-living-lamp'),
                    excludeFromSemantics: true, behavior: HitTestBehavior.opaque,
                    onTap: _toggleLivingLamp))),
            if (!widget.small && widget.room == PetCareRoom.living && widget.onGardenTap != null)
              Positioned.fromRect(
                rect: _touchable(viewport.toView(const Rect.fromLTWH(307, 87, 49, 68))),
                child: Semantics(button: true, label: widget.gardenDoorLabel,
                  child: GestureDetector(key: const ValueKey('pet-care-back-door'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _foreground ? widget.onGardenTap : null))),
            if (!widget.small && widget.sleepingLabel != null)
              for (final (pet, at) in _awaySigns())
                _sleepSign(viewport, pet, at),
            if (_visit != null &&
                !widget.small &&
                widget.room == PetCareRoom.living)
              _guestTouchTarget(viewport),
            if (!widget.small &&
                widget.onPetTap != null &&
                !(widget.room != PetCareRoom.bedroom && _vitals.sleeping))
              _petTouchTarget(viewport, true),
            // Khi đang ngồi, vùng sofa nằm trên vùng chạm thân để có thể
            // chạm lại ghế và đứng dậy; trạng thái đứng vẫn ưu tiên chạm bé.
            if (!widget.small &&
                widget.room == PetCareRoom.living &&
                (_seatRequested || _seat.value > 0))
              _propTarget(viewport, PetCareProp.cushion),
            if (!widget.small &&
                widget.room == PetCareRoom.living &&
                (widget.onInteract != null || _ballBusy))
              _roomBallTarget(viewport),
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
  CompanionSpinFrame spin = CompanionSpinFrame.none;

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
  double get visualStride => strideCycles * 2;
  @override
  double get elapsedSeconds => seconds;
  @override
  double get affection => cuddle;
  @override
  double get hopLift => lift;
  @override
  double get celebration => cheering ? cheer : 0;
  @override
  CompanionSpinFrame get handSpinFrame => spin;
}
