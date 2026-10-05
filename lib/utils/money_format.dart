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
      return NumberFormat.simpleCurrency(locale: LocaleDateFormat.intlLocale)
              .currencyName ??
          'USD';
    } catch (_) {
      return 'USD';
    }
  }

  static String normalizeCode(Object? raw) {
    final code = raw?.toString().trim().toUpperCase() ?? '';
    return RegExp(r'^[A-Z]{3}$').hasMatch(code) ? code : '';
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
