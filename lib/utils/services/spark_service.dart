import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'intimacy_service.dart';

/// Data model đại diện cho trạng thái Ngọn lửa Spark của Ngôi nhà
class SparkState {
  final int currentStreak;
  final int longestStreak;
  final String? lastCheckinDate;
  final Set<String> checkedInDates;
  final int? lastCheckinTs;
  final String? lastCheckinBy;

  const SparkState({
    required this.currentStreak,
    required this.longestStreak,
    this.lastCheckinDate,
    required this.checkedInDates,
    this.lastCheckinTs,
    this.lastCheckinBy,
  });

  factory SparkState.empty() {
    return const SparkState(
      currentStreak: 0,
      longestStreak: 0,
      checkedInDates: {},
    );
  }

  factory SparkState.fromMap(Map<dynamic, dynamic> map) {
    final rawDates = map['checkins'];
    final checkedInDates = <String>{};
    if (rawDates is Map) {
      for (final key in rawDates.keys) {
        checkedInDates.add(key.toString());
      }
    }

    return SparkState(
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      lastCheckinDate: map['lastCheckinDate']?.toString(),
      checkedInDates: checkedInDates,
      lastCheckinTs: (map['lastCheckinTs'] as num?)?.toInt(),
      lastCheckinBy: map['lastCheckinBy']?.toString(),
    );
  }

  static String dateKey(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  bool isCheckedInForDate(DateTime dt) {
    return checkedInDates.contains(dateKey(dt));
  }

  bool get isCheckedInToday {
    return isCheckedInForDate(DateTime.now());
  }

  /// Trả về danh sách 7 ngày trong tuần hiện tại (Thứ 2 -> Chủ Nhật) kèm trạng thái đã điểm danh
  List<DaySparkInfo> get currentWeekDays {
    final now = DateTime.now();
    // Monday is weekday 1, Sunday is 7 in Dart DateTime
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = <DaySparkInfo>[];

    for (int i = 0; i < 7; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
      final isPast = day.isBefore(DateTime(now.year, now.month, now.day));
      final checked = isCheckedInForDate(day);

      days.add(DaySparkInfo(
        date: day,
        dayLabel: _weekdayShortLabel(day.weekday),
        isCheckedIn: checked,
        isToday: isToday,
        isPast: isPast,
      ));
    }

    return days;
  }

  static String _weekdayShortLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'T2';
      case 2:
        return 'T3';
      case 3:
        return 'T4';
      case 4:
        return 'T5';
      case 5:
        return 'T6';
      case 6:
        return 'T7';
      case 7:
        return 'CN';
      default:
        return '';
    }
  }
}

class DaySparkInfo {
  final DateTime date;
  final String dayLabel;
  final bool isCheckedIn;
  final bool isToday;
  final bool isPast;

  const DaySparkInfo({
    required this.date,
    required this.dayLabel,
    required this.isCheckedIn,
    required this.isToday,
    required this.isPast,
  });
}

/// Dịch vụ quản lý Spark Điểm Danh Hàng Ngày
class SparkService {
  static final SparkService _instance = SparkService._internal();
  factory SparkService() => _instance;
  SparkService._internal();

  static SparkService get instance => _instance;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Stream<SparkState> streamSpark(String houseId) {
    if (houseId.isEmpty) {
      return Stream.value(SparkState.empty());
    }
    return _dbRef.child('houses/$houseId/spark').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return SparkState.empty();
      }
      return SparkState.fromMap(event.snapshot.value as Map);
    });
  }

  /// Thực hiện điểm danh cho ngày hôm nay
  Future<bool> checkIn({
    required String houseId,
    required String role,
  }) async {
    if (houseId.isEmpty) return false;

    final now = DateTime.now();
    final todayKey = SparkState.dateKey(now);
    final sparkRef = _dbRef.child('houses/$houseId/spark');

    final snap = await sparkRef.get();
    var currentStreak = 0;
    var longestStreak = 0;
    String? lastDate;
    final checkins = <String, bool>{};

    if (snap.exists && snap.value is Map) {
      final map = snap.value as Map;
      currentStreak = (map['currentStreak'] as num?)?.toInt() ?? 0;
      longestStreak = (map['longestStreak'] as num?)?.toInt() ?? 0;
      lastDate = map['lastCheckinDate']?.toString();
      if (map['checkins'] is Map) {
        for (final k in (map['checkins'] as Map).keys) {
          checkins[k.toString()] = true;
        }
      }
    }

    // Nếu đã điểm danh hôm nay rồi thì không tính lại
    if (checkins.containsKey(todayKey)) {
      return false;
    }

    // Tính toán chuỗi liên tiếp (Streak)
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey = SparkState.dateKey(yesterday);

    if (lastDate == yesterdayKey) {
      // Nối tiếp chuỗi
      currentStreak += 1;
    } else if (lastDate == todayKey) {
      // Đã điểm danh hôm nay
    } else {
      // Đứt chuỗi -> Bắt đầu chuỗi mới từ 1
      currentStreak = 1;
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    checkins[todayKey] = true;

    await sparkRef.update({
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastCheckinDate': todayKey,
      'lastCheckinTs': now.millisecondsSinceEpoch,
      'lastCheckinBy': role,
      'checkins/$todayKey': true,
    });

    // Tự động thưởng EXP thân mật
    unawaited(
      IntimacyService.instance.addExp(
        houseId: houseId,
        action: 'spark_checkin',
        exp: 15,
        description: 'Điểm danh ngọn lửa Spark hằng ngày (+15 EXP)',
      ),
    );

    return true;
  }
}
