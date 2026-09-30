import '../utils/calendar/lunar_calendar.dart';

class SoulEvent {
  final String id;
  final String title;
  final int dateMs;
  final bool isLunar;
  final String category;
  final String colorHex;
  final int createdAt;
  final bool isPinned;
  final bool isAnniversary;

  /// Ngày cả ngày giữ nguyên khi thiết bị thay múi giờ.
  final String? civilDate;
  final int? lunarMonth;
  final int? lunarDay;
  final bool lunarLeapMonth;
  final int lunarOffsetHours;
  final bool reminderEnabled;
  final int reminderMinutes;

  SoulEvent({
    required this.id,
    required this.title,
    required this.dateMs,
    this.isLunar = false,
    required this.category,
    required this.colorHex,
    required this.createdAt,
    this.isPinned = false,
    this.isAnniversary = false,
    this.civilDate,
    this.lunarMonth,
    this.lunarDay,
    this.lunarLeapMonth = false,
    this.lunarOffsetHours = 7,
    this.reminderEnabled = false,
    this.reminderMinutes = 540,
  });

  bool get hasConfirmedLunarDate =>
      isLunar &&
      lunarMonth != null &&
      lunarMonth! >= 1 &&
      lunarMonth! <= 12 &&
      lunarDay != null &&
      lunarDay! >= 1 &&
      lunarDay! <= 30 &&
      (lunarOffsetHours == 7 || lunarOffsetHours == 8);

  DateTime get originalDate {
    final raw = civilDate;
    if (raw != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      final date = DateTime.tryParse(raw);
      if (date != null && dateKey(date) == raw) return date;
    }
    return DateTime.fromMillisecondsSinceEpoch(dateMs);
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Dùng ngày UTC tổng hợp để DST không làm một ngày dân sự thành 23 giờ.
  static int daysBetween(DateTime later, DateTime earlier) => DateTime.utc(
    later.year,
    later.month,
    later.day,
  ).difference(DateTime.utc(earlier.year, earlier.month, earlier.day)).inDays;

  factory SoulEvent.fromJson(String id, Map<dynamic, dynamic> json) {
    return SoulEvent(
      id: id,
      title: json['title']?.toString() ?? '',
      dateMs: int.tryParse(json['date']?.toString() ?? '0') ?? 0,
      isLunar: json['isLunar'] == true,
      category: json['category']?.toString() ?? 'all',
      colorHex: json['colorHex']?.toString() ?? '#FF4D94',
      createdAt: int.tryParse(json['createdAt']?.toString() ?? '0') ?? 0,
      isPinned: json['isPinned'] == true,
      isAnniversary: json['isAnniversary'] == true,
      civilDate: json['civilDate']?.toString(),
      reminderEnabled: json['reminderEnabled'] == true,
      reminderMinutes:
          (int.tryParse(json['reminderMinutes']?.toString() ?? '') ?? 540)
              .clamp(0, 1439),
      lunarMonth: int.tryParse(json['lunarMonth']?.toString() ?? ''),
      lunarDay: int.tryParse(json['lunarDay']?.toString() ?? ''),
      lunarLeapMonth: json['lunarLeapMonth'] == true,
      lunarOffsetHours:
          int.tryParse(json['lunarOffsetHours']?.toString() ?? '') ?? 7,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'date': dateMs,
    'isLunar': isLunar,
    'category': category,
    'colorHex': colorHex,
    'createdAt': createdAt,
    'isPinned': isPinned,
    'isAnniversary': isAnniversary,
    'reminderEnabled': reminderEnabled,
    'reminderMinutes': reminderMinutes,
    if (civilDate != null) 'civilDate': civilDate,
    if (hasConfirmedLunarDate) ...{
      'calendarVersion': 1,
      'lunarMonth': lunarMonth,
      'lunarDay': lunarDay,
      'lunarLeapMonth': lunarLeapMonth,
      'lunarOffsetHours': lunarOffsetHours,
    },
  };

  DateTime? calculateNextOccurrence(DateTime today) {
    final date = originalDate;
    final from = DateTime(today.year, today.month, today.day);
    if (hasConfirmedLunarDate) {
      final seed = DateTime(date.year, date.month, date.day);
      return LunarCalendar.nextOccurrence(
        month: lunarMonth!,
        day: lunarDay!,
        leapMonth: lunarLeapMonth,
        offsetHours: lunarOffsetHours,
        from: from.isBefore(seed) ? seed : from,
      );
    }
    // Dữ liệu âm lịch cũ chưa đủ để suy ngày âm: giữ hành vi đã lưu.
    if (!isAnniversary) return date;
    DateTime occurrence(int year) {
      final lastDay = DateTime(year, date.month + 1, 0).day;
      return DateTime(
        year,
        date.month,
        date.day > lastDay ? lastDay : date.day,
      );
    }

    var next = occurrence(from.year < date.year ? date.year : from.year);
    if (next.isBefore(from)) next = occurrence(next.year + 1);
    return next;
  }

  SoulEvent copyWith({
    String? id,
    String? title,
    int? dateMs,
    bool? isLunar,
    String? category,
    String? colorHex,
    int? createdAt,
    bool? isPinned,
    bool? isAnniversary,
    String? civilDate,
    int? lunarMonth,
    int? lunarDay,
    bool? lunarLeapMonth,
    int? lunarOffsetHours,
    bool? reminderEnabled,
    int? reminderMinutes,
  }) => SoulEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    dateMs: dateMs ?? this.dateMs,
    isLunar: isLunar ?? this.isLunar,
    category: category ?? this.category,
    colorHex: colorHex ?? this.colorHex,
    createdAt: createdAt ?? this.createdAt,
    isPinned: isPinned ?? this.isPinned,
    isAnniversary: isAnniversary ?? this.isAnniversary,
    civilDate: civilDate ?? (dateMs == null ? this.civilDate : null),
    lunarMonth:
        lunarMonth ??
        (dateMs == null && isLunar != false ? this.lunarMonth : null),
    lunarDay:
        lunarDay ?? (dateMs == null && isLunar != false ? this.lunarDay : null),
    lunarLeapMonth: lunarLeapMonth ?? this.lunarLeapMonth,
    lunarOffsetHours: lunarOffsetHours ?? this.lunarOffsetHours,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
  );
}
