import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../models/utilities/finance_transaction.dart';

/// ============================================================
///  FinanceService — Gra (Logic/Data)
///  Kế toán Tình Yêu (Quỹ chung đôi) (Phase 10)
///
///  Chức năng:
///  1. Ghi nhận chi tiêu (Expense) hoặc Nạp tiền (Income).
///  2. Đấu nối cơ chế Khóa An Toàn 2 Lớp (Transaction):
///     Chỉ xoá hoá đơn khi được sự đồng ý của cả 2.
///  3. Tổng hợp biểu đồ (GroupBy) theo danh mục siêu tốc.
/// ============================================================
class FinanceService {
  static final FinanceService _instance = FinanceService._internal();
  factory FinanceService() => _instance;
  FinanceService._internal();

  final _db = FirebaseDatabase.instance;

  /// Nhập hoá đơn chi tiêu / nạp quỹ
  Future<void> addTransaction(String houseId, FinanceTransaction tr) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final ref = _db.ref('houses/$normalizedHouseId/finances').push();

    // Ghi hoá đơn lên Firebase Database
    await ref.set({
      ...tr.toMap(),
      'id': ref.key,
      'locked': false, // Mặc định chưa được chốt khoá
    });
  }

  /// Lắng nghe Realtime toàn bộ hoá đơn trong quỹ chung để Trae vẽ biểu đồ hình tròn
  Stream<List<FinanceTransaction>> getTransactions(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<FinanceTransaction>>.value(const []);
    }
    return _db
        .ref('houses/$normalizedHouseId/finances')
        .orderByChild('ts')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return data.entries
          .where((e) => e.value is Map)
          .map((e) => FinanceTransaction.fromMap(
                e.key.toString(),
                Map<dynamic, dynamic>.from(e.value as Map),
              ))
          .toList();
    });
  }

  /// Hệ thống khóa chống cãi nhau (Không cho xóa hoá đơn)
  /// Phải có người kia (Chữ ký điện tử/UID) duyệt thì mới cho phép xóa hoặc sửa.
  Future<bool> requestDeleteTransaction(
      String houseId, String transactionId, String requesterUid) async {
    final normalizedHouseId = houseId.trim();
    final normalizedTransactionId = transactionId.trim();
    final normalizedRequesterUid = requesterUid.trim();
    if (normalizedHouseId.isEmpty ||
        normalizedTransactionId.isEmpty ||
        normalizedRequesterUid.isEmpty) {
      return false;
    }
    final ref = _db.ref('houses/$normalizedHouseId/finances/$normalizedTransactionId');
    final snap = await ref.get();

    if (!snap.exists || snap.value is! Map) return false;
    final data = Map<dynamic, dynamic>.from(snap.value as Map);

    final bool isLocked = data['locked'] ?? false;

    if (isLocked) {
      // Đã nộp giấy tờ khoá tài khoản, kích hoạt luồng xin phép (Bật cờ yêu cầu xóa)
      await ref.child('delete_requests').update({
        normalizedRequesterUid: true,
      });

      // Kiểm tra xem người kia đã đồng ý xóa chưa?
      final reqSnap = await ref.child('delete_requests').get();
      if (reqSnap.exists &&
          reqSnap.value is Map &&
          (reqSnap.value as Map).length == 2) {
        // Cả 2 cùng đồng ý xóa (2 keys UID) (Bật transaction rỗng xóa data)
        await ref.remove();
        return true;
      }
      return false; // Phải đợi chữ ký của người kia
    } else {
      // Giao dịch lỗi hoặc vừa tạo (còn nóng), được phép xóa liền
      await ref.remove();
      return true;
    }
  }

  /// Chốt sổ (Khoá số liệu một tháng, không cho sửa bằng tay nữa)
  Future<void> lockMonthlyBook(String houseId, String transactionId) async {
    final normalizedHouseId = houseId.trim();
    final normalizedTransactionId = transactionId.trim();
    if (normalizedHouseId.isEmpty || normalizedTransactionId.isEmpty) return;
    await _db
        .ref('houses/$normalizedHouseId/finances/$normalizedTransactionId')
        .update({'locked': true});
  }
}
