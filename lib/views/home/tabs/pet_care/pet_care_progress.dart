import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

enum PetCareFood {
  carrot(cost: 0, nutrition: 22),
  apple(cost: 2, nutrition: 30),
  soup(cost: 4, nutrition: 45),
  cake(cost: 6, nutrition: 18);

  const PetCareFood({required this.cost, required this.nutrition});
  final int cost;
  final int nutrition;
}

enum PetCareDecor {
  moon(6),
  planet(12),
  garden(18);

  const PetCareDecor(this.cost);
  final int cost;
}

enum PetCareUpgrade { kitchen, bathroom, bedroom }

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
  int get level => _clampInt(1 + bondPoints ~/ 20, 1, 20);
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
          joy: before.joy + 4,
          energy: before.energy + 2,
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

  PetCareProgress claim() =>
      canClaim ? copyWith(seeds: seeds + 5, claimedDay: day) : this;

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
  });
  final String key;
  final PetCareProgress progress;
  final int revision;
}

class PetCareStore {
  PetCareStore({
    required this.key,
    required this.read,
    required this.write,
    required this.isCurrent,
    this.ownedPet,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  factory PetCareStore.preferences({
    required SharedPreferences prefs,
    required String uid,
    required String houseId,
    required bool Function() isCurrent,
    PetCarePet? ownedPet,
    DateTime Function()? now,
  }) {
    final key = storageKey(uid, houseId);
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
      now: now,
    );
  }

  static String storageKey(String uid, String houseId) {
    if (uid.isEmpty || houseId.isEmpty) throw const PetCareScopeChanged();
    return 'pet_care_v1_${base64Url.encode(utf8.encode(jsonEncode([uid, houseId])))}';
  }

  final String key;
  final String? Function() read;
  final Future<bool> Function(String value) write;
  final bool Function() isCurrent;
  final PetCarePet? ownedPet;
  final DateTime Function() now;
  static final Map<String, Future<void>> _pending = {};
  static final Map<String, int> _revisions = {};
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

  void _publish(PetCareProgress progress) {
    final revision = (_revisions[key] ?? 0) + 1;
    _revisions[key] = revision;
    changes.value = PetCareStoreEvent(
      key: key,
      progress: progress,
      revision: revision,
    );
  }

  Future<PetCareProgress> load() async {
    final pending = _pending[key];
    if (pending != null) await pending;
    final progress = _read();
    _checkScope();
    _publish(progress);
    return progress;
  }

  Future<PetCareProgress> update(
    PetCareProgress Function(PetCareProgress state) change,
  ) {
    final previous = _pending[key] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final current = _read();
      final next = change(current);
      _checkScope();
      final owner = ownedPet;
      if (owner != null) {
        final partner = owner == PetCarePet.rabbit
            ? PetCarePet.bear
            : PetCarePet.rabbit;
        // So sau elapsed: nhịp thời gian được phép đổi cả hai bé, còn thao tác
        // người dùng chỉ được thay đổi bé thuộc vai của mình.
        if (jsonEncode(next.vitalsFor(partner).toJson()) !=
            jsonEncode(current.vitalsFor(partner).toJson())) {
          throw const PetCareOwnershipDenied();
        }
      }
      if (next.encode() != current.encode() && !await write(next.encode())) {
        throw StateError('Pet care save failed');
      }
      _checkScope();
      _publish(next);
      return next;
    });
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
}
