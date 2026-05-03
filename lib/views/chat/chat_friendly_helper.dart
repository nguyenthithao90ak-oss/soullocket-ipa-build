import 'dart:math';

class ChatFriendlyHelper {
  static const List<String> greetings = [
    'Chào bạn nhé! Chúc bạn một ngày thật tuyệt vời! 🌟',
    'Hí chào bạn! Rất vui được gặp lại bạn. 👋',
    'Chào bạn! SoulLocket luôn ở đây cùng bạn nè. ✨',
    'Chào buổi sáng/trưa/tối tốt lành nhé bạn yêu! 🌈',
    'Hello! Chúc bạn luôn ngập tràn niềm vui và hạnh phúc. ❤️',
  ];

  static const List<String> wishes = [
    'Chúc bạn luôn xinh đẹp, yêu đời và gặp nhiều may mắn! 🍀',
    'Mong mọi điều tốt đẹp nhất sẽ đến với bạn trong hôm nay. 🌻',
    'Chúc bạn có những phút giây thật thư giãn và ý nghĩa. ☕',
    'Mãi rạng rỡ và tự tin như thế này nhé! 🌸',
    'Chúc bạn ngủ ngon và có những giấc mơ thật đẹp. 🌙',
  ];

  static const List<String> encouragements = [
    'Bạn đang làm rất tốt rồi, cố gắng lên nhé! 💪',
    'Mọi chuyện rồi sẽ ổn thôi, đừng lo lắng quá nha. 🤗',
    'Hãy luôn tin tưởng vào bản thân mình, bạn tuyệt vời lắm! 💎',
    'Đừng quên dành thời gian yêu thương chính mình nhé. ❤️',
    'Cố gắng một chút nữa thôi, thành công đang đợi bạn phía trước. 🚀',
  ];

  static const List<String> offlineResponses = [
    'Hiện tại mình đang offline, nhưng đừng lo, mình vẫn luôn quan tâm bạn! 🧸',
    'Kết nối hơi gián đoạn một chút, nhưng tình cảm của mình vẫn đầy đủ nè. 📶❤️',
    'Mạng hơi yếu nhưng lời chúc của mình dành cho bạn vẫn cực mạnh nha! ✨',
    'Dù mất kết nối, nhưng mình vẫn muốn gửi tới bạn một cái ôm thật ấm. 🫂',
    'Chờ một lát mạng ổn định lại rồi chúng mình tiếp tục trò chuyện nhé! ⏳',
  ];

  static const Map<String, List<String>> qaPairs = {
    'mật khẩu|pass': [
      'Để bảo vệ bạn, mình không thể xem hay đổi mật khẩu giúp bạn được. Bạn vào mục "Cài đặt" -> "Bảo mật" để tự quản lý nhé! 🔒',
      'Bạn muốn đổi mật khẩu à? Hãy vào phần thiết lập Bảo mật trong app để thực hiện an toàn nhất nha. 🛡️',
    ],
    'buồn|chán|mệt': [
      'Mình ở đây nghe bạn tâm sự nè. Hít một hơi thật sâu, mọi chuyện rồi sẽ ổn thôi mà. 🤗',
      'Đừng buồn nữa nha, bạn tuyệt vời hơn bạn nghĩ nhiều đó. Gửi tới bạn một cái ôm thật chặt! 🫂',
      'Nếu mệt quá thì nghỉ ngơi một chút nhé. SoulLocket luôn là nơi bình yên dành cho bạn. ✨',
    ],
    'yêu|thích': [
      'Tình yêu là điều kỳ diệu nhất thế gian. Mong bạn và người ấy luôn hạnh phúc bên nhau! ❤️',
      'Yêu thương chính mình cũng quan trọng lắm đó. Hãy luôn rạng rỡ như thế nhé! 🌸',
    ],
    'tên|là ai': [
      'Mình là Trợ lý thân thiện của SoulLocket, rất vui được bầu bạn cùng bạn! 🤖💖',
      'Bạn cứ gọi mình là bạn đồng hành nhé, mình luôn ở đây để lắng nghe bạn. ✨',
    ],
    'định vị|bản đồ|vị trí': [
      'Tính năng Bản đồ giúp bạn và người ấy luôn thấy nhau. Đừng quên cấp quyền vị trí để hoạt động chính xác nha! 📍',
      'Bạn có thể ghim những kỷ niệm đẹp trên bản đồ để lưu giữ khoảnh khắc của hai người đó. 🗺️✨',
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
