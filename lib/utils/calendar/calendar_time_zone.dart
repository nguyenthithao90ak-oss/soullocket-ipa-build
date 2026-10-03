import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Chuẩn hóa múi giờ IANA cho các luồng lịch có giờ.
/// Ngày cả ngày vẫn dùng date key dân sự và không đi qua UTC.
abstract final class CalendarTimeZone {
  static void ensureInitialized() {
    // NotificationService có thể đã chọn tz.local theo thiết bị. Nạp lại
    // database sẽ xóa lựa chọn đó và đặt UTC, nên chỉ nạp khi chưa sẵn sàng.
    if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
  }

  static bool isValidId(String? id) {
    if (id == null || id.isEmpty || id != id.trim()) return false;
    ensureInitialized();
    return tz.timeZoneDatabase.locations.containsKey(id);
  }

  static tz.Location? locationFor(String? id) {
    final normalized = id?.trim();
    // null nghĩa là giờ thiết bị của Dart, không phải tz.local mặc định UTC.
    if (normalized == null || normalized.isEmpty) return null;
    if (!isValidId(normalized)) throw ArgumentError.value(id, 'timeZoneId');
    return tz.getLocation(normalized);
  }

  static DateTime fromMilliseconds(int milliseconds, String? id) {
    final instant = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final location = locationFor(id);
    return location == null ? instant : tz.TZDateTime.from(instant, location);
  }
}
