import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_locale_registry.dart';

/// Formatter dùng cho ngày hiển thị trong Lịch chung.
/// Không dùng chuỗi đã dịch để lưu hoặc parse date key.
class CalendarDisplayFormat {
  const CalendarDisplayFormat({required this.locale});

  final Locale locale;

  String get intlLocale {
    final language = locale.languageCode;
    final normalized = locale.toLanguageTag().replaceAll('-', '_');
    // intl không có bộ ký hiệu riêng cho tl ở mọi phiên bản; fil là alias
    // được CLDR dùng cho cùng ngôn ngữ hiển thị.
    final candidate = language == 'tl' ? 'fil' : normalized;
    // Giữ biến thể vùng khi intl hỗ trợ; vùng chưa có dùng cùng ngôn ngữ.
    return Intl.verifiedLocale(
          candidate,
          DateFormat.localeExists,
          onFailure: (_) => 'en_US',
        ) ??
        'en_US';
  }

  String longDate(DateTime date) =>
      DateFormat.yMMMMEEEEd(intlLocale).format(date);

  String shortDate(DateTime date) => DateFormat.yMd(intlLocale).format(date);

  String time(DateTime date, {bool alwaysUse24HourFormat = false}) =>
      (alwaysUse24HourFormat
              ? DateFormat.Hm(intlLocale)
              : DateFormat.jm(intlLocale))
          .format(date);

  static CalendarDisplayFormat forLocale(Locale language, String marketCode) {
    return CalendarDisplayFormat(
      locale: AppLocaleRegistry.formattingLocale(language, marketCode),
    );
  }
}
