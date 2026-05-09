part of '../../main_home_tab.dart';

class _PartnerInteractionPreset {
  final String type;
  final String label;
  final String emoji;
  final String? assetPath;
  final int weight;
  final bool showInSmartSuggestion;
  final List<Color> gradient;
  final Color accent;
  final List<String> titles;
  final List<String> messages;

  const _PartnerInteractionPreset({
    required this.type,
    required this.label,
    required this.emoji,
    this.assetPath,
    required this.weight,
    this.showInSmartSuggestion = true,
    required this.gradient,
    required this.accent,
    required this.titles,
    required this.messages,
  });
}

class _CountdownQuickOption {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isPremium;

  const _CountdownQuickOption({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.isPremium = false,
  });
}

const List<_PartnerInteractionPreset> _kPartnerInteractionPresets = [
  _PartnerInteractionPreset(
    type: 'miss',
    label: 'Nhớ',
    emoji: '\u{1F496}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_098.png',
    weight: 42,
    gradient: [Color(0xFFFFD8E6), Color(0xFFFFF3F7)],
    accent: Color(0xFFD94C86),
    titles: [
      'Bỗng thấy nhớ bạn thật nhiều',
      'Nỗi nhớ hôm nay lại đầy lên',
      'Vừa chạm tim là nhớ bạn ngay',
      'Tim vừa chuẩn đoán: nhớ bạn',
    ],
    messages: [
      'Mình nhớ bạn nhiều hơn mọi cảm xúc khác đó.',
      'Nếu đang rảnh thì cho mình thấy bạn một chút nha.',
      'Nỗi nhớ này tự bật lên ngay khi chạm tim đó.',
      'Hôm nay app đoán mình đang rất nhớ bạn.',
    ],
  ),
  _PartnerInteractionPreset(
    type: 'angry',
    label: 'Giận',
    emoji: '\u{1F63E}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_154.png',
    weight: 12,
    gradient: [Color(0xFFFFE6DC), Color(0xFFFFF6F2)],
    accent: Color(0xFFE26A3A),
    titles: [
      'Hơi dỗi bạn một xíu',
      'Tim báo động: đang giận nhẹ',
      'Người ta đang chờ được dỗ',
      'Có ai đó vừa hơi hờn',
    ],
    messages: [
      'Dỗ mình một câu là hết ngay đó.',
      'Giận yêu thôi nên đừng để lâu nha.',
      'App nói mình đang cần được bạn quan tâm thêm.',
      'Nhìn vậy thôi chứ thật ra vẫn chờ bạn dỗ đó.',
    ],
  ),
  _PartnerInteractionPreset(
    type: 'furious',
    label: 'Tức',
    emoji: '\u{1F621}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_049.png',
    weight: 7,
    showInSmartSuggestion: false,
    gradient: [Color(0xFFFFD7DC), Color(0xFFFFF1F3)],
    accent: Color(0xFFE53935),
    titles: [
      'Đang tức bạn thiệt đó',
      'Mặt đang hầm hầm chờ bạn dỗ',
      'Cục tức này đang đỏ rực luôn',
      'App báo mình đang tức bạn rồi đó',
    ],
    messages: [
      'Tức thật đó nha, qua dỗ mình liền đi 😡',
      'Mình đang hờn đỏ mặt luôn, ôm một cái mới hết.',
      'Đừng để cơn tức này kéo dài nha, mình chờ bạn đó.',
      'Tín hiệu tức giận đỏ rực vừa bay qua màn hình rồi đó.',
    ],
  ),
  _PartnerInteractionPreset(
    type: 'kiss',
    label: 'Hôn',
    emoji: '\u{1F48B}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_047.png',
    weight: 18,
    gradient: [Color(0xFFFFE1EC), Color(0xFFFFF7FA)],
    accent: Color(0xFFE14A8B),
    titles: [
      'Một nụ hôn bay tới bạn',
      'Chu môi một cái thật xinh',
      'Hôm nay muốn hôn bạn ghê',
      'Nụ hôn vừa được gửi đi',
    ],
    messages: [
      'Chụt một cái thật dịu dàng nha.',
      'Mong sớm được hôn bạn ngoài đời hơn.',
      'Nụ hôn này ngọt như lúc mình nhớ bạn vậy.',
      'Bắt lấy nụ hôn đang bay qua màn hình nhé.',
    ],
  ),
  _PartnerInteractionPreset(
    type: 'tease',
    label: 'Trêu',
    emoji: '\u{1F921}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_006.png',
    weight: 9,
    showInSmartSuggestion: false,
    gradient: [Color(0xFFE8E1FF), Color(0xFFF8F5FF)],
    accent: Color(0xFF7B61D9),
    titles: [
      'Trêu bạn một chút nha',
      'Có tín hiệu tinh nghịch vừa bay tới',
      'App rủ mình chọc bạn đó',
      'Một cú troll siêu nhẹ nhàng',
    ],
    messages: [
      'Đừng quạu, mình chỉ muốn bạn bật cười thôi.',
      'Nhận lấy tín hiệu nghịch ngợm từ mình nhé.',
      'Hôm nay mình muốn làm bạn cười hơn là làm bạn giận.',
      'Cảm xúc tinh nghịch vừa được gửi đến bạn đó.',
    ],
  ),
  _PartnerInteractionPreset(
    type: 'hug',
    label: 'Ôm',
    emoji: '\u{1F428}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_082.png',
    weight: 17,
    gradient: [Color(0xFFDDF3FF), Color(0xFFF5FBFF)],
    accent: Color(0xFF2D8FE3),
    titles: [
      'Muốn ôm bạn thật chặt',
      'Một cái ôm mềm đang tới',
      'Gửi bạn cảm giác an toàn',
      'Cái ôm hôm nay thật dịu',
    ],
    messages: [
      'Ôm một cái cho đỡ mệt nha.',
      'Nếu hôm nay hơi buồn thì tựa vào cái ôm này nhé.',
      'Mình muốn bạn thấy ấm áp ngay lúc này.',
      'Cứ xem đây là một chiếc ôm bỏ túi dành cho bạn.',
    ],
  ),
  _PartnerInteractionPreset(
    type: 'cry',
    label: 'Khóc',
    emoji: '\u{1F62D}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_089.png',
    weight: 8,
    showInSmartSuggestion: false,
    gradient: [Color(0xFFDDEBFF), Color(0xFFF4F8FF)],
    accent: Color(0xFF5B8DEF),
    titles: [
      'Hôm nay mình hơi muốn khóc',
      'Có một chiếc ôm đang rất cần',
      'Tim đang mềm xuống một chút',
      'Mình đang cần bạn dỗ dành',
    ],
    messages: [
      'Hôm nay mình hơi tủi một chút, dỗ mình nha.',
      'Chỉ muốn bạn ôm và nói một câu nhẹ thôi.',
      'Nếu bạn rảnh thì ghé qua xoa đầu mình một cái nhé.',
      'Cảm xúc hôm nay hơi mềm, mình cần bạn hơn một chút.',
    ],
  ),
  _PartnerInteractionPreset(
    type: 'poop',
    label: 'Troll',
    emoji: '\u{1F4A9}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_193.png',
    weight: 6,
    showInSmartSuggestion: false,
    gradient: [Color(0xFFFFE1B9), Color(0xFFFFF4E6)],
    accent: Color(0xFFB96B2C),
    titles: [
      'Ném bạn một cú troll nhẹ',
      'Icon này chỉ để chọc cười thôi',
      'App vừa xin phép trêu bạn một chút',
      'Coi như đây là trò đùa dễ thương nha',
    ],
    messages: [
      'Đừng giận, đây chỉ là một cú troll vô hại thôi.',
      'Nhận lấy chiếc icon troll nhỏ xíu từ mình nhé.',
      'Mình gửi bạn một cú troll để bạn bật cười đó.',
      'Chỉ là chọc nhẹ thôi nên cười cho mình một cái nha.',
    ],
  ),
];

const Duration _kInteractionSuggestionRefreshInterval = Duration(minutes: 2);
const int _kReactionThrowBurstLimit = 30;
const Duration _kReactionThrowWindow = Duration(seconds: 15);
const Duration _kReactionFlightMaxReplayAge = Duration(seconds: 45);
const Duration _kReactionFlightListenGrace = Duration(seconds: 5);
const int _kMaxVisibleReactionFlights = 24;
const Duration _kWeatherReverseGeocodeCacheTtl = Duration(hours: 6);
const int _kWeatherReverseGeocodeCacheMaxEntries = 24;
const Duration _kWeatherRefreshSkipTtl = Duration(minutes: 12);
const Duration _kWeatherDuplicateWriteSkipTtl = Duration(minutes: 45);

_PartnerInteractionPreset? _maybePresetForInteractionType(String type) {
  for (final item in _kPartnerInteractionPresets) {
    if (item.type == type) {
      return item;
    }
  }
  return null;
}

Widget _buildInteractionVisual({
  required dynamic visual,
  String? assetPath,
  required double size,
  double? emojiSize,
  Color? iconColor,
  BoxFit fit = BoxFit.contain,
  List<Shadow>? emojiShadows,
  bool preferAsset = true,
}) {
  final resolvedAssetPath = assetPath != null && assetPath.trim().isNotEmpty
      ? assetPath.trim()
      : (visual is String && visual.startsWith('assets/') ? visual : null);

  if (preferAsset && resolvedAssetPath != null) {
    return Image.asset(
      resolvedAssetPath,
      width: size,
      height: size,
      fit: fit,
      isAntiAlias: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _buildInteractionVisual(
        visual: visual,
        size: size,
        emojiSize: emojiSize,
        iconColor: iconColor,
        fit: fit,
        emojiShadows: emojiShadows,
        preferAsset: false,
      ),
    );
  }

  if (visual is IconData) {
    return Icon(
      visual,
      size: 55,
      color: iconColor ?? Colors.white,
    );
  }

  return Center(
    child: Text(
      visual?.toString() ?? '',
      style: TextStyle(
        fontSize: 40,
        height: 1,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        fontFamilyFallback: const [
          'Noto Color Emoji',
          'Apple Color Emoji',
          'Segoe UI Emoji',
        ],
      ),
    ),
  );
}

_PartnerInteractionPreset _presetForInteractionType(String type) {
  return _kPartnerInteractionPresets.firstWhere(
    (item) => item.type == type,
    orElse: () => _kPartnerInteractionPresets.first,
  );
}

_PartnerInteractionPreset _defaultSmartInteractionPreset() {
  for (final item in _kPartnerInteractionPresets) {
    if (item.showInSmartSuggestion) return item;
  }
  return _kPartnerInteractionPresets.first;
}

String _emojiForInteractionType(String type) {
  final preset = _maybePresetForInteractionType(type);
  if (preset != null) return preset.emoji;
  return switch (type) {
    'hot' => '\u{1F4A7}',
    'warmth' => '\u{1F9E3}',
    _ => '\u{1F496}',
  };
}

class _HomeReactionFlight {
  final String id;
  final String fromRole;
  final String toRole;
  final String emoji;
  final String assetPath;
  final int sentAtMs;

  const _HomeReactionFlight({
    required this.id,
    required this.fromRole,
    required this.toRole,
    required this.emoji,
    this.assetPath = '',
    required this.sentAtMs,
  });

  bool get shootToRight => fromRole == 'user1';
}
