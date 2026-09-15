part of 'living_sticker_scene.dart';

/// Mã theo ý nghĩa, độc lập ngôn ngữ và vị trí trong danh sách.
abstract final class MilestoneStickerCatalog {
  static const holidays = <String, LivingStickerScene>{
    'new_year': LivingStickerScene(StickerSubject.fireworks, StickerGesture.celebrate, prop: StickerSubject.star),
    'valentine': LivingStickerScene(StickerSubject.chocolateBox, StickerGesture.love, prop: StickerSubject.heart),
    'international_women': LivingStickerScene(StickerSubject.bouquet, StickerGesture.love, prop: StickerSubject.star),
    'white_valentine': LivingStickerScene(StickerSubject.letter, StickerGesture.shy, prop: StickerSubject.chocolateBox, accent: Color(0xFFB7CDD9)),
    'april_fools': LivingStickerScene(StickerSubject.fish, StickerGesture.play, prop: StickerSubject.star),
    'black_valentine': LivingStickerScene(StickerSubject.coffee, StickerGesture.heal, prop: StickerSubject.chocolateBox, accent: Color(0xFFAA8298)),
    'children': LivingStickerScene(StickerSubject.balloons, StickerGesture.play, prop: StickerSubject.game),
    'family': LivingStickerScene(StickerSubject.couple, StickerGesture.hug, prop: StickerSubject.book),
    'vietnamese_women': LivingStickerScene(StickerSubject.flower, StickerGesture.shy, prop: StickerSubject.letter, accent: Color(0xFFC08AD2)),
    'halloween': LivingStickerScene(StickerSubject.pumpkin, StickerGesture.play, prop: StickerSubject.ghost),
    'christmas_eve': LivingStickerScene(StickerSubject.tree, StickerGesture.celebrate, prop: StickerSubject.moon),
    'christmas_day': LivingStickerScene(StickerSubject.stocking, StickerGesture.celebrate, prop: StickerSubject.gift),
    'new_year_eve': LivingStickerScene(StickerSubject.clock, StickerGesture.celebrate, prop: StickerSubject.fireworks),
    'tet': LivingStickerScene(StickerSubject.redEnvelope, StickerGesture.celebrate, prop: StickerSubject.flower),
    'mid_autumn': LivingStickerScene(StickerSubject.lantern, StickerGesture.celebrate, prop: StickerSubject.mooncake),
    'qixi': LivingStickerScene(StickerSubject.couple, StickerGesture.kiss, prop: StickerSubject.moon),
    'teachers': LivingStickerScene(StickerSubject.book, StickerGesture.heal, prop: StickerSubject.bouquet),
    'mothers': LivingStickerScene(StickerSubject.bunny, StickerGesture.hug, prop: StickerSubject.bouquet),
    'fathers': LivingStickerScene(StickerSubject.puppy, StickerGesture.heal, prop: StickerSubject.heart),
    'earth': LivingStickerScene(StickerSubject.planet, StickerGesture.heal, prop: StickerSubject.tree),
    'peace': LivingStickerScene(StickerSubject.cloud, StickerGesture.love, prop: StickerSubject.flower),
    'friendship': LivingStickerScene(StickerSubject.cat, StickerGesture.wave, prop: StickerSubject.letter),
  };

  static const moments = <String, LivingStickerScene>{
    'birthday_u1': LivingStickerScene(StickerSubject.cake, StickerGesture.celebrate, prop: StickerSubject.cat),
    'birthday_u2': LivingStickerScene(StickerSubject.balloons, StickerGesture.celebrate, prop: StickerSubject.cake),
    'first_date': LivingStickerScene(StickerSubject.couple, StickerGesture.shy, prop: StickerSubject.flower),
    'first_kiss': LivingStickerScene(StickerSubject.couple, StickerGesture.kiss, prop: StickerSubject.heart),
    'engagement': LivingStickerScene(StickerSubject.rings, StickerGesture.love, prop: StickerSubject.bouquet),
    'wedding': LivingStickerScene(StickerSubject.cake, StickerGesture.love, prop: StickerSubject.rings),
    'movie': LivingStickerScene(StickerSubject.film, StickerGesture.play, prop: StickerSubject.heart),
    'travel': LivingStickerScene(StickerSubject.bag, StickerGesture.wave, prop: StickerSubject.camera),
    'coffee': LivingStickerScene(StickerSubject.coffee, StickerGesture.love, prop: StickerSubject.flower),
    'picnic': LivingStickerScene(StickerSubject.bag, StickerGesture.love, prop: StickerSubject.mushroom),
    'beach': LivingStickerScene(StickerSubject.umbrella, StickerGesture.play, prop: StickerSubject.fish),
    'camping': LivingStickerScene(StickerSubject.tree, StickerGesture.sleep, prop: StickerSubject.telescope),
    'concert': LivingStickerScene(StickerSubject.music, StickerGesture.sing, prop: StickerSubject.microphone),
    'graduation': LivingStickerScene(StickerSubject.book, StickerGesture.celebrate, prop: StickerSubject.trophy),
    'new_home': LivingStickerScene(StickerSubject.lock, StickerGesture.celebrate, prop: StickerSubject.heart),
    'reunion': LivingStickerScene(StickerSubject.couple, StickerGesture.wave, prop: StickerSubject.gift),
    'long_distance': LivingStickerScene(StickerSubject.planet, StickerGesture.shy, prop: StickerSubject.letter),
    'cooking': LivingStickerScene(StickerSubject.cake, StickerGesture.laugh, prop: StickerSubject.coffee),
    'rainy_date': LivingStickerScene(StickerSubject.umbrella, StickerGesture.hug, prop: StickerSubject.couple),
    'stargazing': LivingStickerScene(StickerSubject.telescope, StickerGesture.think, prop: StickerSubject.moon),
    'achievement': LivingStickerScene(StickerSubject.trophy, StickerGesture.celebrate, prop: StickerSubject.star),
    'photo_day': LivingStickerScene(StickerSubject.camera, StickerGesture.love, prop: StickerSubject.letter),
    'gift_day': LivingStickerScene(StickerSubject.gift, StickerGesture.shy, prop: StickerSubject.bouquet),
    'self_care': LivingStickerScene(StickerSubject.health, StickerGesture.heal, prop: StickerSubject.flower),
  };

  static const solarHolidays = <String, String>{
    '1-1': 'new_year', '2-14': 'valentine', '3-8': 'international_women',
    '3-14': 'white_valentine', '4-1': 'april_fools', '4-14': 'black_valentine',
    '6-1': 'children', '6-28': 'family', '10-20': 'vietnamese_women',
    '10-31': 'halloween', '12-24': 'christmas_eve', '12-25': 'christmas_day',
    '12-31': 'new_year_eve',
  };

  static const dayMilestones = [7, 14, 30, 50, 60, 90, 100, 111, 150, 200, 222,
    250, 300, 333, 365, 400, 444, 500, 555, 600, 666, 700, 730, 777, 800, 888,
    900, 999, 1000, 1111, 1500, 2000, 2500, 3000, 4000, 5000, 10000];

  static List<String> get anniversaryKeys => [
    for (final n in dayMilestones) 'days_$n',
    for (var n = 1; n <= 11; n++) 'months_$n',
    for (var n = 1; n <= 25; n++) 'years_$n',
  ];
  static List<String> get allKeys => [
    for (final id in holidays.keys) 'holiday_$id',
    for (final id in moments.keys) 'moment_$id',
    ...anniversaryKeys,
  ];

  static String holidayKey(DateTime date) =>
      'holiday_${solarHolidays['${date.month}-${date.day}'] ?? 'friendship'}';

  static LivingStickerScene? scene(String id) {
    if (id.startsWith('holiday_')) return holidays[id.substring(8)];
    if (id.startsWith('moment_')) return moments[id.substring(7)];
    final match = RegExp(r'^(days|months|years)_([1-9][0-9]{0,5})$').firstMatch(id);
    if (match == null) return null;
    final unit = match.group(1)!;
    final value = match.group(2)!;
    // Giữ số như sticker 500 ngày; tháng/năm có đạo cụ khác, không đổi số thành ngày.
    return LivingStickerScene(StickerSubject.calendar, StickerGesture.celebrate,
      detail: value,
      accent: unit == 'months' ? const Color(0xFFAB99D4)
          : unit == 'years' ? const Color(0xFFE2B569) : const Color(0xFFE9799B),
      prop: unit == 'months' ? StickerSubject.moon
          : unit == 'years' ? StickerSubject.rings : null);
  }
}
