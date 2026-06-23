/// Schema cho Thú cưng / Cây ảo (Phase 5)
class PetVirtual {
  final String id;
  final String type; // 'dog', 'cat', 'tree'
  final String name;
  final int level;
  final int hunger; // 0 - 100
  final int happiness; // 0 - 100
  final int exp; // Điểm kinh nghiệm để lên cấp
  final int lastFedAt;
  final int lastPlayedAt;

  PetVirtual({
    required this.id,
    required this.type,
    required this.name,
    this.level = 1,
    this.hunger = 100,
    this.happiness = 100,
    this.exp = 0,
    required this.lastFedAt,
    required this.lastPlayedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'level': level,
      'hunger': hunger,
      'happiness': happiness,
      'exp': exp,
      'lastFedAt': lastFedAt,
      'lastPlayedAt': lastPlayedAt,
    };
  }

  factory PetVirtual.fromMap(Map<dynamic, dynamic> map) {
    return PetVirtual(
      id: map['id'] ?? '',
      type: map['type'] ?? 'dog',
      name: map['name'] ?? 'Pet',
      level: (map['level'] as num?)?.toInt() ?? 1,
      hunger: (map['hunger'] as num?)?.toInt() ?? 100,
      happiness: (map['happiness'] as num?)?.toInt() ?? 100,
      exp: (map['exp'] as num?)?.toInt() ?? 0,
      lastFedAt: (map['lastFedAt'] as num?)?.toInt() ?? 0,
      lastPlayedAt: (map['lastPlayedAt'] as num?)?.toInt() ?? 0,
    );
  }
}
