import 'package:firebase_database/firebase_database.dart';
import '../../models/utilities/finance_transaction.dart';

class FinanceService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Đẩy log thu chi lên máy chủ Firebase
  Future<void> addTransaction(
      String houseId, FinanceTransaction transaction) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final pushRef = _dbRef
        .child('houses/$normalizedHouseId/utilities/finance/transactions')
        .push();
    await pushRef.set(transaction.toMap());
    await _recalculateBalance(normalizedHouseId);
  }

  // Chỉnh sửa giao dịch bị sai
  Future<void> updateTransaction(
      String houseId, FinanceTransaction transaction) async {
    final normalizedHouseId = houseId.trim();
    final transactionId = transaction.id.trim();
    if (normalizedHouseId.isEmpty || transactionId.isEmpty) return;
    await _dbRef
        .child(
            'houses/$normalizedHouseId/utilities/finance/transactions/$transactionId')
        .update(transaction.toMap());
    await _recalculateBalance(normalizedHouseId);
  }

  // Xóa giao dịch nếu nhập lộn
  Future<void> deleteTransaction(String houseId, String transactionId) async {
    final normalizedHouseId = houseId.trim();
    final normalizedTransactionId = transactionId.trim();
    if (normalizedHouseId.isEmpty || normalizedTransactionId.isEmpty) return;
    await _dbRef
        .child(
            'houses/$normalizedHouseId/utilities/finance/transactions/$normalizedTransactionId')
        .remove();
    await _recalculateBalance(normalizedHouseId);
  }

  // Cung cấp luồng dữ liệu (Stream) dồi dào về cho Trae (AI 1) làm UI
  // Tự động phân tích và tạo List giao dịch mới nhất (Bỏ qua caching tạm thời)
  Stream<List<FinanceTransaction>> streamTransactions(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<FinanceTransaction>>.value(const []);
    }
    return _dbRef
        .child('houses/$normalizedHouseId/utilities/finance/transactions')
        .orderByChild('ts')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<FinanceTransaction> transactions = [];
      data.forEach((key, value) {
        if (value is! Map) return;
        final map = Map<dynamic, dynamic>.from(value);
        transactions.add(FinanceTransaction.fromMap(key, map));
      });
      // Sắp xếp giảm dần (mới nhất lên trên)
      transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return transactions;
    });
  }

  // Stream số dư (Balance) realtime cho UI
  Stream<double> streamBalance(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<double>.value(0.0);
    return _dbRef
        .child('houses/$normalizedHouseId/utilities/finance/balance')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return 0.0;
      return double.tryParse(event.snapshot.value.toString()) ?? 0.0;
    });
  }

  // [JS-05] Thuật toán tính toán số dư realtime (Hạch toán song song)
  Future<void> _recalculateBalance(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final ds = await _dbRef
        .child('houses/$normalizedHouseId/utilities/finance/transactions')
        .get();
    double totalBalance = 0;

    if (ds.exists) {
      final data = Map<dynamic, dynamic>.from(ds.value as Map);
      data.forEach((key, value) {
        if (value is! Map) return;
        final map = Map<dynamic, dynamic>.from(value);
        final tx = FinanceTransaction.fromMap(key, map);
        if (tx.type == 'in' || tx.type == 'income') {
          totalBalance += tx.amount;
        } else {
          totalBalance -= tx.amount;
        }
      });
    }

    // Chốt số dư ngay tức khắc
    await _dbRef
        .child('houses/$normalizedHouseId/utilities/finance/balance')
        .set(totalBalance);
  }

  // Thống kê tổng Quỹ chung, Tổng đã chi tháng này... (Để UI vẽ biểu đồ)
  Future<Map<String, double>> getMonthlyStats(
      String houseId, int month, int year) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return {'income': 0, 'expense': 0, 'balance': 0};
    }
    final ds = await _dbRef
        .child('houses/$normalizedHouseId/utilities/finance/transactions')
        .get();
    if (!ds.exists) return {'income': 0, 'expense': 0, 'balance': 0};

    double totalIncome = 0;
    double totalExpense = 0;

    final data = Map<dynamic, dynamic>.from(ds.value as Map);
    data.forEach((key, value) {
      if (value is! Map) return;
      final map = Map<dynamic, dynamic>.from(value);
      final tx = FinanceTransaction.fromMap(key, map);

      final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
      if (date.month == month && date.year == year) {
        if (tx.type == 'in' || tx.type == 'income') {
          totalIncome += tx.amount;
        } else {
          totalExpense += tx.amount;
        }
      }
    });

    return {
      'income': totalIncome, // Nạp quỹ
      'expense': totalExpense, // Đã tiêu
      'balance': totalIncome - totalExpense // Tiền quỹ dư lại
    };
  }

  // [JS-05] Tính năng Kế hoạch chi tiêu (Budget Plan)
  Future<void> saveBudgetPlan(String houseId, double amount, int days) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    await _dbRef.child('houses/$normalizedHouseId/utilities/finance/plan').set({
      'amount': amount,
      'days': days,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Stream<Map<dynamic, dynamic>?> streamBudgetPlan(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<Map<dynamic, dynamic>?>.value(null);
    }
    return _dbRef
        .child('houses/$normalizedHouseId/utilities/finance/plan')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return null;
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    });
  }
}
