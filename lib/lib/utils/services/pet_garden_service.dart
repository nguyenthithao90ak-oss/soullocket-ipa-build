import 'package:firebase_database/firebase_database.dart';
import '../../models/pet_virtual.dart';

/// ============================================================
///  PetGardenService — Gra (Logic/Data)
///  Hệ thống Nuôi Thú Cưng / Trồng Cây Áo & Điểm Thưởng (Phase 5)
///
///  Chức năng:
///  1. Khởi tạo / Lấy dữ liệu thú cưng chung của cả nhà.
///  2. Tính năng Cho ăn (Feed), Chơi đùa (Play).
///  3. Hệ thống điểm (Point System) dựa trên thời gian & tương tác.
/// ============================================================
class PetGardenService {
  static final PetGardenService _instance = PetGardenService._internal();
  factory PetGardenService() => _instance;
  PetGardenService._internal();

  final _db = FirebaseDatabase.instance;

  /// Lấy dữ liệu Thú cưng của nhà (nếu chưa có thì trả về null)
  Future<PetVirtual?> getPet(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return null;
    final snap = await _db.ref('houses/$normalizedHouseId/pet').get();
    if (!snap.exists || snap.value is! Map) return null;

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    return PetVirtual.fromMap(data);
  }

  /// Nhận nuôi Thú cưng / Trồng cây lần đầu tiên
  Future<void> adoptPet(String houseId, String type, String name) async {
    final normalizedHouseId = houseId.trim();
    final normalizedType = type.trim();
    final normalizedName = name.trim();
    if (normalizedHouseId.isEmpty ||
        normalizedType.isEmpty ||
        normalizedName.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final pet = PetVirtual(
      id: 'pet_$normalizedHouseId',
      type: normalizedType,
      name: normalizedName,
      lastFedAt: now,
      lastPlayedAt: now,
    );

    await _db.ref('houses/$normalizedHouseId/pet').set(pet.toMap());
  }

  /// Cho thú cưng ăn (Tăng Độ no, Cộng EXP kinh nghiệm)
  Future<void> feedPet(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final ref = _db.ref('houses/$normalizedHouseId/pet');

    // Giao dịch an toàn (Transaction) để tránh hai người bấm cùng lúc bị lỗi đè số liệu
    await ref.runTransaction((Object? petData) {
      if (petData is! Map) return Transaction.abort();

      final Map<dynamic, dynamic> pet = Map<dynamic, dynamic>.from(petData);

      int currentHunger = (pet['hunger'] as num?)?.toInt() ?? 0;
      int currentExp = (pet['exp'] as num?)?.toInt() ?? 0;
      int currentLevel = (pet['level'] as num?)?.toInt() ?? 1;

      // Cập nhật chỉ số
      currentHunger = (currentHunger + 30).clamp(0, 100);
      currentExp += 10; // Được 10 điểm kinh nghiệm khi cho ăn

      // Logic chuyển cấp (Level up) khi đạt mốc
      final expNeeded = currentLevel * 100;
      if (currentExp >= expNeeded) {
        currentLevel++;
        currentExp -= expNeeded; // Dư kinh nghiệm chuyển sang cấp sau
      }

      pet['hunger'] = currentHunger;
      pet['exp'] = currentExp;
      pet['level'] = currentLevel;
      pet['lastFedAt'] = ServerValue.timestamp;

      return Transaction.success(pet);
    });
  }

  /// Chơi với thú cưng (Tăng Độ vui vẻ)
  Future<void> playWithPet(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final ref = _db.ref('houses/$normalizedHouseId/pet');

    await ref.runTransaction((Object? petData) {
      if (petData is! Map) return Transaction.abort();

      final Map<dynamic, dynamic> pet = Map<dynamic, dynamic>.from(petData);

      int currentHappiness = (pet['happiness'] as num?)?.toInt() ?? 0;

      currentHappiness = (currentHappiness + 20).clamp(0, 100);

      pet['happiness'] = currentHappiness;
      pet['lastPlayedAt'] = ServerValue.timestamp;

      return Transaction.success(pet);
    });
  }

  /// Cập nhật tụt độ no và độ vui theo thời gian thực (Trừ điểm khi không chăm sóc)
  Future<void> decayPetStatus(String houseId) async {
    final pet = await getPet(houseId);
    if (pet == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceFed = (now - pet.lastFedAt) / (1000 * 60 * 60);
    final hoursSincePlayed = (now - pet.lastPlayedAt) / (1000 * 60 * 60);

    // Mỗi giờ trừ 5 điểm No và Vui vẻ
    final hungerDecay = (hoursSinceFed * 5).toInt();
    final happinessDecay = (hoursSincePlayed * 5).toInt();

    if (hungerDecay > 0 || happinessDecay > 0) {
      final newHunger = (pet.hunger - hungerDecay).clamp(0, 100);
      final newHappiness = (pet.happiness - happinessDecay).clamp(0, 100);

      await _db.ref('houses/${houseId.trim()}/pet').update({
        'hunger': newHunger,
        'happiness': newHappiness,
      });
    }
  }

  /// Theo dõi Thú cưng Real-time để Trae vẽ UI chuyển động
  Stream<PetVirtual?> petStream(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<PetVirtual?>.value(null);
    return _db.ref('houses/$normalizedHouseId/pet').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
      return PetVirtual.fromMap(
        Map<dynamic, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }
}
