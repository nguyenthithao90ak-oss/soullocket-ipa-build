import '../views/home/widgets/companion/home_companion_outfit.dart';

/// Snapshot quyền sở hữu từ server; không suy ra quyền từ SharedPreferences.
class CompanionJourney {
  const CompanionJourney({
    required this.enabled,
    this.xp = 0,
    this.level = 1,
    this.points = 0,
    this.nextLevelXp,
    this.levelFloor = 0,
    this.dailyXp = 0,
    this.adRemaining = 0,
    this.unlocked = const {},
    this.owned = const {},
    this.outfits = const {},
    this.catalog = const {},
    this.claims = const {},
    this.quests = const {},
  });

  final bool enabled;
  final int xp, level, points, levelFloor, dailyXp;
  final int adRemaining;
  final int? nextLevelXp;
  final Set<HomeCompanionCharacter> unlocked;
  final Set<String> owned;
  final Map<HomeCompanionCharacter, HomeCompanionOutfit> outfits;
  final Map<String, CompanionShopItem> catalog;
  final Set<String> claims;
  final Map<String, CompanionQuest> quests;

  bool owns(String category, String item) =>
      owned.contains('${category}_$item');
  double get progress => nextLevelXp == null
      ? 1
      : ((xp - levelFloor) / (nextLevelXp! - levelFloor)).clamp(0.0, 1.0);

  factory CompanionJourney.fromJson(Map<dynamic, dynamic> json) {
    int number(String key, [int fallback = 0]) => json[key] is num
        ? (json[key] as num).toInt().clamp(0, 100000000)
        : fallback;
    final enabled = json['enabled'] == true;
    final characters = HomeCompanionCharacter.values
        .where(
          (character) =>
              !enabled ||
              (json['unlocked'] is List &&
                  (json['unlocked'] as List).contains(character.name)),
        )
        .toSet();
    final rawOutfits = json['outfits'] is Map
        ? json['outfits'] as Map
        : const {};
    final rawQuests = json['quests'] is Map ? json['quests'] as Map : const {};
    final rawCatalog = json['catalog'] is Map
        ? json['catalog'] as Map
        : const {};
    Set<String> flags(String key) => json[key] is Map
        ? (json[key] as Map).entries
              .where((e) => e.value == true)
              .map((e) => e.key.toString())
              .toSet()
        : {};
    return CompanionJourney(
      enabled: enabled,
      xp: number('xp'),
      level: number('level', 1),
      points: number('points'),
      levelFloor: number('levelFloor'),
      dailyXp: number('dailyXp'),
      adRemaining: number('adRemaining').clamp(0, 3),
      nextLevelXp: json['nextLevelXp'] is num ? number('nextLevelXp') : null,
      unlocked: Set.unmodifiable(characters),
      owned: Set.unmodifiable(flags('owned')),
      claims: Set.unmodifiable(flags('claims')),
      quests: Map.unmodifiable({
        for (final entry in rawQuests.entries)
          if (CompanionQuest.ids.contains(entry.key) && entry.value is Map)
            entry.key.toString(): CompanionQuest.fromJson(entry.value as Map),
      }),
      outfits: Map.unmodifiable({
        for (final character in characters)
          if (rawOutfits[character.name] is Map)
            character: HomeCompanionOutfit.fromJson(
              rawOutfits[character.name],
              character,
            ),
      }),
      catalog: Map.unmodifiable({
        for (final entry in rawCatalog.entries)
          if (entry.value is Map)
            entry.key.toString(): CompanionShopItem.fromJson(
              entry.value as Map,
            ),
      }),
    );
  }
}

class CompanionQuest {
  const CompanionQuest({
    required this.xp,
    this.available = false,
    this.completed = false,
  });
  static const ids = {
    'daily_checkin',
    'diary_entry',
    'partner_interaction',
    'map_checkin',
    'simultaneous_online',
  };
  final int xp;
  final bool available, completed;
  factory CompanionQuest.fromJson(Map<dynamic, dynamic> json) => CompanionQuest(
    xp: json['xp'] is num ? (json['xp'] as num).toInt().clamp(0, 40) : 0,
    available: json['available'] == true,
    completed: json['completed'] == true,
  );
}

class CompanionShopItem {
  const CompanionShopItem(this.price, this.level);
  final int price, level;
  factory CompanionShopItem.fromJson(Map<dynamic, dynamic> json) =>
      CompanionShopItem(
        (json['price'] as num?)?.toInt() ?? 0,
        (json['level'] as num?)?.toInt() ?? 1,
      );
}
