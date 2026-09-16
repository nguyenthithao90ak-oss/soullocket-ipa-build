import 'package:flutter/foundation.dart';

enum HomeCompanionCharacter { bunny, bear }

enum CompanionHat { none, bow, cap, crown }

enum CompanionGlasses { none, round, sunglasses, star }

enum CompanionClothes { classic, overalls, hoodie, night }

enum CompanionProp { none, mirror, flower, wand }

/// Tủ đồ trang trí trên thiết bị, độc lập cho từng bé, không chứa dữ liệu cá nhân.
@immutable
class HomeCompanionOutfit {
  const HomeCompanionOutfit({
    this.hat = CompanionHat.none,
    this.glasses = CompanionGlasses.none,
    this.clothes = CompanionClothes.classic,
    this.prop = CompanionProp.none,
  });

  final CompanionHat hat;
  final CompanionGlasses glasses;
  final CompanionClothes clothes;
  final CompanionProp prop;

  static HomeCompanionOutfit defaults(HomeCompanionCharacter character) =>
      character == HomeCompanionCharacter.bear
      ? const HomeCompanionOutfit(clothes: CompanionClothes.overalls)
      : const HomeCompanionOutfit();

  HomeCompanionOutfit copyWith({
    CompanionHat? hat,
    CompanionGlasses? glasses,
    CompanionClothes? clothes,
    CompanionProp? prop,
  }) => HomeCompanionOutfit(
    hat: hat ?? this.hat,
    glasses: glasses ?? this.glasses,
    clothes: clothes ?? this.clothes,
    prop: prop ?? this.prop,
  );

  Map<String, String> toJson() => {
    'hat': hat.name,
    'glasses': glasses.name,
    'clothes': clothes.name,
    'prop': prop.name,
  };

  static HomeCompanionOutfit fromJson(
    dynamic value,
    HomeCompanionCharacter character,
  ) {
    final fallback = defaults(character);
    if (value is! Map) return fallback;
    return HomeCompanionOutfit(
      hat: _read(CompanionHat.values, value['hat'], fallback.hat),
      glasses: _read(
        CompanionGlasses.values,
        value['glasses'],
        fallback.glasses,
      ),
      clothes: _read(
        CompanionClothes.values,
        value['clothes'],
        fallback.clothes,
      ),
      prop: _read(CompanionProp.values, value['prop'], fallback.prop),
    );
  }

  static T _read<T extends Enum>(List<T> values, dynamic key, T fallback) {
    for (final value in values) {
      if (value.name == key) return value;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is HomeCompanionOutfit &&
      hat == other.hat &&
      glasses == other.glasses &&
      clothes == other.clothes &&
      prop == other.prop;
  @override
  int get hashCode => Object.hash(hat, glasses, clothes, prop);
}
