import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pet_care_outfit.dart';
import 'pet_care_garden_state.dart';
export 'pet_care_garden_state.dart';
export 'pet_care_outfit.dart';

enum PetCareAction { bath, feed, hug }

enum PetCarePet { rabbit, bear }

enum PetCareMood {
  happy,
  content,
  hungry,
  dirty,
  angry,
  crying,
  sleepy,
  sleeping,
}

enum PetCareRoom { living, kitchen, bathroom, bedroom }

/// Nhóm món trong tủ lạnh, chỉ để xếp kệ và lọc.
enum PetCareFoodKind { fruit, meal, sweet, drink }

/// Thực đơn mua bằng Hạt Ấm theo từng phần ăn. Bốn món đầu dùng ảnh vẽ sẵn
/// trong atlas; các món sau dùng emoji hệ thống (không cần thêm ảnh vào gói).
enum PetCareFood {
  carrot(
    cost: 0,
    nutrition: 22,
    kind: PetCareFoodKind.fruit,
    favorite: PetCarePet.rabbit,
  ),
  apple(cost: 2, nutrition: 30, kind: PetCareFoodKind.fruit),
  soup(cost: 4, nutrition: 45, kind: PetCareFoodKind.meal),
  cake(cost: 6, nutrition: 18, kind: PetCareFoodKind.sweet, joy: 14),
  milk(
    cost: 0,
    nutrition: 14,
    kind: PetCareFoodKind.drink,
    emoji: '🥛',
    energy: 6,
  ),
  banana(cost: 2, nutrition: 26, kind: PetCareFoodKind.fruit, emoji: '🍌'),
  strawberry(
    cost: 3,
    nutrition: 22,
    kind: PetCareFoodKind.fruit,
    emoji: '🍓',
    joy: 8,
    favorite: PetCarePet.rabbit,
  ),
  watermelon(
    cost: 3,
    nutrition: 26,
    kind: PetCareFoodKind.fruit,
    emoji: '🍉',
    joy: 6,
  ),
  grapes(
    cost: 3,
    nutrition: 24,
    kind: PetCareFoodKind.fruit,
    emoji: '🍇',
    joy: 6,
  ),
  corn(cost: 2, nutrition: 30, kind: PetCareFoodKind.fruit, emoji: '🌽'),
  chili(
    cost: 1,
    nutrition: 8,
    kind: PetCareFoodKind.fruit,
    emoji: '🌶️',
    joy: 2,
  ),
  bread(cost: 2, nutrition: 32, kind: PetCareFoodKind.meal, emoji: '🍞'),
  riceBall(cost: 4, nutrition: 40, kind: PetCareFoodKind.meal, emoji: '🍙'),
  dumpling(cost: 4, nutrition: 38, kind: PetCareFoodKind.meal, emoji: '🥟'),
  pancake(
    cost: 5,
    nutrition: 40,
    kind: PetCareFoodKind.meal,
    emoji: '🥞',
    joy: 6,
  ),
  noodles(cost: 5, nutrition: 50, kind: PetCareFoodKind.meal, emoji: '🍜'),
  shrimp(cost: 5, nutrition: 42, kind: PetCareFoodKind.meal, emoji: '🍤'),
  sushi(
    cost: 6,
    nutrition: 44,
    kind: PetCareFoodKind.meal,
    emoji: '🍣',
    favorite: PetCarePet.bear,
  ),
  pizza(
    cost: 6,
    nutrition: 52,
    kind: PetCareFoodKind.meal,
    emoji: '🍕',
    joy: 6,
  ),
  cookie(
    cost: 2,
    nutrition: 12,
    kind: PetCareFoodKind.sweet,
    emoji: '🍪',
    joy: 8,
  ),
  chocolate(
    cost: 3,
    nutrition: 12,
    kind: PetCareFoodKind.sweet,
    emoji: '🍫',
    joy: 10,
  ),
  lollipop(
    cost: 3,
    nutrition: 8,
    kind: PetCareFoodKind.sweet,
    emoji: '🍭',
    joy: 12,
  ),
  donut(
    cost: 4,
    nutrition: 16,
    kind: PetCareFoodKind.sweet,
    emoji: '🍩',
    joy: 12,
  ),
  iceCream(
    cost: 4,
    nutrition: 14,
    kind: PetCareFoodKind.sweet,
    emoji: '🍦',
    joy: 12,
  ),
  honey(
    cost: 5,
    nutrition: 24,
    kind: PetCareFoodKind.sweet,
    emoji: '🍯',
    joy: 10,
    favorite: PetCarePet.bear,
  ),
  pudding(
    cost: 5,
    nutrition: 18,
    kind: PetCareFoodKind.sweet,
    emoji: '🍮',
    joy: 12,
  ),
  birthdayCake(
    cost: 12,
    nutrition: 30,
    kind: PetCareFoodKind.sweet,
    emoji: '🎂',
    joy: 30,
  ),
  juice(
    cost: 3,
    nutrition: 12,
    kind: PetCareFoodKind.drink,
    emoji: '🥤',
    joy: 8,
    energy: 4,
  ),
  tea(
    cost: 2,
    nutrition: 8,
    kind: PetCareFoodKind.drink,
    emoji: '🍵',
    energy: 10,
  );

  const PetCareFood({
    required this.cost,
    required this.nutrition,
    required this.kind,
    this.emoji,
    this.joy = 4,
    this.energy = 2,
    this.favorite,
  });
  final int cost;
  final int nutrition;
  final PetCareFoodKind kind;

  /// Null với bốn món có ảnh vẽ sẵn (atlas).
  final String? emoji;
  final int joy;
  final int energy;

  /// Món ruột: bé được thêm niềm vui và mắt tim khi ăn.
  final PetCarePet? favorite;
  bool get isFree => cost == 0;
  bool get spicy => this == chili;
  bool lovedBy(PetCarePet pet) => favorite == pet;
}

/// Đồ vật trong phòng chạm được. Thứ tự cố định vì dùng làm bit đánh dấu hạt
/// đã tìm trong ngày; chỉ thêm món mới ở cuối.
enum PetCareProp {
  livingWindow(PetCareRoom.living),
  clock(PetCareRoom.living),
  plant(PetCareRoom.living),
  radio(PetCareRoom.living),
  basket(PetCareRoom.living),
  cushion(PetCareRoom.living),
  fridge(PetCareRoom.kitchen),
  stove(PetCareRoom.kitchen),
  sink(PetCareRoom.kitchen),
  utensils(PetCareRoom.kitchen),
  kitchenWindow(PetCareRoom.kitchen),
  jars(PetCareRoom.kitchen),
  bathSink(PetCareRoom.bathroom),
  mirror(PetCareRoom.bathroom),
  duck(PetCareRoom.bathroom),
  towel(PetCareRoom.bathroom),
  bathWindow(PetCareRoom.bathroom),
  cabinet(PetCareRoom.bathroom),
  lamp(PetCareRoom.bedroom),
  curtains(PetCareRoom.bedroom),
  mobile(PetCareRoom.bedroom),
  drawer(PetCareRoom.bedroom),
  books(PetCareRoom.bedroom),
  slippers(PetCareRoom.bedroom);

  const PetCareProp(this.room);
  final PetCareRoom room;

  /// Đèn ngủ là công tắc ngủ/thức; gối sofa nằm sau lưng hai bé nên khó
  /// chạm. Hai món này không giấu hạt.
  bool get canHideSeed => this != lamp && this != cushion;
  static List<PetCareProp> inRoom(PetCareRoom room) =>
      values.where((prop) => prop.room == room).toList(growable: false);
}

/// Phần phòng đổi được như My Talking Tom.
enum PetCareRoomSlot { wall, floor, window, furniture }

/// Giấy dán tường, sàn, cửa sổ và màu nội thất; mỗi ô có một món miễn phí
/// giữ đúng diện mạo cũ của từng phòng. Mua một lần dùng được mọi phòng.
enum PetCareRoomItem {
  wallClassic(PetCareRoomSlot.wall, 0),
  wallPolka(PetCareRoomSlot.wall, 10),
  wallStripe(PetCareRoomSlot.wall, 10),
  wallHearts(PetCareRoomSlot.wall, 14),
  wallClouds(PetCareRoomSlot.wall, 16),
  wallLeaves(PetCareRoomSlot.wall, 18),
  wallCheck(PetCareRoomSlot.wall, 18),
  wallStars(PetCareRoomSlot.wall, 22),
  floorClassic(PetCareRoomSlot.floor, 0),
  floorOak(PetCareRoomSlot.floor, 10),
  floorChecker(PetCareRoomSlot.floor, 14),
  floorCarpet(PetCareRoomSlot.floor, 14),
  floorMarble(PetCareRoomSlot.floor, 18),
  floorGrass(PetCareRoomSlot.floor, 20),
  floorNight(PetCareRoomSlot.floor, 22),
  windowClassic(PetCareRoomSlot.window, 0),
  windowRound(PetCareRoomSlot.window, 10),
  windowBay(PetCareRoomSlot.window, 14),
  windowHeart(PetCareRoomSlot.window, 16),
  windowStar(PetCareRoomSlot.window, 18),
  furnitureClassic(PetCareRoomSlot.furniture, 0),
  furniturePeach(PetCareRoomSlot.furniture, 12),
  furnitureMint(PetCareRoomSlot.furniture, 12),
  furnitureLilac(PetCareRoomSlot.furniture, 12),
  furnitureSky(PetCareRoomSlot.furniture, 14),
  furnitureHoney(PetCareRoomSlot.furniture, 16),
  furnitureCocoa(PetCareRoomSlot.furniture, 18);

  const PetCareRoomItem(this.slot, this.cost);
  final PetCareRoomSlot slot;
  final int cost;
  bool get isFree => cost == 0;

  static PetCareRoomItem defaultFor(PetCareRoomSlot slot) =>
      values.firstWhere((item) => item.slot == slot && item.isFree);
  static List<PetCareRoomItem> forSlot(PetCareRoomSlot slot) =>
      values.where((item) => item.slot == slot).toList(growable: false);
}

/// Diện mạo một phòng truyền xuống cảnh vẽ.
@immutable
class PetCareRoomLook {
  const PetCareRoomLook({
    this.wall = PetCareRoomItem.wallClassic,
    this.floor = PetCareRoomItem.floorClassic,
    this.window = PetCareRoomItem.windowClassic,
    this.furniture = PetCareRoomItem.furnitureClassic,
  });

  final PetCareRoomItem wall;
  final PetCareRoomItem floor;
  final PetCareRoomItem window;
  final PetCareRoomItem furniture;

  PetCareRoomItem operator [](PetCareRoomSlot slot) => switch (slot) {
    PetCareRoomSlot.wall => wall,
    PetCareRoomSlot.floor => floor,
    PetCareRoomSlot.window => window,
    PetCareRoomSlot.furniture => furniture,
  };

  /// Bản xem thử khi đang chọn món trong chế độ trang trí.
  PetCareRoomLook withItem(PetCareRoomItem item) => PetCareRoomLook(
    wall: item.slot == PetCareRoomSlot.wall ? item : wall,
    floor: item.slot == PetCareRoomSlot.floor ? item : floor,
    window: item.slot == PetCareRoomSlot.window ? item : window,
    furniture: item.slot == PetCareRoomSlot.furniture ? item : furniture,
  );

  @override
  bool operator ==(Object other) =>
      other is PetCareRoomLook &&
      other.wall == wall &&
      other.floor == floor &&
      other.window == window &&
      other.furniture == furniture;

  @override
  int get hashCode => Object.hash(wall, floor, window, furniture);
}

/// Điểm gắn kết để bé lớn hẳn (cấp 16, khoảng hơn hai tuần chăm đều).
const petCareGrownBond = 300;

/// Cỡ bé sơ sinh và cỡ lúc trưởng thành (1 = cỡ vẽ gốc).
const petCareBabySize = .4;
const petCareAdultSize = 1.22;

/// Bé lớn dần theo điểm gắn kết của nhà: mới đầu là bé sơ sinh nhỏ xíu
/// (40% cỡ), mỗi lần chăm được điểm là lớn thêm một chút, đủ
/// [petCareGrownBond] điểm (cấp 16) thì lớn hẳn, to cao hơn cỡ gốc.
/// Chỉ đổi cỡ khi vẽ, không đổi chỉ số.
double petCareGrowth(int bondPoints) =>
    petCareBabySize +
    (petCareAdultSize - petCareBabySize) *
        (bondPoints.clamp(0, petCareGrownBond) / petCareGrownBond);

/// Mỗi cấp (một tuổi) cần bấy nhiêu điểm gắn kết; tối đa [petCareMaxLevel].
const petCareBondPerLevel = 20;
const petCareMaxLevel = 20;

/// Cột mốc tuổi: mỗi lần lên cấp là một sinh nhật có tiệc và hộp quà Hạt Ấm,
/// sinh nhật bước sang giai đoạn mới (Bé con, Bé lớn, Trưởng thành) quà to
/// hơn.
abstract final class PetCareBirthday {
  /// Điểm gắn kết cần để tới tuổi [age].
  static int bondFor(int age) => (age - 1) * petCareBondPerLevel;

  /// Giai đoạn bắt đầu đúng ở tuổi [age] (null nếu không đổi giai đoạn).
  static PetCareGrowthStage? stageAt(int age) {
    for (final stage in PetCareGrowthStage.values) {
      if (1 + stage.fromBond ~/ petCareBondPerLevel == age) return stage;
    }
    return null;
  }

  /// Hạt Ấm trong hộp quà sinh nhật [age] tuổi (tuổi 1 là chào đời, không quà).
  static int giftFor(int age) {
    if (age <= 1) return 0;
    final stage = stageAt(age);
    return 4 + age ~/ 2 + (stage != null ? 10 : 0);
  }
}

/// Giai đoạn lớn của hai bé theo điểm gắn kết.
enum PetCareGrowthStage {
  /// Sơ sinh (cấp 1–3): ngậm ti giả, đi lẫm chẫm.
  baby(0),
  kid(60),
  teen(150),
  adult(petCareGrownBond);

  const PetCareGrowthStage(this.fromBond);
  final int fromBond;

  static PetCareGrowthStage of(int bondPoints) => values.lastWhere(
    (stage) => bondPoints >= stage.fromBond,
    orElse: () => baby,
  );
}

/// Giới hạn kiếm Hạt Ấm mỗi ngày từ quảng cáo, mini game, đồ vật và ôm nhau.
abstract final class PetCareEarn {
  static const adSeeds = 5;
  static const adsPerDay = 10;
  static const giftSeeds = 5;

  /// Quảng cáo nhân đôi Hạt sau một ván mini game (mỗi người, mỗi ngày).
  static const doublesPerDay = 5;

  /// Quảng cáo hồi sức cho bé đang mệt (mỗi người, mỗi ngày).
  static const revivesPerDay = 3;

  /// Năng lượng dưới mức này (hoặc bé đang ngủ) mới cần hồi sức.
  static const reviveBelow = 60;
  static const gameSeedsPerDay = 15;
  static const gameEnergy = 8;
  static const pointsPerSeed = 4;
  static const friendSeeds = 2;
  static const hiddenSeedsPerDay = 6;

  /// Bạn ghé chơi (Mèo Mây/Chuột Phô Mai): số lượt ghé và quà mỗi ngày.
  /// Bộ đếm lượt giữ trên máy, không thêm trường vào bản chung của nhà.
  static const guestVisitsPerDay = 4;
  static const guestGiftsPerDay = 3;
  static const guestSeeds = 3;
}

enum PetCareDecor {
  moon(6),
  planet(12),
  garden(18);

  const PetCareDecor(this.cost);
  final int cost;
}

enum PetCareUpgrade { kitchen, bathroom, bedroom }

/// Ô đồ dùng/hoạt ảnh có thể đổi kiểu; mỗi ô luôn có một món miễn phí.
enum PetCareStyleSlot { soap, shower, towel, dance }

/// Món mua bằng Hạt Ấm chỉ đổi hình và hiệu ứng, không đổi chỉ số chăm.
enum PetCareStyle {
  soapLavender(PetCareStyleSlot.soap, 0),
  soapStrawberry(PetCareStyleSlot.soap, 10),
  soapMint(PetCareStyleSlot.soap, 14),
  soapRainbow(PetCareStyleSlot.soap, 24),
  showerClassic(PetCareStyleSlot.shower, 0),
  showerPetal(PetCareStyleSlot.shower, 12),
  showerRainbow(PetCareStyleSlot.shower, 20),
  towelCream(PetCareStyleSlot.towel, 0),
  towelCloud(PetCareStyleSlot.towel, 8),
  towelStar(PetCareStyleSlot.towel, 16),
  danceHop(PetCareStyleSlot.dance, 0),
  danceSpin(PetCareStyleSlot.dance, 12),
  danceHeart(PetCareStyleSlot.dance, 16),
  danceConfetti(PetCareStyleSlot.dance, 22);

  const PetCareStyle(this.slot, this.cost);
  final PetCareStyleSlot slot;
  final int cost;
  bool get isFree => cost == 0;

  static PetCareStyle defaultFor(PetCareStyleSlot slot) =>
      values.firstWhere((style) => style.slot == slot && style.isFree);
  static List<PetCareStyle> forSlot(PetCareStyleSlot slot) =>
      values.where((style) => style.slot == slot).toList(growable: false);
}

/// Bộ đồ đang dùng truyền xuống cảnh; mặc định là các món miễn phí.
@immutable
class PetCareLook {
  const PetCareLook({
    this.soap = PetCareStyle.soapLavender,
    this.shower = PetCareStyle.showerClassic,
    this.towel = PetCareStyle.towelCream,
    this.dance = PetCareStyle.danceHop,
  });

  final PetCareStyle soap;
  final PetCareStyle shower;
  final PetCareStyle towel;
  final PetCareStyle dance;

  PetCareStyle operator [](PetCareStyleSlot slot) => switch (slot) {
    PetCareStyleSlot.soap => soap,
    PetCareStyleSlot.shower => shower,
    PetCareStyleSlot.towel => towel,
    PetCareStyleSlot.dance => dance,
  };

  @override
  bool operator ==(Object other) =>
      other is PetCareLook &&
      other.soap == soap &&
      other.shower == shower &&
      other.towel == towel &&
      other.dance == dance;

  @override
  int get hashCode => Object.hash(soap, shower, towel, dance);
}

String petCareDay(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

int _clampInt(int value, int min, int max) => value.clamp(min, max);

class PetCareVitals {
  const PetCareVitals({
    this.joy = 76,
    this.food = 58,
    this.clean = 64,
    this.energy = 82,
    this.sleeping = false,
    this.joyRemainder = 0,
    this.foodRemainder = 0,
    this.cleanRemainder = 0,
    this.energyRemainder = 0,
  });

  final int joy;
  final int food;
  final int clean;
  final int energy;
  final bool sleeping;
  // Phần lẻ của nhịp giờ (microsecond × tốc độ), giữ qua mỗi lần refresh/lưu.
  final int joyRemainder;
  final int foodRemainder;
  final int cleanRemainder;
  final int energyRemainder;

  PetCareMood get mood {
    if (sleeping) return PetCareMood.sleeping;
    if (joy <= 20) return PetCareMood.crying;
    if (clean <= 25) return PetCareMood.dirty;
    if (food <= 25) return PetCareMood.hungry;
    if (energy <= 22) return PetCareMood.sleepy;
    if (joy < 50) return PetCareMood.angry;
    if (joy < 76) return PetCareMood.content;
    return PetCareMood.happy;
  }

  bool get isDirty => clean <= 25;
  bool get isHungry => food <= 25;
  bool get isCrying => mood == PetCareMood.crying;

  PetCareVitals copyWith({
    int? joy,
    int? food,
    int? clean,
    int? energy,
    bool? sleeping,
    int? joyRemainder,
    int? foodRemainder,
    int? cleanRemainder,
    int? energyRemainder,
  }) => PetCareVitals(
    joy: _clampInt(joy ?? this.joy, 0, 100),
    food: _clampInt(food ?? this.food, 0, 100),
    clean: _clampInt(clean ?? this.clean, 0, 100),
    energy: _clampInt(energy ?? this.energy, 0, 100),
    sleeping: sleeping ?? this.sleeping,
    joyRemainder: joyRemainder ?? (joy == null ? this.joyRemainder : 0),
    foodRemainder: foodRemainder ?? (food == null ? this.foodRemainder : 0),
    cleanRemainder: cleanRemainder ?? (clean == null ? this.cleanRemainder : 0),
    energyRemainder:
        energyRemainder ??
        (energy == null && sleeping == null ? this.energyRemainder : 0),
  );

  Map<String, dynamic> toJson() => {
    'joy': joy,
    'food': food,
    'clean': clean,
    'energy': energy,
    'sleeping': sleeping,
    'remainder': {
      'joy': joyRemainder,
      'food': foodRemainder,
      'clean': cleanRemainder,
      'energy': energyRemainder,
    },
  };

  factory PetCareVitals.fromJson(
    dynamic raw, {
    PetCareVitals fallback = const PetCareVitals(),
  }) {
    if (raw is! Map) return fallback;
    int number(String key, int value) =>
        raw[key] is num ? _clampInt((raw[key] as num).round(), 0, 100) : value;
    final remainder = raw['remainder'];
    int fraction(String key) => remainder is Map && remainder[key] is num
        ? _clampInt((remainder[key] as num).round(), 0, 3599999999)
        : 0;
    return PetCareVitals(
      joy: number('joy', fallback.joy),
      food: number('food', fallback.food),
      clean: number('clean', fallback.clean),
      energy: number('energy', fallback.energy),
      sleeping: raw['sleeping'] is bool
          ? raw['sleeping'] as bool
          : fallback.sleeping,
      joyRemainder: fraction('joy'),
      foodRemainder: fraction('food'),
      cleanRemainder: fraction('clean'),
      energyRemainder: fraction('energy'),
    );
  }
}

class PetCareProgress {
  const PetCareProgress({
    required this.day,
    this.joy = 76,
    this.food = 58,
    this.clean = 64,
    this.energy = 82,
    this.seeds = 0,
    this.careMask = 0,
    this.claimedDay,
    this.unlocked = const {},
    this.decoration,
    this.selectedPet = PetCarePet.rabbit,
    this.rabbitState,
    this.bearState,
    this.lastEvaluatedAt,
    this.bondPoints = 0,
    this.dailyPlayCount = 0,
    this.dailyPlayDay,
    this.upgradeLevels = const {},
    this.dailyBondPoints = 0,
    this.ownedOutfits = const {},
    this.wornOutfits = const {},
    this.ownedStyles = const {},
    this.equippedStyles = const {},
    this.roomItems = const {},
    this.roomLooks = const {},
    this.adDay,
    this.adCount = 0,
    this.foundDay,
    this.foundMask = 0,
    this.gameDay,
    this.gameSeeds = 0,
    this.friendDay,
    this.doubleDay,
    this.doubleCount = 0,
    this.reviveDay,
    this.reviveCount = 0,
    this.giftDoubleDay,
    this.birthdayLevel = 1,
    this.garden = const PetCareGarden(),
  });

  factory PetCareProgress.forPet(PetCarePet pet, {String? day, DateTime? now}) {
    final today = day ?? petCareDay(now ?? DateTime.now());
    const starter = PetCareVitals();
    return PetCareProgress(
      day: today,
      selectedPet: pet,
      rabbitState: starter,
      bearState: starter,
      lastEvaluatedAt: now,
    );
  }

  final PetCareGarden garden;
  final String day;
  final int joy;
  final int food;
  final int clean;
  final int energy;
  final int seeds;
  final int careMask;
  final String? claimedDay;
  final Set<PetCareDecor> unlocked;
  final PetCareDecor? decoration;
  final PetCarePet selectedPet;
  final PetCareVitals? rabbitState;
  final PetCareVitals? bearState;
  final DateTime? lastEvaluatedAt;
  final int bondPoints;
  final int dailyPlayCount;
  final String? dailyPlayDay;
  final Map<PetCareUpgrade, int> upgradeLevels;
  final int dailyBondPoints;

  /// Trang phục mua chung cả nhà; mỗi bé có lựa chọn mặc riêng.
  final Set<PetCareOutfit> ownedOutfits;
  final Map<PetCarePet, PetCareOutfit> wornOutfits;

  bool ownsOutfit(PetCareOutfit outfit) =>
      outfit.isFree || ownedOutfits.contains(outfit);

  PetCareOutfit outfitFor(PetCarePet pet) {
    final worn = wornOutfits[pet];
    return worn != null && ownsOutfit(worn) ? worn : PetCareOutfit.bare;
  }

  /// Món trả phí đã mua; món miễn phí luôn thuộc về người chơi.
  final Set<PetCareStyle> ownedStyles;
  final Map<PetCareStyleSlot, PetCareStyle> equippedStyles;

  /// Đồ trang trí phòng đã mua (món miễn phí luôn có) và lựa chọn từng phòng.
  final Set<PetCareRoomItem> roomItems;
  final Map<PetCareRoom, Map<PetCareRoomSlot, PetCareRoomItem>> roomLooks;

  /// Lượt xem quảng cáo nhận Hạt trong ngày [adDay].
  final String? adDay;
  final int adCount;

  /// Bit theo [PetCareProp.index]: hạt giấu đã tìm trong ngày [foundDay].
  final String? foundDay;
  final int foundMask;

  /// Hạt đã nhận từ mini game trong ngày [gameDay].
  final String? gameDay;
  final int gameSeeds;

  /// Ngày hai bé đã ôm nhau nhận quà.
  final String? friendDay;

  /// Lượt quảng cáo nhân đôi Hạt mini game trong ngày [doubleDay].
  final String? doubleDay;
  final int doubleCount;

  /// Lượt quảng cáo hồi sức cho bé trong ngày [reviveDay].
  final String? reviveDay;
  final int reviveCount;

  /// Ngày quà chăm bé đã được nhân đôi bằng quảng cáo (chung cả nhà).
  final String? giftDoubleDay;

  /// Tuổi (cấp) cao nhất đã mở quà sinh nhật, chung cả nhà. Nhà cũ chưa có
  /// trường này bắt đầu từ 1 nên các sinh nhật đã qua vẫn mở quà được.
  final int birthdayLevel;

  /// Các sinh nhật đã tới mà chưa mở quà.
  List<int> get pendingBirthdays => [
    for (var age = birthdayLevel + 1; age <= level; age++) age,
  ];

  /// Tổng Hạt Ấm của các hộp quà sinh nhật đang chờ mở.
  int get birthdayGiftPending => pendingBirthdays.fold(
    0,
    (sum, age) => sum + PetCareBirthday.giftFor(age),
  );

  /// Mở mọi hộp quà sinh nhật đang chờ (một lần cho cả nhà mỗi tuổi).
  PetCareProgress openBirthdayGifts() {
    final gift = birthdayGiftPending;
    if (gift <= 0) return this;
    return copyWith(seeds: seeds + gift, birthdayLevel: level);
  }

  int get adsToday => adDay == day ? adCount : 0;
  bool get canWatchAd => adsToday < PetCareEarn.adsPerDay;
  int get doublesToday => doubleDay == day ? doubleCount : 0;
  bool get canDoubleGame => doublesToday < PetCareEarn.doublesPerDay;
  int get revivesToday => reviveDay == day ? reviveCount : 0;
  bool get giftDoubledToday => giftDoubleDay == day;
  bool get canDoubleGift => claimed && !giftDoubledToday;

  /// Bé đang ngủ hoặc mệt, còn lượt hồi sức hôm nay.
  bool canRevive(PetCarePet pet) {
    final vitals = vitalsFor(pet);
    return revivesToday < PetCareEarn.revivesPerDay &&
        (vitals.sleeping || vitals.energy < PetCareEarn.reviveBelow);
  }

  int get gameSeedsToday => gameDay == day ? gameSeeds : 0;
  int get foundToday => foundDay == day ? foundMask : 0;
  bool get huggedFriendToday => friendDay == day;

  bool ownsRoomItem(PetCareRoomItem item) =>
      item.isFree || roomItems.contains(item);
  PetCareRoomItem roomItemFor(PetCareRoom room, PetCareRoomSlot slot) {
    final chosen = roomLooks[room]?[slot];
    return chosen != null && chosen.slot == slot && ownsRoomItem(chosen)
        ? chosen
        : PetCareRoomItem.defaultFor(slot);
  }

  PetCareRoomLook roomLook(PetCareRoom room) => PetCareRoomLook(
    wall: roomItemFor(room, PetCareRoomSlot.wall),
    floor: roomItemFor(room, PetCareRoomSlot.floor),
    window: roomItemFor(room, PetCareRoomSlot.window),
    furniture: roomItemFor(room, PetCareRoomSlot.furniture),
  );

  /// Đồ vật giấu hạt hôm nay: mỗi phòng một món, phòng khách và bếp thêm
  /// một món nữa. Chọn theo ngày nên mở lại app trong ngày vẫn giống nhau.
  static Set<PetCareProp> hiddenProps(String day) {
    var hash = 17;
    for (final unit in day.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final result = <PetCareProp>{};
    for (final room in PetCareRoom.values) {
      final choices = PetCareProp.inRoom(
        room,
      ).where((prop) => prop.canHideSeed).toList(growable: false);
      final count = room == PetCareRoom.living || room == PetCareRoom.kitchen
          ? 2
          : 1;
      var seed = hash + room.index * 7919;
      for (var i = 0; i < count; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        var pick = choices[seed % choices.length];
        while (result.contains(pick)) {
          pick = choices[(choices.indexOf(pick) + 1) % choices.length];
        }
        result.add(pick);
      }
    }
    return result;
  }

  Set<PetCareProp> get seedPropsLeft => {
    for (final prop in hiddenProps(day))
      if (foundToday & (1 << prop.index) == 0) prop,
  };
  int get seedsFoundToday => hiddenProps(
    day,
  ).where((prop) => foundToday & (1 << prop.index) != 0).length;

  bool ownsStyle(PetCareStyle style) =>
      style.isFree || ownedStyles.contains(style);
  PetCareStyle styleFor(PetCareStyleSlot slot) {
    final chosen = equippedStyles[slot];
    return chosen != null && chosen.slot == slot && ownsStyle(chosen)
        ? chosen
        : PetCareStyle.defaultFor(slot);
  }

  PetCareLook get look => PetCareLook(
    soap: styleFor(PetCareStyleSlot.soap),
    shower: styleFor(PetCareStyleSlot.shower),
    towel: styleFor(PetCareStyleSlot.towel),
    dance: styleFor(PetCareStyleSlot.dance),
  );

  PetCareVitals get _legacyVitals =>
      PetCareVitals(joy: joy, food: food, clean: clean, energy: energy);
  PetCareVitals get rabbitVitals => rabbitState ?? _legacyVitals;
  PetCareVitals get bearVitals => bearState ?? _legacyVitals;
  Map<PetCarePet, PetCareVitals> get petVitals => Map.unmodifiable({
    PetCarePet.rabbit: rabbitVitals,
    PetCarePet.bear: bearVitals,
  });
  PetCareVitals vitalsFor(PetCarePet pet) =>
      pet == PetCarePet.rabbit ? rabbitVitals : bearVitals;
  PetCareVitals get currentVitals => vitalsFor(selectedPet);
  PetCareMood get mood => currentVitals.mood;
  int get bond => bondPoints;
  int get level =>
      _clampInt(1 + bondPoints ~/ petCareBondPerLevel, 1, petCareMaxLevel);
  int get playCurrency => seeds;
  int get currency => seeds;

  int get completed => PetCareAction.values
      .where((action) => careMask & (1 << action.index) != 0)
      .length;
  bool get claimed => claimedDay != null && claimedDay!.compareTo(day) >= 0;
  bool get canClaim => completed == PetCareAction.values.length && !claimed;
  bool didCare(PetCareAction action) => careMask & (1 << action.index) != 0;

  int upgradeLevel(PetCareUpgrade upgrade) => upgradeLevels[upgrade] ?? 0;
  int get kitchenLevel => upgradeLevel(PetCareUpgrade.kitchen);
  int get bathroomLevel => upgradeLevel(PetCareUpgrade.bathroom);
  int get bedroomLevel => upgradeLevel(PetCareUpgrade.bedroom);

  int upgradeCost(PetCareUpgrade upgrade) {
    final level = upgradeLevel(upgrade);
    if (level >= 3) return 0;
    const base = {
      PetCareUpgrade.kitchen: 8,
      PetCareUpgrade.bathroom: 8,
      PetCareUpgrade.bedroom: 10,
    };
    return base[upgrade]! * (level + 1);
  }

  PetCareProgress copyWith({
    String? day,
    int? joy,
    int? food,
    int? clean,
    int? energy,
    int? seeds,
    int? careMask,
    String? claimedDay,
    Set<PetCareDecor>? unlocked,
    PetCareDecor? decoration,
    PetCarePet? selectedPet,
    PetCareVitals? rabbitState,
    PetCareVitals? bearState,
    DateTime? lastEvaluatedAt,
    int? bondPoints,
    int? dailyPlayCount,
    String? dailyPlayDay,
    Map<PetCareUpgrade, int>? upgradeLevels,
    int? dailyBondPoints,
    Set<PetCareOutfit>? ownedOutfits,
    Map<PetCarePet, PetCareOutfit>? wornOutfits,
    Set<PetCareStyle>? ownedStyles,
    Map<PetCareStyleSlot, PetCareStyle>? equippedStyles,
    Set<PetCareRoomItem>? roomItems,
    Map<PetCareRoom, Map<PetCareRoomSlot, PetCareRoomItem>>? roomLooks,
    String? adDay,
    int? adCount,
    String? foundDay,
    int? foundMask,
    String? gameDay,
    int? gameSeeds,
    String? friendDay,
    String? doubleDay,
    int? doubleCount,
    String? reviveDay,
    int? reviveCount,
    String? giftDoubleDay,
    int? birthdayLevel,
    PetCareGarden? garden,
  }) {
    final nextPet = selectedPet ?? this.selectedPet;
    final nextRabbit = rabbitState ?? this.rabbitState;
    final nextBear = bearState ?? this.bearState;
    final visible = nextPet == PetCarePet.rabbit ? nextRabbit : nextBear;
    return PetCareProgress(
      day: day ?? this.day,
      joy: joy ?? visible?.joy ?? this.joy,
      food: food ?? visible?.food ?? this.food,
      clean: clean ?? visible?.clean ?? this.clean,
      energy: energy ?? visible?.energy ?? this.energy,
      seeds: seeds ?? this.seeds,
      careMask: careMask ?? this.careMask,
      claimedDay: claimedDay ?? this.claimedDay,
      unlocked: unlocked ?? this.unlocked,
      decoration: decoration ?? this.decoration,
      selectedPet: nextPet,
      rabbitState: nextRabbit,
      bearState: nextBear,
      lastEvaluatedAt: lastEvaluatedAt ?? this.lastEvaluatedAt,
      bondPoints: bondPoints ?? this.bondPoints,
      dailyPlayCount: dailyPlayCount ?? this.dailyPlayCount,
      dailyPlayDay: dailyPlayDay ?? this.dailyPlayDay,
      upgradeLevels: upgradeLevels ?? this.upgradeLevels,
      dailyBondPoints: dailyBondPoints ?? this.dailyBondPoints,
      ownedOutfits: ownedOutfits ?? this.ownedOutfits,
      wornOutfits: wornOutfits ?? this.wornOutfits,
      ownedStyles: ownedStyles ?? this.ownedStyles,
      equippedStyles: equippedStyles ?? this.equippedStyles,
      roomItems: roomItems ?? this.roomItems,
      roomLooks: roomLooks ?? this.roomLooks,
      adDay: adDay ?? this.adDay,
      adCount: adCount ?? this.adCount,
      foundDay: foundDay ?? this.foundDay,
      foundMask: foundMask ?? this.foundMask,
      gameDay: gameDay ?? this.gameDay,
      gameSeeds: gameSeeds ?? this.gameSeeds,
      friendDay: friendDay ?? this.friendDay,
      doubleDay: doubleDay ?? this.doubleDay,
      doubleCount: doubleCount ?? this.doubleCount,
      reviveDay: reviveDay ?? this.reviveDay,
      reviveCount: reviveCount ?? this.reviveCount,
      giftDoubleDay: giftDoubleDay ?? this.giftDoubleDay,
      birthdayLevel: birthdayLevel ?? this.birthdayLevel,
      garden: garden ?? this.garden,
    );
  }

  PetCareProgress _withPet(PetCarePet pet, PetCareVitals value) {
    final rabbit = pet == PetCarePet.rabbit ? value : rabbitVitals;
    final bear = pet == PetCarePet.bear ? value : bearVitals;
    final visible = pet == selectedPet ? value : currentVitals;
    return copyWith(
      joy: visible.joy,
      food: visible.food,
      clean: visible.clean,
      energy: visible.energy,
      rabbitState: rabbit,
      bearState: bear,
    );
  }

  PetCareProgress _withBoth(PetCareVitals rabbit, PetCareVitals bear) {
    final visible = selectedPet == PetCarePet.rabbit ? rabbit : bear;
    return copyWith(
      joy: visible.joy,
      food: visible.food,
      clean: visible.clean,
      energy: visible.energy,
      rabbitState: rabbit,
      bearState: bear,
    );
  }

  PetCareVitals _careVitals(
    PetCarePet pet,
    PetCareAction action,
    PetCareFood foodChoice,
  ) {
    final before = vitalsFor(pet);
    if (before.sleeping) return before;
    final bathroomBonus = bathroomLevel * 5;
    final kitchenBonus = kitchenLevel * 4;
    switch (action) {
      case PetCareAction.bath:
        if (before.clean >= 100) return before;
        return before.copyWith(
          clean: before.clean + 24 + bathroomBonus,
          joy: before.joy + 5,
        );
      case PetCareAction.feed:
        if (before.food >= 100) return before;
        return before.copyWith(
          food: before.food + foodChoice.nutrition + kitchenBonus,
          joy: before.joy + foodChoice.joy + (foodChoice.lovedBy(pet) ? 6 : 0),
          energy: before.energy + foodChoice.energy,
        );
      case PetCareAction.hug:
        if (before.joy >= 100 && before.energy >= 100) return before;
        return before.copyWith(joy: before.joy + 16, energy: before.energy + 3);
    }
  }

  PetCareProgress care(
    PetCareAction action, {
    PetCarePet? pet,
    PetCareFood food = PetCareFood.carrot,
  }) {
    if (action == PetCareAction.feed && seeds < food.cost) return this;
    if (pet != null && vitalsFor(pet).sleeping) return this;
    if (pet == null && rabbitVitals.sleeping && bearVitals.sleeping) {
      return this;
    }
    if (action == PetCareAction.feed &&
        food.cost > 0 &&
        (pet == null
            ? rabbitVitals.food >= 100 && bearVitals.food >= 100
            : vitalsFor(pet).food >= 100)) {
      return this;
    }
    final changed = pet == null
        ? _withBoth(
            _careVitals(PetCarePet.rabbit, action, food),
            _careVitals(PetCarePet.bear, action, food),
          )
        : _withPet(pet, _careVitals(pet, action, food));
    final firstCare = careMask == 0;
    final improved =
        jsonEncode(
          changed.petVitals.map(
            (key, value) => MapEntry(key.name, value.toJson()),
          ),
        ) !=
        jsonEncode(
          petVitals.map((key, value) => MapEntry(key.name, value.toJson())),
        );
    if (!improved) return this;
    final earnedBond = dailyBondPoints < 30 ? 1 : 0;
    return changed.copyWith(
      seeds:
          seeds +
          (firstCare ? 1 : 0) -
          (action == PetCareAction.feed ? food.cost : 0),
      careMask: careMask | (1 << action.index),
      bondPoints: bondPoints + earnedBond,
      dailyBondPoints: dailyBondPoints + earnedBond,
    );
  }

  PetCareProgress play(PetCarePet pet) {
    final before = vitalsFor(pet);
    if (before.sleeping || before.energy < 10) return this;
    final alreadyToday = dailyPlayDay == day ? dailyPlayCount : 0;
    final earn = alreadyToday < 3 ? 1 : 0;
    final earnedBond = before.joy < 100
        ? _clampInt(30 - dailyBondPoints, 0, 2)
        : 0;
    final next = _withPet(
      pet,
      before.copyWith(joy: before.joy + 14, energy: before.energy - 10),
    );
    return next.copyWith(
      seeds: seeds + earn,
      careMask: careMask | (1 << PetCareAction.hug.index),
      bondPoints: bondPoints + earnedBond,
      dailyBondPoints: dailyBondPoints + earnedBond,
      dailyPlayCount: _clampInt(alreadyToday + 1, 0, 3),
      dailyPlayDay: day,
    );
  }

  PetCareProgress rest(PetCarePet pet) {
    final before = vitalsFor(pet);
    return _withPet(pet, before.copyWith(sleeping: !before.sleeping));
  }

  /// Rời phòng ngủ thì bé dậy theo, không để đồ ở phòng khác bị khóa.
  PetCareProgress wake(PetCarePet pet) {
    final before = vitalsFor(pet);
    if (!before.sleeping) return this;
    return _withPet(pet, before.copyWith(sleeping: false));
  }

  PetCareProgress claim() => canClaim
      ? copyWith(seeds: seeds + PetCareEarn.giftSeeds, claimedDay: day)
      : this;

  /// Xem quảng cáo nhân đôi quà chăm bé hôm nay: một lần mỗi ngày cho cả nhà.
  PetCareProgress doubleGift() => canDoubleGift
      ? copyWith(seeds: seeds + PetCareEarn.giftSeeds, giftDoubleDay: day)
      : this;

  PetCareProgress decorate(PetCareDecor decor) {
    if (unlocked.contains(decor)) return copyWith(decoration: decor);
    if (seeds < decor.cost) return this;
    return copyWith(
      seeds: seeds - decor.cost,
      unlocked: Set.unmodifiable({...unlocked, decor}),
      decoration: decor,
    );
  }

  PetCareProgress upgrade(PetCareUpgrade upgrade) {
    final oldLevel = upgradeLevel(upgrade);
    final cost = upgradeCost(upgrade);
    if (oldLevel >= 3 || seeds < cost) return this;
    return copyWith(
      seeds: seeds - cost,
      bondPoints: bondPoints + 2,
      upgradeLevels: Map.unmodifiable({
        ...upgradeLevels,
        upgrade: oldLevel + 1,
      }),
    );
  }

  /// Mua một lần cho cả nhà rồi mặc cho đúng bé đã chọn. Chọn bộ gốc
  /// để tháo đồ; không đổi lựa chọn của bé kia hoặc chỉ số chăm sóc.
  PetCareProgress useOutfit(PetCarePet pet, PetCareOutfit outfit) {
    final owned = ownsOutfit(outfit);
    if (owned && outfitFor(pet) == outfit) return this;
    if (!owned && seeds < outfit.cost) return this;
    return copyWith(
      seeds: seeds - (owned ? 0 : outfit.cost),
      ownedOutfits: Set.unmodifiable({
        ...ownedOutfits,
        if (!outfit.isFree) outfit,
      }),
      wornOutfits: Map.unmodifiable({...wornOutfits, pet: outfit}),
    );
  }

  /// Mua món chưa có (trừ Hạt Ấm) rồi dùng ngay; món đã có thì chỉ đổi sang.
  PetCareProgress useStyle(PetCareStyle style) {
    if (ownsStyle(style)) {
      if (styleFor(style.slot) == style) return this;
      return copyWith(
        equippedStyles: Map.unmodifiable({
          ...equippedStyles,
          style.slot: style,
        }),
      );
    }
    if (seeds < style.cost) return this;
    return copyWith(
      seeds: seeds - style.cost,
      ownedStyles: Set.unmodifiable({...ownedStyles, style}),
      equippedStyles: Map.unmodifiable({...equippedStyles, style.slot: style}),
    );
  }

  /// Mua đồ trang trí chưa có rồi đặt vào [room]; món đã có thì chỉ đổi.
  PetCareProgress useRoomItem(PetCareRoom room, PetCareRoomItem item) {
    Map<PetCareRoom, Map<PetCareRoomSlot, PetCareRoomItem>> placed() =>
        Map.unmodifiable({
          ...roomLooks,
          room: Map<PetCareRoomSlot, PetCareRoomItem>.unmodifiable({
            ...?roomLooks[room],
            item.slot: item,
          }),
        });
    if (ownsRoomItem(item)) {
      if (roomItemFor(room, item.slot) == item) return this;
      return copyWith(roomLooks: placed());
    }
    if (seeds < item.cost) return this;
    return copyWith(
      seeds: seeds - item.cost,
      roomItems: Set.unmodifiable({...roomItems, item}),
      roomLooks: placed(),
    );
  }

  /// Chạm đúng đồ vật giấu hạt hôm nay: +1 Hạt, mỗi món một lần/ngày.
  PetCareProgress findSeed(PetCareProp prop) {
    if (!hiddenProps(day).contains(prop)) return this;
    final mask = foundToday;
    if (mask & (1 << prop.index) != 0) return this;
    return copyWith(
      seeds: seeds + 1,
      foundDay: day,
      foundMask: mask | (1 << prop.index),
    );
  }

  /// Bạn ghé chơi ăn xong bánh được mời: tặng Hạt. Trần mỗi ngày do màn
  /// chơi đếm trên máy ([PetCareEarn.guestGiftsPerDay]).
  PetCareProgress guestGift() =>
      copyWith(seeds: seeds + PetCareEarn.guestSeeds);

  /// Xem hết quảng cáo có thưởng (hoặc PRO được bỏ qua quảng cáo).
  PetCareProgress rewardAd() {
    if (!canWatchAd) return this;
    return copyWith(
      seeds: seeds + PetCareEarn.adSeeds,
      adDay: day,
      adCount: adsToday + 1,
    );
  }

  /// Xem quảng cáo nhân đôi Hạt vừa nhận từ một ván mini game.
  PetCareProgress doubleGame(int earned) {
    final bonus = _clampInt(earned, 0, PetCareEarn.gameSeedsPerDay);
    if (!canDoubleGame || bonus == 0) return this;
    return copyWith(
      seeds: seeds + bonus,
      doubleDay: day,
      doubleCount: doublesToday + 1,
    );
  }

  /// Xem quảng cáo hồi sức: bé thức dậy, đầy năng lượng để chơi tiếp ngay.
  PetCareProgress revive(PetCarePet pet) {
    if (!canRevive(pet)) return this;
    final before = vitalsFor(pet);
    return _withPet(
      pet,
      before.copyWith(energy: 100, sleeping: false),
    ).copyWith(reviveDay: day, reviveCount: revivesToday + 1);
  }

  /// Một ván mini game: tốn năng lượng, bé vui hơn, đổi điểm ra Hạt theo trần ngày.
  PetCareProgress rewardGame(PetCarePet pet, int score) {
    final before = vitalsFor(pet);
    if (before.sleeping || before.energy < PetCareEarn.gameEnergy) return this;
    final earned = _clampInt(
      score ~/ PetCareEarn.pointsPerSeed,
      0,
      PetCareEarn.gameSeedsPerDay - gameSeedsToday,
    );
    final earnedBond = _clampInt(30 - dailyBondPoints, 0, 2);
    final next = _withPet(
      pet,
      before.copyWith(
        joy: before.joy + 10,
        energy: before.energy - PetCareEarn.gameEnergy,
      ),
    );
    return next.copyWith(
      seeds: seeds + earned,
      gameDay: day,
      gameSeeds: gameSeedsToday + earned,
      bondPoints: bondPoints + earnedBond,
      dailyBondPoints: dailyBondPoints + earnedBond,
    );
  }

  /// Hai bé ôm nhau: chỉ bé của mình đổi chỉ số; quà Hạt một lần mỗi ngày.
  PetCareProgress hugFriend(PetCarePet pet) {
    final before = vitalsFor(pet);
    if (before.sleeping) return this;
    final gift = huggedFriendToday ? 0 : PetCareEarn.friendSeeds;
    final next = _withPet(pet, before.copyWith(joy: before.joy + 8));
    return next.copyWith(seeds: seeds + gift, friendDay: day);
  }

  /// Các mục riêng của từng người khi hai máy dùng chung một bản: bé đang
  /// xem, lượt quảng cáo (nhận Hạt, nhân đôi, hồi sức) và Hạt mini game
  /// trong ngày (mỗi người một trần).
  PetCareProgress withPersonal(PetCareProgress mine) => PetCareProgress(
    day: day,
    seeds: seeds,
    careMask: careMask,
    claimedDay: claimedDay,
    unlocked: unlocked,
    decoration: decoration,
    selectedPet: mine.selectedPet,
    rabbitState: rabbitVitals,
    bearState: bearVitals,
    lastEvaluatedAt: lastEvaluatedAt,
    bondPoints: bondPoints,
    dailyPlayCount: dailyPlayCount,
    dailyPlayDay: dailyPlayDay,
    upgradeLevels: upgradeLevels,
    dailyBondPoints: dailyBondPoints,
    ownedOutfits: ownedOutfits,
    wornOutfits: wornOutfits,
    ownedStyles: ownedStyles,
    equippedStyles: equippedStyles,
    roomItems: roomItems,
    roomLooks: roomLooks,
    adDay: mine.adDay,
    adCount: mine.adCount,
    foundDay: foundDay,
    foundMask: foundMask,
    gameDay: mine.gameDay,
    gameSeeds: mine.gameSeeds,
    friendDay: friendDay,
    doubleDay: mine.doubleDay,
    doubleCount: mine.doubleCount,
    reviveDay: mine.reviveDay,
    reviveCount: mine.reviveCount,
    giftDoubleDay: giftDoubleDay,
    birthdayLevel: birthdayLevel,
    garden: garden,
  ).copyWith(selectedPet: mine.selectedPet);

  /// Lần đầu một máy nối vào bản chung của nhà: bé của người này lấy theo
  /// máy họ (trước đây chỉ họ chăm được), Hạt cộng chung, đồ đã mua gộp lại,
  /// lựa chọn trang trí giữ theo bản chung nếu đã có.
  static PetCareProgress joinHouse({
    required PetCareProgress shared,
    required PetCareProgress mine,
    required PetCarePet owned,
  }) {
    final rabbit = owned == PetCarePet.rabbit
        ? mine.rabbitVitals
        : shared.rabbitVitals;
    final bear = owned == PetCarePet.bear ? mine.bearVitals : shared.bearVitals;
    final levels = <PetCareUpgrade, int>{
      for (final upgrade in PetCareUpgrade.values)
        if (math.max(shared.upgradeLevel(upgrade), mine.upgradeLevel(upgrade))
            case final level when level > 0)
          upgrade: level,
    };
    final looks = <PetCareRoom, Map<PetCareRoomSlot, PetCareRoomItem>>{
      ...mine.roomLooks,
      for (final entry in shared.roomLooks.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
    return shared
        ._withBoth(rabbit, bear)
        .copyWith(
          seeds: shared.seeds + mine.seeds,
          unlocked: {...shared.unlocked, ...mine.unlocked},
          decoration: shared.decoration ?? mine.decoration,
          bondPoints: math.max(shared.bondPoints, mine.bondPoints),
          upgradeLevels: levels,
          ownedOutfits: {...shared.ownedOutfits, ...mine.ownedOutfits},
          wornOutfits: {...mine.wornOutfits, ...shared.wornOutfits},
          ownedStyles: {...shared.ownedStyles, ...mine.ownedStyles},
          equippedStyles: {...mine.equippedStyles, ...shared.equippedStyles},
          roomItems: {...shared.roomItems, ...mine.roomItems},
          roomLooks: looks,
          garden: shared.garden.isEmpty ? mine.garden : shared.garden,
          birthdayLevel: math.max(shared.birthdayLevel, mine.birthdayLevel),
        )
        .withPersonal(mine);
  }

  PetCareProgress elapsed(DateTime now) {
    final previous = lastEvaluatedAt;
    if (previous != null && !now.isAfter(previous)) return this;
    final started = onDay(now);
    if (previous == null) return started.copyWith(lastEvaluatedAt: now);
    const hour = 60 * 60 * Duration.microsecondsPerSecond;
    final microseconds = now
        .difference(previous)
        .inMicroseconds
        .clamp(0, 48 * hour);
    List<int> step(int value, int rate, int remainder, {bool restore = false}) {
      final units = microseconds * rate + remainder;
      final amount = units ~/ hour;
      final floor = value < 5 ? value : 5;
      final next = restore
          ? _clampInt(value + amount, 0, 100)
          : _clampInt(value - amount, floor, 100);
      final atLimit = restore ? next == 100 : next == floor;
      return [next, atLimit ? 0 : units % hour];
    }

    PetCareVitals tick(PetCarePet pet) {
      final before = started.vitalsFor(pet);
      final bedroomBonus = started.bedroomLevel;
      final food = step(before.food, 4, before.foodRemainder);
      final clean = step(before.clean, 4, before.cleanRemainder);
      final joy = step(before.joy, 3, before.joyRemainder);
      final energy = step(
        before.energy,
        before.sleeping ? 2 + bedroomBonus : 2,
        before.energyRemainder,
        restore: before.sleeping,
      );
      return before.copyWith(
        food: food[0],
        foodRemainder: food[1],
        clean: clean[0],
        cleanRemainder: clean[1],
        joy: joy[0],
        joyRemainder: joy[1],
        energy: energy[0],
        energyRemainder: energy[1],
      );
    }

    final ticked = started._withBoth(
      tick(PetCarePet.rabbit),
      tick(PetCarePet.bear),
    );
    return ticked.copyWith(lastEvaluatedAt: now);
  }

  PetCareProgress onDay(DateTime now) {
    final today = petCareDay(now);
    return today.compareTo(day) > 0
        ? copyWith(
            day: today,
            careMask: 0,
            dailyPlayCount: 0,
            dailyPlayDay: today,
            dailyBondPoints: 0,
          )
        : this;
  }

  String encode() => jsonEncode({
    'version': 2,
    'day': day,
    'joy': joy,
    'food': food,
    'clean': clean,
    'energy': energy,
    'seeds': seeds,
    'careMask': careMask,
    'claimedDay': claimedDay,
    'unlocked': unlocked.map((decor) => decor.name).toList(),
    'decoration': decoration?.name,
    'selectedPet': selectedPet.name,
    'rabbit': rabbitVitals.toJson(),
    'bear': bearVitals.toJson(),
    'lastEvaluatedAt': lastEvaluatedAt?.toIso8601String(),
    'bond': bondPoints,
    'dailyBondPoints': dailyBondPoints,
    'dailyPlayCount': dailyPlayCount,
    'dailyPlayDay': dailyPlayDay,
    'upgrades': {
      for (final entry in upgradeLevels.entries) entry.key.name: entry.value,
    },
    // Thứ tự cố định để so sánh snapshot không lệch theo thứ tự mua.
    'outfits': [
      for (final outfit in PetCareOutfit.values)
        if (!outfit.isFree && ownedOutfits.contains(outfit)) outfit.name,
    ],
    'worn': {
      for (final pet in PetCarePet.values)
        if (wornOutfits[pet] case final outfit?)
          if (ownsOutfit(outfit)) pet.name: outfit.name,
    },
    'styles': [
      for (final style in PetCareStyle.values)
        if (!style.isFree && ownedStyles.contains(style)) style.name,
    ],
    'equipped': {
      for (final slot in PetCareStyleSlot.values)
        if (equippedStyles[slot] case final style?)
          if (style.slot == slot && ownsStyle(style)) slot.name: style.name,
    },
    'roomItems': [
      for (final item in PetCareRoomItem.values)
        if (!item.isFree && roomItems.contains(item)) item.name,
    ],
    'roomLooks': {
      for (final room in PetCareRoom.values)
        if (roomLooks[room] case final look? when look.isNotEmpty)
          room.name: {
            for (final slot in PetCareRoomSlot.values)
              if (look[slot] case final item?)
                if (item.slot == slot && ownsRoomItem(item))
                  slot.name: item.name,
          },
    },
    'adDay': adDay,
    'adCount': adCount,
    'foundDay': foundDay,
    'foundMask': foundMask,
    'gameDay': gameDay,
    'gameSeeds': gameSeeds,
    'friendDay': friendDay,
    'doubleDay': doubleDay,
    'doubleCount': doubleCount,
    'reviveDay': reviveDay,
    'reviveCount': reviveCount,
    'giftDoubleDay': giftDoubleDay,
    'birthdayLevel': birthdayLevel,
    'garden': garden.toJson(),
  });

  factory PetCareProgress.decode(String raw, {DateTime? now}) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on Object {
      throw const FormatException('Invalid pet care snapshot');
    }
    if (decoded is! Map) {
      throw const FormatException('Invalid pet care snapshot');
    }
    final value = decoded;
    String checkedDay(dynamic candidate) {
      if (candidate is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(candidate)) {
        throw const FormatException('Invalid pet care day');
      }
      final parsed = DateTime.tryParse(candidate);
      if (parsed == null || petCareDay(parsed) != candidate) {
        throw const FormatException('Invalid pet care day');
      }
      return candidate;
    }

    int number(String key, int fallback, int max) {
      final rawNumber = value[key];
      return rawNumber is num ? _clampInt(rawNumber.round(), 0, max) : fallback;
    }

    final version = value['version'];
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported pet care snapshot');
    }
    final day = checkedDay(value['day']);
    final legacy = PetCareVitals(
      joy: number('joy', 76, 100),
      food: number('food', 58, 100),
      clean: number('clean', 64, 100),
      energy: number('energy', 82, 100),
    );
    final rabbit = version == 1
        ? legacy
        : PetCareVitals.fromJson(value['rabbit'], fallback: legacy);
    final bear = version == 1
        ? legacy
        : PetCareVitals.fromJson(value['bear'], fallback: legacy);
    final selected = value['selectedPet'] == PetCarePet.bear.name
        ? PetCarePet.bear
        : PetCarePet.rabbit;
    final unlocked = PetCareDecor.values
        .where(
          (decor) => (value['unlocked'] as List? ?? []).contains(decor.name),
        )
        .toSet();
    PetCareDecor? selectedDecor;
    for (final decor in unlocked) {
      if (decor.name == value['decoration']) selectedDecor = decor;
    }
    final levels = <PetCareUpgrade, int>{};
    if (value['upgrades'] is Map) {
      final source = value['upgrades'] as Map;
      for (final upgrade in PetCareUpgrade.values) {
        final rawLevel = source[upgrade.name];
        if (rawLevel is num) {
          levels[upgrade] = _clampInt(rawLevel.round(), 0, 3);
        }
      }
    }
    final rawOutfits = value['outfits'];
    final outfits = <PetCareOutfit>{
      for (final outfit in PetCareOutfit.values)
        if (!outfit.isFree &&
            rawOutfits is List &&
            rawOutfits.contains(outfit.name))
          outfit,
    };
    final rawWorn = value['worn'];
    final worn = <PetCarePet, PetCareOutfit>{};
    if (rawWorn is Map) {
      for (final pet in PetCarePet.values) {
        for (final outfit in PetCareOutfit.values) {
          if (rawWorn[pet.name] == outfit.name &&
              (outfit.isFree || outfits.contains(outfit))) {
            worn[pet] = outfit;
          }
        }
      }
    }
    final rawStyles = value['styles'];
    final owned = <PetCareStyle>{
      for (final style in PetCareStyle.values)
        if (!style.isFree &&
            rawStyles is List &&
            rawStyles.contains(style.name))
          style,
    };
    final rawEquipped = value['equipped'];
    final equipped = <PetCareStyleSlot, PetCareStyle>{};
    if (rawEquipped is Map) {
      for (final slot in PetCareStyleSlot.values) {
        for (final style in PetCareStyle.forSlot(slot)) {
          if (rawEquipped[slot.name] == style.name &&
              (style.isFree || owned.contains(style))) {
            equipped[slot] = style;
          }
        }
      }
    }
    final rawRoomItems = value['roomItems'];
    final ownedRoomItems = <PetCareRoomItem>{
      for (final item in PetCareRoomItem.values)
        if (!item.isFree &&
            rawRoomItems is List &&
            rawRoomItems.contains(item.name))
          item,
    };
    final rawLooks = value['roomLooks'];
    final looks = <PetCareRoom, Map<PetCareRoomSlot, PetCareRoomItem>>{};
    if (rawLooks is Map) {
      for (final room in PetCareRoom.values) {
        final rawLook = rawLooks[room.name];
        if (rawLook is! Map) continue;
        final look = <PetCareRoomSlot, PetCareRoomItem>{};
        for (final slot in PetCareRoomSlot.values) {
          for (final item in PetCareRoomItem.forSlot(slot)) {
            if (rawLook[slot.name] == item.name &&
                (item.isFree || ownedRoomItems.contains(item))) {
              look[slot] = item;
            }
          }
        }
        if (look.isNotEmpty) looks[room] = Map.unmodifiable(look);
      }
    }
    String? optionalDay(String key) {
      final raw = value[key];
      if (raw is! String) return null;
      try {
        return checkedDay(raw);
      } on FormatException {
        return null;
      }
    }

    final propMask = (1 << PetCareProp.values.length) - 1;
    DateTime? evaluated = version == 2 && value['lastEvaluatedAt'] is String
        ? DateTime.tryParse(value['lastEvaluatedAt'] as String)
        : null;
    if (evaluated == null && version == 1 && now != null) evaluated = now;
    return PetCareProgress(
      day: day,
      joy: legacy.joy,
      food: legacy.food,
      clean: legacy.clean,
      energy: legacy.energy,
      seeds: number('seeds', 0, 1000000),
      careMask: number('careMask', 0, 7),
      claimedDay: value['claimedDay'] == null
          ? null
          : checkedDay(value['claimedDay']),
      unlocked: Set.unmodifiable(unlocked),
      decoration: selectedDecor,
      selectedPet: selected,
      rabbitState: rabbit,
      bearState: bear,
      lastEvaluatedAt: evaluated,
      bondPoints: number('bond', 0, 1000000),
      dailyBondPoints: number('dailyBondPoints', 0, 30),
      dailyPlayCount: number('dailyPlayCount', 0, 3),
      dailyPlayDay: value['dailyPlayDay'] == null
          ? null
          : checkedDay(value['dailyPlayDay']),
      upgradeLevels: Map.unmodifiable(levels),
      ownedOutfits: Set.unmodifiable(outfits),
      wornOutfits: Map.unmodifiable(worn),
      ownedStyles: Set.unmodifiable(owned),
      equippedStyles: Map.unmodifiable(equipped),
      roomItems: Set.unmodifiable(ownedRoomItems),
      roomLooks: Map.unmodifiable(looks),
      adDay: optionalDay('adDay'),
      adCount: number('adCount', 0, PetCareEarn.adsPerDay),
      foundDay: optionalDay('foundDay'),
      foundMask: number('foundMask', 0, propMask),
      gameDay: optionalDay('gameDay'),
      gameSeeds: number('gameSeeds', 0, PetCareEarn.gameSeedsPerDay),
      friendDay: optionalDay('friendDay'),
      doubleDay: optionalDay('doubleDay'),
      doubleCount: number('doubleCount', 0, PetCareEarn.doublesPerDay),
      reviveDay: optionalDay('reviveDay'),
      reviveCount: number('reviveCount', 0, PetCareEarn.revivesPerDay),
      giftDoubleDay: optionalDay('giftDoubleDay'),
      birthdayLevel: math.max(1, number('birthdayLevel', 1, petCareMaxLevel)),
      garden: PetCareGarden.fromJson(value['garden']),
    );
  }
}

class PetCareScopeChanged implements Exception {
  const PetCareScopeChanged();
}

class PetCareOwnershipDenied implements Exception {
  const PetCareOwnershipDenied();
}

class PetCareStoreEvent {
  const PetCareStoreEvent({
    required this.key,
    required this.progress,
    required this.revision,
    this.fromPartner = false,
    this.merged = false,
  });
  final String key;
  final PetCareProgress progress;
  final int revision;

  /// Bản vừa nhận từ máy người ấy (họ vừa chăm/mua/trang trí).
  final bool fromPartner;

  /// Máy này vừa gộp tiến trình riêng vào bản chung lần đầu.
  final bool merged;
}

/// Bản Trạm Mây chung của một nhà trên máy chủ (`houses/{houseId}/pet_care`).
/// [rev] tăng đúng 1 mỗi lần ghi (luật máy chủ bắt buộc) để không ai ghi đè
/// bản cũ; [joined] là UID đã gộp tiến trình riêng vào bản chung.
@immutable
class PetCareRemoteDoc {
  const PetCareRemoteDoc({
    required this.state,
    required this.rev,
    required this.by,
    this.joined = const {},
  });
  final String state;
  final int rev;
  final String by;
  final Set<String> joined;

  static PetCareRemoteDoc? fromValue(Object? value) {
    if (value is! Map) return null;
    final state = value['state'];
    final rev = value['rev'];
    final by = value['by'];
    if (state is! String || rev is! num || by is! String) return null;
    final joined = value['joined'];
    return PetCareRemoteDoc(
      state: state,
      rev: rev.toInt(),
      by: by,
      joined: {
        if (joined is Map)
          for (final entry in joined.entries)
            if (entry.value == true) '${entry.key}',
      },
    );
  }

  Map<String, Object> toValue() => {
    'state': state,
    'rev': rev,
    'by': by,
    if (joined.isNotEmpty) 'joined': {for (final uid in joined) uid: true},
  };
}

/// Kho chung của nhà; tách giao diện để test dùng bản giả trong bộ nhớ.
abstract interface class PetCareRemote {
  Future<PetCareRemoteDoc?> fetch();
  Stream<PetCareRemoteDoc?> watch();

  /// So-và-đổi (transaction): [apply] nhận bản đang có trên máy chủ (null nếu
  /// chưa có) và trả bản mới, hoặc null để giữ nguyên. Trả bản sau cùng.
  Future<PetCareRemoteDoc?> commit(
    PetCareRemoteDoc? Function(PetCareRemoteDoc? current) apply,
  );
}

/// Trạng thái đồng bộ lưu trên máy: bản chung đã thấy và thao tác chờ đẩy
/// (lúc mất mạng) dựa trên bản chung nào.
@immutable
class _PetCareSyncMeta {
  const _PetCareSyncMeta({
    this.rev = 0,
    this.dirty = false,
    this.base = 0,
    this.pendingOperations = const [],
  });
  final int rev;
  final bool dirty;
  final int base;
  final List<String> pendingOperations;
  String? get pendingOperation =>
      pendingOperations.isEmpty ? null : pendingOperations.last;

  static _PetCareSyncMeta decode(String? raw) {
    if (raw == null) return const _PetCareSyncMeta();
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return const _PetCareSyncMeta();
      int read(String key) =>
          value[key] is num ? (value[key] as num).toInt() : 0;
      return _PetCareSyncMeta(
        rev: read('rev'),
        dirty: value['dirty'] == true,
        base: read('base'),
        pendingOperations: [
          if (value['pendingOperations'] is List)
            for (final operation in value['pendingOperations'] as List)
              if (operation is String && operation.isNotEmpty) operation,
          if (value['pendingOperations'] is! List &&
              value['pendingOperation'] is String &&
              (value['pendingOperation'] as String).isNotEmpty)
            value['pendingOperation'] as String,
        ],
      );
    } on Object {
      return const _PetCareSyncMeta();
    }
  }

  String encode() => jsonEncode({
    'rev': rev,
    'dirty': dirty,
    'base': base,
    if (pendingOperations.isNotEmpty) 'pendingOperations': pendingOperations,
  });
}

class PetCareStore {
  PetCareStore({
    required this.key,
    required this.read,
    required this.write,
    required this.isCurrent,
    this.ownedPet,
    this.remote,
    this.uid,
    this.readMeta,
    this.writeMeta,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  factory PetCareStore.preferences({
    required SharedPreferences prefs,
    required String uid,
    required String houseId,
    required bool Function() isCurrent,
    PetCarePet? ownedPet,
    PetCareRemote? remote,
    DateTime Function()? now,
  }) {
    final key = storageKey(uid, houseId);
    final metaKey = '${key}_sync';
    return PetCareStore(
      key: key,
      read: () => prefs.getString(key),
      write: (value) async {
        try {
          final saved = await prefs.setString(key, value);
          if (!saved) throw StateError('Pet care save failed');
          return true;
        } catch (_) {
          await prefs.reload();
          rethrow;
        }
      },
      isCurrent: isCurrent,
      ownedPet: ownedPet,
      remote: remote,
      uid: uid,
      readMeta: () => prefs.getString(metaKey),
      writeMeta: (value) => prefs.setString(metaKey, value),
      now: now,
    );
  }

  static String storageKey(String uid, String houseId) {
    if (uid.isEmpty || houseId.isEmpty) throw const PetCareScopeChanged();
    return 'pet_care_v1_${base64Url.encode(utf8.encode(jsonEncode([uid, houseId])))}';
  }

  /// Chờ máy chủ tối đa chừng này; quá thì lưu trên máy và đẩy lên sau.
  static const remoteTimeout = Duration(seconds: 6);
  static const _operationHistoryLimit = 32;

  final String key;
  final String? Function() read;
  final Future<bool> Function(String value) write;
  final bool Function() isCurrent;

  /// Bé thuộc vai người này: dùng khi gộp tiến trình lần đầu nối máy.
  final PetCarePet? ownedPet;

  /// Bản chung của nhà; null thì chỉ lưu trên máy (test, chưa đăng nhập).
  final PetCareRemote? remote;
  final String? uid;
  final String? Function()? readMeta;
  final Future<bool> Function(String value)? writeMeta;
  final DateTime Function() now;
  static final Map<String, Future<void>> _pending = {};
  static final Map<String, int> _revisions = {};
  static int _operationSequence = 0;
  static final ValueNotifier<PetCareStoreEvent?> changes = ValueNotifier(null);

  void _checkScope() {
    if (!isCurrent()) throw const PetCareScopeChanged();
  }

  PetCareProgress _read() {
    _checkScope();
    final moment = now();
    final raw = read();
    final loaded = raw == null
        ? PetCareProgress(day: petCareDay(moment), lastEvaluatedAt: moment)
        : PetCareProgress.decode(raw, now: moment);
    return loaded.elapsed(moment);
  }

  void _publish(
    PetCareProgress progress, {
    bool fromPartner = false,
    bool merged = false,
  }) {
    final revision = (_revisions[key] ?? 0) + 1;
    _revisions[key] = revision;
    changes.value = PetCareStoreEvent(
      key: key,
      progress: progress,
      revision: revision,
      fromPartner: fromPartner,
      merged: merged,
    );
  }

  _PetCareSyncMeta _meta() => _PetCareSyncMeta.decode(readMeta?.call());

  Future<void> _saveMeta(_PetCareSyncMeta meta) async {
    await writeMeta?.call(meta.encode());
  }

  /// Gắn mã thao tác vào snapshot mà không thay đổi schema tiến trình.
  /// PetCareProgress.decode bỏ qua khóa mở rộng này nên vẫn tương thích bản cũ.
  static String? _operationOf(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      final operation = value is Map ? value['_syncOperation'] : null;
      return operation is String && operation.isNotEmpty ? operation : null;
    } on Object {
      return null;
    }
  }

  static List<String> _operationsOf(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      return [
        if (decoded['_syncOperations'] is List)
          for (final operation in decoded['_syncOperations'] as List)
            if (operation is String && operation.isNotEmpty) operation,
        ?_operationOf(raw),
      ];
    } on Object {
      return const [];
    }
  }

  static List<String> _recentOperations(Iterable<String> operations) {
    final unique = operations.toSet().toList(growable: false);
    return unique.length <= _operationHistoryLimit
        ? unique
        : unique.sublist(unique.length - _operationHistoryLimit);
  }

  static String _stampOperation(
    String raw,
    String operation, {
    Iterable<String> previous = const [],
  }) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return raw;
      final value = Map<String, dynamic>.from(decoded);
      value['_syncOperation'] = operation;
      value['_syncOperations'] = _recentOperations([...previous, operation]);
      return jsonEncode(value);
    } on Object {
      return raw;
    }
  }

  String _newOperation() {
    _operationSequence++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_operationSequence';
  }

  /// Xếp hàng thao tác theo khóa để lưu/đồng bộ không chen nhau.
  Future<T> _enqueue<T>(Future<T> Function() task) {
    final previous = _pending[key] ?? Future<void>.value();
    final operation = previous.then((_) => task());
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[key] = tail;
    tail.then((_) {
      if (identical(_pending[key], tail)) _pending.remove(key);
    });
    return operation;
  }

  Future<PetCareProgress> load() async {
    final pending = _pending[key];
    if (pending != null) await pending;
    final progress = _read();
    _checkScope();
    _publish(progress);
    return progress;
  }

  /// Bản chung → bản trên máy: giữ mục riêng (bé đang xem, lượt quảng cáo,
  /// Hạt mini game) của người này.
  PetCareProgress _adopt(PetCareRemoteDoc doc, PetCareProgress mine) {
    final moment = now();
    return PetCareProgress.decode(
      doc.state,
      now: moment,
    ).elapsed(moment).withPersonal(mine);
  }

  /// Bản làm nền cho thao tác: bản chung mới nhất; lần đầu nối máy thì gộp;
  /// đang có thao tác chờ đẩy mà bản chung chưa đổi thì giữ bản trên máy.
  bool _canUsePending(PetCareRemoteDoc? current, _PetCareSyncMeta meta) =>
      meta.dirty &&
      (current == null ||
          current.rev == meta.base ||
          (current.by == uid &&
              meta.pendingOperations.contains(_operationOf(current.state))));

  (PetCareProgress, bool) _baseFor(
    PetCareRemoteDoc? current,
    PetCareProgress local,
    bool hadLocal,
    _PetCareSyncMeta meta,
  ) {
    if (current == null) return (local, true);
    final shared = _adopt(current, local);
    final owner = ownedPet;
    if (!current.joined.contains(uid)) {
      if (!hadLocal || owner == null) return (shared, true);
      return (
        PetCareProgress.joinHouse(shared: shared, mine: local, owned: owner),
        true,
      );
    }
    if (_canUsePending(current, meta)) return (local, true);
    return (shared, false);
  }

  Future<PetCareProgress> update(
    PetCareProgress Function(PetCareProgress state) change, {
    bool reconcilePending = false,
  }) => _enqueue(() async {
    final local = _read();
    final hadLocal = read() != null;
    final remote = this.remote;
    final writer = uid;
    if (remote == null || writer == null) {
      final next = change(local);
      _checkScope();
      if (next.encode() != local.encode() && !await write(next.encode())) {
        throw StateError('Pet care save failed');
      }
      _checkScope();
      _publish(next);
      return next;
    }
    final meta = _meta();
    final operation = reconcilePending
        ? meta.pendingOperation ?? _newOperation()
        : _newOperation();
    PetCareProgress? result;
    PetCareRemoteDoc? settled;
    var merged = false;
    try {
      settled = await remote
          .commit((current) {
            // Timeout không hủy transaction Firebase. Callback cũ có thể
            // chạy lại sau khi sync đã ghi cùng thao tác, kể cả khi người
            // ấy vừa ghi một thao tác khác tiếp theo.
            final applied = _operationsOf(current?.state);
            if (current != null && applied.contains(operation)) {
              result = _adopt(current, local);
              return null;
            }
            final (base, mustWrite) = _baseFor(current, local, hadLocal, meta);
            merged =
                current != null &&
                hadLocal &&
                ownedPet != null &&
                !current.joined.contains(writer);
            final next = change(base);
            result = next;
            if (!mustWrite && next.encode() == base.encode()) return null;
            return PetCareRemoteDoc(
              state: _stampOperation(
                next.encode(),
                operation,
                previous: [
                  ...applied,
                  if (_canUsePending(current, meta)) ...meta.pendingOperations,
                ],
              ),
              rev: (current?.rev ?? 0) + 1,
              by: writer,
              joined: {...?current?.joined, writer},
            );
          })
          .timeout(remoteTimeout);
    } on PetCareScopeChanged {
      rethrow;
    } catch (_) {
      settled = null;
      result = null;
    }
    _checkScope();
    if (settled == null) {
      // Mất mạng/máy chủ chưa sẵn sàng: lưu trên máy, lần sau có mạng đẩy lên
      // nếu bản chung chưa bị người ấy đổi trong lúc đó.
      final next = change(local);
      if (next.encode() != local.encode()) {
        final pendingOperations = _recentOperations([
          ...meta.pendingOperations,
          operation,
        ]);
        final stamped = _stampOperation(
          next.encode(),
          operation,
          previous: [..._operationsOf(read()), ...pendingOperations],
        );
        if (!await write(stamped)) {
          throw StateError('Pet care save failed');
        }
        await _saveMeta(
          _PetCareSyncMeta(
            rev: meta.rev,
            dirty: true,
            base: meta.dirty ? meta.base : meta.rev,
            pendingOperations: pendingOperations,
          ),
        );
      } else if (meta.dirty && meta.pendingOperation == null) {
        await _saveMeta(
          _PetCareSyncMeta(
            rev: meta.rev,
            dirty: true,
            base: meta.base,
            pendingOperations: [operation],
          ),
        );
      }
      _checkScope();
      _publish(next);
      return next;
    }
    final next = _adopt(settled, result ?? local);
    final settledOperation = _operationOf(settled.state);
    final localSnapshot = settledOperation == null
        ? next.encode()
        : _stampOperation(
            next.encode(),
            settledOperation,
            previous: _operationsOf(settled.state),
          );
    if (!await write(localSnapshot)) throw StateError('Pet care save failed');
    await _saveMeta(_PetCareSyncMeta(rev: settled.rev));
    _checkScope();
    _publish(next, merged: merged && settled.joined.contains(writer));
    return next;
  });

  /// Nối/đẩy bản chung: lần đầu gộp tiến trình, có thao tác chờ thì đẩy lên,
  /// còn lại chỉ nhận bản mới nhất. Không ghi gì nếu không cần.
  Future<PetCareProgress> sync() =>
      update((state) => state, reconcilePending: true);

  /// Nhận bản chung vừa đổi (đang mở Trạm Mây hoặc Home vừa đọc một lần).
  /// Chưa nối máy hoặc còn thao tác chờ đẩy thì để [sync] xử lý.
  Future<PetCareProgress?> receive(PetCareRemoteDoc? doc) => _enqueue(() async {
    final writer = uid;
    if (doc == null || writer == null) return null;
    final meta = _meta();
    final pendingApplied =
        meta.dirty &&
        meta.pendingOperation != null &&
        _operationOf(doc.state) == meta.pendingOperation;
    if (!doc.joined.contains(writer) || (meta.dirty && !pendingApplied)) {
      return null;
    }
    if (doc.rev == meta.rev) return null;
    final local = _read();
    final next = _adopt(doc, local);
    final receivedOperation = _operationOf(doc.state) ?? meta.pendingOperation;
    final localSnapshot = receivedOperation == null
        ? next.encode()
        : _stampOperation(
            next.encode(),
            receivedOperation,
            previous: _operationsOf(doc.state),
          );
    if (!await write(localSnapshot)) throw StateError('Pet care save failed');
    await _saveMeta(_PetCareSyncMeta(rev: doc.rev));
    _checkScope();
    _publish(next, fromPartner: doc.by != writer && doc.rev > meta.rev);
    return next;
  });

  /// Lắng nghe bản chung trong lúc màn chơi mở (chỉ tải khi có thay đổi).
  StreamSubscription<PetCareRemoteDoc?>? watch({
    void Function(Object error)? onError,
  }) {
    final remote = this.remote;
    if (remote == null || uid == null) return null;
    return remote.watch().listen((doc) async {
      final needsSync =
          doc == null || !doc.joined.contains(uid) || _meta().dirty;
      try {
        if (needsSync) {
          await sync();
        } else {
          await receive(doc);
        }
      } on Object catch (error) {
        onError?.call(error);
      }
    }, onError: (Object error) => onError?.call(error));
  }

  /// Home: đọc bản chung một lần (không giữ kết nối nghe) khi mở app/quay lại.
  Future<void> pull() async {
    final remote = this.remote;
    if (remote == null || uid == null) return;
    final doc = await remote.fetch().timeout(remoteTimeout);
    await receive(doc);
  }
}
