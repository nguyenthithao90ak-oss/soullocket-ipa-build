import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class IntimacyLevelData {
  final int level;
  final String title;
  final String emoji;
  final int minExp;
  final int maxExp;
  final Color primaryColor;
  final Color secondaryColor;
  final String privilegeDescription;

  const IntimacyLevelData({
    required this.level,
    required this.title,
    required this.emoji,
    required this.minExp,
    required this.maxExp,
    required this.primaryColor,
    required this.secondaryColor,
    required this.privilegeDescription,
  });

  double progress(int totalExp) {
    if (level == 7) return 1.0;
    final range = maxExp - minExp;
    if (range <= 0) return 1.0;
    final current = totalExp - minExp;
    return (current / range).clamp(0.0, 1.0);
  }

  int expNeededForNextLevel(int totalExp) {
    if (level == 7) return 0;
    return (maxExp - totalExp).clamp(0, 999999);
  }
}

class IntimacyState {
  final int totalExp;
  final IntimacyLevelData levelData;
  final int? lastLevelUpTs;
  final int? lastLevelUpLevel;

  const IntimacyState({
    required this.totalExp,
    required this.levelData,
    this.lastLevelUpTs,
    this.lastLevelUpLevel,
  });

  factory IntimacyState.empty() {
    return IntimacyState(
      totalExp: 0,
      levelData: IntimacyService.levelConfigs[0],
    );
  }

  factory IntimacyState.fromMap(Map<dynamic, dynamic> map) {
    final totalExp = (map['totalExp'] as num?)?.toInt() ?? 0;
    final levelData = IntimacyService.getLevelData(totalExp);
    return IntimacyState(
      totalExp: totalExp,
      levelData: levelData,
      lastLevelUpTs: (map['lastLevelUpTs'] as num?)?.toInt(),
      lastLevelUpLevel: (map['lastLevelUpLevel'] as num?)?.toInt(),
    );
  }
}

class IntimacyService {
  static final IntimacyService _instance = IntimacyService._internal();
  factory IntimacyService() => _instance;
  IntimacyService._internal();

  static IntimacyService get instance => _instance;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  static const List<IntimacyLevelData> levelConfigs = [
    IntimacyLevelData(
      level: 1,
      title: 'Chớm Nở',
      emoji: '🌸',
      minExp: 0,
      maxExp: 100,
      primaryColor: Color(0xFFF472B6),
      secondaryColor: Color(0xFFFB7185),
      privilegeDescription: 'Mở khóa nhịp tim tương tác cơ bản',
    ),
    IntimacyLevelData(
      level: 2,
      title: 'Thân Thiết',
      emoji: '🌿',
      minExp: 100,
      maxExp: 300,
      primaryColor: Color(0xFF34D399),
      secondaryColor: Color(0xFF10B981),
      privilegeDescription: 'Mở khóa hiệu ứng gõ tim rung đôi',
    ),
    IntimacyLevelData(
      level: 3,
      title: 'Mặn Nồng',
      emoji: '💖',
      minExp: 300,
      maxExp: 700,
      primaryColor: Color(0xFFEC4899),
      secondaryColor: Color(0xFFF43F5E),
      privilegeDescription: 'Mở khóa viền phát sáng Avatar đôi',
    ),
    IntimacyLevelData(
      level: 4,
      title: 'Say Đắm',
      emoji: '🔥',
      minExp: 700,
      maxExp: 1500,
      primaryColor: Color(0xFFF97316),
      secondaryColor: Color(0xFFEF4444),
      privilegeDescription: 'Mở khóa vòng hào quang thiên thần Angel Halo',
    ),
    IntimacyLevelData(
      level: 5,
      title: 'Khăng Khít',
      emoji: '💎',
      minExp: 1500,
      maxExp: 3000,
      primaryColor: Color(0xFF38BDF8),
      secondaryColor: Color(0xFF6366F1),
      privilegeDescription: 'Mở khóa vệt sáng OSRM cực quang trên Map',
    ),
    IntimacyLevelData(
      level: 6,
      title: 'Tri Kỷ',
      emoji: '👑',
      minExp: 3000,
      maxExp: 6000,
      primaryColor: Color(0xFFA855F7),
      secondaryColor: Color(0xFF8B5CF6),
      privilegeDescription: 'Mở khóa Vương miện Tình yêu lấp lánh',
    ),
    IntimacyLevelData(
      level: 7,
      title: 'Vĩnh Cửu',
      emoji: '🌌',
      minExp: 6000,
      maxExp: 999999,
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFFFD700),
      privilegeDescription: 'Danh hiệu Tình Yêu Vĩnh Cửu + Hào quang Kim Cương',
    ),
  ];

  static IntimacyLevelData getLevelData(int exp) {
    for (final cfg in levelConfigs.reversed) {
      if (exp >= cfg.minExp) {
        return cfg;
      }
    }
    return levelConfigs.first;
  }

  Stream<IntimacyState> streamIntimacy(String houseId) {
    if (houseId.isEmpty) {
      return Stream.value(IntimacyState.empty());
    }
    return _dbRef.child('houses/$houseId/intimacy').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return IntimacyState.empty();
      }
      return IntimacyState.fromMap(event.snapshot.value as Map);
    });
  }

  /// Cộng điểm kinh nghiệm EXP và tự động kiểm tra thăng cấp
  Future<void> addExp({
    required String houseId,
    required String action,
    required int exp,
    String? description,
  }) async {
    if (houseId.isEmpty || exp <= 0) return;

    final intimacyRef = _dbRef.child('houses/$houseId/intimacy');
    final snap = await intimacyRef.get();

    var currentExp = 0;
    var currentLevel = 1;
    if (snap.exists && snap.value is Map) {
      final map = snap.value as Map;
      currentExp = (map['totalExp'] as num?)?.toInt() ?? 0;
    }

    final oldLevelData = getLevelData(currentExp);
    final newExp = currentExp + exp;
    final newLevelData = getLevelData(newExp);

    final updates = <String, dynamic>{
      'totalExp': newExp,
      'level': newLevelData.level,
      'lastUpdatedTs': ServerValue.timestamp,
    };

    // Nếu lên cấp mới
    if (newLevelData.level > oldLevelData.level) {
      updates['lastLevelUpTs'] = ServerValue.timestamp;
      updates['lastLevelUpLevel'] = newLevelData.level;
    }

    await intimacyRef.update(updates);

    // Ghi nhật ký EXP
    unawaited(
      _dbRef.child('houses/$houseId/intimacy_logs').push().set({
        'action': action,
        'exp': exp,
        'description': description ?? action,
        'ts': ServerValue.timestamp,
      }),
    );
  }
}
