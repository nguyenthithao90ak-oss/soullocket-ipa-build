import 'package:firebase_database/firebase_database.dart';

/// ============================================================
///  MiniGamesService — GRA (Phase 40)
///  Mini Games & Entertainment (Store, Quiz, Custom Events)
///
///  Logic theo web gốc: core-entertainment.js
///  - Câu đố cặp đôi (Quiz)
///  - Cửa hàng điểm thưởng (Store)
///  - Game Who Is (Ai là người...)
/// ============================================================

class MiniGamesService {
  static final MiniGamesService _instance = MiniGamesService._internal();
  factory MiniGamesService() => _instance;
  MiniGamesService._internal();

  final _db = FirebaseDatabase.instance;

  // ─────────────────────────────────────────────────────────────
  // 1. GAME: Câu Đố Ai Là Người (Who Is)
  // ─────────────────────────────────────────────────────────────

  static const List<String> _whoIsQuestions = [
    'Ai hay dỗi hơn?',
    'Ai ăn nhiều hơn?',
    'Ai ngủ nướng hơn?',
    'Ai chủ động làm quen trước?',
    'Ai lãng mạn hơn?',
    'Ai hay quên hơn?',
    'Ai nấu ăn ngon hơn?',
    'Ai bừa bộn hơn?',
    'Ai chi tiêu tiết kiệm hơn?',
    'Ai hay ghen hơn?'
  ];

  /// Set câu hỏi mới
  Future<void> nextWhoIsQuestion(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final q = (List<String>.from(_whoIsQuestions)..shuffle()).first;
    await _db.ref('houses/$normalizedHouseId/game_whois').update({
      'question': q,
      'ans_u1': null,
      'ans_u2': null,
    });
  }

  /// Trả lời câu hỏi
  Future<WhoIsResult?> answerWhoIs({
    required String houseId,
    required String myRole, // 'u1' or 'u2'
    required String answer,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedRole = myRole.trim();
    final normalizedAnswer = answer.trim();
    if (normalizedHouseId.isEmpty ||
        (normalizedRole != 'u1' && normalizedRole != 'u2') ||
        normalizedAnswer.isEmpty) {
      return null;
    }
    await _db
        .ref('houses/$normalizedHouseId/game_whois/ans_$normalizedRole')
        .set(normalizedAnswer);

    // Kiểm tra xem đã đủ 2 người trả lời chưa
    final snap = await _db.ref('houses/$normalizedHouseId/game_whois').get();
    if (!snap.exists || snap.value is! Map) return null;

    final data = Map<String, dynamic>.from(snap.value as Map);
    final a1 = data['ans_u1']?.toString();
    final a2 = data['ans_u2']?.toString();

    if (a1 != null && a2 != null) {
      final isMatch = a1 == a2;

      // Tự xoá câu trả lời sau 3 giây (nhưng Flutter có thể tự quản lý state này)
      Future.delayed(const Duration(seconds: 3), () {
        _db.ref('houses/$normalizedHouseId/game_whois/ans_u1').remove();
        _db.ref('houses/$normalizedHouseId/game_whois/ans_u2').remove();
      });

      return WhoIsResult(isMatch: isMatch, a1: a1, a2: a2);
    }

    return null; // Đang chờ người kia
  }

  /// Stream state game realtime
  Stream<WhoIsState> streamWhoIsState(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<WhoIsState>.value(WhoIsState(question: ''));
    return _db.ref('houses/$normalizedHouseId/game_whois').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return WhoIsState(question: '');
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return WhoIsState(
        question: data['question']?.toString() ?? '',
        ansU1: data['ans_u1']?.toString(),
        ansU2: data['ans_u2']?.toString(),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 2. COUPLE QUIZ (Người Hỏi, Người Trả Lời)
  // ─────────────────────────────────────────────────────────────

  Future<void> createQuiz({
    required String houseId,
    required String askerName,
    required String question,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedQuestion = question.trim();
    if (normalizedHouseId.isEmpty || normalizedQuestion.isEmpty) return;
    await _db.ref('houses/$normalizedHouseId/quiz').push().set({
      'q': normalizedQuestion,
      'asker': askerName.trim(),
      'a1': '',
      'a2': '',
      'ts': ServerValue.timestamp,
    });
  }

  Future<void> answerQuiz({
    required String houseId,
    required String quizId,
    required String myRole, // 'user1' or 'user2'
    required String answer,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedQuizId = quizId.trim();
    final normalizedAnswer = answer.trim();
    final normalizedRole = myRole.trim();
    if (normalizedHouseId.isEmpty ||
        normalizedQuizId.isEmpty ||
        (normalizedRole != 'user1' && normalizedRole != 'user2')) {
      return;
    }
    final field = normalizedRole == 'user1' ? 'a1' : 'a2';
    await _db
        .ref('houses/$normalizedHouseId/quiz/$normalizedQuizId')
        .update({field: normalizedAnswer});
  }

  Stream<List<QuizData>> streamQuizzes(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<List<QuizData>>.value(const []);
    return _db
        .ref('houses/$normalizedHouseId/quiz')
        .orderByChild('ts')
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return [];
      final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;

      final res = <QuizData>[];
      map.forEach((k, v) {
        if (v is! Map) return;
        final data = Map<String, dynamic>.from(v);
        final ts = _asTimestamp(data['ts']);

        // Auto remove items older than 24h
        if (now - ts > 86400000) {
          _db.ref('houses/$normalizedHouseId/quiz/$k').remove();
          return;
        }
        data['id'] = k.toString();
        res.add(QuizData.fromMap(data));
      });
      res.sort((a, b) => b.ts.compareTo(a.ts));
      return res;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 3. STORE (Đổi điểm thành hành động)
  // ─────────────────────────────────────────────────────────────

  Future<bool> buyStoreItem({
    required String houseId,
    required String itemName,
    required int cost,
    required String buyerName,
    required int currentPoints,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedItemName = itemName.trim();
    final normalizedBuyerName = buyerName.trim();
    if (normalizedHouseId.isEmpty ||
        normalizedItemName.isEmpty ||
        normalizedBuyerName.isEmpty ||
        cost <= 0 ||
        currentPoints < cost) {
      return false;
    }

    // Trừ điểm và lưu lịch sử đổi đồ
    await _db.ref('houses/$normalizedHouseId/points').runTransaction((currentData) {
      int pts = 0;
      if (currentData is num) {
        pts = currentData.toInt();
      } else if (currentData != null) {
        pts = int.tryParse(currentData.toString()) ?? 0;
      }

      if (pts < cost) return Transaction.abort();
      return Transaction.success(pts - cost);
    });

    // Lưu vào store history
    await _db.ref('houses/$normalizedHouseId/store').push().set({
      'it': normalizedItemName,
      'c': cost,
      'a': normalizedBuyerName,
      'ts': ServerValue.timestamp,
      'time': DateTime.now().toIso8601String(),
    });

    return true;
  }
  int _asTimestamp(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ─── MODELS ─────────────────────────────────────────────────────────────────

class WhoIsResult {
  final bool isMatch;
  final String a1;
  final String a2;
  WhoIsResult({required this.isMatch, required this.a1, required this.a2});
}

class WhoIsState {
  final String question;
  final String? ansU1;
  final String? ansU2;
  WhoIsState({required this.question, this.ansU1, this.ansU2});
}

class QuizData {
  final String id;
  final String question;
  final String asker;
  final String? ansU1;
  final String? ansU2;
  final int ts;

  QuizData({
    required this.id,
    required this.question,
    required this.asker,
    this.ansU1,
    this.ansU2,
    required this.ts,
  });

  factory QuizData.fromMap(Map<String, dynamic> map) {
    return QuizData(
      id: map['id']?.toString() ?? '',
      question: map['q']?.toString() ?? '',
      asker: map['asker']?.toString() ?? '',
      ansU1:
          map['a1']?.toString().isEmpty ?? true ? null : map['a1']?.toString(),
      ansU2:
          map['a2']?.toString().isEmpty ?? true ? null : map['a2']?.toString(),
      ts: _asTimestamp(map['ts']),
    );
  }
}

int _asTimestamp(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
