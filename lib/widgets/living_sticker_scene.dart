import 'package:flutter/material.dart';

enum StickerSubject {
  couple,
  cat,
  bunny,
  puppy,
  heart,
  star,
  moon,
  planet,
  robot,
  ghost,
  cloud,
  drop,
  game,
  coffee,
  music,
  mushroom,
  letter,
  calendar,
  gift,
  camera,
  book,
  clock,
  cake,
  flower,
  umbrella,
  tree,
  lock,
  wheel,
  microphone,
  film,
  calculator,
  wallet,
  brush,
  bag,
  health,
  tarot,
  checklist,
  telescope,
}

enum StickerGesture {
  love,
  hug,
  kiss,
  wave,
  laugh,
  dance,
  celebrate,
  sad,
  sleep,
  shy,
  think,
  angry,
  pout,
  sorry,
  heal,
  play,
  peek,
  sing,
}

@immutable
class LivingStickerScene {
  const LivingStickerScene(
    this.subject,
    this.gesture, {
    this.prop,
    this.accent = const Color(0xFFE9799B),
    this.detail,
  });

  final StickerSubject subject;
  final StickerGesture gesture;
  final StickerSubject? prop;
  final Color accent;
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is LivingStickerScene &&
      other.subject == subject &&
      other.gesture == gesture &&
      other.prop == prop &&
      other.accent == accent &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(subject, gesture, prop, accent, detail);
}

/// Ánh xạ theo ý nghĩa, không gán hình ngẫu nhiên theo hash hoặc số thứ tự.
abstract final class LivingStickerCatalog {
  static const scenes = <String, LivingStickerScene>{
    'novelty_star_love': LivingStickerScene(
      StickerSubject.star,
      StickerGesture.love,
    ),
    'novelty_planet_crush': LivingStickerScene(
      StickerSubject.planet,
      StickerGesture.shy,
    ),
    'novelty_robot_laugh': LivingStickerScene(
      StickerSubject.robot,
      StickerGesture.laugh,
    ),
    'novelty_moon_kiss': LivingStickerScene(
      StickerSubject.moon,
      StickerGesture.kiss,
    ),
    'novelty_ghost_tease': LivingStickerScene(
      StickerSubject.ghost,
      StickerGesture.play,
    ),
    'novelty_cloud_hug': LivingStickerScene(
      StickerSubject.cloud,
      StickerGesture.hug,
    ),
    'novelty_raindrop_comfort': LivingStickerScene(
      StickerSubject.drop,
      StickerGesture.sad,
    ),
    'novelty_game_party': LivingStickerScene(
      StickerSubject.game,
      StickerGesture.celebrate,
    ),
    'novelty_coffee_date': LivingStickerScene(
      StickerSubject.coffee,
      StickerGesture.love,
    ),
    'novelty_music_mix': LivingStickerScene(
      StickerSubject.music,
      StickerGesture.sing,
    ),
    'novelty_mushroom_cuddle': LivingStickerScene(
      StickerSubject.mushroom,
      StickerGesture.hug,
    ),
    'novelty_love_plane': LivingStickerScene(
      StickerSubject.letter,
      StickerGesture.wave,
    ),
    'motion_missing': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.sad,
      prop: StickerSubject.heart,
    ),
    'motion_cuddle': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.hug,
    ),
    'motion_kiss': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.kiss,
    ),
    'motion_tease': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.play,
    ),
    'motion_comfort': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.heal,
    ),
    'motion_celebrate': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.celebrate,
    ),
    'motion_sleep': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.sleep,
    ),
    'motion_send_love': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.love,
      prop: StickerSubject.letter,
    ),
    'motion_dance': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.dance,
    ),
    'heart_scrapbook': LivingStickerScene(
      StickerSubject.heart,
      StickerGesture.love,
      prop: StickerSubject.book,
    ),
    'heart_plush': LivingStickerScene(StickerSubject.heart, StickerGesture.hug),
    'heart_glass': LivingStickerScene(
      StickerSubject.heart,
      StickerGesture.shy,
      accent: Color(0xFF91C9D8),
    ),
    'heart_letter': LivingStickerScene(
      StickerSubject.letter,
      StickerGesture.love,
    ),
    'heart_locket': LivingStickerScene(
      StickerSubject.lock,
      StickerGesture.love,
    ),
    'heart_healing': LivingStickerScene(
      StickerSubject.heart,
      StickerGesture.heal,
    ),
    'heart_sleep': LivingStickerScene(
      StickerSubject.heart,
      StickerGesture.sleep,
    ),
    'heart_celebrate': LivingStickerScene(
      StickerSubject.heart,
      StickerGesture.celebrate,
    ),
    'heart_thread': LivingStickerScene(
      StickerSubject.heart,
      StickerGesture.kiss,
      accent: Color(0xFFB28FD0),
    ),
    'heart_calendar': LivingStickerScene(
      StickerSubject.calendar,
      StickerGesture.love,
    ),
    'heart_heartbeat': LivingStickerScene(
      StickerSubject.heart,
      StickerGesture.love,
    ),
    'heart_gift': LivingStickerScene(StickerSubject.gift, StickerGesture.love),
    'diary_reflective': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.think,
      prop: StickerSubject.book,
    ),
    'diary_shy': LivingStickerScene(StickerSubject.bunny, StickerGesture.shy),
    'diary_missing': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.sad,
      prop: StickerSubject.heart,
    ),
    'diary_proud': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.celebrate,
      prop: StickerSubject.star,
    ),
    'diary_sleepy': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.sleep,
    ),
    'diary_anxious': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.think,
    ),
    'diary_grumpy': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.angry,
    ),
    'diary_playful': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.play,
    ),
    'diary_healing': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.heal,
      prop: StickerSubject.heart,
    ),
    'merge_joy_confetti': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.celebrate,
    ),
    'merge_joy_laugh': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.laugh,
    ),
    'merge_joy_dance': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.dance,
    ),
    'merge_joy_high_five': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.wave,
    ),
    'merge_joy_big_heart': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.hug,
      prop: StickerSubject.heart,
    ),
    'merge_joy_wave': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.wave,
    ),
    'merge_joy_coffee_date': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.laugh,
      prop: StickerSubject.coffee,
    ),
    'merge_joy_cake': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.celebrate,
      prop: StickerSubject.cake,
    ),
    'merge_joy_send_hearts': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.love,
    ),
    'merge_comfort_hold': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.sad,
    ),
    'merge_comfort_tissues': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.sad,
      prop: StickerSubject.letter,
    ),
    'merge_comfort_blanket': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.sleep,
      prop: StickerSubject.book,
    ),
    'merge_comfort_rainy': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.sad,
      prop: StickerSubject.umbrella,
    ),
    'merge_comfort_holding_hands': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.heal,
    ),
    'merge_comfort_healing': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.heal,
      prop: StickerSubject.heart,
    ),
    'merge_comfort_goodnight': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.sleep,
      prop: StickerSubject.moon,
    ),
    'merge_comfort_sorry': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.sorry,
    ),
    'merge_comfort_hug': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.hug,
    ),
    'merge_love_big_heart': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.love,
      prop: StickerSubject.heart,
    ),
    'merge_love_cheek_kiss': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.kiss,
    ),
    'merge_love_umbrella': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.hug,
      prop: StickerSubject.umbrella,
    ),
    'merge_love_letter': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.shy,
      prop: StickerSubject.letter,
    ),
    'merge_love_pinky': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.heal,
      prop: StickerSubject.star,
    ),
    'merge_love_dance': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.dance,
      prop: StickerSubject.heart,
    ),
    'merge_love_locket': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.love,
      prop: StickerSubject.lock,
    ),
    'merge_love_flowers': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.shy,
      prop: StickerSubject.flower,
    ),
    'merge_love_cuddle': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.hug,
      prop: StickerSubject.moon,
    ),
    'merge_playful_tease': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.play,
    ),
    'merge_playful_peekaboo': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.peek,
    ),
    'merge_playful_game': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.play,
      prop: StickerSubject.game,
    ),
    'merge_playful_photo': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.wave,
      prop: StickerSubject.camera,
    ),
    'merge_playful_snack': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.laugh,
      prop: StickerSubject.cake,
    ),
    'merge_playful_faces': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.peek,
    ),
    'merge_playful_shopping': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.wave,
      prop: StickerSubject.bag,
    ),
    'merge_playful_singing': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.sing,
      prop: StickerSubject.microphone,
    ),
    'merge_playful_movie': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.laugh,
      prop: StickerSubject.film,
    ),
    'mood_pout': LivingStickerScene(StickerSubject.cat, StickerGesture.pout),
    'mood_crossed_arms': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.pout,
    ),
    'mood_angry': LivingStickerScene(StickerSubject.cat, StickerGesture.angry),
    'mood_furious': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.angry,
    ),
    'mood_sulking': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.pout,
    ),
    'mood_sorry': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.sorry,
      prop: StickerSubject.flower,
    ),
    'mood_make_up': LivingStickerScene(
      StickerSubject.couple,
      StickerGesture.heal,
      prop: StickerSubject.flower,
    ),
    'mood_jealous': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.pout,
      prop: StickerSubject.heart,
    ),
    'mood_peace': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.heal,
      prop: StickerSubject.star,
    ),
  };

  static LivingStickerScene? find(String reference) {
    const prefix = 'soullocket://sticker/';
    return scenes[reference.startsWith(prefix)
        ? reference.substring(prefix.length)
        : reference];
  }

  static const utilitySubjects = <String, StickerSubject>{
    'age_zodiac': StickerSubject.telescope,
    'bucket': StickerSubject.checklist,
    'calculator': StickerSubject.calculator,
    'calendar': StickerSubject.calendar,
    'capsule': StickerSubject.clock,
    'cinema': StickerSubject.film,
    'collage': StickerSubject.camera,
    'creative_diary': StickerSubject.book,
    'diary_export': StickerSubject.book,
    'drawing': StickerSubject.brush,
    'finance': StickerSubject.wallet,
    'friendly_chat': StickerSubject.cloud,
    'gift': StickerSubject.gift,
    'giftcode': StickerSubject.gift,
    'habit': StickerSubject.checklist,
    'health': StickerSubject.health,
    'history': StickerSubject.clock,
    'love_card': StickerSubject.letter,
    'note': StickerSubject.book,
    'photo': StickerSubject.camera,
    'store': StickerSubject.bag,
    'surprise': StickerSubject.gift,
    'tarot': StickerSubject.tarot,
    'vault': StickerSubject.lock,
    'voice': StickerSubject.microphone,
    'wheel': StickerSubject.wheel,
    'wish': StickerSubject.star,
  };

  static LivingStickerScene? utility(String id) {
    final subject = utilitySubjects[id];
    return subject == null
        ? null
        : LivingStickerScene(subject, StickerGesture.love);
  }

  static const milestoneSubjects = <String, StickerSubject>{
    'womens_day': StickerSubject.flower,
    'chocolate': StickerSubject.gift,
    'april': StickerSubject.flower,
    'beach': StickerSubject.umbrella,
    'rainy': StickerSubject.umbrella,
    'picnic': StickerSubject.bag,
    'halloween': StickerSubject.ghost,
    'christmas_tree': StickerSubject.tree,
    'christmas_stocking': StickerSubject.gift,
    'fireworks_couple': StickerSubject.couple,
    'moon_bunnies': StickerSubject.bunny,
    'birthday_cupcake': StickerSubject.cake,
    'first_date': StickerSubject.couple,
    'movie_date': StickerSubject.film,
    'travel': StickerSubject.telescope,
    'coffee': StickerSubject.coffee,
    'heart_lock': StickerSubject.lock,
  };

  static LivingStickerScene? milestone(String id) {
    if (const {
      'days_30',
      'days_50',
      'days_100',
      'days_365',
      'days_500',
      'days_730',
      'days_1000',
    }.contains(id)) {
      return LivingStickerScene(
        StickerSubject.calendar,
        StickerGesture.celebrate,
        detail: id.substring(5),
      );
    }
    final subject = milestoneSubjects[id];
    return subject == null
        ? null
        : LivingStickerScene(subject, StickerGesture.celebrate);
  }

  static const homeAssets = <String, LivingStickerScene>{
    'icon_bubble_lol_cloud': LivingStickerScene(
      StickerSubject.cloud,
      StickerGesture.laugh,
    ),
    'card_ngay_yeu_calendar': LivingStickerScene(
      StickerSubject.calendar,
      StickerGesture.love,
    ),
    'card_ky_niem_photos': LivingStickerScene(
      StickerSubject.camera,
      StickerGesture.love,
    ),
    'card_ban_nam_boy': LivingStickerScene(
      StickerSubject.cat,
      StickerGesture.wave,
    ),
    'card_ban_nu_girl': LivingStickerScene(
      StickerSubject.bunny,
      StickerGesture.wave,
    ),
    'avatar_puppy_heart': LivingStickerScene(
      StickerSubject.puppy,
      StickerGesture.hug,
    ),
  };

  static LivingStickerScene? asset(String path) {
    final name = path
        .split('/')
        .last
        .replaceFirst(RegExp(r'\.(png|webp)$'), '');
    if (path.startsWith('assets/icons/cute_3d/')) return homeAssets[name];
    if (path.startsWith('assets/images/utility_stickers/')) {
      return utility(name);
    }
    if (path.startsWith('assets/images/milestone_embedded/')) {
      return milestone(name);
    }
    return find(path);
  }
}
