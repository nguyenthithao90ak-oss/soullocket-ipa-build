import 'package:table_calendar/table_calendar.dart';

/// Quy ước hiển thị lịch theo vùng. Đây là mặc định CLDR cho giao diện,
/// không phải lịch làm việc bắt buộc của người dùng.
class MarketCalendarProfile {
  const MarketCalendarProfile({
    required this.marketCode,
    required this.firstWeekday,
    required this.weekendDays,
  });

  final String marketCode;
  final StartingDayOfWeek firstWeekday;
  final List<int> weekendDays;
}

abstract final class MarketCalendarProfiles {
  // CLDR supplemental weekData, đối chiếu ngày 03/10/2026 (UTC+07:00).
  // RTL do ngôn ngữ/Directionality quyết định, không suy từ thị trường.
  static const sourceUrl =
      'https://raw.githubusercontent.com/unicode-org/cldr/main/common/supplemental/supplementalData.xml';
  static const sourceReviewedOn = '2026-10-03';

  static const _standardWeekend = <int>[DateTime.saturday, DateTime.sunday];
  static const _sundayOnlyWeekend = <int>[DateTime.sunday];
  static const _fridaySaturdayWeekend = <int>[
    DateTime.friday,
    DateTime.saturday,
  ];

  static const _all = MarketCalendarProfile(
    marketCode: 'ALL',
    firstWeekday: StartingDayOfWeek.monday,
    weekendDays: _standardWeekend,
  );

  static const profiles = <String, MarketCalendarProfile>{
    'ALL': _all,
    'VN': MarketCalendarProfile(
      marketCode: 'VN',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'TH': MarketCalendarProfile(
      marketCode: 'TH',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'ID': MarketCalendarProfile(
      marketCode: 'ID',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'PH': MarketCalendarProfile(
      marketCode: 'PH',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'MY': MarketCalendarProfile(
      marketCode: 'MY',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'JP': MarketCalendarProfile(
      marketCode: 'JP',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'KR': MarketCalendarProfile(
      marketCode: 'KR',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'TW': MarketCalendarProfile(
      marketCode: 'TW',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'US': MarketCalendarProfile(
      marketCode: 'US',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'BR': MarketCalendarProfile(
      marketCode: 'BR',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'IN': MarketCalendarProfile(
      marketCode: 'IN',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _sundayOnlyWeekend,
    ),
    'GB': MarketCalendarProfile(
      marketCode: 'GB',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'CA': MarketCalendarProfile(
      marketCode: 'CA',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'AU': MarketCalendarProfile(
      marketCode: 'AU',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'SG': MarketCalendarProfile(
      marketCode: 'SG',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'MX': MarketCalendarProfile(
      marketCode: 'MX',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'AR': MarketCalendarProfile(
      marketCode: 'AR',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'CO': MarketCalendarProfile(
      marketCode: 'CO',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'ES': MarketCalendarProfile(
      marketCode: 'ES',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'FR': MarketCalendarProfile(
      marketCode: 'FR',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'DE': MarketCalendarProfile(
      marketCode: 'DE',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'IT': MarketCalendarProfile(
      marketCode: 'IT',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'NL': MarketCalendarProfile(
      marketCode: 'NL',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'PL': MarketCalendarProfile(
      marketCode: 'PL',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'TR': MarketCalendarProfile(
      marketCode: 'TR',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'SA': MarketCalendarProfile(
      marketCode: 'SA',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _fridaySaturdayWeekend,
    ),
    'AE': MarketCalendarProfile(
      marketCode: 'AE',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'EG': MarketCalendarProfile(
      marketCode: 'EG',
      firstWeekday: StartingDayOfWeek.saturday,
      weekendDays: _fridaySaturdayWeekend,
    ),
    'CN': MarketCalendarProfile(
      marketCode: 'CN',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'RU': MarketCalendarProfile(
      marketCode: 'RU',
      firstWeekday: StartingDayOfWeek.monday,
      weekendDays: _standardWeekend,
    ),
    'PT': MarketCalendarProfile(
      marketCode: 'PT',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'HK': MarketCalendarProfile(
      marketCode: 'HK',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
    'MO': MarketCalendarProfile(
      marketCode: 'MO',
      firstWeekday: StartingDayOfWeek.sunday,
      weekendDays: _standardWeekend,
    ),
  };

  static MarketCalendarProfile forMarket(String? marketCode) {
    final normalized = marketCode?.trim().toUpperCase();
    return profiles[normalized] ?? _all;
  }
}
