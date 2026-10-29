/// Hợp đồng lựa chọn dùng chung cho cài đặt và đồng bộ widget Android.
abstract final class WidgetAppearance {
  /// Các mốc đổi mẫu được hỗ trợ trên cả Flutter, Android và iOS.
  /// Mặc định 5 phút để vẫn có cảm giác sống động mà không đánh thức widget
  /// quá thường xuyên.
  static const motionIntervalOptions = <int>[1, 5, 15, 30];
  static const iosMotionIntervalOptions = <int>[5, 15, 30];
  static const defaultMotionIntervalMinutes = 5;

  static int normalizeMotionInterval(int? value, {bool isIos = false}) {
    if (value == null) return defaultMotionIntervalMinutes;
    final options = isIos ? iosMotionIntervalOptions : motionIntervalOptions;
    return options.contains(value)
        ? value
        : defaultMotionIntervalMinutes;
  }

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

  /// Xáo trộn từng vòng để dùng đủ bộ và không lặp hai mẫu liên tiếp.
  /// Cùng tick luôn cho cùng mẫu, kể cả khi widget được dựng lại.
  static T motionItemForTick<T>(
    List<T> items,
    int tick, {
    int seed = 0,
  }) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must not be empty');
    }
    if (items.length == 1) return items.first;
    final safeTick = tick < 0 ? 0 : tick;
    final count = items.length;
    if (count == 2) return items[(safeTick + (seed & 1)) % count];
    final cycle = safeTick ~/ count;
    final order = _motionOrder(cycle, seed, count);
    // Với >= 3 mẫu, đổi hai phần tử đầu không làm đổi phần tử cuối vòng.
    if (cycle > 0 && order.first == _motionOrder(cycle - 1, seed, count).last) {
      final first = order[0];
      order[0] = order[1];
      order[1] = first;
    }
    return items[order[safeTick % count]];
  }

  static List<int> _motionOrder(int cycle, int seed, int count) {
    // Giữ phép nhân trong miền số nguyên chính xác cả trên Dart Web.
    var state = ((cycle & 0x7fffffff) * 1664525 +
            (seed & 0x7fffffff) * 12345 +
            1013904223) &
        0x7fffffff;
    final order = List<int>.generate(count, (index) => index);
    for (var index = count - 1; index > 0; index--) {
      state = (state * 1664525 + 1013904223) & 0x7fffffff;
      final other = state % (index + 1);
      final value = order[index];
      order[index] = order[other];
      order[other] = value;
    }
    return order;
  }

  static String animatedHeartForTick(int tick, {int seed = 0}) =>
      motionItemForTick(heartStyles, tick, seed: seed);

  static String animatedStickerForTick(int tick, {int seed = 0}) =>
      motionItemForTick(
        stickerKeys.where((key) => key != 'none').toList(growable: false),
        tick,
        seed: seed,
      );
}
