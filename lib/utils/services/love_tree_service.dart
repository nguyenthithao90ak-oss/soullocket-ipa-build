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
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final ref = _db.ref('houses/$normalizedHouseId/love_tree');
    final snapshot = await ref.get();

    int currentHealth = 0;
    int currentLevel = 1;

    if (snapshot.exists && snapshot.value is Map) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      currentHealth = (data['health'] as num?)?.toInt() ?? 0;
      currentLevel = (data['level'] as num?)?.toInt() ?? 1;
    }

    // Tăng health
    currentHealth +=
        (waterAmount.clamp(0, 100) + fertilizerAmount.clamp(0, 100));

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
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    // Logic: Nếu quá 24h chưa tưới, trừ 5 điểm health (tối thiểu về 0)
    final ref = _db.ref('houses/$normalizedHouseId/love_tree');
    final snapshot = await ref.get();

    if (snapshot.exists && snapshot.value is Map) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final lastTime = (data['lastNurtured'] as num?)?.toInt() ?? 0;
      final currentHealth = (data['health'] as num?)?.toInt() ?? 0;

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
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<Map<dynamic, dynamic>>.value({});
    }
    return _db.ref('houses/$normalizedHouseId/love_tree').onValue.map((event) {
      if (event.snapshot.value is! Map) return {};
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    });
  }
}
