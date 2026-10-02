/// Hợp đồng lựa chọn dùng chung cho cài đặt và đồng bộ widget Android.
abstract final class WidgetAppearance {
  static const heartStyles = <String>[
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '♥️',
    '❣️',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '💟',
    '❤️‍🔥',
    '❤️‍🩹',
    '💌',
    '💋',
    '🫶',
    '🫀',
    '💫💗',
    '✧♥︎',
    '❥∞',
    '🩷',
    '🩶',
    '🩵',
  ];
  static String normalizeHeart(String? value) {
    final key = (value ?? '').trim();
    return heartStyles.contains(key) ? key : '❤️';
  }

  static const stickerKeys = <String>[
    'none',
    'bears',
    'bunnies',
    'cats',
    'letter',
    'gift',
    'moon',
  ];
  static const photoFrameKeys = <String>['rounded', 'heart', 'polaroid'];
  static String normalizeSticker(String? key) =>
      stickerKeys.contains(key) ? key! : 'none';
  static String normalizePhotoFrame(String? key) =>
      photoFrameKeys.contains(key) ? key! : 'rounded';
}
