part of '../tarot_screen.dart';

class TarotCard {
  final String name;
  final String symbol;
  final String uprightMeaning;
  final String reversedMeaning;

  const TarotCard({
    required this.name,
    required this.symbol,
    required this.uprightMeaning,
    required this.reversedMeaning,
  });
}

class PickedCard {
  final TarotCard card;
  final bool isReversed;
  bool isFlipped;

  PickedCard({
    required this.card,
    required this.isReversed,
    this.isFlipped = false,
  });
}
