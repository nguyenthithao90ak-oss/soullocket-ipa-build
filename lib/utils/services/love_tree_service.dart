import 'package:firebase_database/firebase_database.dart';

/// ============================================================
///  LoveTreeService — Gra (Phase 29 Backend)
///  Lõi nuôi cây cây tình yêu ảo (Virtual Plant Logic)
/// ============================================================
class LoveTreeService {
  static final LoveTreeService _instance = LoveTreeService._internal();
  factory LoveTreeService() => _instance;
  LoveTreeService._internal();

  final _db = FirebaseDatabase.instance;

  /// [JS-06] Nâng cấp: Cập nhật sức khoẻ của cây (Tưới nước/Bón phân) và Level cây
  Future<void> nurtureTree(String houseId,
      {required int waterAmount, required int fertilizerAmount}) async {
    final ref = _db.ref('houses/$houseId/love_tree');
    final snapshot = await ref.get();

    int currentHealth = 0;
    int currentLevel = 1;

    if (snapshot.exists) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      currentHealth = (data['health'] as int?) ?? 0;
      currentLevel = (data['level'] as int?) ?? 1;
    }

    // Tăng health
    currentHealth += (waterAmount + fertilizerAmount);

    // Tính toán Level (Cứ 100 health lên 1 level)
    if (currentHealth >= currentLevel * 100) {
      currentLevel++;
    }

    await ref.update({
      'health': currentHealth,
      'level': currentLevel,
      'lastNurtured': ServerValue.timestamp,
      'nurtureCount': ServerValue.increment(1),
    });
  }

  /// [JS-06] Tự động trừ sức khoẻ cây theo thời gian (nếu lâu không vào app)
  Future<void> applyNaturalDecay(String houseId) async {
    // Logic: Nếu quá 24h chưa tưới, trừ 5 điểm health (tối thiểu về 0)
    final ref = _db.ref('houses/$houseId/love_tree');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final lastTime = data['lastNurtured'] as int? ?? 0;
      final currentHealth = data['health'] as int? ?? 0;

      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - lastTime > 86400000 && currentHealth > 0) {
        int newHealth = currentHealth - 5;
        if (newHealth < 0) newHealth = 0;

        await ref.update({
          'health': newHealth,
        });
      }
    }
  }

  Stream<Map<dynamic, dynamic>> listenToTreeStatus(String houseId) {
    return _db.ref('houses/$houseId/love_tree').onValue.map((event) {
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map? ?? {});
    });
  }
}
