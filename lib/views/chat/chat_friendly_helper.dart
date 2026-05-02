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

  static String getRandom(List<String> list) {
    return list[Random().nextInt(list.length)];
  }

  static String getFriendlyResponse({bool isOffline = false}) {
    if (isOffline) {
      return getRandom(offlineResponses);
    }
    
    final all = [...greetings, ...wishes, ...encouragements];
    return getRandom(all);
  }
}
