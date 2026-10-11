import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../utils/services/l10n_service.dart';

enum TarotSuit { major, cups, wands, swords, pentacles }

class TarotCard {
  final String id;
  final TarotSuit suit;
  final int number;
  final String? rank;
  const TarotCard({
    required this.id,
    required this.suit,
    required this.number,
    this.rank,
  });
  bool get isMajor => suit == TarotSuit.major;
  String get localizedName => isMajor
      ? L10nService().translate('tarot2_name_$id')
      : L10nService().format('tarot2_minor_name', {
          'rank': L10nService().translate('tarot2_rank_${rank!}'),
          'suit': suitName,
        });
  String get suitName => L10nService().translate(
    isMajor ? 'tarot2_major' : 'tarot2_suit_${suit.name}',
  );
  String get theme => L10nService().translate(
    'tarot2_${isMajor ? 'theme_$id' : 'rank_theme_${rank!}'}',
  );
  String meaning(bool reversed) =>
      L10nService().translate('tarot2_${reversed ? 'rev_' : 'up_'}$id');
  String get reflection => L10nService().translate(
    'tarot2_${isMajor ? 'reflect_$id' : 'rank_reflect_${rank!}'}',
  );
  String get action => L10nService().translate(
    'tarot2_${isMajor ? 'action_$id' : 'rank_action_${rank!}'}',
  );
  String get focus =>
      isMajor ? theme : L10nService().translate('tarot2_focus_${suit.name}');
}

class TarotSpread {
  final String id;
  final int minutes;
  final List<String> slots;
  const TarotSpread(this.id, this.minutes, this.slots);
  String get title => L10nService().translate('tarot2_spread_$id');
  String get description => L10nService().translate('tarot2_spread_desc_$id');
}

const tarotSpreads = [
  TarotSpread('daily', 2, ['message']),
  TarotSpread('clarity', 5, ['situation', 'challenge', 'step']),
  TarotSpread('connection', 7, ['you', 'other', 'shared', 'bridge']),
  TarotSpread('crossroads', 7, ['option_a', 'option_b', 'support', 'step']),
  TarotSpread('growth', 10, ['root', 'need', 'challenge', 'support', 'step']),
  TarotSpread('renewal', 5, ['release', 'keep', 'welcome']),
];
const tarotTopics = ['self', 'love', 'work', 'balance', 'choice', 'growth'];

class TarotDraw {
  final TarotCard card;
  final bool reversed;
  final bool revealed;
  const TarotDraw(this.card, {this.reversed = false, this.revealed = false});
  TarotDraw reveal() => TarotDraw(card, reversed: reversed, revealed: true);
}

class TarotSession {
  final String id;
  final DateTime date;
  final String topic;
  final String spreadId;
  final String question;
  final String note;
  final List<TarotDraw> draws;
  const TarotSession({
    required this.id,
    required this.date,
    required this.topic,
    required this.spreadId,
    required this.question,
    required this.draws,
    this.note = '',
  });
  TarotSpread get spread => tarotSpreads.firstWhere((s) => s.id == spreadId);
  TarotSession withNote(String value) => TarotSession(
    id: id,
    date: date,
    topic: topic,
    spreadId: spreadId,
    question: question,
    draws: draws,
    note: value,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.millisecondsSinceEpoch,
    'topic': topic,
    'spread': spreadId,
    'question': question,
    'note': note,
    'cards': draws
        .map((d) => {'id': d.card.id, 'reversed': d.reversed})
        .toList(),
  };
  static TarotSession? fromJson(dynamic value) {
    try {
      if (value is! Map || value['cards'] is! List) return null;
      final spread = tarotSpreads
          .where((s) => s.id == value['spread'])
          .firstOrNull;
      if (spread == null || !tarotTopics.contains(value['topic'])) return null;
      final draws = <TarotDraw>[];
      for (final raw in value['cards'] as List) {
        if (raw is! Map || raw['reversed'] is! bool) return null;
        final card = tarotCards.where((c) => c.id == raw['id']).firstOrNull;
        if (card == null || draws.any((d) => d.card.id == card.id)) return null;
        draws.add(
          TarotDraw(card, reversed: raw['reversed'] as bool, revealed: true),
        );
      }
      if (draws.length != spread.slots.length ||
          value['date'] is! int ||
          value['id'] is! String ||
          ((value['id'] as String).isEmpty ||
              (value['id'] as String).length > 100)) {
        return null;
      }
      final question = value['question'];
      final note = value['note'];
      if (question is! String ||
          note is! String ||
          question.length > 220 ||
          note.length > 1200) {
        return null;
      }
      return TarotSession(
        id: value['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(value['date'] as int),
        topic: value['topic'] as String,
        spreadId: spread.id,
        question: question,
        note: note,
        draws: draws,
      );
    } catch (_) {
      return null;
    }
  }
}

class TarotJournalStore {
  static const capacity = 60;
  static String key(String uid, String houseId) =>
      'tarot_journal_v2:${Uri.encodeComponent(uid)}:${Uri.encodeComponent(houseId)}';
  static List<TarotSession> load(
    SharedPreferences prefs,
    String uid,
    String houseId,
  ) {
    if (uid.isEmpty || houseId.isEmpty) return [];
    try {
      final raw = jsonDecode(prefs.getString(key(uid, houseId)) ?? '[]');
      if (raw is! List) return [];
      final seen = <String>{};
      return raw
          .take(capacity)
          .map(TarotSession.fromJson)
          .whereType<TarotSession>()
          .where((s) => seen.add(s.id))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  static Future<List<TarotSession>> save(
    SharedPreferences prefs,
    String uid,
    String houseId,
    TarotSession session,
  ) async {
    if (uid.isEmpty ||
        houseId.isEmpty ||
        (session.draws.any((d) => !d.revealed) ||
            TarotSession.fromJson(session.toJson()) == null)) {
      throw StateError('Phiên Tarot chưa sẵn sàng để lưu.');
    }
    final entries = [
      session,
      ...load(prefs, uid, houseId).where((s) => s.id != session.id),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final bounded = entries.take(capacity).toList();
    final saved = await prefs.setString(
      key(uid, houseId),
      jsonEncode(bounded.map((s) => s.toJson()).toList()),
    );
    if (!saved) throw StateError('Chưa lưu được nhật ký Tarot.');
    return bounded;
  }

  static Future<List<TarotSession>> delete(
    SharedPreferences prefs,
    String uid,
    String houseId,
    String sessionId,
  ) async {
    if (uid.isEmpty || houseId.isEmpty) {
      throw StateError('Không có phạm vi nhật ký Tarot.');
    }
    final rest = load(
      prefs,
      uid,
      houseId,
    ).where((entry) => entry.id != sessionId).toList();
    final saved = await prefs.setString(
      key(uid, houseId),
      jsonEncode(rest.map((entry) => entry.toJson()).toList()),
    );
    if (!saved) throw StateError('Chưa xóa được nhật ký Tarot.');
    return rest;
  }
}

List<TarotCard> shuffledTarotDeck([Random? random]) =>
    List.of(tarotCards)..shuffle(random ?? Random());
TarotCard tarotDailyCard(DateTime date) =>
    tarotCards[DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(2026, 1, 1)).inDays.abs() %
        tarotCards.length];

const List<TarotCard> tarotCards = [
  TarotCard(id: 'fool', suit: TarotSuit.major, number: 0),
  TarotCard(id: 'magician', suit: TarotSuit.major, number: 1),
  TarotCard(id: 'priestess', suit: TarotSuit.major, number: 2),
  TarotCard(id: 'empress', suit: TarotSuit.major, number: 3),
  TarotCard(id: 'emperor', suit: TarotSuit.major, number: 4),
  TarotCard(id: 'hierophant', suit: TarotSuit.major, number: 5),
  TarotCard(id: 'lovers', suit: TarotSuit.major, number: 6),
  TarotCard(id: 'chariot', suit: TarotSuit.major, number: 7),
  TarotCard(id: 'strength', suit: TarotSuit.major, number: 8),
  TarotCard(id: 'hermit', suit: TarotSuit.major, number: 9),
  TarotCard(id: 'wheel', suit: TarotSuit.major, number: 10),
  TarotCard(id: 'justice', suit: TarotSuit.major, number: 11),
  TarotCard(id: 'hanged', suit: TarotSuit.major, number: 12),
  TarotCard(id: 'death', suit: TarotSuit.major, number: 13),
  TarotCard(id: 'temperance', suit: TarotSuit.major, number: 14),
  TarotCard(id: 'devil', suit: TarotSuit.major, number: 15),
  TarotCard(id: 'tower', suit: TarotSuit.major, number: 16),
  TarotCard(id: 'star', suit: TarotSuit.major, number: 17),
  TarotCard(id: 'moon', suit: TarotSuit.major, number: 18),
  TarotCard(id: 'sun', suit: TarotSuit.major, number: 19),
  TarotCard(id: 'judgement', suit: TarotSuit.major, number: 20),
  TarotCard(id: 'world', suit: TarotSuit.major, number: 21),
  TarotCard(id: 'cups_ace', suit: TarotSuit.cups, number: 1, rank: 'ace'),
  TarotCard(id: 'cups_two', suit: TarotSuit.cups, number: 2, rank: 'two'),
  TarotCard(id: 'cups_three', suit: TarotSuit.cups, number: 3, rank: 'three'),
  TarotCard(id: 'cups_four', suit: TarotSuit.cups, number: 4, rank: 'four'),
  TarotCard(id: 'cups_five', suit: TarotSuit.cups, number: 5, rank: 'five'),
  TarotCard(id: 'cups_six', suit: TarotSuit.cups, number: 6, rank: 'six'),
  TarotCard(id: 'cups_seven', suit: TarotSuit.cups, number: 7, rank: 'seven'),
  TarotCard(id: 'cups_eight', suit: TarotSuit.cups, number: 8, rank: 'eight'),
  TarotCard(id: 'cups_nine', suit: TarotSuit.cups, number: 9, rank: 'nine'),
  TarotCard(id: 'cups_ten', suit: TarotSuit.cups, number: 10, rank: 'ten'),
  TarotCard(id: 'cups_page', suit: TarotSuit.cups, number: 11, rank: 'page'),
  TarotCard(
    id: 'cups_knight',
    suit: TarotSuit.cups,
    number: 12,
    rank: 'knight',
  ),
  TarotCard(id: 'cups_queen', suit: TarotSuit.cups, number: 13, rank: 'queen'),
  TarotCard(id: 'cups_king', suit: TarotSuit.cups, number: 14, rank: 'king'),
  TarotCard(id: 'wands_ace', suit: TarotSuit.wands, number: 1, rank: 'ace'),
  TarotCard(id: 'wands_two', suit: TarotSuit.wands, number: 2, rank: 'two'),
  TarotCard(id: 'wands_three', suit: TarotSuit.wands, number: 3, rank: 'three'),
  TarotCard(id: 'wands_four', suit: TarotSuit.wands, number: 4, rank: 'four'),
  TarotCard(id: 'wands_five', suit: TarotSuit.wands, number: 5, rank: 'five'),
  TarotCard(id: 'wands_six', suit: TarotSuit.wands, number: 6, rank: 'six'),
  TarotCard(id: 'wands_seven', suit: TarotSuit.wands, number: 7, rank: 'seven'),
  TarotCard(id: 'wands_eight', suit: TarotSuit.wands, number: 8, rank: 'eight'),
  TarotCard(id: 'wands_nine', suit: TarotSuit.wands, number: 9, rank: 'nine'),
  TarotCard(id: 'wands_ten', suit: TarotSuit.wands, number: 10, rank: 'ten'),
  TarotCard(id: 'wands_page', suit: TarotSuit.wands, number: 11, rank: 'page'),
  TarotCard(
    id: 'wands_knight',
    suit: TarotSuit.wands,
    number: 12,
    rank: 'knight',
  ),
  TarotCard(
    id: 'wands_queen',
    suit: TarotSuit.wands,
    number: 13,
    rank: 'queen',
  ),
  TarotCard(id: 'wands_king', suit: TarotSuit.wands, number: 14, rank: 'king'),
  TarotCard(id: 'swords_ace', suit: TarotSuit.swords, number: 1, rank: 'ace'),
  TarotCard(id: 'swords_two', suit: TarotSuit.swords, number: 2, rank: 'two'),
  TarotCard(
    id: 'swords_three',
    suit: TarotSuit.swords,
    number: 3,
    rank: 'three',
  ),
  TarotCard(id: 'swords_four', suit: TarotSuit.swords, number: 4, rank: 'four'),
  TarotCard(id: 'swords_five', suit: TarotSuit.swords, number: 5, rank: 'five'),
  TarotCard(id: 'swords_six', suit: TarotSuit.swords, number: 6, rank: 'six'),
  TarotCard(
    id: 'swords_seven',
    suit: TarotSuit.swords,
    number: 7,
    rank: 'seven',
  ),
  TarotCard(
    id: 'swords_eight',
    suit: TarotSuit.swords,
    number: 8,
    rank: 'eight',
  ),
  TarotCard(id: 'swords_nine', suit: TarotSuit.swords, number: 9, rank: 'nine'),
  TarotCard(id: 'swords_ten', suit: TarotSuit.swords, number: 10, rank: 'ten'),
  TarotCard(
    id: 'swords_page',
    suit: TarotSuit.swords,
    number: 11,
    rank: 'page',
  ),
  TarotCard(
    id: 'swords_knight',
    suit: TarotSuit.swords,
    number: 12,
    rank: 'knight',
  ),
  TarotCard(
    id: 'swords_queen',
    suit: TarotSuit.swords,
    number: 13,
    rank: 'queen',
  ),
  TarotCard(
    id: 'swords_king',
    suit: TarotSuit.swords,
    number: 14,
    rank: 'king',
  ),
  TarotCard(
    id: 'pentacles_ace',
    suit: TarotSuit.pentacles,
    number: 1,
    rank: 'ace',
  ),
  TarotCard(
    id: 'pentacles_two',
    suit: TarotSuit.pentacles,
    number: 2,
    rank: 'two',
  ),
  TarotCard(
    id: 'pentacles_three',
    suit: TarotSuit.pentacles,
    number: 3,
    rank: 'three',
  ),
  TarotCard(
    id: 'pentacles_four',
    suit: TarotSuit.pentacles,
    number: 4,
    rank: 'four',
  ),
  TarotCard(
    id: 'pentacles_five',
    suit: TarotSuit.pentacles,
    number: 5,
    rank: 'five',
  ),
  TarotCard(
    id: 'pentacles_six',
    suit: TarotSuit.pentacles,
    number: 6,
    rank: 'six',
  ),
  TarotCard(
    id: 'pentacles_seven',
    suit: TarotSuit.pentacles,
    number: 7,
    rank: 'seven',
  ),
  TarotCard(
    id: 'pentacles_eight',
    suit: TarotSuit.pentacles,
    number: 8,
    rank: 'eight',
  ),
  TarotCard(
    id: 'pentacles_nine',
    suit: TarotSuit.pentacles,
    number: 9,
    rank: 'nine',
  ),
  TarotCard(
    id: 'pentacles_ten',
    suit: TarotSuit.pentacles,
    number: 10,
    rank: 'ten',
  ),
  TarotCard(
    id: 'pentacles_page',
    suit: TarotSuit.pentacles,
    number: 11,
    rank: 'page',
  ),
  TarotCard(
    id: 'pentacles_knight',
    suit: TarotSuit.pentacles,
    number: 12,
    rank: 'knight',
  ),
  TarotCard(
    id: 'pentacles_queen',
    suit: TarotSuit.pentacles,
    number: 13,
    rank: 'queen',
  ),
  TarotCard(
    id: 'pentacles_king',
    suit: TarotSuit.pentacles,
    number: 14,
    rank: 'king',
  ),
];
