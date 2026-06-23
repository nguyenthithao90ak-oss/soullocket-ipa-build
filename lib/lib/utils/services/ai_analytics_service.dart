import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

/// ============================================================
///  AILoveAnalyticsService — Gra (Logic/Data)
///  Trí tuệ nhân tạo phân tích dữ liệu tình cảm (Phase 4)
///
///  Chức năng:
///  1. Quét lịch sử nhật ký (Diaries) và phân tích cảm xúc (Sentiment).
///  2. Đánh giá "Điểm số Tình Yêu" (Love Score) dựa trên từ khóa.
///  3. Cung cấp dữ liệu để Trae vẽ biểu đồ "Mood Tracker".
/// ============================================================
class AILoveAnalyticsService {
  static final AILoveAnalyticsService _instance =
      AILoveAnalyticsService._internal();
  factory AILoveAnalyticsService() => _instance;
  AILoveAnalyticsService._internal();

  final _db = FirebaseDatabase.instance;

  // Keyword đơn giản để phân loại cảm xúc (Phase 4 Mở rộng sau = Machine Learning thật)
  final List<String> _positiveWords = [
    'vui',
    'yêu',
    'hạnh phúc',
    'nhớ',
    'ngọt ngào',
    'ôm',
    'tuyệt',
    'thương'
  ];
  final List<String> _negativeWords = [
    'buồn',
    'giận',
    'khóc',
    'chán',
    'mệt',
    'cãi',
    'lỗi',
    'chia tay'
  ];

  /// Phân tích dữ liệu nhật ký của 1 cắp đôi trong 30 ngày qua
  Future<Map<String, dynamic>> analyzeMonthlyMood(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return _emptyResult();
    // Pull only the most recent diary entries to avoid scanning the entire history.
    final snap =
        await _db.ref('houses/$normalizedHouseId/diaries').limitToLast(30).get();
    if (!snap.exists || snap.value is! Map) return _emptyResult();

    final data = Map<String, dynamic>.from(snap.value as Map);

    int positiveCount = 0;
    int negativeCount = 0;
    int neutralCount = 0;

    // Lặp qua tất cả nhật ký
    data.forEach((key, value) {
      if (value is! Map) {
        neutralCount++;
        return;
      }
      final content = (value['content'] ?? '').toString().toLowerCase();

      int posScore = 0;
      int negScore = 0;

      for (var word in _positiveWords) {
        if (content.contains(word)) posScore++;
      }
      for (var word in _negativeWords) {
        if (content.contains(word)) negScore++;
      }

      if (posScore > negScore) {
        positiveCount++;
      } else if (negScore > posScore) {
        negativeCount++;
      } else {
        neutralCount++;
      }
    });

    final total = positiveCount + negativeCount + neutralCount;
    // Tính điểm 0-100 (tối thiểu 50 nếu không có gì đặc biệt)
    final loveScore = 50 + (positiveCount * 5) - (negativeCount * 5);

    return {
      'totalDiaries': total,
      'positive': positiveCount,
      'negative': negativeCount,
      'neutral': neutralCount,
      'loveScore': loveScore.clamp(0, 100), // Không vượt quá 100 hoặc dưới 0
      'status': _getLoveStatus((loveScore.clamp(0, 100) as num).toInt()),
    };
  }

  Map<String, dynamic> _emptyResult() {
    return {
      'totalDiaries': 0,
      'positive': 0,
      'negative': 0,
      'neutral': 0,
      'loveScore': 50,
      'status': 'Chưa đủ dữ liệu. Hãy viết nhật ký nhiều hơn nhé! 💕',
    };
  }

  String _getLoveStatus(int score) {
    if (score >= 80) {
      return 'Tuyệt vời! Hai bạn đang chìm đắm trong tình yêu! 🥰';
    }
    if (score >= 60) return 'Tốt! Tình cảm đang phát triển ổn định. ❤️';
    if (score >= 40) {
      return 'Bình thường. Hãy dành thời gian cho nhau nhiều hơn nhé! ☕';
    }
    return 'Cảnh báo! Có vẻ hai bạn đang có chút trục trặc. Hãy ôm nhau 1 cái nhé! 🥺';
  }
}
