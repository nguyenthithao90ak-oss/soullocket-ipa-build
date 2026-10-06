import 'package:intl/intl.dart';

import 'locale_date_format.dart';
import 'services/market_service.dart';

/// Định dạng số tiền theo loại tiền của "nhà" và cách viết số của người xem.
/// Số tiền được lưu là số nguyên (đơn vị chính, không phần lẻ) để tương thích
/// dữ liệu cũ, nên luôn hiển thị 0 chữ số thập phân.
abstract final class MoneyFormat {
  /// Đường dẫn lưu loại tiền dùng chung cho cả hai người trong nhà.
  static String houseCurrencyPath(String houseId) =>
      'houses/$houseId/settings/moneyCurrency';

  static const _currencyByMarket = <String, String>{
    'VN': 'VND', 'TH': 'THB', 'ID': 'IDR', 'PH': 'PHP', 'MY': 'MYR', //
    'JP': 'JPY', 'KR': 'KRW', 'TW': 'TWD', 'US': 'USD', 'BR': 'BRL', //
    'IN': 'INR', 'GB': 'GBP', 'CA': 'CAD', 'AU': 'AUD', 'SG': 'SGD', //
    'MX': 'MXN', 'AR': 'ARS', 'CO': 'COP', 'ES': 'EUR', 'FR': 'EUR', //
    'DE': 'EUR', 'IT': 'EUR', 'NL': 'EUR', 'PT': 'EUR', 'PL': 'PLN', //
    'TR': 'TRY', 'SA': 'SAR', 'AE': 'AED', 'EG': 'EGP', 'CN': 'CNY', //
    'RU': 'RUB', 'HK': 'HKD', 'MO': 'MOP', //
  };

  /// Loại tiền mặc định theo khu vực đã chọn/thiết bị, rồi theo ngôn ngữ.
  static String get defaultCurrencyCode {
    try {
      final byMarket = _currencyByMarket[MarketService.instance.marketCode];
      if (byMarket != null) return byMarket;
    } catch (_) {
      // MarketService chưa sẵn sàng: dùng ngôn ngữ.
    }
    try {
      return NumberFormat.simpleCurrency(
            locale: LocaleDateFormat.intlLocale,
          ).currencyName ??
          'USD';
    } catch (_) {
      return 'USD';
    }
  }

  static String normalizeCode(Object? raw) {
    final code = raw?.toString().trim().toUpperCase() ?? '';
    return RegExp(r'^[A-Z]{3}$').hasMatch(code) ? code : '';
  }

  /// Nhận số nguyên hoặc số có 1–2 chữ số lẻ, rồi làm tròn về đơn vị chính.
  /// Dấu chấm/phẩy có ba chữ số phía sau là phân nhóm hàng nghìn.
  /// Không xoá mù ký tự: dữ liệu sai hoặc vượt độ chính xác RTDB bị từ chối.
  static int? parseWholeAmount(String raw) {
    final digits = StringBuffer();
    for (final rune in raw.trim().runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        digits.write(rune - 0x0660);
      } else if (rune >= 0x06f0 && rune <= 0x06f9) {
        digits.write(rune - 0x06f0);
      } else if (rune >= 0xff10 && rune <= 0xff19) {
        digits.write(rune - 0xff10);
      } else if (rune == 0x066b) {
        digits.write('.');
      } else if (rune == 0x066c) {
        digits.write(',');
      } else {
        digits.writeCharCode(rune);
      }
    }
    final text = digits.toString().replaceAll(
      RegExp(r'[\s\u00a0\u202f\u2009]'),
      '',
    );
    if (!RegExp(r'^\+?\d+(?:[.,]\d+)*$').hasMatch(text)) return null;
    final unsigned = text.startsWith('+') ? text.substring(1) : text;
    final separator = unsigned.lastIndexOf(RegExp('[.,]'));
    var whole = unsigned;
    var roundUp = false;
    if (separator >= 0 && unsigned.length - separator - 1 <= 2) {
      whole = unsigned.substring(0, separator);
      if (whole.contains(unsigned[separator])) return null;
      roundUp = unsigned.codeUnitAt(separator + 1) >= 0x35;
    }
    if (!RegExp(r'^\d+$').hasMatch(whole) &&
        !RegExp(r'^\d{1,3}(?:,\d{3})+$').hasMatch(whole) &&
        !RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(whole) &&
        !RegExp(r'^\d{1,2}(?:,\d{2})*,\d{3}$').hasMatch(whole)) {
      return null;
    }
    final value =
        BigInt.parse(whole.replaceAll(RegExp('[.,]'), '')) +
        (roundUp ? BigInt.one : BigInt.zero);
    if (value > BigInt.from(9007199254740991)) return null;
    return value.toInt();
  }

  static NumberFormat forCurrency(String? currencyCode) {
    final code = normalizeCode(currencyCode);
    final resolved = code.isEmpty ? defaultCurrencyCode : code;
    try {
      return NumberFormat.simpleCurrency(
        locale: LocaleDateFormat.intlLocale,
        name: resolved,
        decimalDigits: 0,
      );
    } catch (_) {
      return NumberFormat.currency(
        name: resolved,
        symbol: resolved,
        decimalDigits: 0,
      );
    }
  }
}
