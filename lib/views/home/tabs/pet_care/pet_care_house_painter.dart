part of 'pet_care_scene.dart';

enum _PetHouseLayer { background, props, foreground }

/// Décor vector theo lớp: tường → nội thất sau → đồ vật chạm được → bé →
/// đồ dùng phía trước. Không chèn chữ vào artwork để nhãn hỗ trợ đủ ngôn ngữ
/// ở màn cha. Hình từng phòng ở `pet_care_rooms.dart`, đồ vật chạm được ở
/// `pet_care_props.dart`.
class _PetHousePainter extends CustomPainter {
  const _PetHousePainter({
    required this.motion,
    required this.layer,
    required this.seconds,
    required this.strideCycles,
    required this.walkWeight,
    required this.sleepBlend,
    required this.room,
    required this.selectedPet,
    required this.partnerVitals,
    required this.food,
    required this.upgrades,
    required this.vitals,
    required this.time,
    required this.progress,
    required this.action,
    required this.decoration,
    required this.small,
    required this.fillRoom,
    required this.dark,
    required this.position,
    required this.walking,
    required this.walkProgress,
    required this.facingRight,
    required this.playing,
    required this.bathStage,
    required this.touch,
    required this.actionable,
    this.look = const PetCareLook(),
    this.roomLook = const PetCareRoomLook(),
    this.foam = const [],
    this.holdPoint,
    this.scrubbing = false,
    this.dryness = 0,
    this.feedFrom,
    this.dance = 0,
    this.props = const {},
    this.propsOn = const {},
    this.seedProps = const {},
    this.seedPop,
    this.seedPopProgress = 0,
    this.friend = 0,
    this.fridgeOpen = 0,
    this.dragTool,
    this.dragFood,
  });

  final _PetSceneMotion motion;
  final _PetHouseLayer layer;
  final double seconds;
  final double strideCycles;
  final double walkWeight;
  final double sleepBlend;
  final PetCareRoom room;
  final PetCarePet selectedPet;
  final PetCareVitals partnerVitals;
  final PetCareFood food;
  final Map<PetCareUpgrade, int> upgrades;
  final PetCareVitals vitals;
  final double time;
  final double progress;
  final PetCareAction? action;
  final PetCareDecor? decoration;
  final bool small;
  final bool fillRoom;
  final bool dark;
  final Offset position;
  final bool walking;
  final double walkProgress;
  final bool facingRight;
  final bool playing;
  final int bathStage;
  final Offset? touch;
  final bool actionable;
  final PetCareLook look;

  /// Giấy tường/sàn/cửa sổ/màu nội thất của phòng đang xem.
  final PetCareRoomLook roomLook;
  final List<_PetFoam> foam;

  /// Món ăn đang được kéo (tọa độ cảnh) để bé há miệng chờ.
  final Offset? holdPoint;
  final bool scrubbing;
  final double dryness;
  final Offset? feedFrom;

  /// Tiến độ điệu nhảy mừng, 0 khi không nhảy.
  final double dance;

  /// Đồ vật vừa chạm và tiến độ hoạt ảnh (0 → 1).
  final Map<PetCareProp, double> props;

  /// Đồ vật đang bật: rèm kéo, vòi nước chảy, đài phát nhạc.
  final Set<PetCareProp> propsOn;

  /// Đồ vật còn giấu hạt hôm nay, lấp lánh nhẹ để gợi ý.
  final Set<PetCareProp> seedProps;
  final PetCareProp? seedPop;
  final double seedPopProgress;

  /// Hai bé ôm nhau (0 khi không ôm).
  final double friend;

  /// Cửa tủ lạnh mở bao nhiêu (0 → 1).
  final double fridgeOpen;

  /// Đồ đang được kéo: món trên đĩa/xà phòng trên kệ/khăn trên móc tạm
  /// biến mất như đã được nhấc lên.
  final PetCareTool? dragTool;
  final PetCareFood? dragFood;

  static const _ink = Color(0xFF856C7A);
  static const _cream = Color(0xFFFFF8E8);
  static const _mint = Color(0xFFABD5C3);
  static const _rose = Color(0xFFECA6B9);
  static const _lilac = Color(0xFFB9A7D9);
  static const _gold = Color(0xFFE7BC78);
  double get _wave => math.sin(time * math.pi * 2);
  double get _pulse => math.sin(progress * math.pi);
  double get _careEnvelope => Curves.easeInOutSine.transform(
    math.min(progress / .2, (1 - progress) / .22).clamp(0, 1),
  );
  bool get _active => progress > 0 && progress < 1;
  bool get _inPlace =>
      !walking &&
      (position - _PetCareSceneState._destination(room, selectedPet)).distance <
          12;
  bool get _inBath => room == PetCareRoom.bathroom && _inPlace;
  bool get _inBed =>
      room == PetCareRoom.bedroom && sleepBlend > .001 && !walking;

  /// Ba nhịp lên giường (ngược lại khi thức): nhảy lên nằm → kéo chăn →
  /// tắt đèn. Mỗi nhịp lấy một đoạn của [sleepBlend].
  double get _hopProgress => _inBed ? _phase(sleepBlend, 0, .42) : 0;
  double get _coverProgress => _inBed ? _phase(sleepBlend, .4, .74) : 0;
  static double _phase(double t, double from, double to) =>
      Curves.easeInOutSine.transform(((t - from) / (to - from)).clamp(0, 1));
  int get _level => switch (room) {
    PetCareRoom.living => 0,
    PetCareRoom.kitchen => upgrades[PetCareUpgrade.kitchen] ?? 0,
    PetCareRoom.bathroom => upgrades[PetCareUpgrade.bathroom] ?? 0,
    PetCareRoom.bedroom => upgrades[PetCareUpgrade.bedroom] ?? 0,
  };

  /// Bộ màu nội thất; null giữ đúng màu gốc của từng món.
  PetCareTone? get _tone => PetCareRoomArt.tone(roomLook.furniture);
  Color _tint(Color classic, Color Function(PetCareTone tone) pick) {
    final tone = _tone;
    if (tone == null) return classic;
    final color = pick(tone);
    return dark ? Color.lerp(color, const Color(0xFF2E2838), .28)! : color;
  }

  bool get _partnerSleeping =>
      room == PetCareRoom.bedroom && partnerVitals.sleeping;

  /// Hai bé ôm nhau: lực nghiêng, có pha vào/ra mềm.
  double get _friendEnvelope => friend <= 0
      ? 0
      : Curves.easeInOutSine.transform(
          math.min(friend / .22, (1 - friend) / .25).clamp(0.0, 1.0),
        );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final viewport = _PetCareViewport(size, fillRoom: fillRoom);
    final extension = viewport.wallExtension;
    final floorExtension = fillRoom ? 52.0 : 0.0;
    canvas.scale(viewport.scaleX, viewport.scaleY);
    canvas.translate(0, extension);
    canvas.clipRect(
      Rect.fromLTWH(0, -extension, 360, 300 + extension + floorExtension),
    );
    switch (layer) {
      case _PetHouseLayer.background:
        _shell(canvas, extension, floorExtension);
        switch (room) {
          case PetCareRoom.living:
            _livingBack(canvas, extension);
          case PetCareRoom.kitchen:
            _kitchenBack(canvas, extension);
          case PetCareRoom.bathroom:
            _bathroomBack(canvas, extension);
          case PetCareRoom.bedroom:
            _bedroomBack(canvas, extension);
        }
        _decoration(canvas);
      case _PetHouseLayer.props:
        _props(canvas, extension);
      case _PetHouseLayer.foreground:
        _front(canvas, extension, floorExtension);
    }
    canvas.restore();
  }

  void _front(Canvas canvas, double extension, double floorExtension) {
    if (touch != null && walking) {
      _oval(
        canvas,
        Rect.fromCenter(center: touch!, width: 29, height: 10),
        _lilac.withValues(alpha: .25),
      );
      _oval(
        canvas,
        Rect.fromCenter(center: touch!, width: 14, height: 5),
        _cream.withValues(alpha: .9),
      );
    }
    // Hai bé luôn ở chung một căn nhà. Chỉ bé đang thuộc vai người dùng
    // mới nhận lệnh đi/chăm; bé còn lại vẫn hiện diện và có mood riêng.
    if (room == PetCareRoom.bedroom) {
      // Bé ngủ nằm trên nệm dưới chăn (Gấu rúc phía sau vẽ trước); bé còn
      // thức đứng trước giường. Lúc nhảy lên, qua đỉnh cú nhảy mới vẽ sau
      // thành giường để không bị cắt ngang người.
      final mineInBed = _inBed;
      final mineBehind = mineInBed && _hopProgress >= .5;
      final order = selectedPet == PetCarePet.bear
          ? [true, false]
          : [false, true];
      for (final mine in order) {
        if (mine && mineBehind) _petInBed(canvas);
        if (!mine && _partnerSleeping) _partnerPet(canvas);
      }
      _bedroomFront(canvas);
      if (!_partnerSleeping) {
        final away =
            _PetHousePainter._phase(sleepBlend, .2, .6) * (_inBed ? 1 : 0);
        if (away < .99) {
          canvas.saveLayer(
            const Rect.fromLTRB(-20, 60, 200, 320),
            Paint()..color = Color.fromRGBO(0, 0, 0, 1 - away),
          );
          _partnerPet(canvas);
          canvas.restore();
        }
      }
      if (mineInBed && !mineBehind) {
        _petInBed(canvas);
      } else if (!mineInBed) {
        _pet(canvas);
      }
    } else {
      // Bé đang ngủ thì nằm trên giường phòng ngủ: phòng khác không vẽ bé,
      // chỉ có chữ "z" bay lên ở chỗ bé hay đứng (biển chữ ở lớp chạm).
      if (!partnerVitals.sleeping) _partnerPet(canvas);
      if (!vitals.sleeping) _pet(canvas);
      switch (room) {
        case PetCareRoom.living:
          _livingFront(canvas);
        case PetCareRoom.kitchen:
          _kitchenFront(canvas);
        case PetCareRoom.bathroom:
          _bathroomFront(canvas);
        case PetCareRoom.bedroom:
          break;
      }
      _awayZees(canvas);
    }
    _affection(canvas);
    _paintFriendHug(canvas);
    // Bếp đã có món nảy trên đĩa làm gợi ý, dấu "+" sẽ đè lên cằm bé.
    if (actionable &&
        !small &&
        !walking &&
        room != PetCareRoom.kitchen &&
        sleepBlend < .01 &&
        !vitals.sleeping &&
        !(_active || playing || bathStage == 1 || bathStage == 2)) {
      final point = switch (room) {
        PetCareRoom.living => const Offset(299, 228),
        PetCareRoom.kitchen => const Offset(257, 201),
        PetCareRoom.bathroom => const Offset(276, 213),
        PetCareRoom.bedroom => const Offset(270, 207),
      };
      _circle(
        canvas,
        point,
        12 + _wave * .7,
        Colors.white.withValues(alpha: .85),
      );
      _circle(canvas, point, 8, _lilac);
      _path(
        canvas,
        Path()
          ..moveTo(point.dx - 3, point.dy)
          ..lineTo(point.dx + 3, point.dy)
          ..moveTo(point.dx, point.dy - 3)
          ..lineTo(point.dx, point.dy + 3),
        Colors.white,
        width: 1.7,
      );
    }
    _paintSeedHints(canvas, extension);
    if (room == PetCareRoom.bedroom) {
      _nightOverlay(canvas, extension, floorExtension);
    }
    _paintSeedPop(canvas, extension);
  }

  void _shell(Canvas c, double extension, double floorExtension) {
    PetCareRoomArt.paintWall(
      c,
      Rect.fromLTWH(0, -extension, 360, 206 + extension),
      room,
      roomLook.wall,
      dark: dark,
    );
    PetCareRoomArt.paintFloor(
      c,
      Rect.fromLTWH(0, 194, 360, 106 + floorExtension),
      room,
      roomLook.floor,
      dark: dark,
    );
    _round(
      c,
      const Rect.fromLTWH(-2, 188, 364, 12),
      3,
      dark ? const Color(0xFF65525E) : _cream,
    );
    _line(
      c,
      const Offset(0, 201),
      const Offset(360, 201),
      dark ? const Color(0xFF443D47) : const Color(0xFFCDAF9C),
      2,
    );
    _oval(
      c,
      const Rect.fromLTWH(34, 259, 300, 42),
      Colors.white.withValues(alpha: dark ? .02 : .08),
    );
  }

  /// Cửa sổ theo kiểu đã chọn; [tilt] chỉ áp cho kiểu cổ điển.
  void _window(
    Canvas c, {
    bool night = false,
    double x = 40,
    double y = 37,
    double width = 77,
    double height = 103,
  }) {
    c.save();
    c.translate(x + width / 2, y + height / 2);
    if (roomLook.window == PetCareRoomItem.windowClassic) c.rotate(-.055);
    PetCareRoomArt.paintWindow(
      c,
      roomLook.window,
      Size(width, height),
      night: night || dark,
      wave: _wave,
    );
    c.restore();
  }

  Offset get _partnerPosition => partnerSpot(room, selectedPet);

  /// Chỗ đứng của bé còn lại, dùng chung cho hình vẽ và vùng chạm ôm nhau.
  static Offset partnerSpot(PetCareRoom room, PetCarePet selectedPet) {
    final onRight = selectedPet == PetCarePet.rabbit;
    return switch (room) {
      // Hai bé cách nhau đủ rộng để mặt không đè lên nhau.
      PetCareRoom.living =>
        onRight ? const Offset(274, 260) : const Offset(86, 260),
      // Bàn ăn cho hai: mỗi bé ngồi sau một chiếc đĩa.
      PetCareRoom.kitchen =>
        onRight ? const Offset(244, 256) : const Offset(140, 256),
      // Bên phải là kệ xà phòng/khăn để kéo, nên bé kia đứng bên trái bồn.
      PetCareRoom.bathroom => const Offset(70, 256),
      // Đứng trước chân giường, không che đèn ngủ và đôi dép.
      PetCareRoom.bedroom => const Offset(80, 280),
    };
  }

  // ── Giấc ngủ: giường nhìn ngang, bé nằm nghiêng gối đầu bên phải ──────
  static const _lyingAngle = 1.18;
  static const _lyingShrink = .86;

  static double _roomScaleOf(PetCarePet pet) =>
      pet == PetCarePet.rabbit ? 2.85 : 2.55;

  static double _spriteOf(PetCarePet pet) =>
      HomeCompanionMetrics.displayScale *
      HomeCompanionMetrics.scale(
        pet == PetCarePet.rabbit
            ? HomeCompanionCharacter.bunny
            : HomeCompanionCharacter.bear,
      );

  /// Điểm trên nét gốc của bé → độ lệch trong cảnh khi bé nằm hẳn.
  static Offset _lyingOffset(PetCarePet pet, Offset sprite) {
    final k = _spriteOf(pet) * _roomScaleOf(pet) * _lyingShrink;
    final cos = math.cos(_lyingAngle);
    final sin = math.sin(_lyingAngle);
    return Offset(
          sprite.dx * cos - sprite.dy * sin,
          sprite.dx * sin + sprite.dy * cos,
        ) *
        k;
  }

  /// Đầu bé trên gối. Hai bé cùng ngủ: Thỏ gối ngoài cùng, Gấu rúc phía
  /// sau lưng Thỏ; [both] đi từ 0 (ngủ một mình) tới 1.
  static Offset _sleepHead(PetCarePet pet, double both) {
    const alone = Offset(234, 192);
    final shared = pet == PetCarePet.rabbit
        ? const Offset(238, 198)
        : const Offset(200, 160);
    return Offset.lerp(alone, shared, both)!;
  }

  static Offset _sleepFeet(PetCarePet pet, double both) =>
      _sleepHead(pet, both) - _lyingOffset(pet, const Offset(0, -48));

  /// Bé kia đang ngủ dịch về chỗ chung khi bé mình nhảy lên giường.
  double get _partnerBoth => _hopProgress;
  double get _mineBoth => _partnerSleeping ? 1 : 0;

  PetCarePet get _partner =>
      selectedPet == PetCarePet.rabbit ? PetCarePet.bear : PetCarePet.rabbit;

  void _partnerPet(Canvas c) {
    final partner = _partner;
    if (_partnerSleeping) {
      _paintLying(
        c,
        partner,
        _sleepFeet(partner, _partnerBoth) + _breath(partner),
        turn: 1,
        shrink: _lyingShrink,
        care: partnerVitals,
      );
      return;
    }
    final hug = _friendEnvelope;
    var p = _partnerPosition;
    if (hug > 0) {
      p += Offset((position.dx - p.dx).sign * 14 * hug, 0);
    }
    final bob = _wave * .85 - hug * 3 * math.sin(friend * math.pi * 4).abs();
    c.save();
    c.translate(p.dx, p.dy + bob);
    c.rotate(
      hug > 0
          ? (position.dx > p.dx ? .09 : -.09) * hug
          : action == PetCareAction.hug && !playing && _active
          ? -_careEnvelope * .025
          : 0,
    );
    final scale = small
        ? 2.65
        : partner == PetCarePet.rabbit
        ? 2.5
        : 2.3;
    c.scale(scale, scale);
    c.translate(-180, -260);
    motion
      ..walking = false
      ..hopping = false
      ..walkWeight = 0
      ..strideCycles = 0
      ..cuddle = hug > 0
          ? hug * .7
          : action == PetCareAction.hug && !playing && _active
          ? _careEnvelope * .35
          : 0
      ..lift = 0
      ..cheering = false
      ..cheer = 0
      ..gameFacingRight = hug > 0
          ? position.dx > p.dx
          : _partnerPosition.dx < 180
      ..seconds = seconds * .78 + 1.8;
    HomeCompanionPainter(
      motion: motion,
      darkMode: dark,
      character: partner == PetCarePet.rabbit
          ? HomeCompanionCharacter.bunny
          : HomeCompanionCharacter.bear,
      showEffects: true,
      care: hug > 0
          ? partnerVitals.copyWith(
              joy: 100,
              food: math.max(60, partnerVitals.food),
            )
          : partnerVitals,
    ).paint(c, const Size(360, 300));
    c.restore();
  }

  /// Nhịp thở khi ngủ: đầu nhấp nhô rất nhẹ, mỗi bé lệch pha một chút.
  Offset _breath(PetCarePet pet) => Offset(
    0,
    math.sin(seconds * 1.6 + (pet == PetCarePet.rabbit ? 0 : 1.7)) * 1.1,
  );

  /// Bé nằm nghiêng: xoay quanh chân [turn] phần của góc nằm, thu nhỏ một
  /// chút cho vừa giường. Biểu cảm ngủ lấy từ chỉ số (mắt nhắm).
  void _paintLying(
    Canvas c,
    PetCarePet pet,
    Offset feet, {
    required double turn,
    required double shrink,
    required PetCareVitals care,
    bool facing = true,
  }) {
    c.save();
    c.translate(feet.dx, feet.dy);
    c.rotate(_lyingAngle * turn);
    final scale = _roomScaleOf(pet) * shrink;
    c.scale(scale, scale);
    c.translate(-180, -260);
    motion
      ..walking = false
      ..hopping = false
      ..walkWeight = 0
      ..strideCycles = 0
      ..cuddle = 0
      ..lift = 0
      ..cheering = false
      ..cheer = 0
      ..gameFacingRight = facing
      ..seconds = seconds * .5 + (pet == PetCarePet.rabbit ? 0 : 1.3);
    HomeCompanionPainter(
      motion: motion,
      darkMode: dark,
      character: pet == PetCarePet.rabbit
          ? HomeCompanionCharacter.bunny
          : HomeCompanionCharacter.bear,
      showEffects: true,
      care: care,
    ).paint(c, const Size(360, 300));
    c.restore();
  }

  /// Bé mình lên giường: đứng trước giường → nhảy vòng cung lên nệm, vừa
  /// bay vừa ngả người nằm xuống (thức dậy thì chạy ngược lại).
  void _petInBed(Canvas c) {
    final hop = _hopProgress;
    final feet = _sleepFeet(selectedPet, _mineBoth);
    final travel = Curves.easeInOutCubic.transform(hop);
    final lift = math.sin(hop * math.pi) * 46;
    final p =
        Offset.lerp(position, feet, travel)! -
        Offset(0, lift) +
        _breath(selectedPet) * hop;
    _paintLying(
      c,
      selectedPet,
      p,
      turn: travel,
      shrink: 1 + (_lyingShrink - 1) * travel,
      care: vitals,
      facing: hop > .25 || facingRight,
    );
  }

  double get _characterScale =>
      HomeCompanionMetrics.displayScale *
      HomeCompanionMetrics.scale(
        selectedPet == PetCarePet.rabbit
            ? HomeCompanionCharacter.bunny
            : HomeCompanionCharacter.bear,
      );
  double get _roomPetScale => selectedPet == PetCarePet.rabbit ? 2.85 : 2.55;
  Offset get _mouth =>
      position +
      Offset(
        (facingRight ? 1 : -1) * 1.7 * _characterScale * _roomPetScale,
        -38.5 * _characterScale * _roomPetScale,
      );

  /// Vị trí vẽ bé đang thức: đi bộ trên sàn, xích lại khi ôm bạn.
  Offset get _petPoint {
    var p = position;
    final hug = _friendEnvelope;
    if (hug > 0) p += Offset((_partnerPosition.dx - p.dx).sign * 14 * hug, 0);
    return p;
  }

  void _pet(Canvas c) {
    final p = _petPoint;
    final hugging = action == PetCareAction.hug && !playing && _active;
    final feeding = action == PetCareAction.feed && _active;
    final playEnvelope = playing && _active ? _careEnvelope : 0.0;
    final friendHug = _friendEnvelope;
    final bob = walking ? 0.0 : math.sin(seconds * 1.7) * .3;
    final chew = feeding && progress > .42 && progress < .8
        ? math.sin((progress - .42) / .38 * math.pi * 6) * 1.8
        : 0.0;
    final reach = feeding ? 0.0 : _reach;
    final hold = holdPoint;
    final lean = hold == null
        ? 0.0
        : ((hold.dx - p.dx) / 220).clamp(-1.0, 1.0) * .07 * reach;
    final eager = reach * 2.5 * math.sin(seconds * 9).abs();
    final wiggle = scrubbing ? math.sin(seconds * 16) * .035 : 0.0;
    final jump = _danceMotion;
    final friendLean = (_partnerPosition.dx > p.dx ? .09 : -.09) * friendHug;
    _paintDanceBack(c, p);
    if (walking) {
      for (var i = 0; i < 2; i++) {
        final offset = (facingRight ? -1 : 1) * (17 + i * 11.0);
        _oval(
          c,
          Rect.fromCenter(
            center: p + Offset(offset, 1 + (i.isOdd ? 3 : -2)),
            width: 4,
            height: 2,
          ),
          _cream.withValues(alpha: (.45 - i * .15) * walkWeight),
        );
      }
    }
    c.save();
    c.translate(
      p.dx,
      p.dy +
          bob -
          chew -
          eager +
          jump.y -
          friendHug * 3 * math.sin(friend * math.pi * 4).abs(),
    );
    c.rotate(
      lean +
          wiggle +
          _shake +
          friendLean +
          (hugging
              ? _careEnvelope * .035
              : feeding
              ? chew * .012 + _spicyShake
              : action == PetCareAction.bath && _active
              ? math.sin(progress * math.pi * 6) * .018 * _careEnvelope
              : 0),
    );
    final scale = small
        ? 3.2
        : selectedPet == PetCarePet.rabbit
        ? 2.85
        : 2.55;
    c.scale(
      scale * (1 + chew * .012 + reach * .03) * jump.sx,
      scale * (1 - chew * .009 + reach * .03) * jump.sy,
    );
    c.translate(-180, -260);
    motion
      ..walking = walking
      ..hopping = playEnvelope > 0 && !walking
      ..gameFacingRight = friendHug > 0
          ? _partnerPosition.dx > p.dx
          : facingRight
      ..strideCycles = walking ? strideCycles : progress * .9
      ..walkWeight = walking ? walkWeight : playEnvelope * .7
      ..seconds = seconds * .78
      ..cuddle = hugging
          ? _careEnvelope * .65
          : friendHug > 0
          ? friendHug * .7
          : feeding
          ? _careEnvelope * .2
          : 0
      ..lift = playEnvelope * math.sin(progress * math.pi) * 1.8
      ..cheering = dance > 0
      ..cheer = dance;
    // Đổi biểu cảm qua dữ liệu hiển thị, không sửa nét vẽ bé dùng chung.
    final face = _cheerful || friendHug > 0
        ? vitals.copyWith(joy: 100, food: math.max(vitals.food, 60))
        : vitals;
    HomeCompanionPainter(
      motion: motion,
      darkMode: dark,
      character: selectedPet == PetCarePet.rabbit
          ? HomeCompanionCharacter.bunny
          : HomeCompanionCharacter.bear,
      showEffects: true,
      care: face,
    ).paint(c, const Size(360, 300));
    final faceRight = motion.gameFacingRight;
    if (reach > .05) {
      c.save();
      c.translate(180, 260);
      c.scale((faceRight ? 1 : -1) * _characterScale, _characterScale);
      _paintMouthOpen(c, reach);
      c.restore();
    }
    if (feeding && progress > .25 && progress < .84) {
      c.save();
      c.translate(180, 260);
      c.scale((faceRight ? 1 : -1) * _characterScale, _characterScale);
      _oval(
        c,
        const Rect.fromLTWH(-3.8, -41.2, 11, 6.7),
        selectedPet == PetCarePet.rabbit
            ? const Color(0xFFFFFAEF)
            : const Color(0xFFF3D7B2),
      );
      final opening = progress < .45 ? 6.0 : 3 + chew.abs() * 1.8;
      _oval(
        c,
        Rect.fromCenter(
          center: const Offset(1.7, -38.6),
          width: 7.5 + chew.abs(),
          height: opening,
        ),
        const Color(0xFF79564E),
      );
      _oval(
        c,
        Rect.fromCenter(
          center: const Offset(1.7, -37.1),
          width: 4.5,
          height: 2,
        ),
        const Color(0xFFEBA0AC),
      );
      _paintCheeks(
        c,
        progress > .46 && progress < .82 ? .6 + chew.abs() * .22 : 0,
      );
      c.restore();
    }
    if (feeding) {
      c.save();
      c.translate(180, 260);
      c.scale((faceRight ? 1 : -1) * _characterScale, _characterScale);
      _paintTasteFace(c);
      c.restore();
    }
    c.restore();
    _paintFoam(c, p);
    _paintDrips(c, p);
    _paintSpray(c, p);
    _paintCraving(c, p, reach);
    _paintDanceFront(c, p);
    if (feeding) _paintTaste(c, p);
    if (vitals.isDirty && !_inBath) {
      for (var i = 0; i < 3; i++) {
        final x = p.dx - 23 + i * 22;
        final y = p.dy - 91 - (i.isOdd ? 12 : 0) + _wave * 2;
        _path(
          c,
          Path()
            ..moveTo(x, y)
            ..quadraticBezierTo(x - 4, y - 5, x, y - 10)
            ..quadraticBezierTo(x + 4, y - 16, x, y - 20),
          const Color(0xFF9B997B).withValues(alpha: .5),
          width: 1.7,
        );
      }
    }
  }

  void _affection(Canvas c) {
    if (action != PetCareAction.hug || playing || !_active) {
      return;
    }
    for (var i = 0; i < 6; i++) {
      final t = (progress * 1.45 - i * .09).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final x = position.dx + math.sin(i * 1.4) * (24 + t * 27);
      final y = position.dy - 72 - t * 65 + (i % 2) * 11;
      _heart(
        c,
        Offset(x, y),
        4 + _pulse * 3,
        [
          _rose,
          _lilac,
          _gold,
        ][i % 3].withValues(alpha: math.sin(t * math.pi) * .85),
      );
    }
  }

  /// Tim lớn giữa hai bé khi ôm nhau, tim nhỏ bay quanh.
  void _paintFriendHug(Canvas c) {
    if (friend <= 0 || friend >= 1) return;
    final mine = _petPoint;
    final other = _partnerPosition;
    final center = Offset((mine.dx + other.dx) / 2, mine.dy - 112);
    final grow = Curves.easeOutBack.transform((friend / .4).clamp(0.0, 1.0));
    final fade = (1 - ((friend - .75) / .25).clamp(0.0, 1.0));
    final r = 16 * grow + math.sin(seconds * 8) * 1.2;
    _heart(c, center, r + 3, Colors.white.withValues(alpha: .9 * fade));
    _heart(c, center, r, const Color(0xFFF08FAC).withValues(alpha: fade));
    for (var i = 0; i < 6; i++) {
      final t = (friend * 1.3 - i * .1).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final angle = i * math.pi / 3 + friend * 2;
      _heart(
        c,
        center + Offset(math.cos(angle) * (20 + t * 40), -t * 34),
        3.5 + math.sin(t * math.pi) * 2,
        [_rose, _gold, _lilac][i % 3].withValues(alpha: math.sin(t * math.pi)),
      );
    }
  }

  void _decoration(Canvas c) {
    switch (decoration) {
      case PetCareDecor.moon:
        _moonMobile(c, const Offset(181, -24));
      case PetCareDecor.planet:
        c.save();
        c.translate(238, 37 + _wave * 2);
        c.rotate(-.3);
        _circle(c, Offset.zero, 14, _lilac);
        _oval(c, const Rect.fromLTWH(-23, -5, 46, 10), _cream, stroke: 3);
        _star(c, const Offset(26, -16), 3, _gold);
        c.restore();
      case PetCareDecor.garden:
        _plant(c, const Offset(19, 254), .72);
        _plant(c, const Offset(345, 249), .75);
      case null:
        break;
    }
  }

  void _food(
    Canvas c,
    PetCareFood type,
    Offset p,
    double scale, {
    bool bitten = false,
  }) {
    final emoji = type.emoji;
    if (emoji != null) {
      PetCareFoodPaint.paint(
        c,
        emoji,
        p,
        44 * scale,
        bite: bitten ? (scale < .5 ? 1 : .4) : 0,
      );
      return;
    }
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    switch (type) {
      case PetCareFood.carrot:
        c.rotate(-.48);
        _path(
          c,
          Path()
            ..moveTo(-11, -12)
            ..quadraticBezierTo(0, -18, 11, -12)
            ..quadraticBezierTo(10, 2, 0, bitten ? 13 : 25)
            ..quadraticBezierTo(-9, 3, -11, -12)
            ..close(),
          const Color(0xFFF2A05E),
        );
        for (var i = 0; i < 3; i++) {
          _line(
            c,
            Offset(-7.0 + i, -7 + i * 8.0),
            Offset(-1.0 + i, -9 + i * 8.0),
            const Color(0xFFD98048),
            1.5,
          );
        }
        for (var i = -1; i < 2; i++) {
          _path(
            c,
            Path()
              ..moveTo(0, -12)
              ..quadraticBezierTo(i * 14, -30, i * 8, -31)
              ..quadraticBezierTo(i * 15, -22, 0, -12),
            _mint,
            width: 4,
          );
        }
      case PetCareFood.apple:
        _path(
          c,
          Path()
            ..moveTo(0, -13)
            ..cubicTo(-18, -25, -25, -5, -16, 10)
            ..quadraticBezierTo(-8, 22, 0, 16)
            ..quadraticBezierTo(9, 22, 18, 8)
            ..cubicTo(27, -10, 14, -24, 0, -13)
            ..close(),
          const Color(0xFFE88F9D),
        );
        _path(
          c,
          Path()
            ..moveTo(0, -12)
            ..quadraticBezierTo(-3, -24, 4, -27),
          const Color(0xFF94745D),
          width: 3,
        );
        _oval(c, const Rect.fromLTWH(4, -26, 14, 7), _mint);
        _oval(
          c,
          const Rect.fromLTWH(-14, -10, 6, 11),
          Colors.white.withValues(alpha: .5),
        );
        if (bitten) {
          _circle(c, const Offset(17, -2), 7, _cream);
        }
      case PetCareFood.soup:
        _oval(c, const Rect.fromLTWH(-29, -4, 58, 13), const Color(0xFFC8DDCF));
        _path(
          c,
          Path()
            ..moveTo(-25, -8)
            ..quadraticBezierTo(-24, 17, 0, 17)
            ..quadraticBezierTo(24, 17, 25, -8)
            ..close(),
          _cream,
        );
        _oval(
          c,
          const Rect.fromLTWH(-25, -15, 50, 16),
          const Color(0xFFBBD3CF),
        );
        _oval(
          c,
          const Rect.fromLTWH(-21, -13, 42, 12),
          const Color(0xFFEFC174),
        );
        _circle(c, const Offset(-8, -7), 3, _mint);
        _circle(c, const Offset(9, -9), 2.5, _rose);
        _round(c, const Rect.fromLTWH(-1, -6, 5, 3), 1, _cream);
        for (var i = -1; i < 2; i++) {
          _path(
            c,
            Path()
              ..moveTo(i * 12, -20)
              ..quadraticBezierTo(i * 12 - 4, -25 - _wave * 2, i * 12, -32),
            _cream.withValues(alpha: .6),
            width: 2,
          );
        }
      case PetCareFood.milk:
        _oval(c, const Rect.fromLTWH(-21, -7, 42, 14), _cream);
        _round(c, const Rect.fromLTWH(-19, -18, 38, 20), 6, _mint);
        _round(c, const Rect.fromLTWH(-16, -22, 32, 7), 3, _cream);
      default:
        _oval(c, const Rect.fromLTWH(-28, 9, 56, 11), const Color(0xFFD9CBDF));
        _round(
          c,
          const Rect.fromLTWH(-22, -14, 44, 28),
          7,
          const Color(0xFFF4D39E),
        );
        _round(c, const Rect.fromLTWH(-22, -5, 44, 6), 2, _rose);
        _round(c, const Rect.fromLTWH(-23, -16, 46, 11), 6, _cream);
        for (var i = 0; i < 4; i++) {
          _circle(c, Offset(-17 + i * 11, -7), 4, _cream);
        }
        _heart(c, const Offset(0, -19), 7, const Color(0xFFE08292));
        _oval(c, const Rect.fromLTWH(-2, -29, 8, 4), _mint);
        if (bitten) {
          _circle(c, const Offset(22, -4), 8, _cream);
        }
    }
    c.restore();
  }

  /// Chai xà phòng trên kệ cùng mẫu đang dùng (giống món nhấc lên kéo).
  void _soap(Canvas c, Offset p, double scale) {
    final (body, deep) = switch (look.soap) {
      PetCareStyle.soapStrawberry => (
        const Color(0xFFF6B8CB),
        const Color(0xFFD9869F),
      ),
      PetCareStyle.soapMint => (
        const Color(0xFFB5E3D1),
        const Color(0xFF7FBCA5),
      ),
      PetCareStyle.soapRainbow => (
        const Color(0xFFD7C8F2),
        const Color(0xFFE7A7C2),
      ),
      _ => (const Color(0xFFCEBCE2), const Color(0xFFAB96C4)),
    };
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    // Vòi bơm và cổ chai.
    _round(c, const Rect.fromLTWH(-4, -40, 8, 10), 2, _cream);
    _round(c, const Rect.fromLTWH(-2, -46, 15, 6), 3, _cream);
    _round(c, const Rect.fromLTWH(-7, -32, 14, 8), 3, deep);
    // Thân chai bo tròn, nhãn hoa ở giữa.
    _round(c, const Rect.fromLTWH(-17, -26, 34, 38), 12, deep);
    _round(c, const Rect.fromLTWH(-16, -27, 32, 36), 12, body);
    if (look.soap == PetCareStyle.soapRainbow) {
      for (var i = 0; i < 3; i++) {
        _line(
          c,
          Offset(-11, -16 + i * 7.0),
          Offset(11, -16 + i * 7.0),
          [_rose, _gold, _mint][i].withValues(alpha: .7),
          2.4,
        );
      }
    }
    _round(
      c,
      const Rect.fromLTWH(-10, -12, 20, 14),
      5,
      _cream.withValues(alpha: .85),
    );
    _flower(c, const Offset(0, -5), 3.6, deep);
    _line(
      c,
      const Offset(-11, -21),
      const Offset(-11, 2),
      Colors.white.withValues(alpha: .55),
      2,
    );
    _bubble(c, const Offset(-20, -30), 4.5, .8);
    c.restore();
  }

  void _sponge(Canvas c, Offset p, double scale) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    c.rotate(
      .12 +
          (bathStage == 1 && _active
              ? math.sin(progress * math.pi * 6) * .16 * _careEnvelope
              : 0),
    );
    _round(
      c,
      const Rect.fromLTWH(-23, -12, 46, 26),
      10,
      const Color(0xFF7EAA99),
    );
    _round(
      c,
      const Rect.fromLTWH(-23, -17, 46, 25),
      10,
      const Color(0xFFC0DFB9),
    );
    for (var i = 0; i < 7; i++) {
      _circle(
        c,
        Offset(-15 + (i * 13 % 34), -9 + i % 2 * 9),
        1.7,
        const Color(0xFF87B595),
      );
    }
    c.restore();
  }

  void _duck(Canvas c, Offset p, double scale) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _oval(c, const Rect.fromLTWH(-15, -5, 31, 18), const Color(0xFFFFD98C));
    _circle(c, const Offset(9, -8), 10, const Color(0xFFFFD98C));
    _path(
      c,
      Path()
        ..moveTo(17, -8)
        ..lineTo(27, -4)
        ..lineTo(17, -1)
        ..close(),
      const Color(0xFFECA073),
    );
    _circle(c, const Offset(12, -10), 1.6, _ink);
    _oval(c, const Rect.fromLTWH(-10, -2, 15, 8), const Color(0xFFFFE6B0));
    c.restore();
  }

  void _slipper(Canvas c, Offset p, double angle) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(angle);
    _oval(c, const Rect.fromLTWH(-9, -14, 19, 28), _rose);
    _round(c, const Rect.fromLTWH(-9, -14, 19, 17), 8, const Color(0xFFF1C3CF));
    _heart(c, const Offset(0, -7), 3, _cream);
    c.restore();
  }

  void _moonMobile(Canvas c, Offset p, {double spin = 0}) {
    final swing = math.sin(spin * math.pi * 4) * 10 * (1 - spin);
    _line(c, p, p + const Offset(0, 37), _gold, 1.3);
    c.save();
    c.translate(p.dx, p.dy + 6);
    c.rotate(swing * .02);
    c.translate(-p.dx, -p.dy - 6);
    _circle(
      c,
      p + Offset(swing * .3, 51 + _wave * 1.2),
      14,
      const Color(0xFFFFDCA1),
    );
    _circle(
      c,
      p + Offset(6 + swing * .3, 46 + _wave * 1.2),
      12,
      dark ? const Color(0xFF57516F) : const Color(0xFFECE5F6),
    );
    _line(c, p + const Offset(-22, 6), p + Offset(-22 - swing, 41), _gold, 1);
    _star(c, p + Offset(-22 - swing, 47 + _wave), 6, _gold);
    _line(c, p + const Offset(25, 10), p + Offset(25 + swing, 53), _gold, 1);
    _star(c, p + Offset(25 + swing, 59 - _wave), 4, _gold);
    c.restore();
  }

  void _plant(Canvas c, Offset p, double scale, {double sway = 0}) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _shadow(c, const Rect.fromLTWH(-20, -2, 40, 8));
    _path(
      c,
      Path()
        ..moveTo(-15, -25)
        ..lineTo(-11, 0)
        ..quadraticBezierTo(0, 5, 11, 0)
        ..lineTo(15, -25)
        ..close(),
      const Color(0xFFD6AA93),
    );
    _round(c, const Rect.fromLTWH(-17, -29, 34, 9), 4, const Color(0xFFE9C5AB));
    c.save();
    c.translate(0, -28);
    c.rotate(sway * .16);
    c.translate(0, 28);
    _line(
      c,
      const Offset(0, -28),
      const Offset(0, -69),
      const Color(0xFF7FA98B),
      2,
    );
    for (var i = 0; i < 5; i++) {
      c.save();
      c.translate(i.isEven ? -5 : 6, -39 - i * 7.0);
      c.rotate((i.isEven ? -.8 : .8) + sway * (i.isEven ? -.3 : .3));
      _oval(
        c,
        const Rect.fromLTWH(-5, -16, 12, 23),
        i.isEven ? _mint : const Color(0xFF8EB49B),
      );
      _line(
        c,
        const Offset(1, 4),
        const Offset(1, -12),
        _cream.withValues(alpha: .35),
        1,
      );
      c.restore();
    }
    c.restore();
    c.restore();
  }

  void _jar(Canvas c, Offset p, Color color, double scale) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _round(
      c,
      const Rect.fromLTWH(-11, -27, 22, 27),
      6,
      _cream.withValues(alpha: .9),
    );
    _round(
      c,
      const Rect.fromLTWH(-8, -17, 16, 14),
      4,
      color.withValues(alpha: .7),
    );
    _round(c, const Rect.fromLTWH(-12, -30, 24, 6), 3, const Color(0xFFD6B592));
    _line(
      c,
      const Offset(-7, -23),
      const Offset(-7, -9),
      Colors.white.withValues(alpha: .65),
      2,
    );
    c.restore();
  }

  void _bunting(Canvas c, double start, double y, double end) {
    _path(
      c,
      Path()
        ..moveTo(start, y)
        ..quadraticBezierTo((start + end) / 2, y + 22, end, y),
      _ink.withValues(alpha: .4),
      width: 1,
    );
    for (var i = 0; i < 6; i++) {
      final x = start + 10 + (end - start - 20) / 5 * i;
      final dy = math.sin(i / 5 * math.pi) * 9;
      _path(
        c,
        Path()
          ..moveTo(x - 5, y + dy + 1)
          ..lineTo(x + 5, y + dy + 1)
          ..lineTo(x, y + dy + 15)
          ..close(),
        [_rose, _mint, _gold][i % 3],
      );
    }
  }

  void _rug(Canvas c, Offset p, double scale, Color color) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale, scale * .28);
    _cloud(c, const Offset(0, 0), 2.0, color);
    _path(
      c,
      Path()
        ..moveTo(-62, 10)
        ..quadraticBezierTo(-13, 30, 57, 11),
      _rose.withValues(alpha: .25),
      width: 3,
    );
    c.restore();
  }

  void _cloud(Canvas c, Offset p, double scale, Color color) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _oval(c, const Rect.fromLTWH(-37, -6, 76, 30), color);
    _circle(c, const Offset(-20, -2), 19, color);
    _circle(c, const Offset(3, -12), 24, color);
    _circle(c, const Offset(26, -1), 18, color);
    c.restore();
  }

  void _flower(Canvas c, Offset p, double radius, Color color) {
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      _circle(
        c,
        p + Offset(math.cos(angle), math.sin(angle)) * radius,
        radius * .7,
        color,
      );
    }
    _circle(c, p, radius * .55, _gold.withValues(alpha: color.a));
  }

  void _bubble(Canvas c, Offset p, double radius, double opacity) {
    _circle(c, p, radius, Colors.white.withValues(alpha: opacity * .6));
    _oval(
      c,
      Rect.fromCircle(center: p, radius: radius),
      Colors.white.withValues(alpha: opacity),
      stroke: .9,
    );
    _circle(
      c,
      p + Offset(-radius * .3, -radius * .35),
      radius * .22,
      Colors.white.withValues(alpha: opacity),
    );
  }

  void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 - math.pi / 2;
      final size = i.isEven ? r : r * .47;
      final point = p + Offset(math.cos(a), math.sin(a)) * size;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    _path(c, path..close(), color);
  }

  void _heart(Canvas c, Offset p, double r, Color color) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(r / 10);
    _path(
      c,
      Path()
        ..moveTo(0, 10)
        ..cubicTo(-23, -4, -8, -16, 0, -6)
        ..cubicTo(8, -16, 23, -4, 0, 10),
      color,
    );
    c.restore();
  }

  /// Chỗ bé hay đứng ở phòng khác khi bé đang ngủ bên phòng ngủ.
  static List<Offset> awaySpots({
    required PetCareRoom room,
    required PetCarePet selectedPet,
    required Offset mine,
    required bool mineSleeping,
    required bool partnerSleeping,
  }) => [
    if (mineSleeping) mine,
    if (partnerSleeping) partnerSpot(room, selectedPet),
  ];

  void _awayZees(Canvas c) {
    final spots = awaySpots(
      room: room,
      selectedPet: selectedPet,
      mine: position,
      mineSleeping: vitals.sleeping,
      partnerSleeping: partnerVitals.sleeping,
    );
    for (var s = 0; s < spots.length; s++) {
      final base = spots[s] + const Offset(6, -124);
      for (var i = 0; i < 3; i++) {
        final phase = (seconds * .3 + i / 3 + s * .17) % 1;
        _zee(
          c,
          base + Offset(phase * 22 + i * 3, -phase * 40),
          7 + phase * 7,
          const Color(
            0xFF8C7BC4,
          ).withValues(alpha: math.sin(phase * math.pi) * .9),
        );
      }
    }
  }

  /// Chữ "z" vẽ bằng nét (không phải văn bản) cho bé đang ngủ.
  void _zee(Canvas c, Offset p, double size, Color color) {
    _path(
      c,
      Path()
        ..moveTo(p.dx - size / 2, p.dy - size / 2)
        ..lineTo(p.dx + size / 2, p.dy - size / 2)
        ..lineTo(p.dx - size / 2, p.dy + size / 2)
        ..lineTo(p.dx + size / 2, p.dy + size / 2),
      color,
      width: math.max(1.4, size * .22),
    );
  }

  void _shadow(Canvas c, Rect rect) => _oval(
    c,
    rect,
    const Color(0xFF78656D).withValues(alpha: dark ? .15 : .10),
  );
  void _round(Canvas c, Rect rect, double radius, Color color) => c.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    Paint()..color = color,
  );
  void _oval(Canvas c, Rect rect, Color color, {double? stroke}) => c.drawOval(
    rect,
    Paint()
      ..color = color
      ..style = stroke == null ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = stroke ?? 1,
  );
  void _circle(Canvas c, Offset center, double radius, Color color) =>
      c.drawCircle(center, radius, Paint()..color = color);
  void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
  void _path(Canvas c, Path path, Color color, {double? width}) => c.drawPath(
    path,
    Paint()
      ..color = color
      ..style = width == null ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = width ?? 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  @override
  bool shouldRepaint(covariant _PetHousePainter oldDelegate) {
    if (layer != _PetHouseLayer.background) return true;
    return oldDelegate.layer != layer ||
        oldDelegate.room != room ||
        oldDelegate.dark != dark ||
        oldDelegate.decoration != decoration ||
        oldDelegate.small != small ||
        oldDelegate.fillRoom != fillRoom ||
        oldDelegate.roomLook != roomLook ||
        oldDelegate.vitals.sleeping != vitals.sleeping ||
        !mapEquals(oldDelegate.upgrades, upgrades);
  }
}
