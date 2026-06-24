import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// LoveWishService — quản lý stickers + câu chúc local
/// Không lưu server, chỉ dùng SharedPreferences.
class LoveWishService {
  static final LoveWishService _instance = LoveWishService._internal();
  factory LoveWishService() => _instance;
  LoveWishService._internal();

  static const String _kTodayWishKey = 'il_love_wish_today';
  static const String _kTodayWishDateKey = 'il_love_wish_date';
  static const String _kFavWishKey = 'il_love_wish_favorites';

  static const List<String> _loveWishes = [
    'Cảm ơn em vì đã đến và ở lại. 💖',
    'Mỗi ngày bên anh đều là một ngày đẹp nhất. 🌸',
    'Yêu em nhiều hơn ngày hôm qua, ít hơn ngày mai. 💕',
    'Có em là có tất cả. 🏠',
    'Đi đâu cũng chỉ nhớ về nhà thôi. 🏡',
    'Cả thế giới này anh chỉ cần mỗi em. 🌍',
    'Mình già đi cùng nhau nhé. 👴👵',
    'Nụ cười của em là điều anh muốn giữ mãi. 😊',
    'Yêu nhau không cần sang trọng, chỉ cần đủ đầy tiếng cười. 🥰',
    'Có em, ngày nào cũng là Valentine. 💝',
    'Hai đứa mình là định mệnh. 🌟',
    'Nắm tay nhau đi hết cuộc đời. 🤝',
    'Em là giấc mơ anh không muốn tỉnh. 🌙',
    'Trái tim anh chỉ thuộc về một người thôi. 💗',
    'Mỗi ngày thức dậy thấy em cạnh bên là đủ. ☀️',
    'Thương em nhiều lắm, không biết nói sao cho hết. 💌',
    'Hai đứa mình là nhất! 🏆',
    'Cảm ơn cuộc đời đã cho ta gặp nhau. 🙏',
    'Bên em anh chẳng cần gì hơn. 🥹',
    'Nhìn em cười là anh thấy hạnh phúc rồi. 😄',
    'Cùng nhau viết tiếp câu chuyện của đôi mình nhé. 📖',
    'Yêu thương không toan tính. 💫',
    'Dù già hay trẻ, anh vẫn chỉ yêu mỗi em. 💘',
    'Chúng mình là gia đình. 👨‍👩‍👧‍👦',
    'Em là phần đẹp nhất trong cuộc đời anh. 🌺',
    'Ngày nào cũng muốn nói yêu em. 💋',
    'Yêu anh không? — Có. 🫶',
    'Người yêu em cũng là bạn thân của em. 🫂',
    'Mình sinh ra là dành cho nhau. 🎀',
    'Chỉ cần em hạnh phúc, anh vui rồi. 😌',
    'Có nhau là đủ qua mọi sóng gió. ⛵',
    'Tụi mình như hình với bóng. 👥',
    'Kề vai nhau đi qua mọi thăng trầm. 🫂',
    'Anh yêu em! Đơn giản vậy thôi. 💖',
    'Mỗi ngày trôi qua đều có em là tuyệt nhất. ✨',
    'Cảm ơn em vì đã kiên nhẫn với anh. 🥺',
    'Em là điều tuyệt vời nhất từng xảy ra với anh. 🌈',
    'Hai đứa ngốc yêu nhau. 🤪',
    'Giữa hàng triệu người, anh chỉ thấy em. 👁️',
    'Cùng nhau làm người già hạnh phúc nhất nhé. 👵💕👴',
    'Yêu em từ cái nhìn đầu tiên. 👀',
    'Mỗi ngày anh lại yêu em nhiều hơn. 📈',
    'Sống tốt, yêu thật, cười nhiều. 🌻',
    'Em là món quà anh trân trọng nhất. 🎁',
    'Bên nhau là mãi mãi. ♾️',
    'Cùng nhau xây tổ ấm nhé. 🐦',
    'Khi có em, anh chẳng sợ điều gì. 🦸',
    'Em là điểm tựa của anh. ⚓',
    'Hai đứa mình là team ngọt ngào nhất. 🍯',
    'Anh thích cả cái cách em càm ràm nữa. 😅',
    'Có đôi khi im lặng, nhưng lúc nào cũng nghĩ về em. 💭',
    'Happy day với em. 🌤️',
    'Hạnh phúc là khi có em kề bên. 🫶',
    'We belong together. 🎵',
    'I love you through the good and the bad. 🌪️',
    'You are my sunshine. ☀️',
    'My soulmate. 💫',
    'Everything reminds me of you. 🍃',
    'I choose you. Every day. ✅',
    'You\'re my home. 🏠',
    'Love you more. ❤️',
    'Stay with me forever. 🔒',
    'You\'re my favorite notification. 📱',
    'I like you a latte. ☕',
    'You\'re the best thing that\'s ever been mine. 👑',
    'I\'d pick you every time. 🔁',
    'You\'re my person. 👫',
    'Forever isn\'t long enough. ⏳',
  ];

  final Random _random = Random();

  /// Lấy câu chúc hôm nay (theo ngày, không random lại)
  Future<String> getTodayWish() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_kTodayWishDateKey) ?? '';
    if (savedDate == today) {
      return prefs.getString(_kTodayWishKey) ?? _loveWishes.first;
    }
    final wish = _loveWishes[_random.nextInt(_loveWishes.length)];
    await prefs.setString(_kTodayWishKey, wish);
    await prefs.setString(_kTodayWishDateKey, today);
    return wish;
  }

  /// Lấy câu chúc random
  Future<String> getRandomWish() async {
    return _loveWishes[_random.nextInt(_loveWishes.length)];
  }

  /// Thêm câu chúc vào danh sách yêu thích
  Future<void> addFavoriteWish(String wish) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kFavWishKey) ?? [];
    if (!list.contains(wish)) {
      list.add(wish);
      await prefs.setStringList(_kFavWishKey, list);
    }
  }

  /// Lấy danh sách yêu thích
  Future<List<String>> getFavoriteWishes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kFavWishKey) ?? [];
  }

  /// Xoá câu chúc yêu thích
  Future<void> removeFavoriteWish(String wish) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kFavWishKey) ?? [];
    list.remove(wish);
    await prefs.setStringList(_kFavWishKey, list);
  }
}
