part of 'original_sticker.dart';

/// Kịch bản theo ý nghĩa hình, không chọn ngẫu nhiên bằng hash hoặc index.
/// Mỗi cue điều khiển đúng một vùng rig: chuẩn bị -> hành động -> giữ -> nghỉ.
@immutable
class OriginalStickerCue {
  const OriginalStickerCue(this.keys);
  final List<(double, double)> keys;

  double valueAt(double phase) {
    if (phase <= keys.first.$1 || phase >= keys.last.$1) return 0;
    for (var i = 1; i < keys.length; i++) {
      final (end, value) = keys[i];
      if (phase > end) continue;
      final (start, previous) = keys[i - 1];
      final t = (phase - start) / (end - start);
      final smooth = t * t * (3 - 2 * t);
      return previous + (value - previous) * smooth;
    }
    return 0;
  }
}

@immutable
class OriginalStickerPerformance {
  const OriginalStickerPerformance(this.action, this.milliseconds, this.cues);
  // Mô tả nội bộ để review/test, không phải chuỗi giao diện.
  final String action;
  final int milliseconds;
  final List<OriginalStickerCue> cues;
  Duration get duration => Duration(milliseconds: milliseconds);
}

// Các động tác có nhịp riêng, chỉ dùng lại khi thật sự cùng hành vi.
const _blink = OriginalStickerCue([
  (0, 0),
  (.12, 0),
  (.15, 1),
  (.19, 0),
  (1, 0),
]);
const _replyBlink = OriginalStickerCue([
  (0, 0),
  (.67, 0),
  (.70, 1),
  (.74, 0),
  (1, 0),
]);
const _wink = OriginalStickerCue([
  (0, 0),
  (.26, 0),
  (.31, 1),
  (.39, 1),
  (.45, 0),
  (1, 0),
]);
const _squeeze = OriginalStickerCue([
  (0, 0),
  (.14, 0),
  (.36, 1),
  (.63, 1),
  (.82, 0),
  (1, 0),
]);
const _receive = OriginalStickerCue([
  (0, 0),
  (.32, 0),
  (.49, .85),
  (.70, .85),
  (.88, 0),
  (1, 0),
]);
const _kiss = OriginalStickerCue([
  (0, 0),
  (.13, 0),
  (.32, 1),
  (.43, 1),
  (.57, 0),
  (1, 0),
]);
const _heartReply = OriginalStickerCue([
  (0, 0),
  (.39, 0),
  (.52, 1),
  (.71, 0),
  (1, 0),
]);
const _wave = OriginalStickerCue([
  (0, 0),
  (.16, 0),
  (.28, 1),
  (.38, .2),
  (.49, 1),
  (.59, .2),
  (.70, .8),
  (.83, 0),
  (1, 0),
]);
const _flick = OriginalStickerCue([
  (0, 0),
  (.34, 0),
  (.45, 1),
  (.56, 0),
  (1, 0),
]);
const _point = OriginalStickerCue([
  (0, 0),
  (.20, 0),
  (.38, 1),
  (.60, 1),
  (.75, 0),
  (1, 0),
]);
const _tease = OriginalStickerCue([
  (0, 0),
  (.36, 0),
  (.46, 1),
  (.64, 1),
  (.74, 0),
  (1, 0),
]);
const _write = OriginalStickerCue([
  (0, 0),
  (.13, 0),
  (.23, 1),
  (.30, .15),
  (.39, .85),
  (.46, .1),
  (.55, .7),
  (.63, 0),
  (1, 0),
]);
const _shy = OriginalStickerCue([
  (0, 0),
  (.19, 0),
  (.39, .8),
  (.67, .8),
  (.86, 0),
  (1, 0),
]);
const _tuck = OriginalStickerCue([
  (0, 0),
  (.10, 0),
  (.31, 1),
  (.56, 1),
  (.76, 0),
  (1, 0),
]);
const _sleep = OriginalStickerCue([
  (0, 0),
  (.10, 0),
  (.43, 1),
  (.52, 1),
  (.94, 0),
  (1, 0),
]);
const _sigh = OriginalStickerCue([
  (0, 0),
  (.10, 0),
  (.27, 1),
  (.43, .9),
  (.81, 0),
  (1, 0),
]);
const _clench = OriginalStickerCue([
  (0, 0),
  (.19, 0),
  (.29, 1),
  (.56, 1),
  (.72, .25),
  (.84, 0),
  (1, 0),
]);
const _frown = OriginalStickerCue([
  (0, 0),
  (.12, 0),
  (.27, .65),
  (.62, .65),
  (.84, 0),
  (1, 0),
]);
const _rain = OriginalStickerCue([
  (0, 0),
  (.24, 0),
  (.41, 1),
  (.49, 0),
  (.66, .8),
  (.75, 0),
  (1, 0),
]);
const _lift = OriginalStickerCue([
  (0, 0),
  (.11, 0),
  (.31, 1),
  (.52, 1),
  (.74, 0),
  (1, 0),
]);
const _answerLift = OriginalStickerCue([
  (0, 0),
  (.32, 0),
  (.50, 1),
  (.66, 1),
  (.86, 0),
  (1, 0),
]);
const _tap = OriginalStickerCue([
  (0, 0),
  (.15, 0),
  (.21, 1),
  (.27, 0),
  (.37, 1),
  (.43, 0),
  (1, 0),
]);
const _answerTap = OriginalStickerCue([
  (0, 0),
  (.47, 0),
  (.54, 1),
  (.60, 0),
  (.68, .8),
  (.74, 0),
  (1, 0),
]);
const _laugh = OriginalStickerCue([
  (0, 0),
  (.25, 0),
  (.34, .8),
  (.40, .25),
  (.48, 1),
  (.55, .3),
  (.62, .65),
  (.76, 0),
  (1, 0),
]);
const _duet = OriginalStickerCue([
  (0, 0),
  (.14, 0),
  (.26, .9),
  (.37, .3),
  (.46, .7),
  (.58, .2),
  (.72, 1),
  (.87, 0),
  (1, 0),
]);
const _chew = OriginalStickerCue([
  (0, 0),
  (.44, 0),
  (.51, 1),
  (.57, 0),
  (.64, .8),
  (.70, 0),
  (1, 0),
]);
const _peek = OriginalStickerCue([
  (0, 0),
  (.20, 0),
  (.33, 1),
  (.50, 1),
  (.60, 0),
  (1, 0),
]);
const _peekReply = OriginalStickerCue([
  (0, 0),
  (.35, 0),
  (.46, 1),
  (.58, 1),
  (.71, 0),
  (1, 0),
]);
const _offer = OriginalStickerCue([
  (0, 0),
  (.17, 0),
  (.40, 1),
  (.72, 1),
  (.89, 0),
  (1, 0),
]);
const _doubleBeat = OriginalStickerCue([
  (0, 0),
  (.22, 0),
  (.29, 1),
  (.35, 0),
  (.43, .7),
  (.50, 0),
  (1, 0),
]);
const _glimmer = OriginalStickerCue([
  (0, 0),
  (.40, 0),
  (.53, 1),
  (.71, 0),
  (.80, .4),
  (.92, 0),
  (1, 0),
]);

abstract final class OriginalStickerPerformances {
  static const byId = <String, OriginalStickerPerformance>{
    'diary_reflective': OriginalStickerPerformance(
      'Viết ba nét rồi ngừng suy nghĩ',
      6100,
      [_write, _sigh],
    ),
    'diary_shy': OriginalStickerPerformance(
      'Rụt tay che miệng rồi nhìn lại',
      5800,
      [_shy, _blink, _blink],
    ),
    'diary_missing': OriginalStickerPerformance(
      'Nâng thư sát ngực, tai cụp nhẹ',
      6200,
      [_replyBlink, _squeeze, _receive],
    ),
    'diary_proud': OriginalStickerPerformance(
      'Hai bạn nâng ngôi sao khoe thành quả',
      4900,
      [_lift, _glimmer],
    ),
    'diary_sleepy': OriginalStickerPerformance(
      'Ôm trăng ngủ, thở ra chậm',
      7300,
      [_sleep, _sigh],
    ),
    'diary_anxious': OriginalStickerPerformance(
      'Chớp mắt lo lắng rồi kéo chăn',
      6800,
      [_blink, _blink, _tuck],
    ),
    'diary_grumpy': OriginalStickerPerformance(
      'Nheo mắt, siết hai tay, mây sà xuống',
      5600,
      [_frown, _frown, _clench, _rain],
    ),
    'diary_playful': OriginalStickerPerformance(
      'Nháy mắt rồi búng ngón tay',
      4400,
      [_wink, _flick, _glimmer],
    ),
    'diary_healing': OriginalStickerPerformance(
      'Trái tim hồi phục, mầm lá vươn lên',
      6900,
      [_doubleBeat, _lift],
    ),
    'motion_missing': OriginalStickerPerformance(
      'Ôm ảnh vào ngực rồi thở dài',
      6700,
      [_squeeze, _shy, _sigh],
    ),
    'motion_cuddle': OriginalStickerPerformance(
      'Gấu siết vòng tay, thỏ ôm đáp lại',
      7100,
      [_squeeze, _receive, _heartReply],
    ),
    'motion_kiss': OriginalStickerPerformance(
      'Thỏ áp má hôn, gấu khép mắt đón',
      5500,
      [_wink, _kiss, _heartReply, _receive],
    ),
    'motion_tease': OriginalStickerPerformance(
      'Chạm má hai lần rồi gấu nháy mắt',
      4700,
      [_tap, _replyBlink, _replyBlink],
    ),
    'motion_comfort': OriginalStickerPerformance(
      'Gấu vỗ về dưới chăn, tim đáp nhẹ',
      7600,
      [_wave, _heartReply],
    ),
    'motion_celebrate': OriginalStickerPerformance(
      'Đập tay rồi ngôi sao bật sáng',
      4200,
      [_tap, _glimmer],
    ),
    'motion_sleep': OriginalStickerPerformance(
      'Ôm gối ngủ, sao sáng sau nhịp thở',
      8200,
      [_sleep, _glimmer],
    ),
    'motion_send_love': OriginalStickerPerformance(
      'Đưa tay gửi tim rồi thư đáp lại',
      5900,
      [_blink, _blink, _heartReply, _offer],
    ),
    'motion_dance': OriginalStickerPerformance(
      'Vẫy tay ba nhịp theo nốt nhạc',
      4600,
      [_wave, _duet],
    ),

    'novelty_star_love': OriginalStickerPerformance(
      'Sao nháy mắt, đưa tay gửi tim',
      5200,
      [_wink, _offer, _heartReply],
    ),
    'novelty_planet_crush': OriginalStickerPerformance(
      'Hành tinh cười rồi hai tay ôm má lần lượt',
      6300,
      [_laugh, _shy, _receive],
    ),
    'novelty_robot_laugh': OriginalStickerPerformance(
      'Robot vẫy chào ba lần rồi cười',
      4300,
      [_wave, _laugh],
    ),
    'novelty_moon_kiss': OriginalStickerPerformance(
      'Mặt trời áp má vào trăng, tim nở sau nụ hôn',
      6000,
      [_kiss, _heartReply],
    ),
    'novelty_ghost_tease': OriginalStickerPerformance(
      'Ma nháy mắt, búng tay rồi lè lưỡi',
      4800,
      [_wink, _flick, _tease],
    ),
    'novelty_cloud_hug': OriginalStickerPerformance(
      'Mây xanh vòng tay, mây trắng tựa vào',
      7400,
      [_squeeze, _receive],
    ),
    'novelty_raindrop_comfort': OriginalStickerPerformance(
      'Giọt nước chớp mắt, nâng ô và nước trượt xuống',
      6500,
      [_blink, _blink, _lift, _rain],
    ),
    'novelty_game_party': OriginalStickerPerformance(
      'Tay cầm bấm D-pad rồi nút màu và cười',
      4100,
      [_replyBlink, _tap, _answerTap, _laugh],
    ),
    'novelty_coffee_date': OriginalStickerPerformance(
      'Hai cốc cười đáp nhau rồi cà phê bắn lên',
      5400,
      [_laugh, _duet, _answerLift],
    ),
    'novelty_music_mix': OriginalStickerPerformance(
      'Hai tim cassette đánh nhịp đối đáp, dây băng nhún',
      3900,
      [_tap, _answerTap, _duet],
    ),
    'novelty_mushroom_cuddle': OriginalStickerPerformance(
      'Nấm lớn tựa sát rồi nấm nhỏ ôm đáp',
      7800,
      [_squeeze, _receive],
    ),
    'novelty_love_plane': OriginalStickerPerformance(
      'Dấu tim trên thư đập rồi đuôi tim đáp lại',
      5700,
      [_doubleBeat, _heartReply],
    ),

    'heart_scrapbook': OriginalStickerPerformance(
      'Hoa vải nở trước rồi chiếc nút đáp lại',
      6600,
      [_lift, _answerTap],
    ),
    'heart_plush': OriginalStickerPerformance(
      'Tim bông nhắm mắt ôm chặt trái tim nhỏ',
      6400,
      [_wink, _wink, _squeeze],
    ),
    'heart_glass': OriginalStickerPerformance(
      'Hai tim trong pha lê sáng lần lượt',
      5700,
      [_doubleBeat, _glimmer],
    ),
    'heart_letter': OriginalStickerPerformance(
      'Ấn dấu sáp rồi bó hoa ngẩng lên',
      6100,
      [_tap, _answerLift],
    ),
    'heart_locket': OriginalStickerPerformance(
      'Chìa khóa nhích mở sau khi nơ thắt chặt',
      6900,
      [_answerLift, _squeeze],
    ),
    'heart_healing': OriginalStickerPerformance(
      'Tim băng bó thở dài, miếng vá đập hai nhịp',
      7900,
      [_sigh, _doubleBeat],
    ),
    'heart_sleep': OriginalStickerPerformance(
      'Tim ngủ trên trăng, chóp mũ rũ xuống sau',
      8500,
      [_sleep, _receive],
    ),
    'heart_celebrate': OriginalStickerPerformance(
      'Tim cười vui rồi nơ tung theo tiếng cười',
      4500,
      [_laugh, _answerTap],
    ),
    'heart_thread': OriginalStickerPerformance(
      'Tim lớn chớp trước, tim nhỏ đáp rồi dây siết lại',
      7200,
      [_blink, _blink, _replyBlink, _replyBlink, _squeeze],
    ),
    'heart_calendar': OriginalStickerPerformance(
      'Tim nhìn lịch rồi vỗ lên trang hai lần',
      5800,
      [_blink, _blink, _tap],
    ),
    'heart_heartbeat': OriginalStickerPerformance(
      'Một nhịp tim mạnh, nhịp nhỏ nối tiếp',
      3800,
      [_doubleBeat, _heartReply],
    ),
    'heart_gift': OriginalStickerPerformance(
      'Nơ mở trước rồi tim trong hộp bật lên',
      5300,
      [_answerLift, _lift],
    ),

    'merge_joy_confetti': OriginalStickerPerformance(
      'Thỏ tung tay rồi mèo reo đáp',
      4100,
      [_lift, _answerLift],
    ),
    'merge_joy_laugh': OriginalStickerPerformance(
      'Thỏ ôm bụng che miệng, mèo cười nối tiếp',
      4800,
      [_laugh, _shy, _duet],
    ),
    'merge_joy_dance': OriginalStickerPerformance(
      'Thỏ đánh nhịp tay, đuôi mèo đáp nhịp sau',
      4400,
      [_duet, _answerTap],
    ),
    'merge_joy_high_five': OriginalStickerPerformance(
      'Nháy mắt rồi đập tay hai lần',
      4200,
      [_wink, _tap],
    ),
    'merge_joy_big_heart': OriginalStickerPerformance(
      'Nâng tim lên rồi tai thỏ nghiêng âu yếm',
      5900,
      [_lift, _receive],
    ),
    'merge_joy_wave': OriginalStickerPerformance(
      'Thỏ nhìn trước, mèo vẫy tay chào',
      5100,
      [_blink, _replyBlink, _wave],
    ),
    'merge_joy_coffee_date': OriginalStickerPerformance(
      'Thỏ nâng cốc trước, mèo nâng cốc đáp',
      7500,
      [_lift, _answerLift],
    ),
    'merge_joy_cake': OriginalStickerPerformance(
      'Chu môi thổi nến rồi ngọn lửa lay xuống',
      6400,
      [_kiss, _heartReply],
    ),
    'merge_joy_send_hearts': OriginalStickerPerformance(
      'Thỏ đưa tay hôn gió, tim bay nối tiếp',
      5600,
      [_kiss, _glimmer],
    ),
    'merge_comfort_hold': OriginalStickerPerformance(
      'Thỏ nhìn mèo rồi ôm vuốt an ủi',
      7700,
      [_blink, _blink, _replyBlink, _replyBlink, _squeeze],
    ),
    'merge_comfort_tissues': OriginalStickerPerformance(
      'Thỏ lau nước mắt trước, mèo chớp đáp',
      7000,
      [_blink, _blink, _replyBlink, _replyBlink, _tap],
    ),
    'merge_comfort_blanket': OriginalStickerPerformance(
      'Thỏ nhìn bạn rồi kéo chăn sát người',
      8100,
      [_replyBlink, _replyBlink, _tuck],
    ),
    'merge_comfort_rainy': OriginalStickerPerformance(
      'Mèo chớp mắt buồn, thỏ đáp rồi thở dài',
      8300,
      [_blink, _blink, _replyBlink, _replyBlink, _sigh],
    ),
    'merge_comfort_holding_hands': OriginalStickerPerformance(
      'Thỏ bóp nhẹ tay, mèo thở bình yên',
      8000,
      [_squeeze, _sleep],
    ),
    'merge_comfort_healing': OriginalStickerPerformance(
      'Nâng tim băng bó rồi tai thỏ rũ dịu xuống',
      7400,
      [_offer, _receive],
    ),
    'merge_comfort_goodnight': OriginalStickerPerformance(
      'Chăn nâng theo hơi thỏ, mèo thở ra sau',
      9100,
      [_sleep, _sigh],
    ),
    'merge_comfort_sorry': OriginalStickerPerformance(
      'Thỏ cúi mắt, mèo đưa hoa xin lỗi',
      8200,
      [_frown, _frown, _replyBlink, _replyBlink, _offer],
    ),
    'merge_comfort_hug': OriginalStickerPerformance(
      'Thỏ ôm trước, mèo dựa vào giữ lâu',
      8600,
      [_squeeze, _receive],
    ),
    'merge_love_big_heart': OriginalStickerPerformance(
      'Hai bạn nâng tim, tai thỏ vểnh sau',
      6700,
      [_offer, _answerLift],
    ),
    'merge_love_cheek_kiss': OriginalStickerPerformance(
      'Thỏ hôn má rồi mèo khép mắt nhận',
      5700,
      [_wink, _kiss],
    ),
    'merge_love_umbrella': OriginalStickerPerformance(
      'Mèo nhìn thỏ rồi nép sát dưới ô',
      7900,
      [_blink, _blink, _receive],
    ),
    'merge_love_letter': OriginalStickerPerformance(
      'Tay đưa thư trước, dấu tim đập đáp',
      6200,
      [_heartReply, _offer],
    ),
    'merge_love_pinky': OriginalStickerPerformance(
      'Móc ngón tay giữ lời hứa, mèo tựa vào',
      7600,
      [_squeeze, _receive],
    ),
    'merge_love_dance': OriginalStickerPerformance(
      'Hai tay dẫn nhịp trước, đuôi mèo theo sau',
      5000,
      [_duet, _answerTap],
    ),
    'merge_love_locket': OriginalStickerPerformance(
      'Mèo nháy mắt rồi đưa chìa khóa',
      6500,
      [_wink, _wink, _offer],
    ),
    'merge_love_flowers': OriginalStickerPerformance(
      'Thỏ dâng hoa, mèo ngượng ngùng đáp',
      7300,
      [_offer, _shy],
    ),
    'merge_love_cuddle': OriginalStickerPerformance(
      'Chăn ôm theo hơi thở, tay siết chậm',
      8900,
      [_sleep, _squeeze],
    ),
    'merge_playful_tease': OriginalStickerPerformance(
      'Kéo má trước rồi thè lưỡi trêu',
      4600,
      [_point, _tease],
    ),
    'merge_playful_peekaboo': OriginalStickerPerformance(
      'Mở tay trái rồi tay phải, che lại ú òa',
      5500,
      [_peek, _peekReply],
    ),
    'merge_playful_game': OriginalStickerPerformance(
      'Liếc bạn rồi đặt quân xuống bàn',
      6100,
      [_blink, _tap],
    ),
    'merge_playful_photo': OriginalStickerPerformance(
      'Nháy mắt tạo dáng rồi tay bấm chụp',
      5400,
      [_wink, _flick],
    ),
    'merge_playful_snack': OriginalStickerPerformance(
      'Thỏ nhìn bánh, mèo lấy hai miếng',
      6300,
      [_blink, _blink, _tap],
    ),
    'merge_playful_faces': OriginalStickerPerformance(
      'Nháy mắt, kéo má giữ rồi lè lưỡi',
      4900,
      [_wink, _point, _tease],
    ),
    'merge_playful_shopping': OriginalStickerPerformance(
      'Thỏ khoe túi trước, mèo giơ túi đáp',
      6800,
      [_lift, _answerLift],
    ),
    'merge_playful_singing': OriginalStickerPerformance(
      'Nâng micro rồi miệng hát ba câu',
      5600,
      [_lift, _duet],
    ),
    'merge_playful_movie': OriginalStickerPerformance(
      'Thỏ ăn bắp trước, mèo lấy phần sau',
      7200,
      [_chew, _answerTap],
    ),
  };
}
