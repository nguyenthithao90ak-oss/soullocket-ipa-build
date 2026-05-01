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
    final snap = await _db.ref('houses/$houseId/pet').get();
    if (!snap.exists || snap.value == null) return null;

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    return PetVirtual.fromMap(data);
  }

  /// Nhận nuôi Thú cưng / Trồng cây lần đầu tiên
  Future<void> adoptPet(String houseId, String type, String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pet = PetVirtual(
      id: 'pet_$houseId',
      type: type,
      name: name,
      lastFedAt: now,
      lastPlayedAt: now,
    );

    await _db.ref('houses/$houseId/pet').set(pet.toMap());
  }

  /// Cho thú cưng ăn (Tăng Độ no, Cộng EXP kinh nghiệm)
  Future<void> feedPet(String houseId) async {
    final ref = _db.ref('houses/$houseId/pet');

    // Giao dịch an toàn (Transaction) để tránh hai người bấm cùng lúc bị lỗi đè số liệu
    await ref.runTransaction((Object? petData) {
      if (petData == null) return Transaction.abort();

      final Map<dynamic, dynamic> pet =
          Map<dynamic, dynamic>.from(petData as Map);

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
    final ref = _db.ref('houses/$houseId/pet');

    await ref.runTransaction((Object? petData) {
      if (petData == null) return Transaction.abort();

      final Map<dynamic, dynamic> pet =
          Map<dynamic, dynamic>.from(petData as Map);

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

      await _db.ref('houses/$houseId/pet').update({
        'hunger': newHunger,
        'happiness': newHappiness,
      });
    }
  }

  /// Theo dõi Thú cưng Real-time để Trae vẽ UI chuyển động
  Stream<PetVirtual?> petStream(String houseId) {
    return _db.ref('houses/$houseId/pet').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return PetVirtual.fromMap(event.snapshot.value as Map<dynamic, dynamic>);
    });
  }
}
