import '../views/home/widgets/companion/home_companion_outfit.dart';

/// Quyền sở hữu các bé đồng hành, tách khỏi điểm kinh nghiệm và nhiệm vụ.
class CompanionRewards {
  const CompanionRewards({
    required this.enabled,
    this.points = 0,
    this.unlocked = const {},
    this.prices = const {},
  });

  final bool enabled;
  final int points;
  final Set<HomeCompanionCharacter> unlocked;
  final Map<HomeCompanionCharacter, int> prices;

  factory CompanionRewards.fromJson(Map<dynamic, dynamic> json) {
    int nonNegative(dynamic value) => value is num && value.isFinite
        ? value.toInt().clamp(0, 100000000)
        : 0;

    final unlocked = <HomeCompanionCharacter>{};
    final rawUnlocked = json['unlocked'];
    if (rawUnlocked is List) {
      for (final character in HomeCompanionCharacter.values) {
        if (rawUnlocked.contains(character.name)) unlocked.add(character);
      }
    }

    final prices = <HomeCompanionCharacter, int>{};
    final rawPrices = json['characterPrices'];
    if (rawPrices is Map) {
      for (final character in const [
        HomeCompanionCharacter.melody,
        HomeCompanionCharacter.kuromi,
      ]) {
        final price = nonNegative(rawPrices[character.name]);
        if (price > 0) prices[character] = price;
      }
    }

    return CompanionRewards(
      enabled: json['enabled'] == true,
      points: nonNegative(json['points']),
      unlocked: Set.unmodifiable(unlocked),
      prices: Map.unmodifiable(prices),
    );
  }
}
