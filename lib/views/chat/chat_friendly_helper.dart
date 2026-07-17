import 'dart:math';



class ChatFriendlyHelper {
  static List<String> get greetings => [
        'Chào bạn nha! Hôm nay có chuyện gì vui kể mình nghe với?',
        'Xin chào! Cần tâm sự gì cứ nói với mình nhé.',
        'Hi bạn! Mình luôn ở đây để lắng nghe nè.',
      ];

  static List<String> get wishes => [
        'Chúc bạn một ngày thật vui vẻ và nhiều năng lượng nha!',
        'Ngủ ngon và có những giấc mơ đẹp nhé!',
      ];

  static List<String> get encouragements => [
        'Đừng buồn nhé, mọi chuyện rồi sẽ ổn thôi!',
        'Bạn làm tốt lắm, hãy cứ tự tin lên nha!',
        'Cố lên bạn nhé, mình luôn ủng hộ bạn!',
      ];

  static List<String> get offlineResponses => [
        'Mạng có vẻ yếu quá, mình chưa nghe rõ bạn nói gì. Bạn kiểm tra lại wifi 3G nhé!',
        'Hình như mất kết nối rồi, bạn gửi lại tin nhắn giúp mình nha.',
        'Mình đang bị rớt mạng một chút, bạn chờ xíu rồi nói lại nha.',
      ];

  static Map<String, List<String>> get qaPairs => {
        'mật khẩu|pass': [
          'Nếu bạn quên mật khẩu, hãy vào Cài đặt và chọn Quên mật khẩu nhé.',
        ],
        'buồn|chán|mệt': [
          'Thương quá! Đừng buồn nữa nha, đi ăn món gì ngon ngon cho đỡ mệt nhé.',
          'Mọi chuyện rồi sẽ qua thôi, bạn hãy nghỉ ngơi một chút nha.',
        ],
        'yêu|thích': [
          'Yêu thương luôn là điều tuyệt vời nhất! Hai bạn hãy luôn hạnh phúc nhé 💕',
          'Nghe lãng mạn quá! Chúc hai bạn mãi mặn nồng nha.',
        ],
        'tên|là ai': [
          'Mình là Trợ lý AI của SoulLocket, luôn sẵn sàng lắng nghe bạn đây!',
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
