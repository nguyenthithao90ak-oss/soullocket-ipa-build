/// Cặp ID ổn định dành riêng cho hai thông báo của một sự kiện lịch.
///
/// Android chỉ nhận ID thông báo dạng số nguyên 32-bit. Namespace ở bit 30 giúp
/// hạn chế đụng với các thông báo hệ thống khác; bit cuối phân biệt thông báo
/// đúng ngày và thông báo trước một ngày.
final class CalendarNotificationIds {
  const CalendarNotificationIds({
    required this.onEventDay,
    required this.dayBefore,
  });

  final int onEventDay;
  final int dayBefore;

  static const int _namespace = 0x40000000;
  static const int _eventHashMask = 0x1fffffff;
  static const int _fnvOffsetBasis = 0x811c9dc5;
  static const int _fnvPrime = 0x01000193;
  static const int _uint32Mask = 0xffffffff;

  factory CalendarNotificationIds.forEvent({
    required String houseId,
    required String dateKey,
    required String eventId,
  }) {
    final source = '$houseId\u0000$dateKey\u0000$eventId';
    var hash = _fnvOffsetBasis;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * _fnvPrime) & _uint32Mask;
    }

    final baseId = _namespace | ((hash & _eventHashMask) << 1);
    return CalendarNotificationIds(onEventDay: baseId, dayBefore: baseId | 1);
  }

  List<int> get values => <int>[onEventDay, dayBefore];
}
