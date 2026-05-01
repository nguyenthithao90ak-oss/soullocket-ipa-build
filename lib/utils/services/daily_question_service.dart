import 'package:firebase_database/firebase_database.dart';

/// ============================================================
///  DailyQuestionService — GRA (Phase 33)
///  Câu Hỏi Hôm Nay — Daily Question Feature
///
///  Logic theo web gốc: feature-daily-question.js
///  - Câu hỏi xoay vòng theo ngày (index = day / 86400)
///  - Lưu trả lời vào: houses/{houseId}/daily_question/{YYYY-M-D}/{role}
///  - Cả hai phải trả lời xong mới hiện đáp án của nhau
/// ============================================================

class DailyQuestionService {
  static final DailyQuestionService _instance =
      DailyQuestionService._internal();
  factory DailyQuestionService() => _instance;
  DailyQuestionService._internal();

  final _db = FirebaseDatabase.instance;

  /// 25 câu hỏi xoay vòng — giống hệt web gốc
  static const List<String> _questions = [
    'Điều em/anh thích nhất ở mình là gì? 🥰',
    'Kỷ niệm đẹp nhất của hai mình là gì? 💕',
    'Nếu được đi du lịch 1 nơi cùng nhau, em/anh chọn đâu? ✈️',
    'Điều gì làm em/anh cảm thấy được yêu nhất? ❤️',
    'Hôm nay em/anh muốn ăn gì cho bữa tối? 🍜',
    'Bài hát nào em/anh muốn mình cùng nghe? 🎵',
    'Một điều ước dành cho hai mình là gì? 🌠',
    'Nếu ngày mai được nghỉ tự do, em/anh muốn làm gì? 🌈',
    'Phim nào em/anh muốn xem cùng mình gần đây? 🎬',
    'Món ăn nào em/anh đang thèm nhất lúc này? 🍕',
    'Siêu năng lực nào em/anh muốn có? 🦸',
    'Nếu mình là 1 loài động vật, em/anh nghĩ mình là con gì? 🐾',
    'Em/Anh thích mùa nào nhất? Tại sao? 🍂',
    'Điều gì khiến em/anh cười nhiều nhất hôm nay? 😂',
    'Điều em/anh lo lắng nhất lúc này là gì? Mình sẽ lắng nghe 🤗',
    'Ước mơ 5 năm tới của em/anh là gì? 🌟',
    'Điều gì em/anh muốn học cùng nhau? 📚',
    'Một điều em/anh chưa nói với mình nhưng muốn nói? 💌',
    'Khoảnh khắc nào gần đây em/anh cảm thấy hạnh phúc nhất? ✨',
    'Điều gì ở mình khiến em/anh tự hào? 🥹',
    'Hôm nay em/anh cảm thấy thế nào? (thật lòng nha) 💬',
    'Cuối tuần này mình làm gì nhỉ? 📅',
    'Gần đây em/anh có stress về điều gì không? 🫂',
    'Mình cần thay đổi thói quen gì để tốt hơn cho nhau? 🌱',
    'Điều em/anh muốn mình làm nhiều hơn là gì? 💡',
  ];

  // ─────────────────────────────────────────────────────────────
  // 1. LẤY CÂU HỎI HÔM NAY
  // ─────────────────────────────────────────────────────────────

  /// Lấy câu hỏi hôm nay dựa theo ngày (xoay vòng)
  String getTodayQuestion() {
    final dayIndex = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    return _questions[dayIndex % _questions.length];
  }

  /// Key ngày hôm nay dùng làm path Firebase (VD: "2026-3-26")
  String _getTodayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  // ─────────────────────────────────────────────────────────────
  // 2. LƯU & ĐỌC CÂU TRẢ LỜI
  // ─────────────────────────────────────────────────────────────

  /// Lưu câu trả lời của mình hôm nay
  /// role: 'user1' hoặc 'user2'
  Future<void> saveMyAnswer({
    required String houseId,
    required String role,
    required String myName,
    required String answer,
  }) async {
    if (answer.trim().isEmpty) return;
    final ref =
        _db.ref('houses/$houseId/daily_question/${_getTodayKey()}/$role');
    await ref.set({
      'text': answer.trim(),
      'ts': ServerValue.timestamp,
      'name': myName,
    });
  }

  /// Stream câu trả lời hôm nay (realtime — để khi người yêu trả lời thì hiện ngay)
  Stream<DailyQuestionState> streamTodayAnswers({
    required String houseId,
    required String myRole,
    required String myName,
    required String partnerRole,
    required String partnerName,
  }) {
    return _db
        .ref('houses/$houseId/daily_question/${_getTodayKey()}')
        .onValue
        .map((event) {
      final data = event.snapshot.exists
          ? Map<String, dynamic>.from(event.snapshot.value as Map)
          : <String, dynamic>{};

      DailyAnswer? myAnswer;
      DailyAnswer? partnerAnswer;

      if (data[myRole] != null) {
        final m = Map<String, dynamic>.from(data[myRole] as Map);
        myAnswer = DailyAnswer(
          name: m['name']?.toString() ?? myName,
          text: m['text']?.toString() ?? '',
          ts: (m['ts'] as num?)?.toInt() ?? 0,
        );
      }

      // Chỉ hiện câu trả lời của partner KHI mình đã trả lời rồi
      if (data[partnerRole] != null && myAnswer != null) {
        final p = Map<String, dynamic>.from(data[partnerRole] as Map);
        partnerAnswer = DailyAnswer(
          name: p['name']?.toString() ?? partnerName,
          text: p['text']?.toString() ?? '',
          ts: (p['ts'] as num?)?.toInt() ?? 0,
        );
      }

      return DailyQuestionState(
        question: getTodayQuestion(),
        myAnswer: myAnswer,
        partnerAnswer: partnerAnswer,
        partnerHasAnswered: data[partnerRole] != null,
      );
    });
  }

  /// Lấy 1 lần (không realtime)
  Future<DailyQuestionState> getTodayState({
    required String houseId,
    required String myRole,
    required String myName,
    required String partnerRole,
    required String partnerName,
  }) async {
    final snap =
        await _db.ref('houses/$houseId/daily_question/${_getTodayKey()}').get();

    final data = snap.exists
        ? Map<String, dynamic>.from(snap.value as Map)
        : <String, dynamic>{};

    DailyAnswer? myAns;
    DailyAnswer? partnerAns;

    if (data[myRole] != null) {
      final m = Map<String, dynamic>.from(data[myRole] as Map);
      myAns = DailyAnswer(
        name: m['name']?.toString() ?? myName,
        text: m['text']?.toString() ?? '',
        ts: (m['ts'] as num?)?.toInt() ?? 0,
      );
    }

    if (data[partnerRole] != null && myAns != null) {
      final p = Map<String, dynamic>.from(data[partnerRole] as Map);
      partnerAns = DailyAnswer(
        name: p['name']?.toString() ?? partnerName,
        text: p['text']?.toString() ?? '',
        ts: (p['ts'] as num?)?.toInt() ?? 0,
      );
    }

    return DailyQuestionState(
      question: getTodayQuestion(),
      myAnswer: myAns,
      partnerAnswer: partnerAns,
      partnerHasAnswered: data[partnerRole] != null,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. LỊCH SỬ CÂU TRẢ LỜI (7 ngày gần nhất)
  // ─────────────────────────────────────────────────────────────

  Future<List<DailyQuestionHistory>> getRecentHistory({
    required String houseId,
    int days = 7,
  }) async {
    final results = <DailyQuestionHistory>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';
      final dayIndex = d.millisecondsSinceEpoch ~/ 86400000;
      final question = _questions[dayIndex % _questions.length];

      try {
        final snap = await _db.ref('houses/$houseId/daily_question/$key').get();
        if (!snap.exists) continue;

        final data = Map<String, dynamic>.from(snap.value as Map);
        results.add(DailyQuestionHistory(
          dateKey: key,
          question: question,
          answers: data.map((k, v) {
            final m = Map<String, dynamic>.from(v as Map);
            return MapEntry(
              k.toString(),
              DailyAnswer(
                name: m['name']?.toString() ?? k.toString(),
                text: m['text']?.toString() ?? '',
                ts: (m['ts'] as num?)?.toInt() ?? 0,
              ),
            );
          }),
        ));
      } catch (_) {}
    }

    return results;
  }
}

// ─── MODELS ─────────────────────────────────────────────────────────────────

class DailyAnswer {
  final String name;
  final String text;
  final int ts;

  DailyAnswer({required this.name, required this.text, required this.ts});
}

class DailyQuestionState {
  final String question;
  final DailyAnswer? myAnswer;
  final DailyAnswer? partnerAnswer;
  final bool partnerHasAnswered;

  bool get iAnswered => myAnswer != null;
  bool get bothAnswered => myAnswer != null && partnerAnswer != null;

  DailyQuestionState({
    required this.question,
    this.myAnswer,
    this.partnerAnswer,
    required this.partnerHasAnswered,
  });
}

class DailyQuestionHistory {
  final String dateKey;
  final String question;
  final Map<String, DailyAnswer> answers;

  DailyQuestionHistory({
    required this.dateKey,
    required this.question,
    required this.answers,
  });
}
