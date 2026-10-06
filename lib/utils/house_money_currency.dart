import 'package:firebase_database/firebase_database.dart';

import 'money_format.dart';

/// Dùng chung cho Wishlist và Tài chính, không đổi đơn vị của số tiền đã lưu.
abstract final class HouseMoneyCurrency {
  static Future<String> ensure({
    required DatabaseReference root,
    required String houseId,
    required bool Function() isCurrent,
  }) async {
    final currency = root.child(MoneyFormat.houseCurrencyPath(houseId));
    final saved = MoneyFormat.normalizeCode((await currency.get()).value);
    if (!isCurrent()) throw StateError('session_changed');
    if (saved.isNotEmpty) return saved;

    // Các bản cũ lưu số tiền VND mà chưa có moneyCurrency.
    var hasLegacyAmounts = false;
    for (final feature in [
      'budget',
      'wishlist',
      'finance_plan',
      'savings_goal',
    ]) {
      final snapshot = await root
          .child('houses/$houseId/$feature')
          .limitToFirst(1)
          .get();
      if (!isCurrent()) throw StateError('session_changed');
      if (snapshot.exists) {
        hasLegacyAmounts = true;
        break;
      }
    }
    final fallback = hasLegacyAmounts ? 'VND' : MoneyFormat.defaultCurrencyCode;
    final result = await currency.runTransaction((current) {
      if (!isCurrent()) return Transaction.abort();
      if (MoneyFormat.normalizeCode(current).isNotEmpty) {
        return Transaction.abort();
      }
      return Transaction.success(fallback);
    }, applyLocally: false);
    if (!isCurrent()) throw StateError('session_changed');
    final resolved = MoneyFormat.normalizeCode(result.snapshot.value);
    if (resolved.isEmpty) throw StateError('money_currency_unavailable');
    return resolved;
  }
}
