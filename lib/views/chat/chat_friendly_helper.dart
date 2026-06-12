import 'dart:math';

import '../../utils/services/l10n_service.dart';

class ChatFriendlyHelper {
  static List<String> get greetings => [
    L10nService().translate('chat_friendly_00'),
    L10nService().translate('chat_friendly_01'),
    L10nService().translate('chat_friendly_02'),
    L10nService().translate('chat_friendly_03'),
    L10nService().translate('chat_friendly_04'),
  ];

  static List<String> get wishes => [
    L10nService().translate('chat_friendly_05'),
    L10nService().translate('chat_friendly_06'),
    L10nService().translate('chat_friendly_07'),
    L10nService().translate('chat_friendly_08'),
    L10nService().translate('chat_friendly_09'),
  ];

  static List<String> get encouragements => [
    L10nService().translate('chat_friendly_10'),
    L10nService().translate('chat_friendly_11'),
    L10nService().translate('chat_friendly_12'),
    L10nService().translate('chat_friendly_13'),
    L10nService().translate('chat_friendly_14'),
  ];

  static List<String> get offlineResponses => [
    L10nService().translate('chat_friendly_15'),
    L10nService().translate('chat_friendly_16'),
    L10nService().translate('chat_friendly_17'),
    L10nService().translate('chat_friendly_18'),
    L10nService().translate('chat_friendly_19'),
  ];

  static Map<String, List<String>> get qaPairs => {
    'mật khẩu|pass': [
      L10nService().translate('chat_friendly_20'),
      L10nService().translate('chat_friendly_21'),
    ],
    'buồn|chán|mệt': [
      L10nService().translate('chat_friendly_22'),
      L10nService().translate('chat_friendly_23'),
      L10nService().translate('chat_friendly_24'),
    ],
    'yêu|thích': [
      L10nService().translate('chat_friendly_25'),
      L10nService().translate('chat_friendly_26'),
    ],
    'tên|là ai': [
      L10nService().translate('chat_friendly_27'),
      L10nService().translate('chat_friendly_28'),
    ],
    'định vị|bản đồ|vị trí': [
      L10nService().translate('chat_friendly_29'),
      L10nService().translate('chat_friendly_30'),
    ],
  };

  static String getRandom(List<String> list) {
    return list[Random().nextInt(list.length)];
  }

  static String findPredefinedResponse(String text) {
    final lowerText = text.toLowerCase();
    for (final entry in qaPairs.entries) {
      final keys = entry.key.split('|');
      if (keys.any((k) => lowerText.contains(k))) {
        return getRandom(entry.value);
      }
    }
    return '';
  }

  static String getFriendlyResponse({
    String? userText,
    bool isOffline = false,
  }) {
    // 1. Ưu tiên tìm trong danh sách thiết lập nếu có text
    if (userText != null && userText.isNotEmpty) {
      final predefined = findPredefinedResponse(userText);
      if (predefined.isNotEmpty) return predefined;
    }

    // 2. Nếu offline và không khớp câu hỏi, dùng câu offline ngẫu nhiên
    if (isOffline) {
      return getRandom(offlineResponses);
    }

    // 3. Mặc định trả về câu ngẫu nhiên vui vẻ
    final all = [...greetings, ...wishes, ...encouragements];
    return getRandom(all);
  }
}
