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

  /// Cập nhật thời tiết dựa trên logic AI hoặc trạng thái cặp đôi
  /// types: 'sunny', 'rainy', 'snowy', 'stormy', 'hearts'
  Future<void> updateWeather(String houseId, String weatherType) async {
    await _db.ref('houses/$houseId/weather').set({
      'type': weatherType,
      'updatedAt': ServerValue.timestamp,
    });
  }

  /// Trae sẽ dùng Stream này để trigger hiệu ứng Particle toàn App
  Stream<String> listenToWeather(String houseId) {
    return _db.ref('houses/$houseId/weather/type').onValue.map((event) {
      return event.snapshot.value?.toString() ?? 'sunny';
    });
  }

  /// Tự động phân tích tâm trạng (Mock logic cho AI)
  Future<void> analyzeAndApplyWeather(String houseId, double loveScore) async {
    String weather;
    if (loveScore > 90) {
      weather = 'hearts'; // Mưa tim lãng mạn
    } else if (loveScore > 70) {
      weather = 'sunny'; // Nắng ấm
    } else if (loveScore > 40) {
      weather = 'rainy'; // Mưa buồn
    } else {
      weather = 'stormy'; // Bão bùng sấm sét
    }
    await updateWeather(houseId, weather);
  }
}
