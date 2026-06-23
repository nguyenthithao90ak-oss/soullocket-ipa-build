import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

/// ============================================================
///  LoveWeatherService — Gra (Phase 26 Backend)
///  Dịch vụ điều phối "Thời tiết Tình yêu" toàn app
/// ============================================================
class LoveWeatherService {
  static final LoveWeatherService _instance = LoveWeatherService._internal();
  factory LoveWeatherService() => _instance;
  LoveWeatherService._internal();

  final _db = FirebaseDatabase.instance;

  static const _validWeatherTypes = {
    'sunny',
    'rainy',
    'snowy',
    'stormy',
    'hearts',
  };

  /// Cập nhật thời tiết dựa trên logic AI hoặc trạng thái cặp đôi
  /// types: 'sunny', 'rainy', 'snowy', 'stormy', 'hearts'
  Future<void> updateWeather(String houseId, String weatherType) async {
    final normalizedHouseId = houseId.trim();
    final normalizedWeatherType = weatherType.trim().toLowerCase();
    if (normalizedHouseId.isEmpty || !_validWeatherTypes.contains(normalizedWeatherType)) {
      return;
    }
    await _db.ref('houses/$normalizedHouseId/weather').set({
      'type': normalizedWeatherType,
      'updatedAt': ServerValue.timestamp,
    });
  }

  /// Trae sẽ dùng Stream này để trigger hiệu ứng Particle toàn App
  Stream<String> listenToWeather(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<String>.value('sunny');
    return _db.ref('houses/$normalizedHouseId/weather/type').onValue.map((event) {
      final value = event.snapshot.value?.toString().trim().toLowerCase() ?? '';
      return _validWeatherTypes.contains(value) ? value : 'sunny';
    });
  }

  /// Tự động phân tích tâm trạng (Mock logic cho AI)
  Future<void> analyzeAndApplyWeather(String houseId, double loveScore) async {
    final score = loveScore.isNaN ? 0.0 : loveScore.clamp(0.0, 100.0);
    String weather;
    if (score > 90) {
      weather = 'hearts'; // Mưa tim lãng mạn
    } else if (score > 70) {
      weather = 'sunny'; // Nắng ấm
    } else if (score > 40) {
      weather = 'rainy'; // Mưa buồn
    } else {
      weather = 'stormy'; // Bão bùng sấm sét
    }
    await updateWeather(houseId.trim(), weather);
  }
}
