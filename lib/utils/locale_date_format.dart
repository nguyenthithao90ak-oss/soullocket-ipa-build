import 'package:intl/intl.dart';

import 'calendar/calendar_display_format.dart';
import 'services/l10n_service.dart';
import 'services/market_service.dart';

/// Định dạng ngày giờ để HIỂN THỊ theo ngôn ngữ và khu vực của người dùng
/// (Mỹ 3/14/2026 2:30 PM, Đức 14.3.2026 14:30, Nhật 2026/03/14 14:30).
/// Không dùng kết quả để lưu hoặc parse lại.
abstract final class LocaleDateFormat {
  static String get intlLocale {
    try {
      return CalendarDisplayFormat.forLocale(
        L10nService().locale,
        MarketService.instance.marketCode,
      ).intlLocale;
    } catch (_) {
      return L10nService().locale.languageCode;
    }
  }

  static bool get _isVietnamese => intlLocale.startsWith('vi');

  static DateFormat _build(
    DateFormat Function(String locale) builder,
    String fallbackPattern,
  ) {
    // Giữ kiểu quen thuộc dd/MM/yyyy cho tiếng Việt.
    if (_isVietnamese) return DateFormat(fallbackPattern, 'vi');
    try {
      return builder(intlLocale);
    } catch (_) {
      // Dữ liệu định dạng của ngôn ngữ chưa nạp (vd. isolate nền).
      return DateFormat(fallbackPattern);
    }
  }

  /// Ngày dạng số: 14/03/2026, 3/14/2026, 2026/3/14...
  static DateFormat dateFormat() => _build(DateFormat.yMd, 'dd/MM/yyyy');

  static DateFormat dateTimeFormat() =>
      _build((l) => DateFormat.yMd(l).add_jm(), 'dd/MM/yyyy HH:mm');

  static DateFormat dayMonthFormat() => _build(DateFormat.Md, 'dd/MM');

  static DateFormat dayMonthTimeFormat() =>
      _build((l) => DateFormat.Md(l).add_jm(), 'dd/MM HH:mm');

  static DateFormat monthYearFormat() => _build(DateFormat.yM, 'MM/yyyy');

  static DateFormat timeFormat() => _build(DateFormat.jm, 'HH:mm');

  static String date(DateTime value) => dateFormat().format(value);

  static String dateTime(DateTime value) => dateTimeFormat().format(value);

  static String dayMonth(DateTime value) => dayMonthFormat().format(value);

  static String dayMonthTime(DateTime value) =>
      dayMonthTimeFormat().format(value);

  static String monthYear(DateTime value) => monthYearFormat().format(value);

  /// "14:30 • 14/03/2026" theo định dạng vùng.
  static String timeAndDate(DateTime value, {String separator = ' • '}) =>
      '${timeFormat().format(value)}$separator${date(value)}';
}
