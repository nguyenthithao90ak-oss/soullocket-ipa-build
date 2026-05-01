import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class RecommendationService {
  static const String _houseAffinityKey = 'il_rec_house_affinity';
  static const String _moodAffinityKey = 'il_rec_mood_affinity';

  // Singleton pattern
  static final RecommendationService _instance =
      RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  Map<String, double> _houseAffinities = {};
  Map<String, double> _moodAffinities = {};
  bool _initialized = false;
  final Random _random = Random();

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    final houseData = prefs.getString(_houseAffinityKey);
    if (houseData != null) {
      try {
        final decoded = json.decode(houseData) as Map<String, dynamic>;
        _houseAffinities =
            decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {}
    }

    final moodData = prefs.getString(_moodAffinityKey);
    if (moodData != null) {
      try {
        final decoded = json.decode(moodData) as Map<String, dynamic>;
        _moodAffinities =
            decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {}
    }

    _initialized = true;
  }

  /// Ghi nhận tương tác của người dùng với một bài viết / nhà nào đó
  /// weight: like = 5.0, comment = 10.0, view profile = 2.0, share = 15.0
  Future<void> recordInteraction({
    String? houseId,
    String? mood,
    required double weight,
  }) async {
    if (!_initialized) await init();
    bool changed = false;

    if (houseId != null && houseId.isNotEmpty) {
      _houseAffinities[houseId] = (_houseAffinities[houseId] ?? 0.0) + weight;
      changed = true;
    }

    if (mood != null && mood.isNotEmpty) {
      _moodAffinities[mood] = (_moodAffinities[mood] ?? 0.0) + weight;
      changed = true;
    }

    if (changed) {
      _saveDebounced();
    }
  }

  /// Tính điểm đề xuất cho bài đăng (For You Score)
  double getPostScore(Map<String, dynamic> post, int currentTimestamp) {
    if (!_initialized) return 0.0;

    final houseId = (post['houseId'] ?? '').toString();
    final mood = (post['moodLabel'] ?? post['mood'] ?? '').toString();

    final authorScore = _houseAffinities[houseId] ?? 0.0;
    final moodScore = _moodAffinities[mood] ?? 0.0;

    // 1. Điểm tương tác cơ bản (Global popularity)
    final likesMap = post['likes_map'];
    final likes = likesMap is Map && likesMap.isNotEmpty
        ? likesMap.length
        : (post['likes'] is int
            ? post['likes'] as int
            : (post['likes'] is num ? (post['likes'] as num).toInt() : 0));
    final comments = post['comments'] is int ? post['comments'] as int : 0;
    final shares = post['shareCount'] is int
        ? post['shareCount'] as int
        : (post['reposts'] is int ? post['reposts'] as int : 0);

    final baseHotness = (likes * 1.0) + (comments * 2.5) + (shares * 4.0);

    // 2. Điểm phân rã theo thời gian (Time decay)
    // Bài viết càng cũ, điểm càng giảm mạnh. Giảm 1 nửa mỗi 24 giờ.
    final postTs = post['ts'] is int ? post['ts'] as int : currentTimestamp;
    final ageHours = (currentTimestamp - postTs) / (1000 * 60 * 60);
    // Tránh ageHours âm nếu giờ client bị sai
    final safeAgeHours = ageHours < 0 ? 0.0 : ageHours;
    final timeMultiplier = 1.0 / (1.0 + (safeAgeHours / 24.0));

    // 3. Sở thích cá nhân (Personal affinity)
    // Trọng số cho tác giả cao hơn mood
    final personalScore = (authorScore * 2.0) + moodScore;

    // 4. Yếu tố ngẫu nhiên để tăng tính khám phá (Serendipity / Discovery)
    // Random từ 0.8 đến 1.2
    final randomFactor = 0.8 + (_random.nextDouble() * 0.4);

    // Tổng hợp: (Độ hot + Sở thích) * Thời gian * Ngẫu nhiên
    final totalScore =
        (baseHotness + personalScore + 5.0) * timeMultiplier * randomFactor;

    return totalScore;
  }

  bool _isSaving = false;
  void _saveDebounced() async {
    if (_isSaving) return;
    _isSaving = true;
    await Future.delayed(const Duration(seconds: 2));
    await _save();
    _isSaving = false;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // Giới hạn số lượng lưu trữ để không bị phình to (giữ top 100)
    if (_houseAffinities.length > 100) {
      final sortedKeys = _houseAffinities.keys.toList()
        ..sort((a, b) => _houseAffinities[b]!.compareTo(_houseAffinities[a]!));
      _houseAffinities = {
        for (var k in sortedKeys.take(100))
          k: _houseAffinities[k]! * 0.9 // decay 10% khi bị đầy
      };
    }

    if (_moodAffinities.length > 50) {
      final sortedKeys = _moodAffinities.keys.toList()
        ..sort((a, b) => _moodAffinities[b]!.compareTo(_moodAffinities[a]!));
      _moodAffinities = {
        for (var k in sortedKeys.take(50)) k: _moodAffinities[k]! * 0.9
      };
    }

    await prefs.setString(_houseAffinityKey, json.encode(_houseAffinities));
    await prefs.setString(_moodAffinityKey, json.encode(_moodAffinities));
  }
}
