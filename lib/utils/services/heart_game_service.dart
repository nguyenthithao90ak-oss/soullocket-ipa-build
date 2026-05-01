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
    await _db.ref('houses/$houseId/game_sessions/live').update({
      'score': score,
      'lastUpdated': ServerValue.timestamp,
    });
  }

  /// Kết thúc game và ghi vào bảng Highscore
  Future<void> submitHighScore(
      String houseId, int finalScore, String playerName) async {
    await _db.ref('houses/$houseId/game_highscores').push().set({
      'name': playerName,
      'score': finalScore,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Lắng nghe điểm số của đối phương đang chơi cùng
  Stream<int> listenToPartnerScore(String houseId) {
    return _db
        .ref('houses/$houseId/game_sessions/live/score')
        .onValue
        .map((event) {
      return (event.snapshot.value as int?) ?? 0;
    });
  }
}
