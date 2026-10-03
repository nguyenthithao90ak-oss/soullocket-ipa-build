/// Quy tắc thứ N (1–5) hoặc thứ cuối cùng (-1) của tháng.
class HolidayWeekdayRule {
  const HolidayWeekdayRule({required this.weekday, required this.ordinal});

  final int weekday;
  final int ordinal;

  bool get isValid =>
      weekday >= DateTime.monday &&
      weekday <= DateTime.sunday &&
      (ordinal == -1 || (ordinal >= 1 && ordinal <= 5));
}

/// Ngày lễ có ID/sticker ổn định; ngày dương mẫu không thay thế bảng năm.
class PresetHoliday {
  const PresetHoliday({
    required this.id,
    required this.month,
    required this.day,
    required this.i18nKey,
    required this.defaultName,
    this.countries = const ['ALL'],
    this.stickerKey,
    this.datesByYear,
    this.weekdayRule,
    this.sourceReferences = const [],
    this.verifiedAt,
    this.verificationStatus = 'pending',
  });

  final String id;
  final int month;
  final int day;
  final String i18nKey;
  final String defaultName;

  /// ALL áp dụng toàn cầu; lễ riêng VN còn phải qua điều kiện ngôn ngữ vi.
  final List<String> countries;
  final String? stickerKey;
  final Map<int, (int, int)>? datesByYear;
  final HolidayWeekdayRule? weekdayRule;
  final List<String> sourceReferences;
  final String? verifiedAt;
  final String verificationStatus;

  bool get isInternational => countries.contains('ALL');
  bool get isVietnamOnly => countries.length == 1 && countries.contains('VN');

  bool get hasVerifiedSource =>
      verificationStatus == 'verified' &&
      sourceReferences.isNotEmpty &&
      sourceReferences.every(HolidayOccurrenceResolver.isSourceUrl) &&
      HolidayOccurrenceResolver.isIsoDate(verifiedAt) &&
      HolidayOccurrenceResolver.isValidDate(2000, month, day) &&
      !(datesByYear != null && weekdayRule != null) &&
      (weekdayRule?.isValid ?? true) &&
      (datesByYear == null ||
          (datesByYear!.isNotEmpty &&
              datesByYear!.entries.every(
                (entry) => HolidayOccurrenceResolver.isValidDate(
                  entry.key,
                  entry.value.$1,
                  entry.value.$2,
                ),
              )));

  // Giữ API cũ cho caller; mọi đường tính ngày đi qua cùng resolver.
  DateTime? dateInYear(int year) =>
      HolidayOccurrenceResolver.dateInYear(this, year);

  DateTime? nextOccurrence(DateTime from) =>
      HolidayOccurrenceResolver.nextOccurrence(this, from)?.date;
}

class HolidayOccurrence {
  const HolidayOccurrence({required this.holiday, required this.date});

  final PresetHoliday holiday;
  final DateTime date;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Không dùng tên đã dịch làm định danh, để đổi ngôn ngữ vẫn cùng sự kiện.
  String get occurrenceId => 'holiday/${holiday.id}/$dateKey';

  /// Đếm ngày dân sự, tránh sai một ngày khi khoảng cách đi qua DST.
  int daysFrom(DateTime from) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

/// Resolver thuần dữ liệu, dùng chung cho Home, kỷ niệm và lớp lịch đọc.
abstract final class HolidayOccurrenceResolver {
  static bool isValidDate(int year, int month, int day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
      return false;
    }
    return day <= DateTime.utc(year, month + 1, 0).day;
  }

  static bool isIsoDate(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    return isValidDate(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }

  static bool isSourceUrl(String value) {
    final uri = Uri.tryParse(value);
    return value.trim() == value &&
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  static DateTime? dateInYear(PresetHoliday holiday, int year) {
    if (year < 1 || year > 9999) return null;
    if (holiday.datesByYear != null && holiday.weekdayRule != null) return null;
    final dates = holiday.datesByYear;
    if (dates != null) {
      if (!holiday.hasVerifiedSource) return null;
      final value = dates[year];
      if (value == null || !isValidDate(year, value.$1, value.$2)) return null;
      return DateTime(year, value.$1, value.$2);
    }
    final rule = holiday.weekdayRule;
    if (rule != null) {
      if (!holiday.hasVerifiedSource || !rule.isValid) return null;
      final month = holiday.month;
      final lastDay = DateTime.utc(year, month + 1, 0);
      final day = rule.ordinal == -1
          ? lastDay.day - (lastDay.weekday - rule.weekday + 7) % 7
          : 1 +
                (rule.weekday - DateTime.utc(year, month).weekday + 7) % 7 +
                (rule.ordinal - 1) * 7;
      return isValidDate(year, month, day) ? DateTime(year, month, day) : null;
    }
    // Ngày cố định legacy vẫn đọc được trong lúc rà nguồn 23 ID hiện có.
    return isValidDate(year, holiday.month, holiday.day)
        ? DateTime(year, holiday.month, holiday.day)
        : null;
  }

  static HolidayOccurrence? nextOccurrence(
    PresetHoliday holiday,
    DateTime from,
  ) {
    final today = DateTime(from.year, from.month, from.day);
    final dates = holiday.datesByYear;
    final years = dates != null
        ? (dates.keys.toList()..sort())
        // Qua thế kỷ không nhuận có thể cách 8 năm giữa hai ngày 29/2.
        : List.generate(
            // Thứ thứ 5 của tháng 2 có thể cách nhiều năm; chu kỳ lịch
            // Gregory 400 năm bao phủ mọi tổ hợp năm nhuận/ngày trong tuần.
            holiday.weekdayRule?.ordinal == 5 ? 401 : 9,
            (offset) => today.year + offset,
          );
    for (final year in years) {
      if (year < today.year) continue;
      final date = dateInYear(holiday, year);
      if (date != null && !date.isBefore(today)) {
        return HolidayOccurrence(holiday: holiday, date: date);
      }
    }
    return null;
  }

  static List<HolidayOccurrence> nextOccurrences(
    Iterable<PresetHoliday> holidays, {
    required DateTime from,
  }) {
    final result = <HolidayOccurrence>[];
    final seenIds = <String>{};
    for (final holiday in holidays) {
      if (!seenIds.add(holiday.id)) continue;
      final occurrence = nextOccurrence(holiday, from);
      if (occurrence != null) result.add(occurrence);
    }
    return _sorted(result);
  }

  /// Hai đầu mút là ngày dân sự, có tính ngày đầu/ngày cuối, bỏ phần giờ.
  static List<HolidayOccurrence> occurrencesBetween(
    Iterable<PresetHoliday> holidays, {
    required DateTime start,
    required DateTime end,
  }) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    if (last.isBefore(first)) return const [];
    final result = <HolidayOccurrence>[];
    final seenIds = <String>{};
    for (final holiday in holidays) {
      if (!seenIds.add(holiday.id)) continue;
      for (var year = first.year; year <= last.year; year++) {
        final date = dateInYear(holiday, year);
        if (date != null && !date.isBefore(first) && !date.isAfter(last)) {
          result.add(HolidayOccurrence(holiday: holiday, date: date));
        }
      }
    }
    return _sorted(result);
  }

  static List<HolidayOccurrence> _sorted(List<HolidayOccurrence> result) {
    result.sort((a, b) {
      final order = a.date.compareTo(b.date);
      return order != 0 ? order : a.holiday.id.compareTo(b.holiday.id);
    });
    return List.unmodifiable(result);
  }
}
