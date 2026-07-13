import 'package:firebase_database/firebase_database.dart';

/// ============================================================
///  HeartGameService — Gra (Phase 28 Backend)
///  Lõi Game Bắt Tim - Đồng bộ điểm số và chống gian lận
/// ============================================================
class HeartGameService {
  static final HeartGameService _instance = HeartGameService._internal();
  factory HeartGameService() => _instance;
  HeartGameService._internal();

  final _db = FirebaseDatabase.instance;

  /// Cập nhật điểm số phiên chơi hiện tại (Realtime sync)
  Future<void> updateLiveScore(String houseId, int score) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    await _db.ref('houses/$normalizedHouseId/game_sessions/live').update({
      'score': score < 0 ? 0 : score,
      'lastUpdated': ServerValue.timestamp,
    });
  }

  /// Kết thúc game và ghi vào bảng Highscore
  Future<void> submitHighScore(
      String houseId, int finalScore, String playerName) async {
    final normalizedHouseId = houseId.trim();
    final normalizedPlayerName = playerName.trim();
    if (normalizedHouseId.isEmpty || normalizedPlayerName.isEmpty) return;
    await _db.ref('houses/$normalizedHouseId/game_highscores').push().set({
      'name': normalizedPlayerName,
      'score': finalScore < 0 ? 0 : finalScore,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Lắng nghe điểm số của đối phương đang chơi cùng
  Stream<int> listenToPartnerScore(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<int>.value(0);
    return _db
        .ref('houses/$normalizedHouseId/game_sessions/live/score')
        .onValue
        .map((event) {
      return (event.snapshot.value as num?)?.toInt() ?? 0;
    });
  }
}
