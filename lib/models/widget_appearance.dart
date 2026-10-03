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
  // Giữ khóa emoji đã lưu; hình vẽ không phụ thuộc bộ font của Android.
  static const heartArtworkKeys = <String, String>{
    '❤️': 'red',
    '🧡': 'orange',
    '💛': 'gold',
    '💚': 'green',
    '💙': 'blue',
    '💜': 'purple',
    '🖤': 'black',
    '🤍': 'white',
    '🤎': 'brown',
    '♥️': 'classic',
    '❣️': 'exclamation',
    '💕': 'pair',
    '💞': 'orbit',
    '💓': 'beat',
    '💗': 'growing',
    '💖': 'sparkle',
    '💘': 'arrow',
    '💝': 'gift',
    '💟': 'badge',
    '❤️‍🔥': 'flame',
    '❤️‍🩹': 'healing',
    '💌': 'letter',
    '💋': 'kiss',
    '🫶': 'hands',
    '🫀': 'anatomical',
    '💫💗': 'comet',
    '✧♥︎': 'outline',
    '❥∞': 'infinity',
    '🩷': 'pink',
    '🩶': 'gray',
    '🩵': 'cyan',
  };
  static const coloredHearts = <String>[
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '🩷',
    '🩶',
    '🩵',
  ];
  static String heartArtworkKey(String? key) =>
      heartArtworkKeys[normalizeHeart(key)]!;

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
