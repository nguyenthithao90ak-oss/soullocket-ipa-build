import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'intimacy_service.dart';

class DeepTalkQuestion {
  final int id;
  final String text;
  final String category;
  final String emoji;

  const DeepTalkQuestion({
    required this.id,
    required this.text,
    required this.category,
    required this.emoji,
  });
}

class DeepTalkDayRecord {
  final String dateKey;
  final int questionId;
  final String questionText;
  final String category;
  final String emoji;
  final String? u1Answer;
  final int? u1AnswerTs;
  final String? u2Answer;
  final int? u2AnswerTs;
  final bool isUnlocked;

  const DeepTalkDayRecord({
    required this.dateKey,
    required this.questionId,
    required this.questionText,
    required this.category,
    required this.emoji,
    this.u1Answer,
    this.u1AnswerTs,
    this.u2Answer,
    this.u2AnswerTs,
    required this.isUnlocked,
  });

  bool hasAnswered(String role) {
    if (role == 'user1') return u1Answer != null && u1Answer!.trim().isNotEmpty;
    return u2Answer != null && u2Answer!.trim().isNotEmpty;
  }

  String? myAnswer(String role) => role == 'user1' ? u1Answer : u2Answer;
  String? partnerAnswer(String role) => role == 'user1' ? u2Answer : u1Answer;

  bool partnerHasAnswered(String role) {
    if (role == 'user1') return u2Answer != null && u2Answer!.trim().isNotEmpty;
    return u1Answer != null && u1Answer!.trim().isNotEmpty;
  }
}

class DeepTalkService {
  static final DeepTalkService _instance = DeepTalkService._internal();
  factory DeepTalkService() => _instance;
  DeepTalkService._internal();

  static DeepTalkService get instance => _instance;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  static const List<DeepTalkQuestion> questionBank = [
    DeepTalkQuestion(
      id: 1,
      text: 'Khoảnh khắc nào ở bên nhau làm bạn cảm thấy bình yên và rung động nhất?',
      category: 'Kỷ niệm',
      emoji: '🌸',
    ),
    DeepTalkQuestion(
      id: 2,
      text: 'Nếu được đi du lịch bất cứ đâu ngay ngày mai, bạn muốn cùng người ấy đến đâu?',
      category: 'Tương lai',
      emoji: '✈️',
    ),
    DeepTalkQuestion(
      id: 3,
      text: 'Thói quen nhỏ nào của người ấy khiến bạn thấy vừa đáng yêu vừa thương?',
      category: 'Thấu hiểu',
      emoji: '🥰',
    ),
    DeepTalkQuestion(
      id: 4,
      text: 'Bài hát nào mỗi khi nghe là bạn lại nhớ ngay đến người ấy?',
      category: 'Âm nhạc & Ký ức',
      emoji: '🎵',
    ),
    DeepTalkQuestion(
      id: 5,
      text: 'Điều ước lớn nhất của bạn dành cho mối quan hệ của hai đứa trong năm nay là gì?',
      category: 'Ước mơ',
      emoji: '✨',
    ),
    DeepTalkQuestion(
      id: 6,
      text: 'Món ăn nào do người ấy nấu hoặc hai đứa cùng ăn làm bạn nhớ mãi không quên?',
      category: 'Ẩm thực & Yêu thương',
      emoji: '🍲',
    ),
    DeepTalkQuestion(
      id: 7,
      text: 'Lần đầu tiên nhìn thấy người ấy, ấn tượng đầu tiên trong đầu bạn là gì?',
      category: 'Lần đầu gặp gỡ',
      emoji: '👀',
    ),
    DeepTalkQuestion(
      id: 8,
      text: 'Khi bạn buồn, một cái ôm hay một lời động viên từ người ấy làm bạn thấy nhẹ lòng hơn?',
      category: 'Tâm sự',
      emoji: '🫂',
    ),
    DeepTalkQuestion(
      id: 9,
      text: 'Nếu hai đứa cùng nuôi một chú thú cưng, bạn muốn đặt tên bé là gì?',
      category: 'Tương lai',
      emoji: '🐾',
    ),
    DeepTalkQuestion(
      id: 10,
      text: 'Ba từ ngắn gọn nhất mà bạn muốn dùng để miêu tả về người ấy là gì?',
      category: 'Chân thành',
      emoji: '💖',
    ),
    DeepTalkQuestion(
      id: 11,
      text: 'Kỷ niệm buồn cười hoặc ngốc nghếch nhất của hai đứa làm bạn bật cười khi nghĩ lại?',
      category: 'Kỷ niệm vui',
      emoji: '😆',
    ),
    DeepTalkQuestion(
      id: 12,
      text: 'Điều gì người ấy từng làm khiến bạn cảm thấy mình được trân trọng và yêu thương vô điều kiện?',
      category: 'Cảm xúc',
      emoji: '💌',
    ),
  ];

  static DeepTalkQuestion getQuestionForDate(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final index = dayOfYear % questionBank.length;
    return questionBank[index];
  }

  static String dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Stream<DeepTalkDayRecord> streamTodayDeepTalk(String houseId) {
    if (houseId.isEmpty) {
      final q = getQuestionForDate(DateTime.now());
      return Stream.value(DeepTalkDayRecord(
        dateKey: dateKey(DateTime.now()),
        questionId: q.id,
        questionText: q.text,
        category: q.category,
        emoji: q.emoji,
        isUnlocked: false,
      ));
    }

    final today = dateKey(DateTime.now());
    return _dbRef.child('houses/$houseId/deep_talk/$today').onValue.map((event) {
      final q = getQuestionForDate(DateTime.now());
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return DeepTalkDayRecord(
          dateKey: today,
          questionId: q.id,
          questionText: q.text,
          category: q.category,
          emoji: q.emoji,
          isUnlocked: false,
        );
      }

      final map = event.snapshot.value as Map;
      final u1Ans = map['u1Answer']?.toString();
      final u2Ans = map['u2Answer']?.toString();
      final isUnlocked = (u1Ans != null && u1Ans.isNotEmpty) && (u2Ans != null && u2Ans.isNotEmpty);

      return DeepTalkDayRecord(
        dateKey: today,
        questionId: (map['questionId'] as num?)?.toInt() ?? q.id,
        questionText: map['questionText']?.toString() ?? q.text,
        category: map['category']?.toString() ?? q.category,
        emoji: map['emoji']?.toString() ?? q.emoji,
        u1Answer: u1Ans,
        u1AnswerTs: (map['u1AnswerTs'] as num?)?.toInt(),
        u2Answer: u2Ans,
        u2AnswerTs: (map['u2AnswerTs'] as num?)?.toInt(),
        isUnlocked: isUnlocked,
      );
    });
  }

  Future<bool> submitAnswer({
    required String houseId,
    required String role,
    required String answer,
  }) async {
    if (houseId.isEmpty || answer.trim().isEmpty) return false;

    final today = dateKey(DateTime.now());
    final q = getQuestionForDate(DateTime.now());
    final talkRef = _dbRef.child('houses/$houseId/deep_talk/$today');

    final snap = await talkRef.get();
    final updates = <String, dynamic>{
      'questionId': q.id,
      'questionText': q.text,
      'category': q.category,
      'emoji': q.emoji,
      'updatedAt': ServerValue.timestamp,
    };

    String? otherAnswer;
    if (snap.exists && snap.value is Map) {
      final map = snap.value as Map;
      otherAnswer = role == 'user1' ? map['u2Answer']?.toString() : map['u1Answer']?.toString();
    }

    if (role == 'user1') {
      updates['u1Answer'] = answer.trim();
      updates['u1AnswerTs'] = ServerValue.timestamp;
    } else {
      updates['u2Answer'] = answer.trim();
      updates['u2AnswerTs'] = ServerValue.timestamp;
    }

    final willUnlock = otherAnswer != null && otherAnswer.trim().isNotEmpty;
    if (willUnlock) {
      updates['isUnlocked'] = true;
    }

    await talkRef.update(updates);

    // Tự động thưởng EXP
    unawaited(
      IntimacyService.instance.addExp(
        houseId: houseId,
        action: 'deep_talk_answer',
        exp: willUnlock ? 25 : 10,
        description: willUnlock
            ? 'Cả hai cùng hoàn thành Daily Deep Talk (+25 EXP)'
            : 'Trả lời Daily Deep Talk (+10 EXP)',
      ),
    );

    return true;
  }
}
