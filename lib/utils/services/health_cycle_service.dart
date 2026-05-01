import 'package:firebase_database/firebase_database.dart';

/// ============================================================
///  HealthCycleService — GRA (Phase 35)
///  Theo Dõi Chu Kỳ Sức Khỏe — Health Cycle Tracker
///
///  Logic theo web gốc: health-cycle.js
///  - Tính pha chu kỳ kinh nguyệt dựa ngày cuối kỳ
///  - 4 giai đoạn: Hành kinh / Nang trứng / Rụng trứng / PMS
///  - Dự đoán 3 kỳ tiếp theo
///  - Mẹo chăm sóc bạn gái theo từng giai đoạn
/// ============================================================

/// 4 giai đoạn theo web gốc
enum CyclePhase {
  menstruation, // 🩸 Hành kinh
  follicular, // ✨ Nang trứng
  ovulation, // 🥚 Rụng trứng
  luteal, // 🌙 Hoàng thể (PMS)
}

class HealthCycleService {
  static final HealthCycleService _instance = HealthCycleService._internal();
  factory HealthCycleService() => _instance;
  HealthCycleService._internal();

  final _db = FirebaseDatabase.instance;

  // ─────────────────────────────────────────────────────────────
  // 1. LƯU & ĐỌC CÀI ĐẶT CHU KỲ
  // ─────────────────────────────────────────────────────────────

  Future<void> saveCycleSettings({
    required String houseId,
    required DateTime lastPeriodDate,
    int cycleLength = 28,
    int periodDays = 5,
  }) async {
    await _db.ref('houses/$houseId/health_cycle').set({
      'lastDate':
          '${lastPeriodDate.year}-${_pad(lastPeriodDate.month)}-${_pad(lastPeriodDate.day)}',
      'length': cycleLength,
      'periodDays': periodDays,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Stream<CycleSettings?> streamCycleSettings(String houseId) {
    return _db.ref('houses/$houseId/health_cycle').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return CycleSettings.fromMap(data);
    });
  }

  Future<CycleSettings?> getCycleSettings(String houseId) async {
    final snap = await _db.ref('houses/$houseId/health_cycle').get();
    if (!snap.exists) return null;
    return CycleSettings.fromMap(Map<String, dynamic>.from(snap.value as Map));
  }

  // ─────────────────────────────────────────────────────────────
  // 2. TÍNH TOÁN TRẠNG THÁI CHU KỲ HIỆN TẠI
  // ─────────────────────────────────────────────────────────────

  /// Tính trạng thái chu kỳ hiện tại từ cài đặt
  CycleState calculateCurrentState(CycleSettings settings) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final lastDate = settings.lastPeriodDate;

    final diffMs =
        todayMidnight.millisecondsSinceEpoch - lastDate.millisecondsSinceEpoch;
    final diffDays = (diffMs / 86400000).floor();

    final length = settings.cycleLength;
    final periodDays = settings.periodDays;

    // Ngày trong chu kỳ hiện tại
    final dayInCycle = ((diffDays % length) + length) % length;
    final nextPeriodDays = length - dayInCycle;

    // Xác định giai đoạn
    CyclePhase phase;
    double progress;

    if (dayInCycle < periodDays) {
      phase = CyclePhase.menstruation;
      progress = (dayInCycle / periodDays) * 25;
    } else if (dayInCycle < length / 2 - 2) {
      phase = CyclePhase.follicular;
      progress =
          25 + ((dayInCycle - periodDays) / (length / 2 - 2 - periodDays)) * 25;
    } else if (dayInCycle < length / 2 + 2) {
      phase = CyclePhase.ovulation;
      progress = 50 + ((dayInCycle - (length / 2 - 2)) / 4) * 25;
    } else {
      phase = CyclePhase.luteal;
      final denominator = length - (length / 2 + 2);
      progress = denominator > 0
          ? 75 + ((dayInCycle - (length / 2 + 2)) / denominator) * 25
          : 75;
    }

    // Dự đoán 3 kỳ tiếp theo
    final predictions = <DateTime>[];
    for (int i = 1; i <= 3; i++) {
      predictions.add(lastDate.add(Duration(days: (length * i).round())));
    }

    return CycleState(
      phase: phase,
      dayInCycle: dayInCycle,
      nextPeriodIn: nextPeriodDays,
      progressPercent: progress.clamp(0.0, 100.0),
      nextPeriodPredictions: predictions,
      tip: _getTip(phase),
      phaseLabel: _getPhaseLabel(phase),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. MẸO CHĂM SÓC THEO TỪNG GIAI ĐOẠN
  // ─────────────────────────────────────────────────────────────

  static String _getPhaseLabel(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstruation:
        return '🩸 Giai đoạn Hành kinh';
      case CyclePhase.follicular:
        return '✨ Giai đoạn Nang trứng';
      case CyclePhase.ovulation:
        return '🥚 Giai đoạn Rụng trứng';
      case CyclePhase.luteal:
        return '🌙 Giai đoạn Hoàng thể (PMS)';
    }
  }

  static String _getTip(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstruation:
        return 'Bạn nữ có thể mệt mỏi, đau bụng. Hãy chuẩn bị nước ấm, túi chườm và đồ ăn nhẹ nhé. Đừng quên những lời an ủi dịu dàng! ❤️';
      case CyclePhase.follicular:
        return 'Năng lượng đang quay trở lại! Đây là lúc thích hợp cho những buổi hẹn hò năng động hoặc cùng nhau học điều mới.';
      case CyclePhase.ovulation:
        return 'Bạn nữ cảm thấy tự tin và quyến rũ nhất. Hãy dành cho nhau những lời khen ngợi và tạo không gian lãng mạn nhé!';
      case CyclePhase.luteal:
        return 'Tâm trạng có thể nhạy cảm hơn một chút do thay đổi nội tiết tố. Hãy kiên nhẫn, lắng nghe và tặng cô ấy những cái ôm thật chặt.';
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ─── MODELS ─────────────────────────────────────────────────────────────────

class CycleSettings {
  final DateTime lastPeriodDate;
  final int cycleLength;
  final int periodDays;

  CycleSettings({
    required this.lastPeriodDate,
    required this.cycleLength,
    required this.periodDays,
  });

  factory CycleSettings.fromMap(Map<String, dynamic> map) {
    final lastDateStr = map['lastDate']?.toString() ?? '';
    DateTime lastDate;
    try {
      final parts = lastDateStr.split('-');
      lastDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      lastDate = DateTime.now().subtract(const Duration(days: 14));
    }
    return CycleSettings(
      lastPeriodDate: lastDate,
      cycleLength: (map['length'] as num?)?.toInt() ?? 28,
      periodDays: (map['periodDays'] as num?)?.toInt() ?? 5,
    );
  }
}

class CycleState {
  final CyclePhase phase;
  final int dayInCycle;
  final int nextPeriodIn;
  final double progressPercent;
  final List<DateTime> nextPeriodPredictions;
  final String tip;
  final String phaseLabel;

  CycleState({
    required this.phase,
    required this.dayInCycle,
    required this.nextPeriodIn,
    required this.progressPercent,
    required this.nextPeriodPredictions,
    required this.tip,
    required this.phaseLabel,
  });

  bool get isPeriodToday => nextPeriodIn == 0;
}
